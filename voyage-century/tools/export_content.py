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
import re
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

    # Häfen: belegt durch Schiffsumbau in der Stadt (macht der Werftmeister, SHIP-ACQUISITION) oder durch
    # einen Dienst im Hafen (Offizierskarten-Tausch). Alle anderen Dienste bleiben NULL = UNKNOWN.
    ports: dict[str, dict] = {}

    def port(city_id: str, rec: dict) -> dict:
        if city_id not in records or records[city_id]["entity"] != "CITY":
            raise SystemExit(f"{rec['id']}: Hafen verweist auf unbekannte Stadt {city_id}")
        return ports.setdefault(city_id, {"city": strip_prefix(city_id), "has_shipyard": None, "services": {},
                                          "recon_id": rec["id"], "confidence": rec["confidence"]})

    for r in by_entity.get("SHIP_MOD_TIER", []):
        if isinstance(r["data"].get("cities"), list):
            for city_id in r["data"]["cities"]:
                port(city_id, r)["has_shipyard"] = True
    officer_cards = records.get("SYS-OFFICER-CARDS")
    if officer_cards and known(officer_cards["data"].get("exchange_city")):
        port(officer_cards["data"]["exchange_city"], officer_cards)["services"]["officer_card_exchange"] = True
    rows["ports"] = list(ports.values())

    total_cap = records.get("SKILL-TOTAL-CAP")
    rows["game_rules"] = [
        {"rule_key": "SKILL_TOTAL_CAP", "int_value": total_cap["data"]["total_cap"],
         "recon_id": total_cap["id"], "confidence": total_cap["confidence"]}
    ] if total_cap and isinstance(known(total_cap["data"].get("total_cap")), int) else []

    for key, value in rows.items():
        value.sort(key=lambda row: row.get("code", row.get("stage_no", row.get("rule_key", row.get("city")))))
    return rows


def dev_curve(spec: dict) -> list[dict]:
    """Entwicklungskurve aus design_data/dev_curves.json (is_dev = TRUE, Confidence UNKNOWN)."""
    return [
        {"level": lvl, "xp_required": spec["xp_factor"] * (lvl - 1) ** 2, "is_dev": True,
         "recon_id": None, "confidence": "UNKNOWN"}
        for lvl in range(1, spec["max_level"] + 1)
    ]


WEAPON_CLASS_UE = {"SWORD": "Sword", "BLADE": "Blade", "AXE": "Axe", "FIREARM": "Firearm", "UNARMED": "Unarmed"}


def resolve_tuning(tuning: dict, records: dict[str, dict]) -> tuple[dict, dict]:
    """Löst from_recon-Verweise auf. Liefert (Werte, {Feld: recon_id})."""
    values, origins = {}, {}
    for key, value in tuning.items():
        if isinstance(value, dict) and "from_recon" in value:
            rec = records.get(value["from_recon"])
            resolved = known(rec["data"].get(value["field"])) if rec else None
            if not isinstance(resolved, (int, float)):
                raise SystemExit(f"design_data/dev_combat.json: {key} verweist auf {value['from_recon']}, Wert fehlt")
            values[key] = resolved
            origins[key] = rec["id"]
        else:
            values[key] = value
    return values, origins


TARGET_UE = {"ENEMY": "Enemy", "SELF": "Caster"}
STATUS_KIND_UE = {"BUFF": "Buff", "DEBUFF": "Debuff"}
STATUS_MODIFIERS = ("attack_power", "defense", "crit_chance", "block_chance", "dodge_chance", "move_speed_multiplier", "stunned")


def check_abilities(abilities: dict, skill_codes: set[str]) -> None:
    """Querverweise prüfen: Skills, Waffenarten, Ziele und Statuseffekte müssen existieren."""
    status_codes = {s["code"] for s in abilities["status_effects"]}
    problems = []
    for s in abilities["status_effects"]:
        if s["kind"] not in STATUS_KIND_UE:
            problems.append(f"{s['code']}: unbekannte Art {s['kind']}")
        if s["max_stacks"] < 1 or s["duration_seconds"] <= 0:
            problems.append(f"{s['code']}: Dauer und Stapel müssen positiv sein")
        for key in s["modifiers"]:
            if key not in STATUS_MODIFIERS:
                problems.append(f"{s['code']}: unbekannter Modifikator {key}")
    for a in abilities["abilities"]:
        if a["skill"] not in skill_codes:
            problems.append(f"{a['code']}: Skill {a['skill']} nicht in der Reconstruction Database")
        if a["weapon_class"] is not None and a["weapon_class"] not in WEAPON_CLASS_UE:
            problems.append(f"{a['code']}: unbekannte Waffenart {a['weapon_class']}")
        if a["target"] not in TARGET_UE:
            problems.append(f"{a['code']}: unbekanntes Ziel {a['target']}")
        for code in a["applies"]:
            if code not in status_codes:
                problems.append(f"{a['code']}: Statuseffekt {code} fehlt")
    if problems:
        raise SystemExit("design_data/dev_abilities.json:\n  " + "\n  ".join(problems))


