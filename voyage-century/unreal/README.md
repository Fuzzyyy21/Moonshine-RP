# Unreal-Projekt (Phase 1)

> **Status: Code geschrieben, aber noch nie kompiliert.** In der Umgebung, in der
> Phase 1 entstanden ist, gibt es keine Unreal Engine. Der erste Build muss lokal
> erfolgen; Compilerfehler bitte als Issue oder direkt zurückmelden.

Engine: in `VoyageCentury.uproject` auf **5.6** eingestellt. Andere 5.x-Versionen per
Rechtsklick auf die `.uproject` → *Switch Unreal Engine version*. Build-Einstellungen
nutzen `BuildSettingsVersion.Latest`, damit kein versionsspezifischer Wert festgeschrieben ist.

## Module

| Modul | Inhalt |
|---|---|
| `VCCore` | Log-Kategorie `LogVC`, Backend-Adressen (`UVCBackendSettings`), Schnittstelle `IVCServerHooks` |
| `VCData` | Row-Structs für die generierten Data Tables |
| `VCNet` | HTTP/JSON-Client `FVCHttp`, Login-Ablauf `UVCSessionSubsystem` |
| `VoyageCentury` | Primärmodul: `AVCPlayerController` (Konsolenbefehle, Admin-RPC), `AVCCharacter` (Bewegung, Kamera), `AVCPlayerState` + `UVCProgressionComponent` (replizierte Progression) |
| `VCServer` | `AVCGameMode`: Ticketprüfung, Laden/Speichern, Admin-Audit, Kills, Respawn; `UVCServerSettings` |
| `VCRules` | Kampfformeln ohne Engine-Abhängigkeit |
| `VCAbilities` | Attribute, Kampfablauf (`FVCCombat`), Grundangriff, Fähigkeiten, Statuseffekte, Hotbar, Kampfdaten (`UVCCombatSettings`) |
| `VCAI` | `AVCMonster`, `AVCMonsterAIController`, `AVCMonsterSpawner` |
| `VCNaval` | `AVCShip` (Schiff als Spielfigur, Fahrt über `VCShipRules`), Schiffsdaten (`UVCNavalSettings`) |
| `VCWorld` | Objekte in Karten: `AVCZoneExit` (Zonenausgang), `AVCNpc`, `AVCDiscoveryPoint`; Weltdaten (`UVCWorldSettings`) |

Targets: `VoyageCentury` (Game), `VoyageCenturyEditor`, `VoyageCenturyServer`, `VoyageCenturyClient`.

## Einmalige Schritte im Editor

Binäre Assets lassen sich nicht als Text anlegen. Nach dem ersten Öffnen:

1. **Testkarte** `Content/Maps/L_DevTestZone` anlegen (Vorlage *Basic*), einen `PlayerStart` platzieren, speichern.
2. **Data Tables** importieren: jede Datei aus `Content/Data/Generated/` per Drag & Drop in den
   Content Browser ziehen und die passende Row-Struktur wählen:

   | Datei | Row-Struktur |
   |---|---|
   | `DT_Professions.json` | `VCProfessionRow` |
   | `DT_Skills.json` | `VCSkillRow` |
   | `DT_SkillStages.json` | `VCSkillStageRow` |
   | `DT_ShipClasses.json` | `VCShipClassRow` |

   Die JSON-Dateien werden von `tools/export_content.py` erzeugt. Nach einem neuen Export
   im Editor *Reimport* ausführen – nie die Tabellen im Editor von Hand ändern.

## Ablauf testen (Abnahme Phase 1)

Voraussetzung: PostgreSQL läuft, Migrationen sind eingespielt und beide Backend-Dienste
laufen (siehe [`../backend/README.md`](../backend/README.md)).

```bash
# 1. Dedicated Server (Service-Key nur über die Umgebung)
export VC_SERVICE_KEY=dev-only-service-key-0000000000000000
VoyageCenturyServer -log -port=7777 -VCZone=DEV_TESTZONE -VCServerId=zone-dev-1

# 2. Zwei Clients starten (gepackt oder "VoyageCentury.exe -game"), in der Konsole (^):
VCLogin <login> <passwort>
VCCharacters
VCCreateCharacter Seefahrer MALE ROYAL_OFFICER
VCConnect 127.0.0.1:7777 <characterId>
```

