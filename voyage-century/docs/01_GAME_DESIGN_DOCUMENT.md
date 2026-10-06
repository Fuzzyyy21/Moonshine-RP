# Game Design Document

Stand: 2026-10-03 · Phase 0 · Version 0.1

## Lesehilfe

Jedes System hat drei Teile:

* **Original** – Befunde aus der Reconstruction Database mit ID und Confidence.
  Nur das ist Rekonstruktion.
* **Design** – wie wir das System bauen. Alles hier ohne Original-ID ist eine
  eigene Designentscheidung (Quellen-Priorität 6) und als `[DESIGN]` markiert.
* **Offen** – unbekannte Punkte. Sie werden nicht erfunden, sondern als leere
  Datenfelder (NULL / UNKNOWN) gebaut und später befüllt.

Grundsatz: **Spielwerte stehen nie im Code.** Sie kommen aus Data Tables, die
aus der Reconstruction Database erzeugt werden. Fehlt ein Wert, ist die
Funktion gesperrt statt mit einer Fantasiezahl aktiv.

---

## 1. Spielkern

Ein Spieler ist Kapitän und Landkämpfer zugleich. Die Progression läuft auf
mehreren getrennten Achsen, die sich gegenseitig freischalten:

```
Berufsstufe (Level) ──► Ausrüstung, Gebiete, Quests
17 Skills (je 1–120, Summe ≤ 1700) ──► Fähigkeiten, Schiffstypen, Crafting
Militärrang ──► UNKNOWN
Schiff: Schiffsstufe + Umbaustufe + 3 Schiffs-Skills ──► Seekampf, Handel, Erkundung
Offiziere ──► Schiffsboni (UNKNOWN)
Gilde ──► Städtebesitz, Belagerung
```

Original: `SKILL-TOTAL-CAP` LIKELY, `SHIP-SKILLS` LIKELY, `SHIPMOD-SYSTEM` LIKELY, `SYS-MILITARY-RANK` UNCERTAIN.

---

## 2. Charakter

**Original**
* Fünf Berufe mit Land- und See-Spezialisierung (`PROF-*`, vier LIKELY, Schatzjäger UNCERTAIN).
* HP und SP (Stamina) als Ressourcen; +10 HP / +5 SP pro Stufe in der intl. Version (`LVL-PER-LEVEL-BONUS` UNCERTAIN).
* Berufswechsel möglich (`SYS-PROFESSION-CHANGE` UNCERTAIN).

**Design**
* Datenfelder wie im Master-Prompt (CharacterID … Guild), Umsetzung siehe [03_DATA_MODEL.md](03_DATA_MODEL.md).
* Charaktererstellung: Geschlecht, Gesicht, Haare, Haarfarbe, Haut, Körper, Startkleidung, Name, **Beruf**. `[DESIGN]` Erscheinungsbild als Parameter-Set (`appearance` JSON), damit neue Optionen ohne Migration dazukommen.
* Attribute: als offene Schlüssel-Wert-Liste modelliert, weil die Originalattribute UNKNOWN sind. `[DESIGN]`
* Beruf bestimmt nur **Spezialisierungsboni**, keine harten Sperren, bis das Original geklärt ist. `[DESIGN]`
* Später: Outfits, Kosmetik, Titel, Pets, Reittiere (Prioritätsstufe 13).

**Umgesetzt (Phase 2, Iteration 2)**
* Merkmale und Anzahl der Optionen stehen in `design_data/appearance.json` → `appearance_slots`. Der Server lehnt unbekannte Merkmale und Werte außerhalb des Bereichs ab und füllt fehlende Merkmale mit 0.
* Die Erstellungsoberfläche baut Berufe, Geschlechter und Merkmale aus `/v1/character-options`; Berufe mit unsicherer Quellenlage sind dort gekennzeichnet.
* Darstellung: Platzhalterfigur mit Haut-, Haarfarbe, Frisurhöhe und Körperbau. Ein echtes Modell wird per Projekteinstellung eingehängt (`UVCAppearanceSettings`), die Animation über ein AnimBP auf `UVCAnimInstance`.

**Offen**: Attributnamen, Startwerte, Startort je Beruf, Kosten des Berufswechsels.

---

## 3. Levelsystem

**Original**: Cap 160 ab 2011 (LIKELY), ≥ 168 später (LIKELY), 230 nur als Indiz (UNCERTAIN). XP-Kurve UNKNOWN.

**Design**
* Das Cap ist **kein Code-Wert**: die höchste Stufe mit gesetztem `xp_required` in `level_table` ist das Cap.
* Bänder aus dem Master-Prompt (1–30 … 221–230) werden als **Content-Bänder** für Gebiete, Gegner und Ausrüstung genutzt. `[DESIGN]`
* Solange die XP-Kurve fehlt, gibt es für Entwicklung und Tests eine **klar markierte Test-Kurve** in einer separaten Data Table `DT_LevelCurve_DEV`, die im Shipping-Build nicht geladen werden darf. `[DESIGN]`

**Umgesetzt (Phase 2, Iteration 1)**
* `level_table` und `skill_level_table` enthalten kumulierte XP-Schwellen. Das Cap ist die letzte Stufe einer **lückenlosen** Folge bekannter Schwellen; fehlt eine Stufe, endet die Kurve dort.
* Entwicklungskurven (`design_data/dev_curves.json`: Charakter 100·(L−1)², Skills 50·(L−1)²) stehen mit `is_dev = TRUE` in der Datenbank und werden nur bei `Progression:AllowDevCurves` benutzt. Echte Werte ersetzen sie stufenweise.
* Ohne nutzbare Kurve sammelt sich XP weiter an, das Level bleibt.

