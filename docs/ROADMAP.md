# Ideen und Ausbaustufen

Stand: Gebaut sind Core, Welt (Zeit/Wetter/Mondphasen/Weltereignisse),
Mystik-System, Sterbesystem, Weltbosse, Fortschritt (Spielzeit, Missionen,
Battle Pass, Kisten), Fraktionen, Auktionshaus, Fahrzeuge und der
Beispiel-Shop.

Was hier steht, ist noch **nicht** umgesetzt — sortiert nach dem Nutzen für
einen mystischen Roleplay-Server. Erledigte Punkte stehen unten unter
*Abgehakt*.

## Offene Fragen aus dem Design

Zwei Dinge sind bewusst als Platzhalter gebaut und warten auf eine Entscheidung.

### Wofür sind Meditationspunkte da?

Aktuell kauft man damit Segen (sofortige Vorteile). Weitere Möglichkeiten:

| Idee | Was es bringt |
|---|---|
| **Klassenwechsel-Token** | Ein Wechsel kostet z. B. 50 Punkte statt Steine — teuer, aber ohne Echtgeld-Gefühl |
| **Perk-Reset ohne Verlust** | Persönliche Skills umverteilen, ohne XP zu verlieren |
| **Steinsegen** | Kleine Chance, beim nächsten Boss doppelte Beute zu bekommen |
| **Bossortung** | Zeigt den nächsten Weltboss 10 Minuten früher an |
| **Zirkelbeitrag** | Punkte in eine Fraktionskasse einzahlen, daraus Gruppenrituale bezahlen |
| **Handelbar machen** | Punkte an andere Spieler übertragen — schafft einen echten Markt |
| **Zweite Skillleiste** | Dauerhaft mehr Slots freischalten |
| **Schutz vor Verlust** | Beim nächsten Tod keine Behandlungskosten |

Mein Vorschlag: **Klassenwechsel-Token und Perk-Reset** zuerst — beides löst ein
echtes Problem (falsche Wahl bereuen), ohne die Kampfbalance anzufassen.

### Was sollen Rituale außer Geld noch geben?

Derzeit 10.000 $ alle 30 Minuten. Naheliegende Erweiterungen:

| Idee | Was es bringt |
|---|---|
| **Gruppenritual** | Je Teilnehmer mehr Ertrag — belohnt Verabredungen |
| **Ritualarten** | Blutritual (Steine), Mondritual (Meditationspunkte), Totenritual (XP) — der Spieler wählt |
| **Bossbeschwörung** | Ein aufwändiges Ritual ruft den Weltboss sofort herbei |
| **Klassenbonus** | Vampire ernten nachts mehr, Feen bei Tag |
| **Ritualzutaten** | Braucht ein Opfer (Item), dafür deutlich höherer Ertrag |
| **Umkämpfte Punkte** | Während eines Rituals ist der Punkt für alle sichtbar — wer stört, unterbricht es |
| **Zirkelritual** | Nur mit Fraktion, Ertrag geht in die gemeinsame Kasse |

Mein Vorschlag: **Ritualarten mit Auswahl** — dieselbe Handlung, aber der
Spieler entscheidet, ob er Geld, Steine oder Punkte will. Das kostet wenig Code
und gibt dem Ritualpunkt sofort Tiefe.

## Zuerst: das macht den Server rund


### 1. Klassenbedürfnis — mittel
Jede Klasse braucht etwas zum Überleben: Vampire Blut (von Spielern oder NPCs
per Nahkampf-Interaktion), Werwölfe rohes Fleisch, Magier Manakristalle, Feen
Nähe zur Natur. Sinkt der Wert, verliert man Essenz-Regeneration und am Ende
Leben. **Warum:** Gibt jeder Klasse einen eigenen Alltag statt nur Kampfskills.
Hunger/Durst aus dem Core ist die Vorlage, das System steht schon.

### 2. Ritualpunkte als umkämpfte Gebiete — mittel
Die Fraktionsgebiete liegen bisher neben den Ritualpunkten. Wer den Punkt hält,
könnte dort passiv Steine bekommen und andere beim Ritual stören. **Warum:**
Verbindet Gebietskontrolle und Steinwirtschaft zu einem Kreislauf statt zwei
getrennten.

## Danach: fehlende RP-Grundlagen