Abnahmekriterien:

| Kriterium | Prüfung |
|---|---|
| Zwei Clients sehen sich | beide Platzhalterfiguren in L_DevTestZone sichtbar |
| Position wird gespeichert | Admin-Teleport (unten) oder warten (Intervall 30 s), Client trennen |
| Position nach Neustart | Server **und** Backend neu starten, erneut verbinden → Figur an alter Position |
| Admin-Kommando im Audit-Log | Konto in der DB zum Admin machen (`UPDATE accounts SET admin_level = 1 WHERE login = '…'`), neu verbinden, dann `VCAdmin "teleport 0 0 300"` → Zeile in `admin_audit_log` mit alter und neuer Position |
| Ohne Ticket kein Zutritt | `open 127.0.0.1:7777` ohne Login → Verbindung abgelehnt |

## Landkampf (Phase 3)

Neue Module: `VCRules` (Kampfformeln, reines C++, getestet mit `tools/test_rules.sh`), `VCAbilities`
(Gameplay Ability System), `VCAI` (Gegner, KI, Spawner).

Zusätzliche Schritte im Editor:

| Data Table | Row-Struktur | Pfad (siehe `DefaultGame.ini`) |
|---|---|---|
| `DT_CombatTuning.json` | `VCCombatTuningRow` | `/Game/Data/DT_CombatTuning` |
| `DT_Weapons.json` | `VCWeaponRow` | `/Game/Data/DT_Weapons` |
| `DT_Monsters.json` | `VCMonsterRow` | `/Game/Data/DT_Monsters` |

In `L_DevTestZone`: ein **NavMeshBoundsVolume** über die Fläche ziehen (sonst laufen Gegner nicht)
und zwei **VCMonsterSpawner** platzieren, `MonsterCode` = `DEV_TRAINING_DUMMY` bzw. `DEV_PIRATE_BRAWLER`.
Fehlen Tabellen, ist Kampf deaktiviert (Log: „Kampfdaten fehlen“) – es wird nie mit Ersatzwerten gekämpft.

Testen:

```
Tab                         → Ziel wählen (nächstes lebendes Ziel, erneut drücken wechselt)
Linke Maustaste             → angreifen (Reichweite und Intervall prüft der Server)
VCStatus                    → Leben, Stufe, Skills
VCAdmin "giveitem DEV_SWORD" → Schwert ins Inventar (Admin, protokolliert)
VCInventory                 → Inventar mit Nummern; VCEquip <nr> rüstet das Schwert aus
```

Erwartung: Übungspuppe besiegen → +20 XP (Wert aus dem Backend), jeder Treffer +5 Skill-XP auf den
Waffenskill. Der Übungspirat greift im Umkreis von 8 m an und kehrt nach 20 m zurück. Zwei Spieler
können sich in der Testzone bekämpfen (PvP-Zone); nach dem Tod Respawn nach 5 s.

Hinweis: In älteren Engine-Versionen muss `UAbilitySystemGlobals::Get().InitGlobalData()` beim Start
aufgerufen werden; in 5.6 sollte das nicht nötig sein – bei Fehlermeldungen zu Target Data bitte melden.

## Welt und Zonenwechsel (Phase 4, Iteration 1)

Jede Zone ist ein eigener Server-Prozess mit eigener Karte. Karten sind Binär-Assets und müssen im Editor
angelegt werden (Vorlage *Basic*, Inhalt Platzhalter – Stadtpläne des Originals sind UNKNOWN):

| Karte | Zone | PlayerStarts (Feld *Player Start Tag*) | `VCZoneExit` (Feld *Exit Code*) |
|---|---|---|---|
| `L_DevTestZone` (vorhanden) | `DEV_TESTZONE` | einer ohne Tag, `FROM_LONDON` | `TO_LONDON` |
| `L_London` | `CITY_LONDON` | einer ohne Tag, `FROM_TESTZONE`, `HARBOR` | `TO_TESTZONE`, `HARBOR` |
| `L_SeaDev` | `SEA_DEV` | `LONDON`, `ATHENS` (auf einem Anleger) | `LONDON`, `ATHENS` |
| `L_Athens` | `CITY_ATHENS` | einer ohne Tag, `HARBOR` | `HARBOR` |