**Offen**: echte XP-Tabelle, aktuelles Cap, Boni pro Stufe in der CN-Version.

---

## 4. Skills

**Original**
* 17 Skills, 4 Kategorien, Stufen 31 / 100 / 120, Summe ≤ 1700 (alle LIKELY).
* Navigation beeinflusst nutzbare Schiffstypen und Spezialfähigkeiten.
* Seekampf-Zweige aus den Berufstexten: Kanonen (nah/fern), Entern, Enterhaken, Rammen, Minen, Reparatur, Verstärkung, Matrosen heilen.

**Design**
* Skill-XP durch **Benutzung** (Kampf mit Schwert erhöht Schwert usw.). `[DESIGN]` – Original-Mechanik UNKNOWN, Annahme muss geprüft werden.
* Stufenaufstieg 31 → 32 und 100 → 101 erfordert eine **Beförderung** (Quest oder NPC). Bedingungen kommen aus `skill_stages.promotion_requirements`; bis zur Klärung ist die Beförderung gesperrt.
* Gesamtcap 1700 wird serverseitig geprüft; Spieler können Skills **senken**, um Punkte umzuverteilen. `[DESIGN]`
* Fähigkeiten (aktiv/passiv) sind GAS-Abilities, die über `abilities.required_skill_level` freigeschaltet werden.
* UI-Gruppierung Kampf / Seefahrt / Berufe wie im Master-Prompt, Datenkategorie bleibt original (`CONTRA-005`).

**Umgesetzt (Phase 2, Iteration 1)**
* Skill-XP wird vom Zonen-Server gemeldet und im GameData-Dienst verbucht. Die Stufe ist begrenzt durch die Skill-XP-Kurve, das Maximum der aktuellen Skillstufe (31/100/120) und das Restbudget des Gesamtcaps (1700 minus Summe aller anderen Skills).
* Skills ohne Eintrag gelten als Stufe 1 mit 0 XP `[DESIGN]` (Startwerte UNKNOWN).
* Automatische Beförderung findet nicht statt, solange die Bedingungen UNKNOWN sind; `/setskill` setzt Stufe und Skillstufe mit Audit.

**Offen**: chinesische Skillnamen für 12 von 17 Skills, XP-Gewinn je Aktion, Liste der Fähigkeiten pro Skill, Beförderungsbedingungen.

---

## 5. Landkampf

**Original**: Waffenklassen Schwert, Klinge, Axt, Schusswaffe, Unbewaffnet (über Skills LIKELY). Schwere Rüstung beim Gardisten. Heilung und Support beim Händler. Kampfmodell (Tab-Target oder Action) **UNKNOWN**.

**Design**
* **Tab-Target mit Auto-Attack und Hotbar-Skills** als Ausgangsbasis `[DESIGN]` – passt zum MMO-Stil der Zeit, muss per Video bestätigt werden. Die Architektur (GAS) trägt auch Action-Kampf.
* Schadensformel serverseitig (`FVCCombat` → `VCRules`); der Gameplay Effect wendet nur den fertigen Schaden an. Alle Koeffizienten aus Data Tables.
* Kritische Treffer, Block, Ausweichen als Attribute im AttributeSet; Buffs, Debuffs und Statuseffekte als serverseitiger Zustand je Kämpfer (Regeln in `VCRules`, Anzeige repliziert). Geändert in Iteration 2 gegenüber „Gameplay Effects mit Tags“, weil Stapeln, Ticks und Kill-Zuordnung so ohne Engine testbar sind.
* Waffen: Damage, Attack Speed, Range, Animation (Montage-Referenz), Skills, Requirements, Durability – alles in `items` bzw. `DT_Weapons`.
* NPC-KI: StateTree je Gegnerprofil (Patrouille, Aggro, Flucht, Rückkehr). Aggro-Liste serverseitig.
* PvP und PvE nutzen dieselbe Pipeline; PvP-Regeln (Zonen, Strafen) siehe Abschnitt 17.

**Umgesetzt (Phase 3, Iteration 1)** `[DESIGN]`, Formeln in `VCRules`, Werte in `design_data/dev_combat.json`
* Kampfwerte: Leben = Grundwert + **10 je Stufe** (aus `LVL-PER-LEVEL-BONUS`, UNCERTAIN), Ausdauer + 5 je Stufe (ebenso); Angriff und Verteidigung je Stufe sind Entwicklungswerte.
* Waffenschaden = Grundschaden × (1 + 1 % je Waffenskillstufe über 1).
* Ablauf je Angriff: Ausweichen (kein Schaden) → Block (halber Schaden, kein Krit) → Krit (×1,5); Verteidigung mindert mit V / (V + 100); mindestens 1 Schaden; ±10 % Streuung. Chancen gedeckelt (Krit 50 %, Block/Ausweichen 40 %).
* Tab-Target: Tab wählt das nächste Ziel, linke Maustaste greift an. Der Client sendet nur das Ziel; Reichweite, Intervall, Feindschaft und Schaden prüft der Server.
* Jeder Treffer gibt 5 Skill-XP auf den Waffenskill; ein Kill gibt die XP aus den Gegnerdaten (vom Backend festgelegt).
* PvP nur in Zonen mit `pvp_mode = FREE` (die Testzone ist FREE). PvP gibt keine XP.
* Tod: Respawn nach 5 s am PlayerStart mit vollem Leben, ohne Verlust (Todesstrafen des Originals UNKNOWN).

