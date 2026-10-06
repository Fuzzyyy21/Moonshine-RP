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


CONFIDENCE_ORDER = ["UNKNOWN", "UNCERTAIN", "LIKELY", "CONFIRMED"]


def weakest(*levels: str) -> str:
    return min(levels, key=CONFIDENCE_ORDER.index)


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

    # Anfängerschiff: als Sonderschiff belegt (SHIP-TIERS-INTL), Klasse im Original UNKNOWN → eigene Klasse BEGINNER.
    tiers = records.get("SHIP-TIERS-INTL")
    if tiers and "Anfängerschiff" in (tiers["data"].get("special_ships") or []):
        rows["ship_classes"].append({"code": "BEGINNER", "zh": None, "en": None, "de": "Anfängerschiff", "leveled_by": None,
                                     "recon_id": tiers["id"], "confidence": tiers["confidence"]})

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

    # NPCs, deren Rolle und Ort belegt sind. Einzelne Namen sind UNKNOWN; der Name ist der Rollentitel der Quelle.
    # Der Hafenarbeiter (SAILOR-SYSTEM) hat keinen belegten Ort und wird deshalb nicht platziert.
    npcs = []
    acquisition = records.get("SHIP-ACQUISITION")
    if acquisition:
        for p in ports.values():
            if p["has_shipyard"]:
                npcs.append({"code": f"{p['city']}_SHIPYARD", "role": "SHIPYARD", "city": p["city"], **names(acquisition),
                             "recon_id": acquisition["id"], "confidence": weakest(acquisition["confidence"], p["confidence"])})
    if officer_cards and known(officer_cards["data"].get("exchange_city")):
        city = strip_prefix(officer_cards["data"]["exchange_city"])
        npcs.append({"code": f"{city}_OFFICER_EXCHANGE", "role": "OFFICER_EXCHANGE", "city": city,
                     "zh": known(officer_cards["data"].get("exchange_npc_title_zh")), "en": None, "de": "Offizierskarten-Tauscher",
                     "recon_id": officer_cards["id"], "confidence": officer_cards["confidence"]})
    rows["npcs"] = npcs

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


def upsert(table: str, key: str | tuple[str, ...], columns: list[str], rows: list[dict],
           insert_only: tuple[str, ...] = ()) -> str:
    """insert_only: Spalten, die nur beim Anlegen gesetzt werden (Laufzeitstand wie Marktbestände bleibt erhalten)."""
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
    updates = ",\n    ".join(f"{c} = EXCLUDED.{c}" for c in columns if c not in keys and c not in insert_only)
    action = f"DO UPDATE SET\n    {updates}" if updates else "DO NOTHING"
    return (
        f"INSERT INTO {table} ({', '.join(columns)}) VALUES\n"
        + ",\n".join(values)
        + f"\nON CONFLICT ({', '.join(keys)}) {action};\n"
    )