Wohin ein Ausgang führt, steht in `design_data/world_layout.json` (nicht in der Karte). Ankunftspunkte nicht
in ein Ausgangsvolumen stellen; zur Sicherheit wechselt eine Figur in den ersten 2 s nach dem Erscheinen nicht.

Starten (Backend wie oben, `World:StartZoneId` = `DEV_TESTZONE` in Development):

```bash
export VC_SERVICE_KEY=dev-only-service-key-0000000000000000
VoyageCenturyServer /Game/Maps/L_DevTestZone -log -port=7777 -VCZone=DEV_TESTZONE -VCServerId=dev-1
VoyageCenturyServer /Game/Maps/L_London      -log -port=7778 -VCZone=CITY_LONDON  -VCServerId=london-1
VoyageCenturyServer /Game/Maps/L_SeaDev      -log -port=7779 -VCZone=SEA_DEV      -VCServerId=sea-1
VoyageCenturyServer /Game/Maps/L_Athens      -log -port=7780 -VCZone=CITY_ATHENS  -VCServerId=athens-1
```

Jeder Server meldet sich beim World Directory an (Log: „Im World Directory angemeldet“). Andere Rechner:
`-VCPublicAddress=<ip>:<port>` setzen. Client: in der Oberfläche das Serverfeld **leer** lassen und *Spielen*,
oder in der Konsole `VCPlay <characterId>`. Dann zum Ausgang `TO_LONDON` laufen → London, weiter über
`HARBOR` auf die Seezone und über `ATHENS` nach Athen.

Was der Server verhindert: zweites Einloggen desselben Charakters (Meldung „Charakter ist bereits online“),
direktes Verbinden in eine Zone, in der der Charakter nicht steht, und Speichern durch den alten Server nach
einem Wechsel.

## Schiffe (Phase 5, Iteration 1)

| Data Table | Row-Struktur | Pfad |
|---|---|---|
| `DT_Ships.json` | `VCShipRow` | `/Game/Data/DT_Ships` |
| `DT_ShipTuning.json` | `VCShipTuningRow` | `/Game/Data/DT_ShipTuning` |
| `DT_ZoneWind.json` | `VCZoneWindRow` | `/Game/Data/DT_ZoneWind` |

`DT_ShipClasses` neu importieren (Klasse `BEGINNER`). In `L_SeaDev` eine große ebene Fläche auf Höhe 0 als Wasser-
Platzhalter (keine Kollision mit dem Schiff nötig; `SeaLevelZ` in *Voyage Century Naval*), Anleger als Hindernisse.

Testen (Server für Athen und Seezone laufen, siehe Phase 4):

```
VCPlay <id>                     → in Athen (oder über die Seezone dorthin)
zum Werftmeister gehen
VCBuyShip DEV_STARTER_SHIP      → kostenlos, wird aktiv
VCAdmin "givegold 6000"         → (Admin) Gold, dann z. B. VCBuyShip DEV_RAIDER_CUTTER
VCShips                         → Schiffe, aktives mit *; VCSetShip <nummer> wechselt (nur an Land)
Ausgang HARBOR                  → Seezone: Spielfigur ist jetzt das Schiff
W/S Segel in Vierteln, A/D Ruder; HUD unten rechts: Fahrt, Kurs, Wind, Rumpf, Matrosen, Proviant
```

Erwartung: gegen den Wind (Winkel zum Wind ≥ 150°) keine Fahrt, halber Wind am schnellsten; Proviant sinkt
(Anfängerschiff mit 6 Matrosen: 0,6 je Minute); Auflaufen stoppt. Nach Neustart sind Schiff und Werte gespeichert.

## Seekampf und Hafendienste (Phase 5, Iteration 2)