**Umgesetzt (Phase 3, Iteration 2)** `[DESIGN]`, Regeln in `VCAbilityRules`, Werte in `design_data/dev_abilities.json`
* Fähigkeiten hängen an einem Skill und werden über dessen Stufe freigeschaltet; manche brauchen eine Waffenart. Kosten: Ausdauer, Abklingzeit. Schaden = Waffenschaden × Faktor, dann derselbe Ablauf wie beim Grundangriff (Ausweichen → Block → Krit).
* Einsatzprüfung in fester Reihenfolge, der erste Grund wird dem Spieler angezeigt: tot → betäubt → falsche Waffe → Skillstufe → Abklingzeit → Ausdauer → kein Ziel → kein Feind → zu weit.
* Statuseffekte haben Dauer und Stapelgrenze; erneutes Anwenden frischt die Dauer auf und erhöht den Stapel. Wirkung je Stapel: Angriff, Verteidigung, Chancen (additiv), Tempo (multiplikativ), Betäubung, Schaden oder Heilung je Tick. Weicht das Ziel aus, wirkt kein Statuseffekt.
* Ein Kill durch Schaden über Zeit zählt für den, der den Effekt gesetzt hat.
* Ausdauer regeneriert 2 pro Sekunde (Entwicklungswert). Statuseffekte enden mit dem Tod und werden nicht gespeichert.
* Hotbar mit 10 Plätzen (Tasten 1–0), je Charakter gespeichert; jede Fähigkeit höchstens einmal.
* Entwicklungsfähigkeiten (alle `DEV_…`, Namen ohne Originalbeleg): Wuchtschlag (Schwert), Sehnenschnitt (Klinge; Verlangsamung + Blutung), Rüstungsbrecher (Axt; −5 Verteidigung je Stapel, bis 3), Gezielter Schuss (Schusswaffe, 20 m), Betäubungsschlag (unbewaffnet, ab Stufe 10; 2 s Betäubung), Erste Hilfe (Medizin; Heilung über Zeit auf sich selbst).

**Offen**: Kampfmodell des Originals, Liste der Originalfähigkeiten je Skill, Combo-System (im Original nicht belegt), Spezialwaffen, alle Originalwerte, Anzahl der Hotbar-Plätze.

---

## 6. Schiffe

**Original**
* Drei Klassen: Kriegsschiff, Erkundungsschiff, Handelsschiff (LIKELY).
* Schiffe nur beim Werftmeister (LIKELY).
* Drei Schiffs-Skills Bewaffnung / Mobilität / Struktur, steigen durch Kampf / Erkundung / Handel (intl., UNCERTAIN).
* Schiffsstufen (10 + Anfänger + Sonderschiff, intl.) getrennt von Umbaustufen (1–14, CN) – `CONTRA-003`.
* Alle Werte UNKNOWN (`SHIP-STATS`).

**Design**
* Schiffsvorlage = Zeile in `ships` / `DT_Ships` mit allen Feldern aus dem Master-Prompt; jedes Feld darf NULL sein.
* Ein Schiff mit NULL in einem **bewegungsrelevanten** Feld (Speed, Turning, HullHP) kann nicht ausgegeben werden. So wird nie mit erfundenen Werten gespielt.
* Schiffs-Instanz trägt Rumpf-HP, Segel-HP, Matrosen (gesund/verletzt), Proviant, Umbaurichtung und -stufe sowie XP der drei Schiffs-Skills.

**Umgesetzt (Phase 5, Iteration 1)** `[DESIGN]`, Werte in `design_data/dev_ships.json`
* Vier Entwicklungsschiffe (`DEV_…`): Anfängerschiff (eigene Klasse BEGINNER, kostenlos, eins je Charakter – Bezugsweg im Original UNKNOWN) und je eins der drei Klassen für 5000 Gold. Die Werte halten die belegten Rangfolgen ein (Erkundungsschiff am schnellsten und mit den meisten Matrosen, Handelsschiff am langsamsten mit der größten Ladung, Kriegsschiff hält am meisten aus); der Export prüft das.
* Kauf nur beim Werftmeister in derselben Zone (Abstand prüft der Server), Gold im Ledger, jeder Kauf genau einmal. Das erste Schiff wird aktiv; das aktive Schiff wechselt man an Land.
* Startbesatzung = Hälfte der Kapazität (Community-Rat aus `SAILOR-SYSTEM`), Startproviant aus den Daten. Anheuern, Proviant kaufen und Reparatur folgen; bis dahin können Rumpf, Matrosen und Proviant nur sinken (Backend lehnt höhere Werte ab).
* Gold: Startguthaben des Originals UNKNOWN (0); Admins können Gold gutschreiben (`givegold`, protokolliert).

**Umgesetzt (Phase 5, Iteration 2)** `[DESIGN]`: Hafendienste beim Werftmeister gegen Gold – Reparatur (2 Gold je Rumpfpunkt), Verletzte heilen (20 je Matrose), Anheuern (50 je Matrose, bis zur Kapazität), Proviant (1 je Einheit, bis zum Maximum). Preise und der Ort fürs Anheuern sind im Original UNKNOWN; belegt ist nur, dass der Hafenarbeiter Matrosen heilt (Ort unbekannt).

**Offen**: alle Schiffsnamen und Werte, Bedingungen für den Schiffsstufen-Aufstieg.

---

## 7. Segeln und Navigation

**Original**: nicht belegt. Belegt ist nur: Matrosenzahl beeinflusst Tempo, Galionsfigur „Wind“ erhöht Tempo, Mobilitäts-Umbau erhöht Vortrieb.

**Design** `[DESIGN]`
* Eigenes, serverautoritatives Bewegungsmodell (kein Chaos-Rigid-Body für die Fahrt):
  `Zielgeschwindigkeit = BaseSpeed × Segelstellung × Windfaktor(Kurs zum Wind) × Matrosenfaktor × Zustandsfaktor`
  Beschleunigung und Drehrate begrenzen den Weg zur Zielgeschwindigkeit.
