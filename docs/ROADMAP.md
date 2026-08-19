# Ideen und Ausbaustufen

Stand: 15 Resources sind gebaut — Core, Aussehen, Welt, Mystik, Beduerfnisse,
Sterbesystem,
Weltbosse, Fortschritt, Fraktionen, Auktionshaus, Fahrzeuge,
Dienstleistungen, Arbeit, Administration und der Beispiel-Shop.

Was vor dem Livegang zu prüfen ist, steht in [`LAUNCH.md`](LAUNCH.md).

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

### 1. Ritualpunkte als umkämpfte Gebiete — mittel
Die Fraktionsgebiete liegen bisher neben den Ritualpunkten. Wer den Punkt hält,
könnte dort passiv Steine bekommen und andere beim Ritual stören. **Warum:**
Verbindet Gebietskontrolle und Steinwirtschaft zu einem Kreislauf statt zwei
getrennten.

### 2. Tattoos — klein
Der Editor deckt alles ab außer Tattoos. `SetPedDecoration` und die
Overlay-Sammlungen wären der nächste Schritt; die Struktur in
`ms_characters.appearance` trägt das mit.

## Danach: mehr Tiefe

### 3. Telefon — groß
Nachrichten, Kontakte, Notruf, Fraktions-Chat, Anzeigenmarkt. Vieles davon
hängt an den Fraktionen und am Notrufsystem, die beide schon stehen.

### 4. Zufluchtsorte statt Housing — mittel
Klassengerecht: Sarg für Vampire, Höhle für Werwölfe, Turm für Magier. Lagerung
von Steinen, sicherer Respawn, kleiner Essenz-Bonus beim Ausruhen.

### 5. Werkstatt-Tuning — klein
Die Werkstätten reparieren bisher nur. Lackierung, Felgen und Leistungsteile
wären der nächste Schritt; die Spalte `mods` in `ms_vehicles` liegt bereit.

### 6. Mehr Aufträge — klein
Das Auftragssystem in `moonshine-jobs` trägt beliebig viele. Naheliegend:
Abschleppdienst, Busfahrer, Nachtwache an den Ritualpunkten.

## Technik und Betrieb

### 7. Discord-Anbindung — klein
Rollen aus Discord auf Adminlevel und Whitelist-Jobs abbilden, Logs als Webhook
(die Log-Funktion kann das bereits, `Config.Logs.webhook`).

### 8. Statistiken und Bestenlisten — klein
Die Arbeit hat schon eine. Sinnvoll wären außerdem: höchste Klassenstufe,
meiste Weltbosse, größte Fraktionskasse, teuerste Auktion. Aus `ms_logs`,
`ms_mystic`, `ms_factions` und `ms_auctions` direkt ableitbar.

### 9. Testlauf auf echter Hardware — Pflicht vor dem Livegang
Nichts davon lief bisher auf einem laufenden FXServer. Die vollständige Liste
steht in [`LAUNCH.md`](LAUNCH.md).

## Balancing, das später Aufmerksamkeit braucht

* Steinpreise im Skilltree gegen die tatsächliche Bossausbeute
* XP-Kurve gegen die durchschnittliche Spielzeit pro Sitzung
* Schaden der Klassenskills gegen normale Schusswaffen
* Abklingzeiten im Gruppenkampf (mehrere Dämonen mit Höllenschlag)
* Weltereignisse: wie stark dürfen Blutmond und Wilde Jagd eine Klasse machen,
  ohne dass die anderen sich ausloggen
* Gebietseinkommen gegen die Zahl aktiver Fraktionen — bei wenigen Fraktionen
  kassiert jede zu viel
* Fahrzeugpreise gegen das Einkommen aus Arbeit, Ritualen, Missionen und
  Gebieten
* Arbeitslöhne gegen die Spritkosten — Fahren muss sich lohnen, aber nicht zu
  sehr
* Verfallsgeschwindigkeit der Klassenbedürfnisse — eine Stunde bis zur
  Warnung klingt richtig, ist aber nie an echten Sitzungen gemessen worden.
  Besonders die Fee (1,4 je Takt) könnte in der Stadt zu schnell leerlaufen.

## Abgehakt

* **Zirkel / Fraktionen** — als `moonshine-factions` gebaut, inklusive Rängen,
  Kasse, Tresor, Skilltree und Gebietskontrolle
* **Blutmond und Weltevents** — als `moonshine-world` gebaut, acht Ereignisse
  und acht Mondphasen mit Ankündigung und Countdown
* **Fahrzeuge und Garagen** — als `moonshine-vehicles` gebaut, inklusive
  Schlüsseln und Verwahrstelle
* **Bank, Geldautomaten, Schwarzmarkt** — in `moonshine-services`, dazu
  Tankstellen und Werkstätten
* **Jobs mit Inhalt** — als `moonshine-jobs` gebaut, vier Aufträge über ein
  gemeinsames Auftragssystem
* **Admin-Panel** — als `moonshine-admin` gebaut, inklusive Noclip,
  Beobachten und Protokollansicht
* **Anticheat-Grundlagen** — Wachhund mit Strikes plus `MS.RateLimit`, das an
  allen geldbewegenden Ereignissen hängt
* **Klassenbedürfnis** — als `moonshine-needs` gebaut: acht Bedürfnisse mit
  eigenen Quellen, Zonen, Interaktionen und Wirkung auf die Klassenwerte
* **Kleidung und Charaktereditor** — als `moonshine-appearance` gebaut, mit
  Gesichtsmischung, Läden in drei Preisstufen, Friseuren und Outfits
* **Steinadern** — durch Weltbosse und den Steinhändler ersetzt