def render_sql(rows: dict[str, list[dict]], curves: dict, appearance: dict, combat: dict, abilities: dict,
               world: dict, discoveries: dict, ships: dict, trade: dict, loot: dict, crafting: dict, auction: dict) -> str:
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
        upsert("npcs", "code", ["code", *name_cols, "npc_role", "port_id", "zone_id", "recon_id", "confidence"],
               [{**n, "npc_role": n["role"],
                 "port_id": SqlExpr(f"(SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = {sql_literal(n['city'])})"),
                 "zone_id": city_zones.get(n["city"])}
                for n in renamed(rows["npcs"])]),
        "-- Entdeckungen (design_data/dev_discoveries.json, is_dev = TRUE).\n",
        upsert("discoveries", "code", ["code", "zone_id", "name_de", "xp_reward", "is_dev", "confidence"],
               [{"code": d["code"], "zone_id": d["zone"], "name_de": d["name_de"], "xp_reward": d["xp_reward"], "is_dev": True,
                 "confidence": "UNKNOWN"} for d in sorted(discoveries["discoveries"], key=lambda d: d["code"])]),
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
        "-- Entwicklungsschiffe (design_data/dev_ships.json, is_dev = TRUE).\n",
        upsert("ships", "code", ["code", "name_de", "ship_class_id", "ship_level", "hull_hp", "speed", "acceleration", "deceleration",
                                 "turning", "crew_min", "crew_capacity", "cargo_capacity", "wind_efficiency", "cost_gold",
                                 "one_per_character", "start_crew", "start_provisions", "provisions_max", "cannon_slots",
                                 "is_dev", "confidence"],
               [{"code": sh["code"], "name_de": sh["name_de"],
                 "ship_class_id": SqlExpr(f"(SELECT ship_class_id FROM ship_classes WHERE code = {sql_literal(sh['class'])})"),
                 "ship_level": sh["level"], "hull_hp": sh["hull_hp"], "speed": sh["max_speed"], "acceleration": sh["acceleration"],
                 "deceleration": sh["deceleration"], "turning": sh["turn_rate"], "crew_min": sh["crew_min"],
                 "crew_capacity": sh["crew_max"], "cargo_capacity": sh["cargo"], "wind_efficiency": sh["wind_efficiency"],
                 "cost_gold": sh["cost_gold"], "one_per_character": sh["one_per_character"],
                 "start_crew": start_crew(sh, ships), "start_provisions": sh["start_provisions"],
                 "provisions_max": sh["start_provisions"], "cannon_slots": sh["cannon_slots"], "is_dev": True,
                 "confidence": "UNKNOWN"} for sh in sorted(ships["ships"], key=lambda sh: sh["code"])]),
        "-- Hafenpreise (design_data/dev_ships.json, UNKNOWN im Original, is_dev = TRUE).\n",
        upsert("game_rules", "rule_key", ["rule_key", "int_value", "is_dev", "confidence"],
               [{"rule_key": key, "int_value": ships["services"][field], "is_dev": True, "confidence": "UNKNOWN"}
                for key, field in sorted(SERVICE_RULES.items())]),
        "-- Piratenschiffe als Gegner (Kill-Belohnung wie bei Landgegnern über monsters).\n",
        upsert("monsters", "code", ["code", "name_de", "domain", "is_pirate", "hp", "stats", "xp_reward", "is_dev", "confidence"],
               [{"code": pr["code"], "name_de": pr["name_de"], "domain": "SEA", "is_pirate": True, "hp": pr["ship"]["hull_hp"],
                 "stats": {k: pr[k] for k in ("crew", "cannon", "aggro_radius_cm", "leash_radius_cm", "respawn_seconds")},
                 "xp_reward": pr["xp_reward"], "is_dev": True, "confidence": "UNKNOWN"}
                for pr in ships["pirates"]]),
        "-- Hafenhandel (design_data/dev_trade.json, is_dev = TRUE). Bestände nur beim Anlegen: danach Laufzeitstand.\n",
        upsert("items", "code", ["code", "item_type", "name_de", "stackable", "max_stack", "is_dev", "confidence"],
               [{"code": g["code"], "item_type": "TRADE_GOOD", "name_de": g["name_de"], "stackable": True,
                 "max_stack": TRADE_MAX_STACK, "is_dev": True, "confidence": "UNKNOWN"}
                for g in sorted(trade["goods"], key=lambda g: g["code"])]),
        upsert("npcs", "code", ["code", "name_de", "npc_role", "port_id", "zone_id", "is_dev", "confidence"],
               [{"code": m["code"], "name_de": m["name_de"], "npc_role": "MERCHANT",
                 "port_id": SqlExpr(f"(SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = {sql_literal(m['city'])})"),
                 "zone_id": city_zones[m["city"]], "is_dev": True, "confidence": "UNKNOWN"}
                for m in sorted(trade["merchants"], key=lambda m: m["code"])]),
        upsert("markets", ("port_id", "item_id"),
               ["port_id", "item_id", "base_price", "stock", "target_stock", "restock_per_hour", "tax_rate", "is_dev"],
               [{"port_id": SqlExpr(f"(SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = {sql_literal(m['city'])})"),
                 "item_id": SqlExpr(f"(SELECT item_id FROM items WHERE code = {sql_literal(m['good'])})"),
                 "base_price": m["base_price"], "stock": m["target_stock"], "target_stock": m["target_stock"],
                 "restock_per_hour": m["restock_per_hour"], "tax_rate": m["tax_rate"], "is_dev": True}
                for m in sorted(trade["markets"], key=lambda m: (m["city"], m["good"]))],
               insert_only=("stock",)),
        upsert("game_rules", "rule_key", ["rule_key", "int_value", "is_dev", "confidence"],
               [{"rule_key": key, "int_value": round(trade["tuning"][field] * 1000), "is_dev": True, "confidence": "UNKNOWN"}
                for key, field in sorted(TRADE_RULES.items())]),
        "-- Inventar und Beute (design_data/dev_loot.json, is_dev = TRUE).\n",
        upsert("items", "code", ["code", "item_type", "name_de", "stackable", "max_stack", "npc_price", "is_dev", "confidence"],
               [{"code": m["code"], "item_type": "MATERIAL", "name_de": m["name_de"], "stackable": True, "max_stack": m["max_stack"],
                 "npc_price": m["npc_price"], "is_dev": True, "confidence": "UNKNOWN"}
                for m in sorted(loot["materials"] + crafting["materials"], key=lambda m: m["code"])]),
        upsert("materials", "item_id", ["item_id", "material_category"],
               [{"item_id": SqlExpr(f"(SELECT item_id FROM items WHERE code = {sql_literal(m['code'])})"),
                 "material_category": m["category"]}
                for m in sorted(loot["materials"] + crafting["materials"], key=lambda m: m["code"])]),
        "".join(f"UPDATE items SET npc_price = {sql_literal(price)} WHERE code = {sql_literal(code)};\n"
                for code, price in sorted(loot["sell_prices"].items())),
        upsert("loot_tables", "code", ["code", "gold_min", "gold_max", "is_dev"],
               [{"code": t["code"], "gold_min": t["gold"]["min"] if t["gold"] else None,
                 "gold_max": t["gold"]["max"] if t["gold"] else None, "is_dev": True}
                for t in sorted(loot["loot_tables"], key=lambda t: t["code"])]),
        upsert("loot_entries", ("loot_table_id", "item_id"), ["loot_table_id", "item_id", "chance", "min_qty", "max_qty"],
               [{"loot_table_id": SqlExpr(f"(SELECT loot_table_id FROM loot_tables WHERE code = {sql_literal(t['code'])})"),
                 "item_id": SqlExpr(f"(SELECT item_id FROM items WHERE code = {sql_literal(e['item'])})"),
                 "chance": e["chance"], "min_qty": e["min"], "max_qty": e["max"]}
                for t in sorted(loot["loot_tables"], key=lambda t: t["code"]) for e in sorted(t["entries"], key=lambda e: e["item"])]),
        "".join(f"UPDATE monsters SET loot_table_id = (SELECT loot_table_id FROM loot_tables WHERE code = {sql_literal(t['code'])}) "
                f"WHERE code = {sql_literal(code)};\n"
                for t in sorted(loot["loot_tables"], key=lambda t: t["code"]) for code in sorted(t["monsters"])),
        upsert("game_rules", "rule_key", ["rule_key", "int_value", "is_dev", "confidence"],
               [{"rule_key": "INVENTORY_SLOTS", "int_value": loot["inventory_slots"], "is_dev": True, "confidence": "UNKNOWN"}]),
        "-- Herstellen und Sammeln (design_data/dev_crafting.json, is_dev = TRUE).\n",
        upsert("recipes", "code", ["code", "name_de", "required_skill_id", "required_level", "craft_time_seconds", "result_item_id",
                                   "result_quantity", "gold_cost", "skill_xp", "is_dev", "confidence"],
               [{"code": r["code"], "name_de": r["name_de"], "required_skill_id": skill_ref(r["skill"]),
                 "required_level": r["required_level"], "craft_time_seconds": r["craft_seconds"], "result_item_id": item_ref(r["result"]),
                 "result_quantity": r["result_quantity"], "gold_cost": r["gold_cost"], "skill_xp": r["skill_xp"], "is_dev": True,
                 "confidence": "UNKNOWN"} for r in sorted(crafting["recipes"], key=lambda r: r["code"])]),
        upsert("recipe_materials", ("recipe_id", "item_id"), ["recipe_id", "item_id", "quantity"],
               [{"recipe_id": SqlExpr(f"(SELECT recipe_id FROM recipes WHERE code = {sql_literal(r['code'])})"),
                 "item_id": item_ref(m["item"]), "quantity": m["quantity"]}
                for r in sorted(crafting["recipes"], key=lambda r: r["code"]) for m in sorted(r["materials"], key=lambda m: m["item"])]),
        upsert("gather_nodes", "code", ["code", "name_de", "skill_id", "required_level", "item_id", "min_qty", "max_qty",
                                        "gather_seconds", "respawn_seconds", "skill_xp", "is_dev", "confidence"],
               [{"code": n["code"], "name_de": n["name_de"], "skill_id": skill_ref(n["skill"]), "required_level": n["required_level"],
                 "item_id": item_ref(n["item"]), "min_qty": n["min"], "max_qty": n["max"], "gather_seconds": n["gather_seconds"],
                 "respawn_seconds": n["respawn_seconds"], "skill_xp": n["skill_xp"], "is_dev": True, "confidence": "UNKNOWN"}
                for n in sorted(crafting["gather_nodes"], key=lambda n: n["code"])]),
        upsert("gather_node_zones", ("gather_node_id", "zone_id"), ["gather_node_id", "zone_id"],
               [{"gather_node_id": SqlExpr(f"(SELECT gather_node_id FROM gather_nodes WHERE code = {sql_literal(n['code'])})"),
                 "zone_id": zone} for n in sorted(crafting["gather_nodes"], key=lambda n: n["code"]) for zone in sorted(n["zones"])]),
        "-- Auktionshaus (design_data/dev_auction.json, is_dev = TRUE).\n",
        upsert("npcs", "code", ["code", "name_de", "npc_role", "port_id", "zone_id", "is_dev", "confidence"],
               [{"code": a["code"], "name_de": a["name_de"], "npc_role": "AUCTION",
                 "port_id": SqlExpr(f"(SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = {sql_literal(a['city'])})"),
                 "zone_id": city_zones[a["city"]], "is_dev": True, "confidence": "UNKNOWN"}
                for a in sorted(auction["auctioneers"], key=lambda a: a["code"])]),
        upsert("game_rules", "rule_key", ["rule_key", "int_value", "is_dev", "confidence"],
               [{"rule_key": f"AUCTION_{key.upper()}", "int_value": value, "is_dev": True, "confidence": "UNKNOWN"}
                for key, value in sorted(auction["tuning"].items())]),
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