* Wind: globales, langsam veränderliches Windfeld pro Seegebiet (Richtung, Stärke), vom Server repliziert.
* Strömung: Vektorfeld je Region, addiert sich zur Fahrt.
* Wellen und Wetter: visuell (Water-Plugin, Niagara) plus ein serverseitiger Wetterzustand, der Sicht und Tempo beeinflussen kann.
* Steuerung: Ruder links/rechts, Segelstufen (z. B. 0 / ¼ / ½ / voll), Anker.
* Alle Faktoren als Kurven in Data Assets, damit sie nach Videoanalyse an das Original angepasst werden können.

**Umgesetzt (Phase 5, Iteration 1)** `[DESIGN]`, Regeln in `VCShipRules` (getestet), Werte in `design_data/dev_ships.json`
* Zielgeschwindigkeit = Höchstfahrt × Segel × Windfaktor × Matrosenfaktor × Proviantfaktor. Windfaktor = (1 − Windabhängigkeit) + Windabhängigkeit × Polare(Winkel zum Wind) × Windstärke. Polare: vor dem Wind 0,8, halber Wind 1,0, ab 150° (gegen den Wind) 0.
* Matrosenfaktor: unter Mindestbesatzung keine Fahrt, sonst 0,5 bis 1,0 bei voller Besatzung. Proviant: 0,1 je Matrose und Minute; ohne Proviant halbe Fahrt (Wirkung im Original UNKNOWN).
* Wendigkeit wächst mit der Fahrt (im Stand 20 %). Segel in Vierteln (W/S), Ruder A/D.
* Wind je Seezone: pendelt langsam um eine Grundrichtung; deterministisch aus Zeit und Zonendaten, daher gleich auf Server und Client ohne Replikation. Strömung und Wetter folgen.
* Fahrt rechnet nur der Server; der Client sendet Segel und Ruder. Auflaufen stoppt das Schiff (Schaden folgt mit dem Seekampf).

**Offen**: Gibt es im Original Wind? Wie war die Steuerung? Wie stark wirkte Matrosenzahl?

---

## 8. Seekampf

**Original**: Kanonen nah/fern, Entern, Enterhaken, Rammen, Minen, Reparatur, Verstärkung, Matrosen heilen (LIKELY). Kanonen sind stufige Ausrüstung (`SHIP-CANNON-LEVELS` UNCERTAIN). Seeschlachten mit sehr vielen Schiffen (LIKELY). Schadensmodell UNKNOWN.

**Design**
* Breitseiten: Kanonen sitzen in Slots links/rechts/Bug/Heck; Feuern nur im Schusswinkel des Slots. `[DESIGN]`
* Projektile: serverseitig ballistisch simuliert (wenige Schüsse pro Sekunde, daher günstig); Client zeigt kosmetische Kugeln mit Vorhersage.
* Schadenskanäle: Rumpf, Segel, Matrosen; optional Feuer und Leck als Dauer-Effekte. Welche Kanäle das Original hatte, ist UNKNOWN – alle sind einzeln abschaltbar.
* Entern: ab Nähe X und Tempo < Y Übergang in einen Boarding-Kampf, Ausgang über Matrosenzahl, Entern-Skill und Offiziere. Werte UNKNOWN.
* Reparatur: auf See mit Material (Fähigkeit), im Hafen gegen Gold (Gold-Senke).
* Flucht: Kampf endet, wenn Abstand > Kampfradius für Z Sekunden.
* Untergang: Schiff sinkt, Spieler respawnt im Hafen; Verlustregeln UNKNOWN.


**Umgesetzt (Phase 5, Iteration 2)** `[DESIGN]`, Regeln in `VCNavalCombatRules` (getestet), Werte in `design_data/dev_ships.json`
* Breitseiten: Q backbord, E steuerbord; je Seite die Hälfte der Kanonenplätze. Getroffen wird das nächste feindliche Schiff im Feuerwinkel (±45° um die Querachse) und in Reichweite.
* Zwei Kanonen (belegt: Nah/Fern): Nahkanone 15 m, mehr Schaden, Fernkanone 40 m, weniger Schaden; Trefferchance sinkt mit der Entfernung. Umschalten mit R.
* Ein Wurf je Kanone; jeder Treffer kostet Rumpf und anteilig Matrosen, davon 30 % tot, der Rest verletzt (Zustände belegt). Verletzte segeln und schießen nicht mit.
* Ohne Mindestbesatzung keine Breitseite. Rumpf 0: Das Schiff sinkt; der Spieler kommt an Land zurück, das Schiff bleibt mit Rumpf 0 im Besitz (Strafe im Original UNKNOWN).
* Piratenschiff als Gegner: legt sich quer zum Ziel, hält Abstand, feuert; XP für das Versenken legt das Backend fest (wie bei Landgegnern).
* PvP auf See nur in Zonen mit `pvp_mode = FREE`.

