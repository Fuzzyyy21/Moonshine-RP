#!/usr/bin/env python3
"""Read-only-Inventar für bereitgestellte Original- oder Clientdateien (Schritt 1 und 2 der Dateianalyse).

Die Dateien werden ausschließlich lesend geöffnet ('rb') und nie verändert, verschoben
oder entpackt. Ergebnis ist ein Bericht mit den Spalten
FILE, TYPE, SIZE, SHA256, PURPOSE, DEPENDENCIES, RELEVANCE, CONFIDENCE.

TYPE wird über Magic Bytes erkannt, ersatzweise über die Endung. PURPOSE, DEPENDENCIES
und RELEVANCE bleiben UNKNOWN, bis ein Mensch oder eine spätere Analyse sie bestätigt;
die Endungsvermutung steht nur als Hinweis in PURPOSE mit CONFIDENCE UNCERTAIN.

Aufruf:
    python3 tools/inventory_files.py <eingabeordner> [--out bericht.md|bericht.csv]
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import re
import sys
from pathlib import Path

# (Magic Bytes, Offset, Typ). Reihenfolge: spezifisch vor allgemein.
MAGIC = [
    (b"PK\x03\x04", 0, "ZIP-Archiv"),
    (b"Rar!\x1a\x07", 0, "RAR-Archiv"),
    (b"7z\xbc\xaf\x27\x1c", 0, "7z-Archiv"),
    (b"\x1f\x8b", 0, "GZIP-Archiv"),
    (b"SQLite format 3\x00", 0, "SQLite-Datenbank"),
    (b"\x89PNG\r\n\x1a\n", 0, "PNG-Bild"),
    (b"\xff\xd8\xff", 0, "JPEG-Bild"),
    (b"GIF8", 0, "GIF-Bild"),
    (b"BM", 0, "BMP-Bild"),
    (b"DDS ", 0, "DDS-Textur"),
    (b"OggS", 0, "OGG-Audio"),
    (b"ID3", 0, "MP3-Audio"),
    (b"fLaC", 0, "FLAC-Audio"),
    (b"WAVE", 8, "WAV-Audio"),
    (b"AVI ", 8, "AVI-Video"),
    (b"ftyp", 4, "MP4/MOV-Video"),
    (b"\x1aE\xdf\xa3", 0, "Matroska/WebM-Video"),
    (b"MZ", 0, "Windows-Programm/DLL (PE)"),
    (b"Gamebryo File Format", 0, "Gamebryo NIF-Modell"),
    (b"NetImmerse File Format", 0, "NetImmerse NIF-Modell"),
    (b"<?xml", 0, "XML"),
    (b"\xef\xbb\xbf<?xml", 0, "XML (UTF-8 BOM)"),
    (b"%PDF", 0, "PDF"),
]

EXTENSION_HINTS = {
    ".ini": "Konfiguration", ".cfg": "Konfiguration", ".conf": "Konfiguration",
    ".xml": "Daten/Konfiguration", ".json": "Daten", ".csv": "Tabelle", ".txt": "Text/Tabelle",
    ".dat": "Binärdaten (Inhalt UNKNOWN)", ".bin": "Binärdaten (Inhalt UNKNOWN)",
    ".pak": "Paketarchiv", ".pkg": "Paketarchiv", ".lua": "Skript", ".py": "Skript",
    ".dds": "Textur", ".tga": "Textur", ".png": "Bild/Textur", ".jpg": "Bild",
    ".nif": "3D-Modell", ".kf": "Animation", ".kfm": "Animation", ".x": "3D-Modell",
    ".wav": "Audio", ".ogg": "Audio", ".mp3": "Audio",
    ".exe": "Programm", ".dll": "Bibliothek",
    ".map": "Karte", ".ter": "Terrain", ".ui": "UI", ".fnt": "Schrift", ".ttf": "Schrift",
    ".db": "Datenbank", ".mdb": "Datenbank", ".sql": "Datenbank-Skript",
}

INI_SECTION = re.compile(rb"^\[[A-Za-z0-9_ .\-]+\]\s*\r?\n")

COLUMNS = ["FILE", "TYPE", "SIZE", "SHA256", "PURPOSE", "DEPENDENCIES", "RELEVANCE", "CONFIDENCE"]


def detect_type(head: bytes, suffix: str) -> tuple[str, str]:
    """Liefert (Typ, Erkennungsart)."""
    for magic, offset, label in MAGIC:
        if head[offset:offset + len(magic)] == magic:
            return label, "magic"
    if head and all(b in b"\t\n\r" or 32 <= b < 127 or b >= 0x80 for b in head[:512]):
        text = head.lstrip()
        if INI_SECTION.match(text):
            return "Text (vermutlich INI)", "heuristic"
        if text.startswith((b"{", b"[")):
            return "Text (vermutlich JSON)", "heuristic"
        return f"Text ({suffix or 'ohne Endung'})", "heuristic"
    return f"Binär ({suffix or 'ohne Endung'})", "extension"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inventory(root: Path) -> list[dict[str, str]]:
    rows = []
    for path in sorted(p for p in root.rglob("*") if p.is_file() and not p.is_symlink()):
        with path.open("rb") as fh:
            head = fh.read(4096)
        suffix = path.suffix.lower()
        ftype, method = detect_type(head, suffix)
        hint = EXTENSION_HINTS.get(suffix)
        rows.append({
            "FILE": str(path.relative_to(root)),
            "TYPE": ftype,
            "SIZE": str(path.stat().st_size),
            "SHA256": sha256(path),
            "PURPOSE": f"Vermutung nach Endung: {hint}" if hint else "UNKNOWN",
            "DEPENDENCIES": "UNKNOWN",
            "RELEVANCE": "UNKNOWN",
            "CONFIDENCE": "LIKELY" if method == "magic" else "UNCERTAIN",
        })
    return rows


def write_markdown(rows: list[dict[str, str]], out) -> None:
    out.write("| " + " | ".join(COLUMNS) + " |\n")
    out.write("|" + "---|" * len(COLUMNS) + "\n")
    for row in rows:
        cells = [row[c].replace("|", "\\|") for c in COLUMNS]
        cells[3] = cells[3][:16] + "…"  # Hash gekürzt; die CSV-Ausgabe enthält ihn vollständig
        out.write("| " + " | ".join(cells) + " |\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input", type=Path, help="Ordner mit den zu inventarisierenden Dateien")
    parser.add_argument("--out", type=Path, help="Zieldatei (.md oder .csv). Ohne Angabe: Markdown auf stdout")
    args = parser.parse_args()

    root = args.input.resolve()
    if not root.is_dir():
        print(f"Kein Ordner: {root}", file=sys.stderr)
        return 1
    if args.out and root in args.out.resolve().parents:
        print("Der Bericht darf nicht in den Originalordner geschrieben werden.", file=sys.stderr)
        return 1

    rows = inventory(root)
    if args.out and args.out.suffix.lower() == ".csv":
        with args.out.open("w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=COLUMNS)
            writer.writeheader()
            writer.writerows(rows)
    elif args.out:
        with args.out.open("w", encoding="utf-8") as fh:
            write_markdown(rows, fh)
    else:
        write_markdown(rows, sys.stdout)
    print(f"{len(rows)} Dateien inventarisiert.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