# Preismodell-Parameter in Promille (game_rules kennt nur Ganzzahlen).
TRADE_RULES = {"TRADE_ELASTICITY_PERMILLE": "elasticity", "TRADE_MIN_FACTOR_PERMILLE": "min_factor",
               "TRADE_MAX_FACTOR_PERMILLE": "max_factor", "TRADE_SPREAD_PERMILLE": "spread"}
# Stapelgrenze für Waren: Die Ladung begrenzt der Laderaum, nicht der Stapel.
TRADE_MAX_STACK = 1_000_000


def check_trade(trade: dict, city_zones: dict[str, str], port_cities: set[str]) -> None:
    problems = []
    t = trade["tuning"]
    if not (0 < t["min_factor"] <= 1 <= t["max_factor"]) or not 0 <= t["spread"] < 1 or t["elasticity"] < 0:
        problems.append("Tuning: min_factor ≤ 1 ≤ max_factor, spread 0 … <1, elasticity ≥ 0")
    goods = {g["code"] for g in trade["goods"]}
    for g in trade["goods"]:
        if not g["code"].startswith("DEV_") or not TAG_RE.match(g["code"]):
            problems.append(f"{g['code']}: Entwicklungsware braucht DEV_-Code")
    for m in trade["merchants"]:
        if not m["code"].startswith("DEV_") or m["city"] not in city_zones or m["city"] not in port_cities:
            problems.append(f"{m['code']}: DEV_-Code und Stadt mit Zone und Hafen nötig")
    seen = set()
    for m in trade["markets"]:
        key = (m["city"], m["good"])
        if key in seen or m["good"] not in goods or m["city"] not in port_cities:
            problems.append(f"Markt {key}: doppelt, Ware unbekannt oder Stadt ohne Hafen")
        seen.add(key)
        if m["base_price"] <= 0 or m["target_stock"] <= 0 or m["restock_per_hour"] < 0 or not 0 <= m["tax_rate"] < 1:
            problems.append(f"Markt {key}: Preis und Gleichgewicht > 0, Auffüllen ≥ 0, Steuer 0 … <1")
    if problems:
        raise SystemExit("design_data/dev_trade.json:\n  " + "\n  ".join(problems))