| Data Table | Row-Struktur | Pfad |
|---|---|---|
| `DT_Cannons.json` | `VCCannonRow` | `/Game/Data/DT_Cannons` |
| `DT_PirateShips.json` | `VCPirateShipRow` | `/Game/Data/DT_PirateShips` |

`DT_Ships` und `DT_ShipTuning` neu importieren. In `L_SeaDev` einen **VCPirateSpawner** (*Pirate Code* `DEV_PIRATE_SLOOP`)
mit Abstand zum Anleger platzieren.

Testen: mit dem Schiff hinaussegeln → der Pirat greift an (Aggro 50 m). Q/E feuern, R wechselt Nah-/Fernkanone,
HUD zeigt Nachladezeit, Treffer stehen über den Schiffen. Pirat versenkt → +150 XP (Backend). Eigenes Schiff gesunken →
an Land; in Athen beim Werftmeister:

```
VCShipService REPAIR            → Rumpf voll (2 Gold je Punkt)
VCShipService HEAL              → Verletzte gesund (20 je Matrose)
VCShipService HIRE 5            → Matrosen anheuern (50 je Matrose, bis zur Kapazität)
VCShipService PROVISIONS 100    → Proviant (1 je Einheit, bis zum Maximum)
```

## Gilden (Phase 7, Iteration 2)

Keine Data Table. Namen mit Leerzeichen in Anführungszeichen.

```
VCAdmin "givegold 1000"
VCGuildCreate "Die Seefahrer" SEE   → Gilde gegründet (1000 Gold), du bist Gildenleiter
VCGuildInvite Anna                  → Anna: VCGuildInvites, dann VCGuildAccept <nr>
VCGuild                             → Name, Kürzel, Rang, Mitglieder mit Rang und Online-Status
VCGuildRank Anna 1                  → Anna wird Gildenoffizier; VCGuildRank Anna 0 übergibt die Leitung
VCGuildKick Bob | VCGuildLeave | VCGuildDisband
VCGuildChat "Treffen am Hafen"      → [Gilde] bei allen Mitgliedern, auch auf anderen Servern
```

## Chat und Freunde (Phase 7, Iteration 1)

Keine Data Table. Der Server holt Chat jede Sekunde vom Backend (nach der Anmeldung im World Directory). Text mit
Leerzeichen in Anführungszeichen setzen.

```
VCSay "Hallo"                   → [Lokal] im Umkreis von 50 m
VCWorld "Wer handelt Öl?"       → [Welt] auf allen Servern (höchstens 2 je 10 s)
VCTradeChat "Kaufe Eisen"       → [Handel]
VCWhisper Anna "Treffen am Hafen?" → [Flüstern] bei Anna, auch auf einem anderen Server; du siehst [An Anna]
VCFriendAdd Anna | VCFriends    → Freunde mit online/offline und Zone
VCIgnore Bob | VCUnignore Bob   → Bobs Nachrichten ausblenden
VCReport Bob "beleidigt"        → Meldung mit Bobs letzten Nachrichten
VCAdmin "mute Bob 30 WORLD Spam" | VCAdmin "announce Wartung um 20 Uhr"
```

## Auktionshaus (Phase 6, Iteration 4)

`DT_Npcs` neu importieren (Rolle `Auctioneer`). In `L_London` einen **VCNpc** `DEV_LONDON_AUCTIONEER`, in `L_Athens`
`DEV_ATHENS_AUCTIONEER` platzieren.

```
VCInventory                          → Nummern der Items
VCAuctionSell <nr> 10 1000           → beim Auktionator: 10 Stück für 1000 Gold einstellen (2 % Gebühr)
VCAuction DEV_MAT_CLOTH              → überall: Angebote, billigste zuerst (ohne Ware: alle)
VCAuctionBuy <angebot>               → beim Auktionator kaufen (Verkäufer erhält 95 %)
VCAuctionMine                        → eigene Angebote mit Status
VCAuctionCancel <angebot> | VCAuctionCollect → zurückziehen / Abgelaufenes zurückholen
```

## Sammeln und Herstellen (Phase 6, Iteration 3)

| Data Table | Row-Struktur | Pfad |
|---|---|---|
| `DT_GatherNodes.json` | `VCGatherNodeRow` | `/Game/Data/DT_GatherNodes` |