**Umgesetzt (Phase 5, Iteration 3)** `[DESIGN]`, Regeln in `VCNavalAbilityRules` (getestet), Werte in `design_data/dev_ships.json` (`naval_abilities`)
* Belegt sind nur die Fähigkeiten selbst und dass das Erkundungsschiff stark beim Entern ist (`SHIPCLASS-RAIDER`); alle Zahlen sind Entwicklungswerte.
* Rammen: Läuft ein Schiff mit mindestens 3 m/s auf ein feindliches Schiff, das innerhalb ±30° vor dem Bug liegt, nimmt das Ziel Tempo × 8 × Rumpf/1000 Schaden, der Rammende ein Viertel davon. Danach stehen beide.
* Enterhaken (F): nächstes feindliches Schiff bis 8 m, beide höchstens 4 m/s; beide liegen 30 s fest. Abklingzeit 45 s, auch bei Fehlwurf.
* Entern (B, nur festgehakt): alle 2 s eine Runde; Verluste je Seite = Gegner × Stärke × 0,15 × Wurf (0,5 … 1,5), Erkundungsschiff Stärke 1,5, sonst 1. Verluste wie bei Treffern verletzt oder tot. Ohne Matrosen verliert die Seite: Verteidiger genommen (für ihn wie Sinken; Pirat → XP), Angreifer abgewehrt (Haken löst sich). Offiziere und Entern-Skill folgen später.
* Minen (M): 6 m hinter dem Heck, nach 3 s scharf, Radius 4 m, 120 Rumpf und 3 Matrosen, 120 s Lebensdauer, Abklingzeit 30 s. Treffen feindliche Schiffe und nach dem Scharfschalten auch den Leger; verschwinden, wenn der Leger die Zone verlässt.
* Pirat: hat er mehr Matrosen als das Ziel, fährt er heran, refft, wirft den Haken und entert.

---

## 9. Crew und Offiziere

**Original**: Matrosen mit Zuständen (UNCERTAIN), Proviant (UNCERTAIN), Offiziere über **Offizierskarten** mit Tauschhändler in London (UNCERTAIN). Rollen und Werte UNKNOWN.

**Design**
* Offiziere als Vorlage (`officers`) + Instanz (`officer_instances`), Karte = Item, das eine Instanz erzeugt.
* Rollenliste aus dem Master-Prompt (Captain, Navigator, Gunner …) nur als **Platzhalter**; Feld `role` ist frei, bis das Original geklärt ist. `[DESIGN]`
* Matrosen: anwerben in Taverne, verletzt → heilen mit Medizin oder im Hafen, tot → neu anwerben.

---

## 10. Schiffs-Upgrades

**Original**
* Umbau in drei Richtungen, Stufen 1–14, an bestimmte Städte gebunden (LIKELY/UNCERTAIN).
* Galionsfiguren Wasser/Feuer/Wind (LIKELY), Verfeinerung von Galionsfiguren (UNCERTAIN).
* Schiffspanzerung aus dem Schiffbau-Skill (LIKELY).

**Design**
* Die Kette aus dem Master-Prompt wird auf das Original abgebildet:
  `Base Ship → Umbau 1–n → Galionsfigur + Panzerung + Kanonen → hohe Umbaustufen → Endgame-Schiff`.
* Umbau ist eine einmal gewählte Richtung pro Schiff (`mod_direction`). Ob das Original einen Richtungswechsel erlaubt, ist UNKNOWN.
* Module (Rumpf, Segel, Kanonen, Panzerung, Steuerung, Frachtraum, Crew, Spezial) als Ausrüstungsslots am Schiff.

---

## 11. Offene Welt

**Original**: reale Weltkarte, fünf Kontinente, sieben Meere; Städte siehe `CITY-*`. Übergang Land/See UNKNOWN.

**Design**
* Hierarchie Kontinent → Region → Stadt / Hafen / Insel / Dungeon / Ruine / Spezialgebiet.
* Technisch: jedes Seegebiet ist eine eigene Server-Zone, Städte sind eigene Zonen, Dungeons sind Instanzen (siehe [02_TECHNICAL_ARCHITECTURE.md](02_TECHNICAL_ARCHITECTURE.md)).
* Maßstab der Karte: verkleinerte reale Geografie; Faktor ist eine offene Designfrage, abhängig von Reisezeiten im Original.

**Umgesetzt (Phase 4, Iteration 1)** `[DESIGN]`, Daten in `design_data/world_layout.json`
* Zonen: `CITY_LONDON`, `CITY_ATHENS` (die am besten belegten Städte) und die technische Seezone `SEA_DEV`, die beide Häfen verbindet. `SEA_DEV` hat bewusst keine Geografie, bis Seegebiete und Maßstab belegt sind.
* Übergänge: Hafen London ↔ Seezone ↔ Hafen Athen; Testzone ↔ London für die Entwicklung. Jeder Übergang ist ein Ausgang in der Karte und ein Ankunftspunkt in der Zielkarte.
* Ein Charakter ist immer in genau einer Zone; er betritt nur die Zone, in der er steht. Neue Charaktere beginnen in der konfigurierten Startzone (Startstadt des Originals UNKNOWN).
* Seegebiete: nicht übernommen, weil die einzige Liste (`REGION-LIST-17173`) mit 大航海时代 Online vermischt sein kann.
* Auf See gibt es bis Phase 5 (Schiffe) nur die Zone selbst; man steht dort auf einem Anleger.

---

## 12. Städte und Häfen

**Original**: Werftmeister, Hafenarbeiter, Offizierskarten-Tauscher, Schiffsumbau in festen Städten.

**Design**: jeder Hafen bekommt Dienste als Flags (`ports.has_*`) und NPCs mit Rolle (`npcs.npc_role`). Regionale Wirtschaftsunterschiede über Warenangebot und Preise je Hafen (`markets`).

**Umgesetzt (Phase 4, Iteration 1)**: Häfen aus der Reconstruction Database – Werft, wo Schiffsumbau belegt ist (Athen, Genua, Algier, Sevilla, Hamburg, Maskat, Seoul, Zhigu), Offizierskarten-Tausch in London. Alle anderen Dienste sind NULL (UNKNOWN), nicht „gibt es nicht“.