### 3. Kleidung und Charaktereditor — mittel
Aktuell bekommt jeder das Standardmodell. Die Spalte `appearance` ist bereits
vorbereitet, der Gestaltwandel meldet sein Ende über `mystic:client:transformEnded`.

### 4. Telefon — groß
Nachrichten, Kontakte, Notruf, Zirkel-Chat, Anzeigenmarkt. Vieles davon hängt
an Zirkeln und am Notrufsystem, das mit `moonshine-death` schon steht.

### 5. Tankstellen und Werkstätten — klein
Das Fahrzeugsystem rechnet bereits mit Sprit und Schäden, es fehlen die Orte
dazu: Zapfsäulen, die `vehicles:server:refuel` aufrufen, und Werkstätten, die
Motor- und Karosseriewerte zurücksetzen.

### 6. Zufluchtsorte statt Housing — mittel
Klassengerecht: Sarg für Vampire, Höhle für Werwölfe, Turm für Magier. Lagerung
von Steinen, sicherer Respawn, kleiner Essenz-Bonus beim Ausruhen.

### 7. Bank, Geldautomaten, Schwarzmarkt — klein bis mittel
Die Konten (Bar, Bank, Schwarzgeld) existieren, es fehlen die Orte dazu.
Schwarzmarkt für Steine und verbotene Artefakte passt zum Setting.

### 8. Jobs mit Inhalt — mittel
Die Jobs im Core sind bisher nur Titel und Gehalt. Sinnvoll wären zwei bis drei
echte Abläufe (Trucker-Touren, Taxi-Aufträge, Werkstatt-Reparaturen).

## Technik und Betrieb

### 9. Admin-Panel als Oberfläche — mittel
Spielerliste, Teleport, Items, Klassen, Bans per Fenster statt Commands.

### 10. Anticheat-Grundlagen — klein
Zentrale Ratenbegrenzung für Netzwerkevents, Distanz- und Plausibilitätsprüfung
an einer Stelle statt in jeder Resource, Logging auffälliger Muster.

### 11. Discord-Anbindung — klein
Rollen aus Discord auf Adminlevel und Whitelist-Jobs abbilden, Logs als Webhook
(die Log-Funktion kann das bereits).

### 12. Statistiken und Bestenlisten — klein
Wer hat die höchste Klassenstufe, die meisten Weltbosse, die größte
Fraktionskasse, die teuerste Auktion. Aus `ms_logs`, `ms_mystic`,
`ms_factions` und `ms_auctions` direkt ableitbar.

### 13. Testlauf auf echter Hardware — Pflicht vor dem Livegang
Nichts davon lief bisher auf einem laufenden FXServer. Vor allem zu prüfen:
alle Koordinaten (Ritualpunkte, Krankenhäuser, Läden, Garagen, Autohäuser,
Auktionatoren, Fraktionsbasen, Gebietsmittelpunkte), die Animationen, das
Zusammenspiel von Modelltausch und Kleidung, und die Last der Marker-Threads
bei vielen Spielern.

## Balancing, das später Aufmerksamkeit braucht

* Steinpreise im Skilltree gegen die tatsächliche Bossausbeute
* XP-Kurve gegen die durchschnittliche Spielzeit pro Sitzung
* Schaden der Klassenskills gegen normale Schusswaffen
* Abklingzeiten im Gruppenkampf (mehrere Dämonen mit Höllenschlag)
* Weltereignisse: wie stark dürfen Blutmond und Wilde Jagd eine Klasse machen,
  ohne dass die anderen sich ausloggen
* Gebietseinkommen gegen die Zahl aktiver Fraktionen — bei wenigen Fraktionen
  kassiert jede zu viel
* Fahrzeugpreise gegen das tatsächliche Einkommen aus Ritualen, Missionen und
  Gebieten

## Abgehakt

* **Zirkel / Fraktionen** — als `moonshine-factions` gebaut, inklusive Rängen,
  Kasse, Tresor, Skilltree und Gebietskontrolle
* **Blutmond und Weltevents** — als `moonshine-world` gebaut, acht Ereignisse
  und acht Mondphasen mit Ankündigung und Countdown
* **Fahrzeuge und Garagen** — als `moonshine-vehicles` gebaut, inklusive
  Schlüsseln und Verwahrstelle
* **Steinadern** — durch Weltbosse und den Steinhändler ersetzt