ZONE_KINDS = {"SEA", "CITY", "LAND", "DUNGEON", "BATTLEFIELD"}
# Zonen, die eine Migration anlegt (nicht im Layout, aber als Ziel von Übergängen erlaubt).
MIGRATION_ZONES = {"DEV_TESTZONE"}
TAG_RE = re.compile(r"^[A-Z0-9_]{1,32}$")


def check_world(layout: dict, records: dict[str, dict]) -> None:
    problems = []
    zone_ids = {z["zone_id"] for z in layout["zones"]}
    for z in layout["zones"]:
        if z["kind"] not in ZONE_KINDS:
            problems.append(f"{z['zone_id']}: unbekannte Zonenart {z['kind']}")
        if z["city"] is not None and (z["city"] not in records or records[z["city"]]["entity"] != "CITY"):
            problems.append(f"{z['zone_id']}: Stadt {z['city']} nicht in der Reconstruction Database")
        if z["pvp_mode"] not in ("NONE", "FREE"):
            problems.append(f"{z['zone_id']}: pvp_mode {z['pvp_mode']}")
    seen = set()
    for link in layout["links"]:
        where = f"{link['from']}/{link['exit']}"
        for end in (link["from"], link["to"]):
            if end not in zone_ids | MIGRATION_ZONES:
                problems.append(f"{where}: unbekannte Zone {end}")
        if not TAG_RE.match(link["exit"]) or not TAG_RE.match(link["arrival"]):
            problems.append(f"{where}: Ausgang und Ankunft nur A-Z, 0-9, _ (max. 32)")
        if (link["from"], link["exit"]) in seen:
            problems.append(f"{where}: Ausgang doppelt")
        seen.add((link["from"], link["exit"]))
    if problems:
        raise SystemExit("design_data/world_layout.json:\n  " + "\n  ".join(problems))


def camel(key: str) -> str:
    return "".join(part.capitalize() for part in key.split("_"))


class SqlExpr(str):
    """Wird unverändert ins SQL übernommen (z. B. Unterabfrage für Fremdschlüssel)."""


def sql_literal(value) -> str:
    if isinstance(value, SqlExpr):
        return str(value)
    if value is None:
        return "NULL"
    if isinstance(value, dict):
        return "'" + json.dumps(value, ensure_ascii=False, sort_keys=True).replace("'", "''") + "'::jsonb"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def upsert(table: str, key: str | tuple[str, ...], columns: list[str], rows: list[dict]) -> str:
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
    keys = (key,) if isinstance(key, str) else key
    updates = ",\n    ".join(f"{c} = EXCLUDED.{c}" for c in columns if c not in keys)
    return (
        f"INSERT INTO {table} ({', '.join(columns)}) VALUES\n"
        + ",\n".join(values)
        + f"\nON CONFLICT ({', '.join(keys)}) DO UPDATE SET\n    {updates};\n"
    )