**Umgesetzt (Phase 4, Iteration 2)**: NPCs nur mit belegter Rolle und belegtem Ort – Werftmeister (船老板, `SHIP-ACQUISITION`) in jeder Stadt mit belegtem Schiffsumbau, Offizierskarten-Tauscher (副官卡片兑换员) in London. Name = Rollentitel der Quelle. Ansprechen mit E (Abstand prüft der Server, 3 m `[DESIGN]`); das Fenster nennt Aufgabe und Beleg, die Dienste folgen mit Schiffen bzw. Offizieren. Der Hafenarbeiter fehlt, weil sein Ort nicht belegt ist.

---

## 13. Handel und Wirtschaft

**Original**: Handel existiert, Rhetorik ist Handels-Skill, Handelsschiffe steigen durch Handel auf (LIKELY). Preismodell, Waren, Steuern UNKNOWN.

**Design** `[DESIGN]`
* Preis je Ware und Hafen:
  `Preis = BasePrice × f(Supply, Demand) × Regionsfaktor × Eventfaktor × (1 ± Rhetorik-Bonus) × (1 + Steuer)`
  Supply und Demand erholen sich zeitbasiert zum Gleichgewicht; Spielerkäufe und -verkäufe verschieben sie.
* Alles serverseitig; Clients sehen nur Preise.
* Währungen: Gold, Premium, Gilde, Event. Nur Gold ist zwischen Spielern handelbar.
* **Inflationskontrolle**: jede Gold-Bewegung landet im `currency_ledger` mit Kennzeichnung SOURCE/SINK. Ein Dashboard vergleicht täglich Quellen und Senken.
* Gold-Senken: Reparaturen, Steuern, Crafting-Gebühren, Schiffskauf, Umbau, Marktgebühren, Matrosenlohn, Proviant.
* Auktionshaus mit Einstellgebühr und Verkaufssteuer.

**Umgesetzt (Phase 6, Iteration 1)** `[DESIGN]`, Regeln in `backend/src/VC.GameData/TradePricing.cs` (getestet), Werte in `design_data/dev_trade.json`
* Jeder Markt (Hafen × Ware) hat Basispreis, Bestand und Gleichgewichtsbestand. Mittelpreis = Basis × (Gleichgewicht / Bestand)^0,7, begrenzt auf das 0,4- bis 2,5-Fache. Kaufen kostet Mittelpreis × 1,05 × (1 + Steuer), Verkaufen bringt Mittelpreis × 0,95 × (1 − Steuer); Steuer 5 %.
* Jede Einheit wird einzeln zum Bestand nach ihrer Bewegung bewertet: große Käufe werden teurer, große Verkäufe billiger, und Kaufen mit sofortigem Rückverkauf im selben Hafen bringt nie Gewinn.
* Der Bestand wandert mit festem Tempo je Stunde zurück zum Gleichgewicht (Händler kaufen nach bzw. verkaufen weiter).
* Testwaren: Wolle billig in London (Kauf etwa 45), teuer in Athen (Verkauf etwa 85); Öl umgekehrt (Athen etwa 50, London etwa 99); Gewürze in beiden Häfen ähnlich teuer.
* Ware liegt im Laderaum des aktiven Schiffs, eine Einheit = ein Platz; Laderaum aus `ships.cargo_capacity` (Handelsschiff am größten, belegt als Rangfolge).
* Händler (Rolle MERCHANT) stehen als Entwicklungs-NPC in London und Athen, weil kein Händlerort belegt ist. Handel braucht den Händler der eigenen Zone.
* Gold: Kauf beim Händler ist eine Senke (`TRADE_BUY`), Verkauf eine Quelle (`TRADE_SELL`). Die Wirtschaftsübersicht zählt Quellen und Senken je Tag und Grund.
* Offen: Wirkung der Rhetorik (Preisbonus), Aufstieg von Handelsschiffen durch Handel, echte Waren und Preise.

**Umgesetzt (Phase 6, Iteration 4)** `[DESIGN]`, Regeln in `backend/src/VC.GameData/AuctionRules.cs` (getestet), Werte in `design_data/dev_auction.json`
* Ein Auktionshaus für alle Häfen, bedient vom Auktionator (Entwicklungs-NPC in London und Athen; im Original nicht belegt). Suchen und eigene Angebote ansehen geht überall, Einstellen, Kaufen, Zurückziehen und Abholen nur beim Auktionator.
* Einstellen: ganzer Stapel oder Teil davon, Preis 1 … 1 Mrd. Gold, Gebühr 2 % (aufgerundet, mindestens 1) als Senke `AUCTION_FEE`, nie erstattet. Laufzeit 24 h, höchstens 10 offene Angebote je Spieler. Gebundene oder nicht handelbare Items gehen nicht.
* Kaufen: Der Käufer zahlt den Preis; der Verkäufer erhält ihn sofort abzüglich 5 % Steuer (abgerundet), auch wenn er offline ist. Gold zwischen Spielern ist ein Transfer (`AUCTION_BUY`/`AUCTION_SALE`), die Steuer eine Senke (`AUCTION_TAX`). Einzelstücke wie Waffen behalten ihr Exemplar.
* Abgelaufene Angebote sind nicht mehr kaufbar; der Verkäufer holt sie beim Auktionator ab (so weit Platz ist). Zurückziehen geht jederzeit.

**Umgesetzt (Phase 6, Iteration 2)** `[DESIGN]`, Regeln in `backend/src/VC.GameData/InventoryRules.cs` (getestet), Werte in `design_data/dev_loot.json`
* Inventar mit 30 Plätzen; stapelbare Items füllen erst vorhandene Stapel, dann den niedrigsten freien Platz. Was nicht passt, geht verloren und wird gemeldet (kein Boden-Loot).
* Ausgerüstete Waffe ist ein Item (EQUIPMENT/WEAPON); Ausrüsten tauscht mit der bisherigen. Damit kann der Client keine Waffe mehr behaupten, die er nicht besitzt.
* Beute: jeder Eintrag einer Beutetabelle wird einzeln gewürfelt; Chance NULL (UNKNOWN) fällt nie. Goldbeute als Spanne, gebucht als Quelle `LOOT_GOLD`. Beute nur für Gegner, nicht im PvP.
* Verkauf an den Händler zu `items.npc_price` (NULL = kauft er nicht), Quelle `ITEM_SELL`. Wegwerfen vernichtet.
* Testmaterialien Stoffrest und Eisenstück stehen für die belegten, aber unbekannten Synthese-Materialien (SYS-EQUIP-SYNTHESIS).

