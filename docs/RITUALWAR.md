# Ritualkrieg – `moonshine-ritualwar`

Bis hierhin liefen zwei Kreisläufe nebeneinander her, ohne sich je zu
berühren: Fraktionen nehmen Gebiete ein und verdienen Geld, Mystiker gehen
an Ritualpunkte und verdienen Steine. Der Ritualkrieg legt beides
übereinander. Die sechs Ritualpunkte aus `moonshine-mystic` werden zu
umkämpftem Besitz – wer einen bindet, verdient an allem, was dort geschieht.

## Der Kreislauf

```
   Bindungsritual            Ertrag                 Wegzoll
   ──────────────            ──────                 ───────
   2 Mitglieder      →   alle 20 Minuten     →   25 % von jedem
   180 Sekunden          Steine in den           fremden Ritual
   75.000 $ Kasse        Fraktionstresor         in die Kasse
        ↑                       ↓                      ↓
        └───────── finanziert die nächste Bindung ─────┘
```

## Die Bindung

Ein Ritualpunkt gehört anfangs niemandem. Um ihn zu binden, braucht eine
Fraktion drei Dinge gleichzeitig:

| | |
|---|---|
| **Leute** | Zwei Mitglieder im Umkreis von 12 Metern, die ganze Zeit über |
| **Zeit** | 180 Sekunden ununterbrochen |
| **Geld** | 75.000 $ aus der Fraktionskasse, fällig beim Start |

Gestartet wird mit `/bindung` am Punkt oder über die Übersicht. Das Recht
dazu hängt am Rang – ein Rang braucht **Gebiete einnehmen**.

Der Balken läuft nur, solange die Bedingungen halten:

* **Jemand aus einer anderen Fraktion steht dabei** → der Balken steht still.
  Nicht rückwärts, nur an. Wer stören will, muss dableiben. Damit sich eine
  Bindung nicht ewig festfährt, endet sie spätestens nach 15 Minuten.
* **Die eigenen Leute gehen weg** → der Balken fällt mit 2 % je Sekunde
  zurück. Ein voller Balken ist nach 50 Sekunden leer, dann bricht die
  Bindung ab. Das gilt auch, wenn gleichzeitig Gegner dastehen: ohne eigene
  Leute läuft nichts.
* **Abbruch** → die halbe Summe kommt zurück in die Kasse. Ein angefangenes
  Ritual verbrennt Material, das lässt sich nicht rückgängig machen.

Der Fraktionsskill **Sturmtrupp** (`soloCapture`) senkt die nötige
Mannstärke auf eine Person; **Blitzeinnahme** (`captureSpeed`) beschleunigt
den Balken.

Nach einer erfolgreichen Bindung ist der Punkt **45 Minuten geschützt** und
kann in dieser Zeit nicht angegriffen werden. Der Skill **Bollwerk**
(`protectionBonus`) verlängert das um bis zu 65 %.

## Was der Besitz einbringt

**Alle 20 Minuten** schüttet jeder gebundene Punkt aus:

| | |
|---|---|
| 1–3 Runensteine | direkt in den Fraktionstresor |
| 1–3 Seelensteine | direkt in den Fraktionstresor |
| 180 XP | auf das Fraktionslevel |

Der Skill **Schürfrechte** (`territoryIncome`) erhöht die Steinmenge.
Ist der Tresor voll, fällt die Ausschüttung aus – Platz schaffen lohnt sich.

Ein Punkt hat sich damit nach gut zwei Stunden bezahlt gemacht. Das ist
Absicht: teuer genug, dass niemand alle sechs nebenbei hält, billig genug,
dass sich der Kampf darum lohnt.

## Wegzoll

Wer an einem fremden Punkt ein Ritual durchführt, lässt etwas da:

| Wer | Ritualertrag | Meditationspunkte |
|---|---|---|
| Mitglied der haltenden Fraktion | **+20 %** | **+20 %** |
| Fremder | **−25 %**, gehen in die Kasse des Halters | **−30 %** |
| Niemand hält den Punkt | unverändert | unverändert |