def render_sql(rows: dict[str, list[dict]], curves: dict, appearance: dict, combat: dict, abilities: dict,
               world: dict) -> str:
    name_cols = ["name_zh", "name_en", "name_de"]
    city_zones = {strip_prefix(z["city"]): z["zone_id"] for z in world["zones"] if z["city"]}

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
        "-- Zonen und Übergänge (design_data/world_layout.json, Designentscheidung). Zonen vor Städten wegen cities.zone_id.\n",
        upsert("zones", "zone_id", ["zone_id", "zone_kind", "map_asset", "max_players", "pvp_mode", "is_dev"],
               [{"zone_id": z["zone_id"], "zone_kind": z["kind"], "map_asset": z["map_asset"], "max_players": z["max_players"],
                 "pvp_mode": z["pvp_mode"], "is_dev": z["is_dev"]} for z in sorted(world["zones"], key=lambda z: z["zone_id"])]),
        upsert("cities", "code", ["code", *name_cols, "coord_as_given", "zone_id", "recon_id", "confidence"],
               [{**c, "zone_id": city_zones.get(c["code"])} for c in renamed(rows["cities"])]),
        upsert("ports", "city_id", ["city_id", "has_shipyard", "services", "recon_id", "confidence"],
               [{"city_id": SqlExpr(f"(SELECT city_id FROM cities WHERE code = {sql_literal(p['city'])})"),
                 "has_shipyard": p["has_shipyard"], "services": p["services"], "recon_id": p["recon_id"],
                 "confidence": p["confidence"]} for p in rows["ports"]]),
        upsert("zone_links", ("from_zone_id", "exit_code"), ["from_zone_id", "exit_code", "to_zone_id", "arrival_tag"],
               [{"from_zone_id": link["from"], "exit_code": link["exit"], "to_zone_id": link["to"], "arrival_tag": link["arrival"]}
                for link in sorted(world["links"], key=lambda link: (link["from"], link["exit"]))]),
        upsert("item_sets", "code", ["code", *name_cols, "level", "recon_id", "confidence"],
               renamed(rows["item_sets"])),
        upsert("game_rules", "rule_key", ["rule_key", "int_value", "recon_id", "confidence"], rows["game_rules"]),
        "-- Entwicklungskurven (design_data/dev_curves.json). Echte Werte aus der Reconstruction Database\n"
        "-- überschreiben einzelne Stufen, sobald sie belegt sind (dann is_dev = FALSE).\n",
        upsert("appearance_slots", "slot", ["slot", "option_count", "sort_order", "is_dev", "recon_id", "confidence"],
               [{"slot": a["slot"], "option_count": a["option_count"], "sort_order": i, "is_dev": True,
                 "recon_id": None, "confidence": "UNKNOWN"} for i, a in enumerate(appearance["slots"])]),
        "-- Entwicklungsinhalte Landkampf (design_data/dev_combat.json, is_dev = TRUE).\n",
        upsert("items", "code", ["code", "item_type", "weapon_class", "name_de", "base_stats", "durability_max", "is_dev", "confidence"],
               [{"code": w["code"], "item_type": "WEAPON", "weapon_class": w["class"], "name_de": w["name_de"],
                 "base_stats": {"baseDamage": w["base_damage"], "attackInterval": w["attack_interval"], "rangeCm": w["range_cm"],
                                "skill": w["skill"]},
                 "durability_max": w["durability"], "is_dev": True, "confidence": "UNKNOWN"}
                for w in combat["weapons"] if w["class"] != "UNARMED"]),
        upsert("monsters", "code", ["code", "name_de", "domain", "is_pirate", "level", "hp", "stats", "xp_reward", "is_dev", "confidence"],
               [{"code": m["code"], "name_de": m["name_de"], "domain": "LAND", "is_pirate": m["is_pirate"], "level": m["level"],
                 "hp": m["max_health"],
                 "stats": {k: m[k] for k in ("attack_power", "defense", "base_damage", "attack_interval", "range_cm",
                                             "aggro_radius_cm", "leash_radius_cm", "respawn_seconds")},
                 "xp_reward": m["xp_reward"], "is_dev": True, "confidence": "UNKNOWN"}
                for m in combat["monsters"]]),
        "-- Entwicklungsfähigkeiten (design_data/dev_abilities.json, is_dev = TRUE). Statuseffekte sind reine\n"
        "-- Laufzeit des Zonen-Servers (DT_StatusEffects) und werden nicht gespeichert.\n",
        upsert("abilities", "code", ["code", "skill_id", "name_de", "ability_kind", "domain", "required_skill_level",
                                     "gas_ability_class", "params", "is_dev", "confidence"],
               [{"code": a["code"],
                 "skill_id": SqlExpr(f"(SELECT skill_id FROM skills WHERE code = {sql_literal(a['skill'])})"),
                 "name_de": a["name_de"], "ability_kind": "ACTIVE", "domain": "LAND",
                 "required_skill_level": a["required_skill_level"], "gas_ability_class": "VCAbility_UseSkill",
                 "params": {k: a[k] for k in ("weapon_class", "stamina_cost", "cooldown_seconds", "damage_multiplier",
                                              "range_cm", "target", "applies")},
                 "is_dev": True, "confidence": "UNKNOWN"}
                for a in sorted(abilities["abilities"], key=lambda a: a["code"])]),
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