---

## 14. Crafting und Berufe

**Original**: Sammel-Skills (Bergbau, Holz, Landwirtschaft, Fischen), Herstellungs-Skills (Schmieden, Schneiderei, Alchemie, Schiffbau), Ausrüstungs-Synthese für Sets (LIKELY).

**Design**: Rezepte mit RecipeID, RequiredSkill, RequiredLevel, Materials, Quantity, CraftTime, Result, Quality. Qualität als Zufallsverteilung, deren Parameter aus der Rezeptzeile kommen. Sammelpunkte als serverseitige Ressourcen-Spawner mit Respawn-Zeit.

**Offen**: alle Rezepte, Materiallisten, Sammelorte.

**Umgesetzt (Phase 6, Iteration 3)** `[DESIGN]`, Regeln in `backend/src/VC.GameData/CraftingRules.cs` (getestet), Werte in `design_data/dev_crafting.json`
* Sammelpunkt-Arten mit Skill (Bergbau, Holzfällerei, Landwirtschaft), Mindeststufe, Ausbeute-Spanne, Sammelzeit, Nachwachszeit und Skill-XP; erlaubt nur in ihren Zonen (Testzone). Der Zonen-Server lässt immer nur einen Spieler sammeln, bricht ab, wenn er sich bewegt, und erschöpft den Punkt erst, wenn das Backend bestätigt.
* Rezepte mit Herstell-Skill und Mindeststufe, Materialliste, Ergebnis, Gebühr (Gold-Senke `CRAFT_FEE`) und Skill-XP. Herstellen ist sofort und alles oder nichts: fehlt Material, Gold oder Platz, ändert sich nichts. Material wird aus den kleinsten Stapeln genommen.
* Testrezepte: Übungsschwert (3 Eisen, 1 Holz, 10 Gold, Schmieden 1), Übungsaxt (Schmieden 5), Segeltuch (3 Stoff, Schneiderei 1).
* Noch nicht: Fischen (braucht Punkte auf See), Alchemie, Schiffbau, Qualität, Herstellzeit, Bonus der Skillstufe auf die Ausbeute.

---

## 15. Ausrüstung und Verfeinerung

**Original**: Sets 148/150/155/168, Synthese, Sockel (bis 3), Verfeinerung mit Stein + Edelstein, Ausrüstung 155/160 (LIKELY/UNCERTAIN). Seltenheitsstufen UNKNOWN.

**Design**
* Item-Felder wie im Master-Prompt (ItemID, Level, Rarity, Stats, Requirements, Durability, Sockets, SetID, EnhancementLevel) plus RefinementLevel.
* Verfeinerung, Sockeln, Set-Boni als **getrennte Module**, jeweils per Feature-Flag schaltbar. Enhancement für Ausrüstung bleibt aus, bis es im Original belegt ist (`SYS-ENHANCEMENT`).
* Seltenheit Common … Endgame `[DESIGN]`, bis Originalstufen bekannt sind.
* Haltbarkeit sinkt durch Kampf, Reparatur kostet Gold.

---

## 16. Quests, Exploration, Dungeons

**Original**: Hauptquest bis ca. 160 mit Rückkehr nach England, Folgequests in Quanzhou, Militärrang durch Hauptquest, 海灵之石-Questgegenstände (UNCERTAIN). Dungeons 波托洛维海湾 (See), 暴风岛, 黄金塔.

**Design**
* Questtypen wie im Master-Prompt; Questdaten mit QuestID, Title, Description, NPC, Objectives, Requirements, Rewards, NextQuest, Unlocks.
* Questfortschritt wird nur vom Server über Gameplay-Events (Kill, Collect, Reach …) erhöht.
* Exploration: Entdeckungspunkte (Inseln, Ruinen, Wracks) als Trigger-Volumen; Schatzkarten als Item mit Zielkoordinate; Entdeckungen geben Erkundungsschiff-XP.
* **Umgesetzt (Phase 4, Iteration 2)** `[DESIGN]`: Entdeckungspunkte zählen je Charakter einmal, nur in ihrer Zone und nur vom zuständigen Server; die Belohnung kommt aus den Daten. Bis es Schiffe gibt, geben die drei technischen Punkte (`design_data/dev_discoveries.json`) Charakter-XP. Originale Entdeckungspunkte sind UNKNOWN.
* Dungeons als eigene Server-Instanzen (Land und See). Raids und Weltbosse nur, wenn im Original belegt oder hier bewusst als neu markiert.

---

## 17. Piraten, Gilden, PvP

**Original**: Karibik-Pirat als Beruf; Gilden mit Banner, Städtekauf und -besetzung; Stadtbelagerung; große Seeschlachten; Gildenquests (LIKELY). Regeln UNKNOWN.

