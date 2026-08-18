# Ideen und Ausbaustufen

Stand: Core, Mystik-System, Sterbesystem, Steinadern und Beispiel-Shop sind
gebaut. Was hier steht, ist noch nicht umgesetzt — sortiert nach dem Nutzen für
einen mystischen Roleplay-Server.

## Zuerst: das macht den Server rund

### 1. Zirkel (Fraktionen der Klassen) — großer Brocken
Vampirzirkel, Rudel, Hexenzirkel, Jägerorden. Gründen kostet Seelensteine,
Ränge mit Rechten, gemeinsame Steintruhe, Zirkel-Chat, Mitgliederliste im
Skilltree-Fenster. **Warum:** Das System hat acht Klassen, aber noch keinen
Grund, sich zu organisieren. Zirkel liefern die Struktur für alles Weitere
(Territorien, Kriege, gemeinsame Rituale).

### 2. Klassenbedürfnis — mittel
Jede Klasse braucht etwas zum Überleben: Vampire Blut (von Spielern oder NPCs
per Nahkampf-Interaktion), Werwölfe rohes Fleisch, Magier Manakristalle, Feen
Nähe zur Natur. Sinkt der Wert, verliert man Essenz-Regeneration und am Ende
Leben. **Warum:** Gibt jeder Klasse einen eigenen Alltag statt nur Kampfskills.
Hunger/Durst aus dem Core ist die Vorlage, das System steht schon.

### 3. Blutmond und Weltevents — mittel
Alle paar Stunden eine Nacht mit Blutmond: Werwölfe verstärkt, alle Steinadern
aufgefüllt, doppelte Meditationsausbeute, ein Weltboss an einem Ritualpunkt.
Ankündigung über den Server, Countdown im HUD. **Warum:** Gibt dem Server
Rhythmus und Termine, zu denen Leute online kommen.

### 4. Territorien an Ritualpunkten — mittel
Ein Zirkel hält einen Ritualpunkt und bekommt passiv Steine. Andere können ihn
durch ein Ritual (mehrere Minuten Anwesenheit, PvP möglich) übernehmen.
**Warum:** Der erste echte Grund für Konflikt zwischen Klassen — und die
Steinwirtschaft bekommt einen zweiten Kreislauf.

## Danach: fehlende RP-Grundlagen

### 5. Kleidung und Charaktereditor — mittel
Aktuell bekommt jeder das Standardmodell. Die Spalte `appearance` ist bereits
vorbereitet, der Gestaltwandel meldet sein Ende über `mystic:client:transformEnded`.

### 6. Telefon — groß
Nachrichten, Kontakte, Notruf, Zirkel-Chat, Anzeigenmarkt. Vieles davon hängt
an Zirkeln und am Notrufsystem, das mit `moonshine-death` schon steht.

### 7. Fahrzeuge und Garagen — mittel
Besitz in der Datenbank, Garagen zum Ein- und Auslagern, Schlüssel. Für einen
Server mit Reisezielen (Ritualpunkte, Steinadern) früher wichtig als Housing.

### 8. Zufluchtsorte statt Housing — mittel
Klassengerecht: Sarg für Vampire, Höhle für Werwölfe, Turm für Magier. Lagerung
von Steinen, sicherer Respawn, kleiner Essenz-Bonus beim Ausruhen.

### 9. Bank, Geldautomaten, Schwarzmarkt — klein bis mittel
Die Konten (Bar, Bank, Schwarzgeld) existieren, es fehlen die Orte dazu.
Schwarzmarkt für Steine und verbotene Artefakte passt zum Setting.

### 10. Jobs mit Inhalt — mittel
Die Jobs im Core sind bisher nur Titel und Gehalt. Sinnvoll wären zwei bis drei
echte Abläufe (Trucker-Touren, Taxi-Aufträge, Werkstatt-Reparaturen).

## Technik und Betrieb

### 11. Admin-Panel als Oberfläche — mittel
Spielerliste, Teleport, Items, Klassen, Bans per Fenster statt Commands.

### 12. Anticheat-Grundlagen — klein
Zentrale Ratenbegrenzung für Netzwerkevents, Distanz- und Plausibilitätsprüfung
an einer Stelle statt in jeder Resource, Logging auffälliger Muster.

### 13. Discord-Anbindung — klein
Rollen aus Discord auf Adminlevel und Whitelist-Jobs abbilden, Logs als Webhook
(die Log-Funktion kann das bereits).

### 14. Statistiken und Bestenlisten — klein
Wer hat die meisten Steine abgebaut, wer die höchste Klassenstufe, wie viele
Wiederbelebungen. Aus `ms_logs` und `ms_mystic` direkt ableitbar.

### 15. Testlauf auf echter Hardware — Pflicht vor dem Livegang
Nichts davon lief bisher auf einem laufenden FXServer. Vor allem zu prüfen:
alle Koordinaten (Ritualpunkte, Steinadern, Krankenhäuser, Läden), die
Animationen, das Zusammenspiel von Modelltausch und Kleidung, und die Last der
Marker-Threads bei vielen Spielern.

## Balancing, das später Aufmerksamkeit braucht

* Steinpreise im Skilltree gegen die tatsächliche Fundrate der Adern
* XP-Kurve gegen die durchschnittliche Spielzeit pro Sitzung
* Schaden der Klassenskills gegen normale Schusswaffen
* Abklingzeiten im Gruppenkampf (mehrere Dämonen mit Höllenschlag)
