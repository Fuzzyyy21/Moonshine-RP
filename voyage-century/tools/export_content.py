#!/usr/bin/env python3
"""Erzeugt aus der Reconstruction Database die abgeleiteten Spieldaten.

Ausgaben (nie von Hand bearbeiten):
    database/seed/R__content.sql                        Upserts für statische Tabellen
    unreal/VoyageCentury/Content/Data/Generated/*.json  Quellen für UE Data Tables

Eingaben:
    reconstruction_db/*.json   Originalbefunde (wird vorher validiert)
    design_data/*.json         Designentscheidungen (Priorität 6), z. B. UI-Gruppen

Aufruf:
    python3 tools/export_content.py           Dateien schreiben
    python3 tools/export_content.py --check   nur prüfen, ob die Dateien aktuell sind (für CI)

Unbekannte Werte ("UNKNOWN") werden zu NULL bzw. leeren Feldern. Es werden keine
Werte ergänzt, die nicht in den Eingaben stehen.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from validate_reconstruction_db import validate  # noqa: E402

DB_DIR = ROOT / "reconstruction_db"
DESIGN_DIR = ROOT / "design_data"
SEED_FILE = ROOT / "database" / "seed" / "R__content.sql"
UE_DATA_DIR = ROOT / "unreal" / "VoyageCentury" / "Content" / "Data" / "Generated"

CATEGORY_CN = {"战斗系": "COMBAT", "贸易系": "TRADE", "采集系": "GATHERING", "生产系": "PRODUCTION"}
UE_CONFIDENCE = {"CONFIRMED": "Confirmed", "LIKELY": "Likely", "UNCERTAIN": "Uncertain", "UNKNOWN": "Unknown"}
UE_CATEGORY = {None: "Unknown", "COMBAT": "Combat", "TRADE": "Trade", "GATHERING": "Gathering", "PRODUCTION": "Production"}
UE_UI_GROUP = {"COMBAT": "Combat", "SEAFARING": "Seafaring", "PROFESSION": "Profession"}


def known(value):
    """UNKNOWN und leere Werte werden zu None."""
    if value is None or value == "UNKNOWN" or value == "":
        return None
    return value


def load_records() -> dict[str, dict]:
    records: dict[str, dict] = {}
    for path in sorted(DB_DIR.glob("*.json")):
        if path.name == "sources.json":
            continue
        for rec in json.loads(path.read_text(encoding="utf-8"))["records"]:
            records[rec["id"]] = rec
    return records


def strip_prefix(record_id: str) -> str:
    return record_id.split("-", 1)[1]


def names(rec: dict) -> dict:
    return {k: known(rec["names"].get(k)) for k in ("zh", "en", "de")}


def build_rows(records: dict[str, dict], ui_groups: dict[str, str]) -> dict[str, list[dict]]:
    by_entity: dict[str, list[dict]] = {}
    for rec in records.values():
        by_entity.setdefault(rec["entity"], []).append(rec)

    rows: dict[str, list[dict]] = {}

    rows["professions"] = [
        {"code": strip_prefix(r["id"]), **names(r), "recon_id": r["id"], "confidence": r["confidence"]}
        for r in by_entity.get("PROFESSION", [])
    ]

    skills = []
    for r in by_entity.get("SKILL", []):
        if r["id"] not in ui_groups:
            raise SystemExit(f"design_data/skill_ui_groups.json: keine UI-Gruppe für {r['id']}")
        skills.append({
            "code": strip_prefix(r["id"]), **names(r),
            "category_cn": CATEGORY_CN.get(r["data"].get("category_cn")),
            "ui_group": ui_groups[r["id"]],
            "recon_id": r["id"], "confidence": r["confidence"],
        })
    rows["skills"] = skills

    stage_rec = records.get("SKILL-STAGES")
    rows["skill_stages"] = [
        {"stage_no": s["stage"], "max_level": s["max_level"], "recon_id": stage_rec["id"],
         "confidence": stage_rec["confidence"]}
        for s in (stage_rec["data"]["stages"] if stage_rec else [])
    ]

    rows["ship_classes"] = [
        {"code": strip_prefix(r["id"]), **names(r), "leveled_by": known(r["data"].get("leveled_by")),
         "recon_id": r["id"], "confidence": r["confidence"]}
        for r in by_entity.get("SHIP_CLASS", [])
    ]

    # Sammeleinträge (z. B. CITY-LIST-17173) haben keine Einzelstadt und werden übersprungen.
    rows["cities"] = [
        {"code": strip_prefix(r["id"]), **names(r), "coord_as_given": known(r["data"].get("coord_as_given")),
         "recon_id": r["id"], "confidence": r["confidence"]}
        for r in by_entity.get("CITY", []) if "cities_zh" not in r["data"]
    ]

    rows["item_sets"] = [
        {"code": strip_prefix(r["id"]), **names(r), "level": known(r["data"].get("level")),
         "recon_id": r["id"], "confidence": r["confidence"]}
        for r in by_entity.get("EQUIPMENT_SET", [])
    ]

    total_cap = records.get("SKILL-TOTAL-CAP")
    rows["game_rules"] = [
        {"rule_key": "SKILL_TOTAL_CAP", "int_value": total_cap["data"]["total_cap"],
         "recon_id": total_cap["id"], "confidence": total_cap["confidence"]}
    ] if total_cap and isinstance(known(total_cap["data"].get("total_cap")), int) else []

    for key, value in rows.items():
        value.sort(key=lambda row: row.get("code", row.get("stage_no", row.get("rule_key"))))
    return rows


def dev_curve(spec: dict) -> list[dict]:
    """Entwicklungskurve aus design_data/dev_curves.json (is_dev = TRUE, Confidence UNKNOWN)."""
    return [
        {"level": lvl, "xp_required": spec["xp_factor"] * (lvl - 1) ** 2, "is_dev": True,
         "recon_id": None, "confidence": "UNKNOWN"}
        for lvl in range(1, spec["max_level"] + 1)
    ]


def sql_literal(value) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def upsert(table: str, key: str, columns: list[str], rows: list[dict]) -> str:
    if not rows:
        return f"-- {table}: keine Datensätze\n"
    values = []
    for row in rows:
        cells = []
        for col in columns:
            lit = sql_literal(row[col])
            if col == "confidence":
                lit += "::confidence_level"
            cells.append(lit)
        values.append("    (" + ", ".join(cells) + ")")
    updates = ",\n    ".join(f"{c} = EXCLUDED.{c}" for c in columns if c != key)
    return (
        f"INSERT INTO {table} ({', '.join(columns)}) VALUES\n"
        + ",\n".join(values)
        + f"\nON CONFLICT ({key}) DO UPDATE SET\n    {updates};\n"
    )


def render_sql(rows: dict[str, list[dict]], curves: dict, appearance: dict) -> str:
    name_cols = ["name_zh", "name_en", "name_de"]

    def renamed(table_rows):
        return [{**{k: v for k, v in r.items() if k not in ("zh", "en", "de")},
                 "name_zh": r.get("zh"), "name_en": r.get("en"), "name_de": r.get("de")} for r in table_rows]

    parts = [
        "-- GENERIERT von tools/export_content.py aus reconstruction_db/ und design_data/.\n"
        "-- Nicht von Hand bearbeiten. Wird vom Migrator als wiederholbares Skript ausgeführt,\n"
        "-- sobald sich der Inhalt ändert. Feldgenaue Confidence steht im Datensatz recon_id.\n"
        "-- Entfernte Datensätze werden hier nicht gelöscht, weil Laufzeitdaten darauf verweisen können.\n",
        upsert("professions", "code", ["code", *name_cols, "recon_id", "confidence"], renamed(rows["professions"])),
        upsert("skills", "code", ["code", "category_cn", "ui_group", *name_cols, "recon_id", "confidence"],
               renamed(rows["skills"])),
        upsert("skill_stages", "stage_no", ["stage_no", "max_level", "recon_id", "confidence"], rows["skill_stages"]),
        upsert("ship_classes", "code", ["code", *name_cols, "leveled_by", "recon_id", "confidence"],
               renamed(rows["ship_classes"])),
        upsert("cities", "code", ["code", *name_cols, "coord_as_given", "recon_id", "confidence"],
               renamed(rows["cities"])),
        upsert("item_sets", "code", ["code", *name_cols, "level", "recon_id", "confidence"],
               renamed(rows["item_sets"])),
        upsert("game_rules", "rule_key", ["rule_key", "int_value", "recon_id", "confidence"], rows["game_rules"]),
        "-- Entwicklungskurven (design_data/dev_curves.json). Echte Werte aus der Reconstruction Database\n"
        "-- überschreiben einzelne Stufen, sobald sie belegt sind (dann is_dev = FALSE).\n",
        upsert("appearance_slots", "slot", ["slot", "option_count", "sort_order", "is_dev", "recon_id", "confidence"],
               [{"slot": a["slot"], "option_count": a["option_count"], "sort_order": i, "is_dev": True,
                 "recon_id": None, "confidence": "UNKNOWN"} for i, a in enumerate(appearance["slots"])]),
        upsert("level_table", "level", ["level", "xp_required", "is_dev", "recon_id", "confidence"],
               dev_curve(curves["character_levels"])),
        upsert("skill_level_table", "level", ["level", "xp_required", "is_dev", "recon_id", "confidence"],
               dev_curve(curves["skill_levels"])),
    ]
    return "\n".join(parts)


def ue_common(row: dict) -> dict:
    return {
        "NameZh": row["zh"] or "", "NameEn": row["en"] or "", "NameDe": row["de"] or "",
        "ReconId": row["recon_id"], "Confidence": UE_CONFIDENCE[row["confidence"]],
    }


def render_ue(rows: dict[str, list[dict]], appearance: dict) -> dict[str, list[dict]]:
    return {
        "DT_AppearanceSlots.json": [
            {"Name": a["slot"], "OptionCount": a["option_count"], "SortOrder": i} for i, a in enumerate(appearance["slots"])
        ],
        "DT_Professions.json": [{"Name": r["code"], **ue_common(r)} for r in rows["professions"]],
        "DT_Skills.json": [
            {"Name": r["code"], **ue_common(r), "CategoryCn": UE_CATEGORY[r["category_cn"]],
             "UiGroup": UE_UI_GROUP[r["ui_group"]]}
            for r in rows["skills"]
        ],
        "DT_SkillStages.json": [
            {"Name": f"STAGE_{r['stage_no']}", "StageNo": r["stage_no"], "MaxLevel": r["max_level"],
             "ReconId": r["recon_id"], "Confidence": UE_CONFIDENCE[r["confidence"]]}
            for r in rows["skill_stages"]
        ],
        "DT_ShipClasses.json": [
            {"Name": r["code"], **ue_common(r), "LeveledBy": r["leveled_by"] or ""} for r in rows["ship_classes"]
        ],
    }


def outputs() -> dict[Path, str]:
    errors, _, _ = validate(DB_DIR)
    if errors:
        raise SystemExit("Reconstruction Database ungültig, Export abgebrochen:\n  " + "\n  ".join(errors))
    design = json.loads((DESIGN_DIR / "skill_ui_groups.json").read_text(encoding="utf-8"))
    rows = build_rows(load_records(), design["groups"])

    curves = json.loads((DESIGN_DIR / "dev_curves.json").read_text(encoding="utf-8"))
    appearance = json.loads((DESIGN_DIR / "appearance.json").read_text(encoding="utf-8"))
    files = {SEED_FILE: render_sql(rows, curves, appearance)}
    for name, table in render_ue(rows, appearance).items():
        files[UE_DATA_DIR / name] = json.dumps(table, ensure_ascii=False, indent=2) + "\n"
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="nur prüfen, nichts schreiben")
    args = parser.parse_args()

    stale = []
    for path, content in outputs().items():
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current == content:
            continue
        if args.check:
            stale.append(path.relative_to(ROOT))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            print(f"geschrieben: {path.relative_to(ROOT)}")

    if stale:
        print("Veraltet, bitte tools/export_content.py ausführen:")
        for p in stale:
            print(f"  - {p}")
        return 1
    if args.check:
        print("Abgeleitete Dateien sind aktuell.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
