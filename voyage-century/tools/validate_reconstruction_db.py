#!/usr/bin/env python3
"""Prüft die Reconstruction Database auf Struktur, Quellenbezug und Confidence-Regeln.

Nur Standardbibliothek. Aufruf:
    python3 tools/validate_reconstruction_db.py [pfad/zur/reconstruction_db]

Exit-Code 0 = gültig, 1 = Fehler gefunden.
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

CONFIDENCE = {"CONFIRMED", "LIKELY", "UNCERTAIN", "UNKNOWN"}
ACCESS = {"DIRECT", "SEARCH_SNIPPET", "NOT_ACCESSED"}
ENTITIES = {
    "GAME_META", "VERSION", "LEVEL_CAP", "MECHANIC", "PROFESSION", "SKILL",
    "SKILL_CATEGORY", "SKILL_STAGE", "SHIP", "SHIP_CLASS", "SHIP_MOD_TIER",
    "REGION", "CITY", "PORT", "ISLAND", "EQUIPMENT_SET", "ITEM", "DUNGEON",
    "NPC", "MONSTER", "QUEST", "RECIPE", "OFFICER", "CONTRADICTION",
}
RECORD_KEYS = {"id", "entity", "names", "data", "sources", "confidence", "field_confidence", "notes"}
SOURCE_KEYS = {"id", "title", "url", "publisher", "priority", "source_type", "access", "retrieved", "language", "notes"}
ID_RE = re.compile(r"^[A-Z][A-Z0-9]*-[A-Z0-9_-]+$")
DESIGN_SOURCE = "SRC-DESIGN"


def load(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def iter_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from iter_strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from iter_strings(v)


def validate(db_dir: Path) -> tuple[list[str], Counter, int]:
    errors: list[str] = []

    sources_file = db_dir / "sources.json"
    if not sources_file.exists():
        return [f"{sources_file}: fehlt"], Counter(), 0

    sources: dict[str, dict] = {}
    for src in load(sources_file).get("sources", []):
        sid = src.get("id", "?")
        missing = SOURCE_KEYS - src.keys()
        if missing:
            errors.append(f"sources.json/{sid}: fehlende Felder {sorted(missing)}")
        if sid in sources:
            errors.append(f"sources.json/{sid}: doppelte ID")
        if src.get("priority") not in range(1, 7):
            errors.append(f"sources.json/{sid}: priority muss 1..6 sein")
        if src.get("access") not in ACCESS:
            errors.append(f"sources.json/{sid}: access muss einer von {sorted(ACCESS)} sein")
        sources[sid] = src

    records: dict[str, tuple[str, dict]] = {}
    for path in sorted(db_dir.glob("*.json")):
        if path.name == "sources.json":
            continue
        try:
            doc = load(path)
        except json.JSONDecodeError as exc:
            errors.append(f"{path.name}: ungültiges JSON ({exc})")
            continue
        if not isinstance(doc.get("records"), list):
            errors.append(f"{path.name}: Schlüssel 'records' (Liste) fehlt")
            continue
        for rec in doc["records"]:
            rid = rec.get("id", "?")
            where = f"{path.name}/{rid}"
            missing = RECORD_KEYS - rec.keys()
            if missing:
                errors.append(f"{where}: fehlende Felder {sorted(missing)}")
                continue
            if not ID_RE.match(rid):
                errors.append(f"{where}: ID entspricht nicht dem Muster PREFIX-NAME")
            if rid in records:
                errors.append(f"{where}: doppelte ID (auch in {records[rid][0]})")
            records[rid] = (path.name, rec)

            if rec["entity"] not in ENTITIES:
                errors.append(f"{where}: unbekannte entity '{rec['entity']}'")
            names = rec["names"]
            if not isinstance(names, dict) or {"zh", "en", "de"} - names.keys():
                errors.append(f"{where}: names braucht zh, en und de (unbekannt = 'UNKNOWN')")
            if not isinstance(rec["data"], dict):
                errors.append(f"{where}: data muss ein Objekt sein")

            conf = rec["confidence"]
            if conf not in CONFIDENCE:
                errors.append(f"{where}: confidence '{conf}' ungültig")
            for field, fconf in rec["field_confidence"].items():
                if fconf not in CONFIDENCE:
                    errors.append(f"{where}: field_confidence.{field} '{fconf}' ungültig")

            cited = rec["sources"]
            for sid in cited:
                if sid not in sources:
                    errors.append(f"{where}: unbekannte Quelle {sid}")
            known = [sources[s] for s in cited if s in sources]

            if conf != "UNKNOWN" and not cited:
                errors.append(f"{where}: confidence {conf} ohne Quelle; ohne Quelle ist nur UNKNOWN erlaubt")
            if conf == "CONFIRMED" and not any(
                s["priority"] <= 2 and s["access"] == "DIRECT" for s in known
            ):
                errors.append(
                    f"{where}: CONFIRMED braucht eine direkt gelesene Quelle mit Priorität 1 oder 2"
                )
            if cited and all(s == DESIGN_SOURCE for s in cited) and rec["entity"] != "CONTRADICTION":
                errors.append(f"{where}: Designentscheidungen gehören ins GDD, nicht als Originalbefund in die DB")

    # Querverweise wie "CITY-ATHENS" in data müssen existieren.
    prefixes = {rid.split("-", 1)[0] for rid in records}
    for rid, (fname, rec) in records.items():
        for text in iter_strings(rec["data"]):
            if ID_RE.match(text) and text.split("-", 1)[0] in prefixes and text not in records:
                errors.append(f"{fname}/{rid}: Verweis auf unbekannte ID {text}")

    stats = Counter(rec["confidence"] for _, rec in records.values())
    return errors, stats, len(sources)


def main() -> int:
    default = Path(__file__).resolve().parent.parent / "reconstruction_db"
    db_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else default
    errors, stats, n_sources = validate(db_dir)
    if errors:
        print(f"{len(errors)} Fehler:")
        for err in errors:
            print(f"  - {err}")
        return 1
    total = sum(stats.values())
    print(f"OK: {total} Datensätze, {n_sources} Quellen")
    for level in ("CONFIRMED", "LIKELY", "UNCERTAIN", "UNKNOWN"):
        print(f"  {level:<10} {stats.get(level, 0)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