In `L_DevTestZone` einige **VCGatherNode** platzieren (*Node Code* `DEV_NODE_IRON`, `DEV_NODE_TREE`, `DEV_NODE_FLAX`,
`DEV_NODE_RICH_IRON`; Platzhalter-Zylinder mit Beschriftung).

```
E am Sammelpunkt                → „Sammle … (3 s, nicht bewegen)“, danach „Gesammelt: 2 × Holzscheit (Test)“; Punkt flach, wächst nach
VCRecipes                       → ✔/✘ je Rezept mit Skillstufe, Material (Vorrat) und Gebühr
VCAdmin "givegold 100"
VCCraft DEV_RECIPE_SWORD        → 3 Eisen + 1 Holz + 10 Gold → Übungsschwert, Schmieden-XP
VCCraft DEV_RECIPE_CANVAS 2     → 6 Stoff → 2 Segeltuch
```

Herstellen geht nur an Land; ob Skill, Material, Gold und Platz reichen, entscheidet das Backend.

## Inventar und Beute (Phase 6, Iteration 2)

Keine neue Data Table: Items, Plätze und Beute kommen aus dem Backend (`design_data/dev_loot.json`). Die ausgerüstete
Waffe ist jetzt ein Item im Inventar und wird beim Login aus dem Backend übernommen; `VCAdmin "equip"` entfällt.

```
VCAdmin "giveitem DEV_SWORD"    → (Admin) Item ins Inventar; "giveitem DEV_MAT_CLOTH 50" für Stapel
VCInventory                     → Plätze mit Nummer (Nr.), Menge, ausgerüstete Waffe [WEAPON]
VCEquip <nr> | VCUnequip        → Waffe ausrüsten (tauscht mit der bisherigen) / ablegen (nur an Land)
VCDiscard <nr> <menge>          → wegwerfen
VCSellItem <nr> <menge>         → beim Händler verkaufen (Stoffrest 3, Eisen 8, Waffen 40/60 Gold)
Übungspirat besiegen            → „Beute: …“ (Stoff, Eisen, selten eine Klinge, 5–20 Gold)
```

Was nicht ins Inventar (30 Plätze) passt, geht verloren und wird gemeldet.

## Hafenhandel (Phase 6, Iteration 1)

`DT_Npcs` neu importieren (neue Rolle `Merchant`, Feld `bIsDev`). In `L_London` einen **VCNpc** mit *Npc Code*
`DEV_LONDON_MERCHANT` und in `L_Athens` einen mit `DEV_ATHENS_MERCHANT` platzieren. Das Backend braucht
`Content:AllowDevContent` (Development).

```
VCMarket                        → beim Händler: Waren, Kauf-/Verkaufspreis der nächsten Einheit, Vorrat, an Bord, Laderaum
VCTrade BUY DEV_GOOD_OIL 30     → in Athen billig kaufen (landet im aktiven Schiff)
… über die Seezone nach London …
VCTrade SELL DEV_GOOD_OIL 30    → teurer verkaufen
```

Gold-Quellen und -Senken: `GET /internal/v1/economy/summary?days=7` (interner Dienstzugang).

## Rammen, Enterhaken, Entern, Minen (Phase 5, Iteration 3)

Keine neue Tabelle: die Werte stehen in `DT_ShipTuning` (Zeile `Default`, Kategorien Rammen/Enterhaken/Entern/Minen) –
neu importieren. Fehlen sie, sind die Fähigkeiten wirkungslos (alles 0), nie Ersatzwerte.

| Taste | Wirkung |
|---|---|
| (Fahrt) | Auflaufen auf ein feindliches Schiff vor dem Bug ab 3 m/s rammt es |
| F | Enterhaken auf das nächste feindliche Schiff (≤ 8 m, beide ≤ 4 m/s) |
| B | Entern, solange festgehakt; Runden alle 2 s, HUD zeigt „ENTERN“ |
| M | Mine hinter dem Heck (`VCMine`, Platzhalter-Kugel) |