**Design**
* Piraten-NPC-Fraktionen mit Flotten, Lagern und Missionen; Kopfgelder (`bounties`) auf NPCs und Spieler mit hoher `infamy`.
* Gilden: Gründung, Ränge mit Rechten, Einladungen, Gildenchat, Gildenlager, Gildenlevel, Gildenskills, Gildenmissionen.
* Territorium: Stadt kann von einer Gilde besessen werden (`territories`), Besitzer erhält Steueranteil und Verwaltungsrechte.
* Belagerung: geplanter Kampf (`territory_wars`) mit Land- und Seephase. Ablauf UNKNOWN, Phase 7.
* PvP-Zonen: sicher (Häfen), umkämpft (Seegebiete mit Regeln je Region), frei (bestimmte Gewässer). Zuordnung `[DESIGN]`.

**Umgesetzt (Phase 7, Iteration 2)**, Regeln in `backend/src/VC.GameData/GuildRules.cs` (getestet), Werte in `design_data/dev_guild.json`
* Belegt und umgesetzt: Der Gründer ist Gildenleiter und legt Name und Banner fest; Ränge Gildenleiter und Gildenoffizier (SYS-GUILD).
* `[DESIGN]`: Name 3–20 Zeichen, Kürzel 2–4 Großbuchstaben/Ziffern (beides eindeutig unter bestehenden Gilden), Banner aus Symbol und zwei Farben (Platzhalter bis zur Oberfläche). Gründung kostet 1000 Gold (Senke `GUILD_FOUND`), höchstens 50 Mitglieder, Einladungen gelten 48 h. Dritter Rang „Mitglied“ ohne Rechte.
* Rechte: Einladen, Entfernen, Rang setzen (Leiter und Offiziere). Entfernt und befördert wird nur unterhalb des eigenen Rangs; die Leitung gibt nur der Leiter ab (er wird dabei Offizier). Der Leiter tritt erst nach der Übergabe aus; das letzte Mitglied löst die Gilde auf (Name und Kürzel werden wieder frei).
* Gildenchat (Kanal GUILD) läuft über denselben Verteiler wie der übrige Chat; das Backend nennt je Server die Mitglieder, die ihn bekommen.
* Offen: Gildenlager, -level, -skills, -quests.

**Umgesetzt (Phase 7, Iteration 3)**, Regeln in `backend/src/VC.GameData/CityRules.cs` (getestet), Werte in `design_data/dev_guild.json`
* Belegt und umgesetzt: Gildenoffiziere kaufen Städte und erhalten Belohnungen und Verwaltungsrechte (SYS-GUILD). Besetzen per Belagerung folgt.
* `[DESIGN]`: Gekauft wird aus der Gildenkasse (London 20 000, Athen 15 000 Gold; Senke `CITY_BUY`), nur freie Städte. Belohnung: 50 % der Handelssteuer im Hafen der Stadt fließen in die Kasse (Quelle `CITY_TAX`, der Rest bleibt Senke). Verwaltungsrecht: Steuersatz 0–15 %, er ersetzt die Marktsteuer im Hafen.
* Gildenkasse: Einzahlen dürfen alle (zählt als Beitrag), Auszahlen nur mit Recht TREASURY (Leiter). Jede Bewegung im `guild_ledger`; die Wirtschaftsübersicht zählt sie mit.
* Auflösen: Städte werden frei, das Restgeld der Kasse geht an den Leiter.

---

## 18. UI/UX

**Original**: Layout nur über Screenshots rekonstruierbar – derzeit **UNKNOWN**.

**Design**: HUD mit Minimap, Kompass, Status, Quest-Tracker, Chat, Hotbar, XP-Leiste, Schiffsstatus, Benachrichtigungen. Fenster wie im Master-Prompt. Umsetzung mit UMG + CommonUI, Fenster als eigenständige Widgets mit eigenem ViewModel (MVVM), damit das Layout nach der Screenshot-Analyse umgebaut werden kann, ohne Logik anzufassen.

---

## 19. Events, Chat, Admin

* **Events**: serverseitiger Scheduler, Eventtypen aus `events.event_type`, Konfiguration in JSON.
* **Chat**: Kanäle Local, World, Trade, Guild, Party, Whisper, System, Combat; Moderation mit Mute, Ignore, Report, Log, Admin-Kontrolle.

**Umgesetzt (Phase 7, Iteration 1)** `[DESIGN]` (Chat und Freundesliste des Originals UNKNOWN), Regeln in `backend/src/VC.GameData/ChatRules.cs` (getestet)
* LOCAL: Umkreis 50 m um den Sprecher, stellt der Zonen-Server sofort zu. WORLD und TRADE: alle Server. WHISPER: an einen Online-Spieler auf beliebigem Server. SYSTEM: nur Admin-Ankündigung. GUILD und PARTY folgen mit Gilden und Gruppen, COMBAT bleibt lokal auf dem Server.
* Jede Nachricht geht durch das Backend: bereinigt (Steuer- und Schreibrichtungszeichen raus, Leerraum zusammengefasst), höchstens 200 Zeichen (länger wird abgelehnt, nicht gekürzt), Stummschaltung je Kanal oder ganz, Rate-Limit 5 je 10 s (WORLD/TRADE: 2). Alles steht im `chat_log`, das zugleich der Verteiler ist: Jeder Zonen-Server holt einmal je Sekunde ab.
* Ignorieren blendet Chat und Flüstern des Ignorierten aus; Flüstern an jemanden, der einen ignoriert, wird abgelehnt.
* Freunde: einseitige Liste (bis 100) mit Online-Status und Zone. Melden speichert die letzten Nachrichten des Gemeldeten der vergangenen Stunde als Kontext.
* Admins: `mute <name> <minuten> [kanal] <grund>` und `announce <text>`, beides im Admin-Audit.
* **Admin**: `/give /item /setlevel /teleport /spawn /kick /ban /mute /announce /event /setmoney /setskill`; jedes Kommando schreibt genau eine Zeile in `admin_audit_log` (append-only, per Trigger erzwungen).
