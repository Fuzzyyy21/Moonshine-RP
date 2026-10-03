# Protokoll für bereitgestellte Dateien

Gilt für alle Dateien, Screenshots, Videos oder Daten, die später geliefert werden.
**Erst analysieren, dann implementieren.**

## Grundregeln

1. Originaldateien werden **nie verändert, überschrieben, verschoben oder im Repo eingecheckt**.
   Sie liegen außerhalb des Repos (z. B. `~/vc-originals/`), schreibgeschützt (`chmod -R a-w`).
2. Alle Analyseergebnisse (Berichte, Extrakte) liegen in `analysis/<lieferung-datum>/` im Repo.
3. Jeder Wert, der in die Reconstruction Database übernommen wird, bekommt eine neue
   Quelle in `sources.json` mit `priority: 1` und `access: DIRECT`, inklusive Dateipfad und SHA-256.
4. Rechtliche Klärung vor der Analyse: Nur Dateien verwenden, deren Nutzung erlaubt ist.
   Extrahierte Assets (Modelle, Texturen, Audio) werden **nicht** ins Spiel übernommen,
   sondern dienen nur als Referenz für Werte und Struktur.

## Ablauf

| Schritt | Tätigkeit | Werkzeug / Ergebnis |
|---|---|---|
| 1 | Dateien inventarisieren | `python3 tools/inventory_files.py <ordner> --out analysis/<lieferung>/inventory.csv` |
| 2 | Formate identifizieren | Magic Bytes (Tool), danach manuelle Prüfung unbekannter Binärformate |
| 3 | Daten extrahieren | Extraktion nur in Kopien; Extraktor-Skripte unter `tools/extract/` versionieren |
| 4 | Beziehungen erkennen | IDs und Fremdschlüssel zwischen Tabellen dokumentieren |
| 5 | Werte dokumentieren | Datensätze in `reconstruction_db/` anlegen oder ergänzen |
| 6 | Mit Screenshots/Videos abgleichen | Abweichungen notieren |
| 7 | Widersprüche markieren | neuer `CONTRA-*`-Datensatz, nie still überschreiben |
| 8 | Reconstruction Database aktualisieren | `python3 tools/validate_reconstruction_db.py` muss grün sein |
| 9 | GDD aktualisieren | betroffene Abschnitte in `01_GAME_DESIGN_DOCUMENT.md` |
| 10 | Erst danach implementieren | Export in Data Tables, Code-Änderungen |

## Berichtsformat

Das Inventar-Tool erzeugt diese Spalten. PURPOSE, DEPENDENCIES und RELEVANCE werden
nach manueller Analyse ergänzt; bis dahin stehen sie auf UNKNOWN.

| Spalte | Inhalt |
|---|---|
| FILE | Pfad relativ zum Lieferordner |
| TYPE | per Magic Bytes erkannt, sonst Heuristik/Endung |
| SIZE | Bytes |
| SHA256 | Prüfsumme für Nachvollziehbarkeit |
| PURPOSE | Zweck (anfangs nur Vermutung nach Endung) |
| DEPENDENCIES | Abhängigkeiten zu anderen Dateien |
| RELEVANCE | HIGH / MEDIUM / LOW für die Rekonstruktion |
| CONFIDENCE | CONFIRMED / LIKELY / UNCERTAIN / UNKNOWN |

## Screenshots und Videos

| Feld | Inhalt |
|---|---|
| Datei / URL | Pfad oder Link, bei Videos mit Zeitstempel |
| Spielversion | falls erkennbar (Datum, Patch, Server) |
| Zeigt | z. B. „Schiffsfenster, Kriegsschiff Stufe 5“ |
| Abgelesene Werte | exakt wie angezeigt, mit Einheit |
| Betroffene Datensätze | IDs in der Reconstruction Database |

Screenshots und Videos sind Priorität 3. Ein Wert, der darauf klar lesbar ist,
gilt als LIKELY; CONFIRMED nur zusammen mit einer Priorität-1/2-Quelle.