Testen: neben dem Piraten Segel reffen, F, B → mit genug Matrosen ist der Pirat genommen (+XP). Mit weniger Matrosen
als der Pirat hakt er selbst an und entert. Mine legen und den Piraten hinterherfahren lassen.

## NPCs und Entdeckungen (Phase 4, Iteration 2)

| Data Table | Row-Struktur | Pfad |
|---|---|---|
| `DT_Npcs.json` | `VCNpcRow` | `/Game/Data/DT_Npcs` |
| `DT_Discoveries.json` | `VCDiscoveryRow` | `/Game/Data/DT_Discoveries` |

In den Karten platzieren (Stadtpläne des Originals sind UNKNOWN, Position frei wählbar):

| Karte | `VCNpc` (*Npc Code*) | `VCDiscoveryPoint` (*Discovery Code*) |
|---|---|---|
| `L_London` | `LONDON_OFFICER_EXCHANGE` | `DEV_DISC_LONDON_LOOKOUT` |
| `L_Athens` | `ATHENS_SHIPYARD` | – |
| `L_SeaDev` | – | `DEV_DISC_SEA_WRECK` |
| `L_DevTestZone` | – | `DEV_DISC_TESTZONE_RUIN` |

Nur NPCs mit belegter Rolle **und** belegtem Ort gibt es: Werftmeister (船老板) in jeder Stadt mit belegtem
Schiffsumbau, Offizierskarten-Tauscher (副官卡片兑换员) in London. Der Hafenarbeiter (heilt Matrosen) hat keinen
belegten Ort und fehlt deshalb.

Testen: zu einem NPC gehen, **E** → Fenster mit Namen (Rollentitel), Aufgabe und Beleg; die Dienste folgen
mit Schiffen bzw. Offizieren. Entdeckungspunkt betreten → „Entdeckt: … (+50 XP)“, zweites Betreten gibt nichts.
Nach Neustart bleibt die Entdeckung gespeichert (`VCStatus` zeigt die XP).

## Fähigkeiten, Statuseffekte, Hotbar (Phase 3, Iteration 2)

Zusätzliche Data Tables (Pfade in `DefaultGame.ini`):

| Data Table | Row-Struktur | Pfad |
|---|---|---|
| `DT_Abilities.json` | `VCAbilityRow` | `/Game/Data/DT_Abilities` |
| `DT_StatusEffects.json` | `VCStatusEffectRow` | `/Game/Data/DT_StatusEffects` |

`DT_CombatTuning` neu importieren (neues Feld `StaminaRegenPerSecond`). Fehlen die beiden neuen Tabellen,
gibt es nur den Grundangriff (Log: „nur Grundangriff verfügbar“).

Das HUD (`AVCHUD`) setzt der GameMode automatisch: Leben/Ausdauer und eigene Statuseffekte unten links,
Zielrahmen oben, Hotbar unten (Abklingzeit als Abdunkelung), Kampftexte über den Köpfen.

Testen (Adminkonto, Backend in Development):

```
VCAbilities                          → alle Fähigkeiten mit Voraussetzungen
VCAdmin "giveitem DEV_SWORD", VCInventory, VCEquip <nr> → Schwert
VCHotbar 1 DEV_POWER_STRIKE          → Platz 1 belegen (Backend speichert)
VCHotbar 2 DEV_FIRST_AID
Tab, dann 1                          → Wuchtschlag auf das Ziel; sofort erneut 1 → „Noch nicht bereit“
2                                    → Erste Hilfe (nach erlittenem Schaden): Heilung alle 2 s, grüne Zahlen
VCAdmin "giveitem DEV_BLADE", VCEquip <nr> → Klinge; VCAdmin "setskill FALCHION 5"
VCHotbar 3 DEV_CRIPPLING_SLASH       → Übungspirat wird langsamer und blutet (orange Zahlen)
VCUnequip                            → unbewaffnet; mit VCAdmin "setskill BAREHAND 10" dann
VCHotbar 4 DEV_STUNNING_BLOW         → Betäubungsschlag: Ziel 2 s betäubt
VCHotbar 3 leer                      → Platz leeren
```