def skill_ref(code: str) -> SqlExpr:
    return SqlExpr(f"(SELECT skill_id FROM skills WHERE code = {sql_literal(code)})")


def item_ref(code: str) -> SqlExpr:
    return SqlExpr(f"(SELECT item_id FROM items WHERE code = {sql_literal(code)})")


def check_crafting(crafting: dict, item_codes: set[str], skill_categories: dict[str, str | None], zone_ids: set[str]) -> None:
    problems = []
    codes = item_codes | {m["code"] for m in crafting["materials"]}
    for m in crafting["materials"]:
        if not m["code"].startswith("DEV_") or not TAG_RE.match(m["code"]) or m["max_stack"] < 1 or m["npc_price"] < 0:
            problems.append(f"{m['code']}: DEV_-Code, Stapel ≥ 1, Preis ≥ 0")
    for n in crafting["gather_nodes"]:
        if not n["code"].startswith("DEV_") or skill_categories.get(n["skill"]) != "GATHERING" or n["item"] not in codes:
            problems.append(f"{n['code']}: DEV_-Code, Sammel-Skill (Kategorie GATHERING) und bekanntes Item nötig")
        if not 1 <= n["min"] <= n["max"] or n["required_level"] < 1 or n["gather_seconds"] < 0 or n["respawn_seconds"] < 0:
            problems.append(f"{n['code']}: 1 ≤ min ≤ max, Stufe ≥ 1, Zeiten ≥ 0")
        if not n["zones"] or any(z not in zone_ids for z in n["zones"]):
            problems.append(f"{n['code']}: Zonen fehlen oder unbekannt")
    for r in crafting["recipes"]:
        if not r["code"].startswith("DEV_") or skill_categories.get(r["skill"]) != "PRODUCTION" or r["result"] not in codes:
            problems.append(f"{r['code']}: DEV_-Code, Herstell-Skill (Kategorie PRODUCTION) und bekanntes Ergebnis nötig")
        if not r["materials"] or any(m["item"] not in codes or m["quantity"] < 1 for m in r["materials"]) \
                or len({m["item"] for m in r["materials"]}) != len(r["materials"]):
            problems.append(f"{r['code']}: Materialien bekannt, Menge ≥ 1, jedes nur einmal")
        if r["result_quantity"] < 1 or r["gold_cost"] < 0 or r["required_level"] < 1 or r["craft_seconds"] < 0:
            problems.append(f"{r['code']}: Menge ≥ 1, Gebühr ≥ 0, Stufe ≥ 1, Zeit ≥ 0")
    if problems:
        raise SystemExit("design_data/dev_crafting.json:\n  " + "\n  ".join(problems))