Beim Ritual bekommt der Spieler eine Meldung, wohin sein Anteil geht. Der
Zoll landet nachvollziehbar im Kassenprotokoll der haltenden Fraktion.

## Störung

Wer **6 Sekunden** lang im Umkreis von **8 Metern** eines Ritualpunkts
steht und einer **anderen Fraktion** angehört als der Ritualist, bricht
dessen Ritual und dessen Meditation ab. Das gilt unabhängig davon, wem der
Punkt gehört.

Stören kann nur, wer selbst in einer Fraktion ist. Das ist Absicht: sonst
blockieren sich an einem belebten Punkt zwei Fremde gegenseitig, ohne dass
einer von beiden das wollte. Wer ohne Fraktion unterwegs ist, stört
niemanden – wird aber von jedem Fraktionsmitglied gestört.

Nicht betroffen ist das Binden von Klassensteinen: Handwerk lässt sich
nicht durch Danebenstehen verhindern (`WarConfig.Disruption.affectsCrafting`).

## Segen der Bindung

Mitglieder der haltenden Fraktion bekommen im Umkreis von **25 Metern**
um ihren Punkt dauerhaft:

* **+0,6** Essenzregeneration
* **+0,3** Lebensregeneration je Tick
* **+15 %** Erfahrung

Das rechnet `moonshine-mystic` in die Modifikatoren des Profils ein, genau
wie Mondphase, Weltereignis und Klassenbedürfnis.

## Commands

| Command | Wer | Wirkung |
|---|---|---|
| `/bindung` | Rang mit *Gebiete einnehmen* | Startet das Bindungsritual am Punkt |
| `/ritualpunkte` | alle | Öffnet die Übersicht |
| `/ritualkarte` | alle | Dasselbe, frei auf eine Taste legbar |
| `/setritualpunkt [id] [fraktionId\|frei]` | Admin ab Level 3 | Vergibt oder befreit einen Punkt |

Auf der Karte trägt jeder Ritualpunkt einen Blip in der Wappenfarbe der
haltenden Fraktion; gebundene Punkte bekommen zusätzlich einen Radius.
Vor Ort zeigt eine Anzeige, wer den Punkt hält, wie lange der Schutz noch
läuft und wie weit ein laufendes Bindungsritual ist.

## Schnittstelle

```lua
local war = exports['moonshine-ritualwar']

war:GetClaims()                       -- Zustand aller Punkte
war:OwnerOf(pointId)                  -- Fraktions-Id oder nil
war:IsHolder(source, pointId)         -- gehoert der Spieler zum Halter?
war:CountPoints(factionId)            -- wie viele Punkte haelt die Fraktion?
war:IsDisrupted(source)               -- stoert gerade jemand?
war:ApplyToll(source, amount)         -- betrag, zoll, halterName
war:MeditationFactor(source)          -- Faktor auf Meditationspunkte
war:GetBlessing(source)               -- Modifikatoren oder nil
war:StartBinding(source)              -- ok, grund
```

### Events

| Event | Argumente |
|---|---|
| `ritualwar:server:claimed` | `pointId, factionId, vorherigeFraktion` |
| `ritualwar:server:bindingStarted` | `pointId, factionId` |
| `ritualwar:server:bindingCancelled` | `pointId, factionId` |
| `ritualwar:server:payout` | `pointId, factionId` |

## Datenbank

```sql
ms_ritual_claims (point_id, faction_id, since, protected_until, payouts)
```

Ein Datensatz je Ritualpunkt. Der Besitz überlebt Neustarts, die Schutzzeit
läuft in Echtzeit weiter.

## Was hier bewusst fehlt

* **Kein Rückerobern während des Schutzes.** 45 Minuten sind hart. Wer den
  Punkt verliert, muss warten – sonst wird jede Bindung zum Dauerkampf.
* **Kein Punktlimit je Fraktion.** Sechs Punkte kosten 450.000 $ und binden
  zwölf Leute gleichzeitig; das reguliert sich über den Aufwand statt über
  eine Zahl in der Config.
* **Keine Zerstörung.** Ein Punkt lässt sich nur übernehmen, nicht
  unbrauchbar machen.