Nach Neustart von Server und Backend ist die Hotbar wieder belegt. Abklingzeiten und Statuseffekte
überdauern keinen Neustart (Absicht: Laufzeitzustand). Betäubte Gegner bleiben stehen und greifen nicht an.

## Charaktererstellung (Phase 2, Iteration 2)

Ein gepackter Client startet offline mit der Login-Oberfläche: anmelden, Charakter mit Name,
Geschlecht, Beruf und Aussehen anlegen, Server-Adresse eintragen, **Spielen**. Im Editor öffnet
`VCCharacterScreen` dieselbe Oberfläche. Alle Auswahlmöglichkeiten kommen vom Backend.

Echtes Modell einbinden: in den Projekteinstellungen *Voyage Century Appearance* `CharacterMesh`
und `AnimClass` (ein Animation Blueprint mit Elternklasse `VCAnimInstance`; Variablen `GroundSpeed`,
`Direction`, `bIsMoving`, `bIsFalling`) setzen. Der Platzhalter wird dann ausgeblendet.

| Data Table zusätzlich | Row-Struktur |
|---|---|
| `DT_AppearanceSlots.json` | `VCAppearanceSlotRow` |

## Phase 2 testen (Progression und Bewegung)

Steuerung: WASD, Maus, Leertaste. Mit Adminkonto (Backend in Development, Entwicklungskurven aktiv):

```
VCAdmin "givexp 450"                → VCStatus zeigt Stufe 3, XP 450
VCAdmin "giveskillxp NAVIGATION 100000" → NAVIGATION Stufe 31 (Grenze der Grundstufe)
VCAdmin "setskill SWORD 60"         → SWORD Stufe 60, Skillstufe 2
```

Danach Client trennen, Server und Backend neu starten, erneut verbinden: `VCStatus` zeigt dieselben Werte.
Jede dieser Aktionen steht in `admin_audit_log`.

Clients haben keinen Weg, Level oder XP zu setzen: Die Progressionskomponente nimmt Werte nur auf dem
Server an und nur aus Backend-Antworten; `CheckAuthority` verwirft alle anderen Aufrufe.

## Sicherheitsregeln im Code

* Der Server spawnt erst einen Pawn, wenn Ticket **und** Charakterbesitz vom Backend bestätigt sind.
* Ohne Bestätigung nach `AuthTimeoutSeconds` (15 s) wird getrennt.
* Gespeicherte Positionen werden nur in der Zone verwendet, in der sie gespeichert wurden.
* Admin-Kommandos: Recht wird auf dem Server geprüft (Adminlevel kommt vom Backend, nie vom Client),
  dann **erst Audit-Eintrag, dann Ausführung**. Scheitert das Audit, passiert nichts.
* Der Service-Key kommt nur aus `VC_SERVICE_KEY`; in Client-Builds (`WITH_SERVER_CODE == 0`)
  existiert der Codepfad nicht.
* Im Editor (PIE) dürfen Spieler ohne Backend spielen (`bAllowUnauthenticatedInEditor`);
  in gepackten Builds ist das wirkungslos.

## Bekannte Grenzen

* Laufgeschwindigkeit, Sprunghöhe usw. sind Engine-Standardwerte (Originalwerte UNKNOWN).
* Platzhalterfigur ohne Animation, bis Modell und AnimBP eingehängt sind; Gesicht und Kleidung werden gespeichert, aber noch nicht dargestellt.
* Konsolenbefehle statt Login-Oberfläche; Passwort steht in der Konsolen-Historie.
* Das Ticket steht in der Verbindungs-URL und kann in ausführlichen Engine-Logs auftauchen.
* Fällt ein Zonen-Server aus, kann der Charakter erst nach `World:ServerTimeoutSeconds` (30 s) wieder einloggen.
* Zonen-Server weisen sich nur über den gemeinsamen Service-Key aus; ein Server könnte sich als anderer ausgeben (Vertrauensgrenze: Serverbetrieb).
* Nur Speichern und Entdeckungen prüfen die Anwesenheit; XP-Vergaben und Kill-Meldungen eines alten Servers würden noch angenommen (idempotent, aber nicht an die Zone gebunden).