def check_auction(auction: dict, zone_cities: set[str], port_cities: set[str]) -> None:
    problems = []
    t = auction["tuning"]
    if set(t) != AUCTION_TUNING_KEYS or not all(isinstance(v, int) for v in t.values()):
        problems.append(f"tuning: genau {sorted(AUCTION_TUNING_KEYS)} als Ganzzahlen")
    elif not (0 <= t["fee_permille"] <= 1000 and 0 <= t["tax_permille"] <= 1000 and t["min_fee"] >= 0
              and t["duration_hours"] > 0 and t["max_listings"] > 0):
        problems.append("tuning: Promille 0 … 1000, Mindestgebühr ≥ 0, Laufzeit und Anzahl > 0")
    for a in auction["auctioneers"]:
        if not a["code"].startswith("DEV_") or a["city"] not in zone_cities or a["city"] not in port_cities:
            problems.append(f"{a['code']}: DEV_-Code und Stadt mit Zone und Hafen nötig")
    if problems:
        raise SystemExit("design_data/dev_auction.json:\n  " + "\n  ".join(problems))


def check_loot(loot: dict, item_codes: set[str], monster_codes: set[str]) -> None:
    problems = []
    codes = item_codes | {m["code"] for m in loot["materials"]}
    for m in loot["materials"]:
        if not m["code"].startswith("DEV_") or not TAG_RE.match(m["code"]) or m["max_stack"] < 1 or m["npc_price"] < 0:
            problems.append(f"{m['code']}: DEV_-Code, Stapel ≥ 1, Preis ≥ 0")
    for code, price in loot["sell_prices"].items():
        if code not in item_codes or price < 0:
            problems.append(f"Verkaufspreis {code}: Item unbekannt oder Preis < 0")
    if loot["inventory_slots"] < 1:
        problems.append("inventory_slots ≥ 1")
    claimed: set[str] = set()
    for t in loot["loot_tables"]:
        gold = t["gold"]
        if gold and not 0 <= gold["min"] <= gold["max"]:
            problems.append(f"{t['code']}: Gold 0 ≤ min ≤ max")
        for monster in t["monsters"]:
            if monster not in monster_codes or monster in claimed:
                problems.append(f"{t['code']}: Gegner {monster} unbekannt oder schon vergeben")
            claimed.add(monster)
        for e in t["entries"]:
            if e["item"] not in codes or not 0 < e["chance"] <= 1 or not 1 <= e["min"] <= e["max"]:
                problems.append(f"{t['code']}/{e['item']}: Item bekannt, Chance 0 … 1, 1 ≤ min ≤ max")
    if problems:
        raise SystemExit("design_data/dev_loot.json:\n  " + "\n  ".join(problems))