def render_ue(rows: dict[str, list[dict]], appearance: dict, combat: dict, abilities: dict) -> dict[str, list[dict]]:
    return {
        "DT_Abilities.json": [
            {"Name": a["code"], "NameDe": a["name_de"], "SkillCode": a["skill"], "RequiredSkillLevel": a["required_skill_level"],
             "bRequiresWeaponClass": a["weapon_class"] is not None,
             "RequiredWeaponClass": WEAPON_CLASS_UE[a["weapon_class"] or "UNARMED"],
             "StaminaCost": a["stamina_cost"], "CooldownSeconds": a["cooldown_seconds"],
             "DamageMultiplier": a["damage_multiplier"], "RangeCm": a["range_cm"], "TargetMode": TARGET_UE[a["target"]],
             "AppliedStatuses": a["applies"], "bIsDev": True}
            for a in sorted(abilities["abilities"], key=lambda a: a["code"])
        ],
        "DT_StatusEffects.json": [
            {"Name": s["code"], "NameDe": s["name_de"], "Kind": STATUS_KIND_UE[s["kind"]],
             "DurationSeconds": s["duration_seconds"], "MaxStacks": s["max_stacks"],
             "AttackPower": s["modifiers"].get("attack_power", 0), "Defense": s["modifiers"].get("defense", 0),
             "CritChance": s["modifiers"].get("crit_chance", 0), "BlockChance": s["modifiers"].get("block_chance", 0),
             "DodgeChance": s["modifiers"].get("dodge_chance", 0),
             "MoveSpeedMultiplier": s["modifiers"].get("move_speed_multiplier", 1),
             "bStunned": s["modifiers"].get("stunned", False),
             "TickIntervalSeconds": s["tick_interval_seconds"], "DamagePerTick": s["damage_per_tick"],
             "HealPerTick": s["heal_per_tick"], "bIsDev": True}
            for s in sorted(abilities["status_effects"], key=lambda s: s["code"])
        ],
        "DT_CombatTuning.json": [
            {"Name": "Default", **{camel(k): v for k, v in combat["tuning"].items()},
             "ReconSources": ", ".join(f"{camel(k)}={v}" for k, v in sorted(combat["tuning_origins"].items()))}
        ],
        "DT_Weapons.json": [
            {"Name": w["code"], "NameDe": w["name_de"], "WeaponClass": WEAPON_CLASS_UE[w["class"]], "SkillCode": w["skill"],
             "BaseDamage": w["base_damage"], "AttackInterval": w["attack_interval"], "RangeCm": w["range_cm"],
             "DurabilityMax": w["durability"] or 0, "bIsDev": True}
            for w in combat["weapons"]
        ],
        "DT_Monsters.json": [
            {"Name": m["code"], "NameDe": m["name_de"], "bIsPirate": m["is_pirate"], "Level": m["level"],
             "MaxHealth": m["max_health"], "AttackPower": m["attack_power"], "Defense": m["defense"],
             "BaseDamage": m["base_damage"], "AttackInterval": m["attack_interval"], "RangeCm": m["range_cm"],
             "AggroRadiusCm": m["aggro_radius_cm"], "LeashRadiusCm": m["leash_radius_cm"],
             "XpReward": m["xp_reward"], "RespawnSeconds": m["respawn_seconds"], "bIsDev": True}
            for m in combat["monsters"]
        ],
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
    combat = json.loads((DESIGN_DIR / "dev_combat.json").read_text(encoding="utf-8"))
    combat["tuning"], combat["tuning_origins"] = resolve_tuning(combat["tuning"], load_records())
    abilities = json.loads((DESIGN_DIR / "dev_abilities.json").read_text(encoding="utf-8"))
    check_abilities(abilities, {r["code"] for r in rows["skills"]})
    world = json.loads((DESIGN_DIR / "world_layout.json").read_text(encoding="utf-8"))
    check_world(world, load_records())
    files = {SEED_FILE: render_sql(rows, curves, appearance, combat, abilities, world)}
    for name, table in render_ue(rows, appearance, combat, abilities).items():
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
