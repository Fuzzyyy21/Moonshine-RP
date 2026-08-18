# Auktionshaus

Resource: `moonshine-auction`
Zugang: Auktionator ansprechen (`E`) oder `/auktionshaus` in Reichweite

Drei Auktionatoren stehen in Vinewood, in der Innenstadt und in Sandy Shores.
Alles läuft über sie – wer nicht davorsteht, kann weder einstellen noch bieten
noch abholen.

## Einstellen

1. Gegenstand aus dem Inventar wählen
2. Menge, Startpreis, optional einen Sofortkauf und die Laufzeit (1, 6, 12 oder
   24 Stunden) setzen
3. *Auktion anlegen*

Die Ware wird sofort aus dem Inventar genommen. Die Einstellgebühr von 500 $
fällt beim Anlegen an und wird nicht erstattet. Pro Charakter dürfen acht
Auktionen gleichzeitig laufen. `id_card` lässt sich nicht versteigern
(`AuctionConfig.Blocked`).

## Bieten

Ein Gebot muss den aktuellen Stand um mindestens 100 $ **und** um mindestens
3 % übertreffen. Das Geld wird sofort von der Bank abgebucht – niemand kann mit
Geld bieten, das er längst ausgegeben hat.

Wer überboten wird, bekommt sein Gebot vollständig ins Abholfach. Wer sein
eigenes Höchstgebot erhöht, zahlt nur die Differenz.

**Sniping**: Ein Gebot in den letzten zwei Minuten verlängert die Auktion um
zwei Minuten. Wer am Ende zuschlagen will, muss also wirklich mitbieten.

## Sofortkauf

Ist ein Sofortkaufpreis gesetzt, endet die Auktion damit sofort. Ein fremdes
Gebot wird erstattet; wer selbst Höchstbietender war, zahlt nur die Differenz.

## Abrechnung

Beim Ablauf:

* **Mit Gebot** – Ware an den Käufer, Erlös abzüglich 5 % Hausgebühr an den
  Verkäufer.
* **Ohne Gebot** – Ware zurück an den Verkäufer. Die Einstellgebühr bleibt weg.

Der Verkäufer kann eine Auktion abbrechen, solange kein Gebot vorliegt.

## Abholfach

Alles landet im Abholfach, nicht direkt im Inventar – so geht auch nichts
verloren, wenn jemand offline ist oder das Inventar voll hat. Dort warten
ersteigerte Ware, Verkaufserlöse, erstattete Gebote und zurückgekommene Ware,
bis man sie beim Auktionator abholt. Beim Einloggen weist eine Meldung darauf
hin, wenn etwas bereitliegt.

## Oberfläche

| Reiter | Inhalt |
|---|---|
| Markt | Alle laufenden Auktionen, Suche, sechs Kategorien, vier Sortierungen |
| Einstellen | Inventar links, Formular mit Gebührenrechnung rechts |
| Meine Auktionen | Eigene Angebote, Abbrechen ohne Gebot |
| Meine Gebote | Alles, worauf man das Höchstgebot hält |
| Abholfach | Einzeln oder alles auf einmal abholen |

Restzeiten laufen live mit; Auktionen unter fünf Minuten sind rot markiert.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/auktionshaus` | – | Oberfläche öffnen (nur beim Auktionator) |
| `/auktionen` | – | Anzahl eigener Auktionen und Höchstgebote |
| `/auktionabbrechen [id]` | 3 | Auktion beenden, Gebot erstatten, Ware zurück |

## API

```lua
local Auction = exports['moonshine-auction']:GetAuctionObject()

exports['moonshine-auction']:GetOpenAuctions()
exports['moonshine-auction']:DeliverToPlayer(characterId, {
    kind = 'item', item = 'runenstein', label = 'Runenstein', count = 5,
    reason = 'Belohnung',
})
```

Ereignisse: `auction:server:created`, `auction:server:bid`,
`auction:server:sold`.

## Tabellen

`ms_auctions` und `ms_auction_mail`. Abgeschlossene Auktionen werden nach
14 Tagen aufgeräumt.