SERVICE_RULES = {"SHIP_REPAIR_GOLD_PER_HP": "repair_gold_per_hp", "SAILOR_HIRE_GOLD": "hire_gold_per_sailor",
                 "SAILOR_HEAL_GOLD": "heal_gold_per_sailor", "PROVISION_GOLD_PER_UNIT": "provisions_gold_per_unit"}


def ue_ship(code: str, name_de: str, sh: dict, cost: int, ship_class: str) -> dict:
    return {"Name": code, "NameDe": name_de, "ShipClass": SHIP_CLASS_UE[ship_class], "Level": sh.get("level", 1),
            "HullHp": sh["hull_hp"], "MaxSpeed": sh["max_speed"], "Acceleration": sh["acceleration"],
            "Deceleration": sh["deceleration"], "TurnRateDeg": sh["turn_rate"], "CrewMin": sh["crew_min"],
            "CrewMax": sh["crew_max"], "Cargo": sh["cargo"], "WindEfficiency": sh["wind_efficiency"],
            "CannonSlots": sh["cannon_slots"], "CostGold": cost, "bIsDev": True}


def start_crew(ship: dict, ships: dict) -> int:
    """Hälfte der Kapazität (Community-Rat, SAILOR-SYSTEM), mindestens die Mindestbesatzung."""
    return max(ship["crew_min"], round(ship["crew_max"] * ships["tuning"]["start_crew_share"]))


def check_ships(ships: dict, class_codes: set[str], zone_ids: set[str]) -> None:
    problems = []
    angles = [a for a, _ in ships["tuning"]["polar"]]
    if angles != sorted(set(angles)) or any(not 0 <= e <= 1 for _, e in ships["tuning"]["polar"]):
        problems.append("Polare: Winkel aufsteigend, Werte 0 … 1")
    for sh in ships["ships"]:
        if sh["class"] not in class_codes:
            problems.append(f"{sh['code']}: unbekannte Klasse {sh['class']}")
        if not 0 <= sh["crew_min"] <= sh["crew_max"]:
            problems.append(f"{sh['code']}: Mindestbesatzung > Kapazität")
    for w in ships["wind"]:
        if w["zone"] not in zone_ids:
            problems.append(f"Wind: unbekannte Zone {w['zone']}")
    # Belegte Rangfolgen (SHIPCLASS-*) dürfen die Entwicklungswerte nicht verletzen.
    by_class = {sh["class"]: sh for sh in ships["ships"]}
    if {"BATTLE", "RAIDER", "MERCHANT"} <= by_class.keys():
        b, r, m = by_class["BATTLE"], by_class["RAIDER"], by_class["MERCHANT"]
        if not (r["max_speed"] > b["max_speed"] and r["max_speed"] > m["max_speed"] and m["max_speed"] < b["max_speed"]):
            problems.append("Rangfolge Geschwindigkeit: Erkundungsschiff am schnellsten, Handelsschiff am langsamsten")
        if not (b["hull_hp"] > r["hull_hp"] and b["hull_hp"] > m["hull_hp"]):
            problems.append("Rangfolge Haltbarkeit: Kriegsschiff hält am meisten aus")
        if not (r["crew_max"] > b["crew_max"] and r["crew_max"] > m["crew_max"]):
            problems.append("Rangfolge Matrosen: Erkundungsschiff hat die meisten")
        if not (m["cargo"] > b["cargo"] and m["cargo"] > r["cargo"]):
            problems.append("Rangfolge Ladung: Handelsschiff hat die größte")
        if not (b["cannon_slots"] > r["cannon_slots"] and b["cannon_slots"] > m["cannon_slots"]):
            problems.append("Rangfolge Kanonen: Kriegsschiff hat die meisten")
    na = ships["naval_abilities"]
    if na["boarding"]["raider_strength"] <= 1:
        problems.append("Entern: Erkundungsschiff muss stärker entern als andere Klassen (SHIPCLASS-RAIDER)")
    if not 0 <= na["ram"]["self_damage_share"] <= 1 or not 0 < na["ram"]["front_arc_deg"] <= 90:
        problems.append("Rammen: Eigenschaden 0 … 1, Bugwinkel 0 … 90")
    if na["mines"]["arm_seconds"] >= na["mines"]["lifetime_seconds"]:
        problems.append("Minen: Scharfschaltzeit muss unter der Lebensdauer liegen")
    cannon_codes = {c["code"] for c in ships["cannons"]}
    for pr in ships["pirates"]:
        if pr["cannon"] not in cannon_codes or pr["zone"] not in zone_ids or pr["ship"]["class"] not in class_codes:
            problems.append(f"{pr['code']}: Kanone, Zone oder Klasse unbekannt")
    if problems:
        raise SystemExit("design_data/dev_ships.json:\n  " + "\n  ".join(problems))


