# Reconstruction Database

Einzige Quelle für alles, was über das Original bekannt ist. Data Tables und
Seed-SQL werden später daraus erzeugt; Spielwerte werden nirgends sonst gepflegt.

## Dateien

| Datei | Inhalt |
|---|---|
| `sources.json` | Quellenregister mit Priorität (1–6) und Zugriffsart |
| `core.json` | Spiel-Metadaten, Versionen, Level-Caps, Hauptquest, Militärrang |
| `professions_skills.json` | Berufe, Skills, Skillstufen |
| `ships.json` | Schiffsklassen, Umbau, Galionsfiguren, Matrosen |
| `world.json` | Seegebiete, Städte |
| `items_content.json` | Sets, Sockel, Verfeinerung, Dungeons, Gilden, Offiziere, Handel |
| `contradictions.json` | Widersprüche zwischen Quellen |

## Datensatz

```json
{
  "id": "SHIPCLASS-BATTLE",
  "entity": "SHIP_CLASS",
  "names": { "zh": "战船", "en": "Battle Ship", "de": "Kriegsschiff" },
  "data": { "...": "Werte; unbekannt = \"UNKNOWN\"" },
  "sources": ["SRC-007", "SRC-010"],
  "confidence": "LIKELY",
  "field_confidence": { "leveled_by": "UNCERTAIN" },
  "notes": "Freitext"
}
```

* `confidence` gilt für den Datensatz, `field_confidence` überschreibt einzelne Felder.
* Unbekannte Werte heißen `"UNKNOWN"`, nie geschätzte Zahlen.
* Verweise auf andere Datensätze stehen als ID (`"CITY-ATHENS"`) und werden geprüft.
* Eigene Designentscheidungen gehören ins GDD, nicht hierher.

## Confidence

| Stufe | Bedingung |
|---|---|
| CONFIRMED | Priorität-1/2-Quelle mit `access: DIRECT` (vom Validator erzwungen) |
| LIKELY | Priorität-2-Auszug oder zwei unabhängige übereinstimmende Quellen |
| UNCERTAIN | Einzelquelle Priorität 3–5, unklare Zuordnung, Verwechslungsgefahr |
| UNKNOWN | keine Quelle |

## Ändern

1. Datensatz anpassen, nie einen zweiten für dasselbe Element anlegen.
2. Bei abweichender neuer Quelle: alten Wert nicht löschen, sondern `CONTRA-*` anlegen.
3. `python3 tools/validate_reconstruction_db.py` ausführen.
4. Betroffene GDD-Abschnitte aktualisieren.