NPC_ROLE_UE = {"SHIPYARD": "Shipyard", "OFFICER_EXCHANGE": "OfficerExchange", "MERCHANT": "Merchant", "AUCTION": "Auctioneer"}
AUCTION_TUNING_KEYS = {"fee_permille", "min_fee", "tax_permille", "duration_hours", "max_listings"}


SHIP_CLASS_UE = {"BATTLE": "Battle", "RAIDER": "Raider", "MERCHANT": "Merchant", "BEGINNER": "Beginner"}


def render_ue(rows: dict[str, list[dict]], appearance: dict, combat: dict, abilities: dict,
              discoveries: dict, ships: dict, trade: dict, crafting: dict, auction: dict) -> dict[str, list[dict]]:
    t = ships["tuning"]
    return {
        "DT_Ships.json": sorted(
            [ue_ship(sh["code"], sh["name_de"], sh, sh["cost_gold"], sh["class"]) for sh in ships["ships"]]
            + [ue_ship(pr["code"], pr["name_de"], pr["ship"], 0, pr["ship"]["class"]) for pr in ships["pirates"]],
            key=lambda row: row["Name"]),
        "DT_Cannons.json": [
            {"Name": c["code"], "NameDe": c["name_de"], "RangeCm": c["range_cm"], "DamagePerHit": c["damage_per_hit"],
             "CrewHitsPerHit": c["crew_hits_per_hit"], "ReloadSeconds": c["reload_seconds"],
             "HitChanceNear": c["hit_chance_near"], "HitChanceFar": c["hit_chance_far"]}
            for c in ships["cannons"]
        ],
        "DT_PirateShips.json": [
            {"Name": pr["code"], "NameDe": pr["name_de"], "ShipCode": pr["code"], "CannonCode": pr["cannon"], "Crew": pr["crew"],
             "XpReward": pr["xp_reward"], "AggroRadiusCm": pr["aggro_radius_cm"], "LeashRadiusCm": pr["leash_radius_cm"],
             "RespawnSeconds": pr["respawn_seconds"]}
            for pr in ships["pirates"]
        ],
        "DT_ShipTuning.json": [
            {"Name": "Default", "PolarAngles": [a for a, _ in t["polar"]], "PolarEfficiencies": [e for _, e in t["polar"]],
             "CrewMinFactor": t["crew_min_factor"], "MinSteerageFactor": t["min_steerage_factor"],
             "ProvisionsPerSailorPerMinute": t["provisions_per_sailor_per_minute"], "NoProvisionsFactor": t["no_provisions_factor"],
             "ArcHalfWidthDeg": ships["broadside"]["arc_half_width_deg"], "DeathShare": ships["broadside"]["death_share"],
             **{f"{prefix}{camel(k)}": v for prefix, group in (("Ram", "ram"), ("Grapple", "grapple"), ("Boarding", "boarding"),
                                                               ("Mine", "mines"))
                for k, v in ships["naval_abilities"][group].items()}}
        ],
        "DT_ZoneWind.json": [
            {"Name": w["zone"], "BaseDirectionDeg": w["base_direction_deg"], "BaseStrength": w["base_strength"],
             "DirectionSwingDeg": w["direction_swing_deg"], "StrengthSwing": w["strength_swing"], "PeriodSeconds": w["period_seconds"]}
            for w in sorted(ships["wind"], key=lambda w: w["zone"])
        ],
        "DT_Npcs.json": [
            {"Name": n["code"], **ue_common(n), "Role": NPC_ROLE_UE[n["role"]], "CityCode": n["city"], "bIsDev": n["is_dev"]}
            for n in sorted([{**n, "is_dev": False} for n in rows["npcs"]]
                            + [{"code": m["code"], "zh": None, "en": None, "de": m["name_de"], "recon_id": "",
                                "confidence": "UNKNOWN", "role": "MERCHANT", "city": m["city"], "is_dev": True}
                               for m in trade["merchants"]]
                            + [{"code": a["code"], "zh": None, "en": None, "de": a["name_de"], "recon_id": "",
                                "confidence": "UNKNOWN", "role": "AUCTION", "city": a["city"], "is_dev": True}
                               for a in auction["auctioneers"]], key=lambda n: n["code"])
        ],
        "DT_GatherNodes.json": [
            {"Name": n["code"], "NameDe": n["name_de"], "SkillCode": n["skill"], "RequiredLevel": n["required_level"],
             "ItemCode": n["item"], "GatherSeconds": n["gather_seconds"], "RespawnSeconds": n["respawn_seconds"], "bIsDev": True}
            for n in sorted(crafting["gather_nodes"], key=lambda n: n["code"])
        ],
        "DT_Discoveries.json": [
            {"Name": d["code"], "NameDe": d["name_de"], "ZoneId": d["zone"], "XpReward": d["xp_reward"], "bIsDev": True}
            for d in sorted(discoveries["discoveries"], key=lambda d: d["code"])
        ],
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
    discoveries = json.loads((DESIGN_DIR / "dev_discoveries.json").read_text(encoding="utf-8"))
    zone_ids = {z["zone_id"] for z in world["zones"]} | MIGRATION_ZONES
    for d in discoveries["discoveries"]:
        if d["zone"] not in zone_ids or not TAG_RE.match(d["code"]):
            raise SystemExit(f"design_data/dev_discoveries.json: {d['code']} (Zone {d['zone']} unbekannt oder Code ungültig)")
    ships = json.loads((DESIGN_DIR / "dev_ships.json").read_text(encoding="utf-8"))
    check_ships(ships, {c["code"] for c in rows["ship_classes"]}, zone_ids)
    trade = json.loads((DESIGN_DIR / "dev_trade.json").read_text(encoding="utf-8"))
    check_trade(trade, {strip_prefix(z["city"]): z["zone_id"] for z in world["zones"] if z["city"]},
                {p["city"] for p in rows["ports"]})
    loot = json.loads((DESIGN_DIR / "dev_loot.json").read_text(encoding="utf-8"))
    check_loot(loot, {w["code"] for w in combat["weapons"] if w["class"] != "UNARMED"} | {g["code"] for g in trade["goods"]},
               {m["code"] for m in combat["monsters"]} | {pr["code"] for pr in ships["pirates"]})
    crafting = json.loads((DESIGN_DIR / "dev_crafting.json").read_text(encoding="utf-8"))
    check_crafting(crafting, {w["code"] for w in combat["weapons"] if w["class"] != "UNARMED"} | {m["code"] for m in loot["materials"]},
                   {r["code"]: r["category_cn"] for r in rows["skills"]}, zone_ids)
    auction = json.loads((DESIGN_DIR / "dev_auction.json").read_text(encoding="utf-8"))
    check_auction(auction, {strip_prefix(z["city"]) for z in world["zones"] if z["city"]}, {p["city"] for p in rows["ports"]})
    files = {SEED_FILE: render_sql(rows, curves, appearance, combat, abilities, world, discoveries, ships, trade, loot, crafting,
                                   auction)}
    for name, table in render_ue(rows, appearance, combat, abilities, discoveries, ships, trade, crafting, auction).items():
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
