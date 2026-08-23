# Vorschau der Oberflächen

Rendert ein NUI ohne laufenden FXServer und schießt Bilder davon. Kein
Mockup: geladen wird die echte `index.html` samt `style.css` und `app.js`,
gefüttert mit genau den Nachrichten, die der Client-Code schickt.

Gut, um vor dem ersten Serverstart zu sehen, ob ein Layout hält – bei der
Anzeige hat es auf Anhieb drei Fehler gezeigt (acht Ringe brachen als 5+3
um, vier Auswahlknöpfe als 3+1, und der Gang stand halb außerhalb des
Tachorings).

## Aufruf

```bash
npm install playwright              # einmalig, Chromium liegt schon bereit

node tools/vorschau/laden.js        # laedt alle 16 Oberflaechen, prueft auf Fehler
lua5.4 tools/vorschau/ziehen.lua    # Config -> daten/*.json
node tools/vorschau/hud.js          # Bilder -> tools/vorschau/bilder/
```

Ein anderer Zielordner geht als Argument: `node tools/vorschau/hud.js /tmp/x`.
Den Browser sucht `browser.js` selbst; `CHROMIUM_PFAD` sticht, falls nicht.

## laden.js — laedt jede Oberflaeche

Prueft ohne Daten, was beim Laden selbst passiert. Das ist mehr als es
klingt: die meisten dieser Dateien haengen schon auf oberster Ebene
Klick-Handler an Elemente (`$('btn-close').onclick = ...`). Fehlt so ein
Element, wirft die Zeile — und alles danach in der Datei laeuft nie.

Geprueft wird ausserdem, dass keine Oberflaeche quer scrollt.

Die verwandte Pruefung `NUI-ELEMENT-FEHLT` in `tools/pruefen.py` findet
dasselbe statisch und braucht keinen Browser. Sie kam von einem echten Fund:
im Skilltree standen vier Zuweisungen auf Element-Namen von vor einem Umbau
mitten in der Zeichenfunktion. Die brach dort ab — und ihre letzte Zeile war
die, die den Bildschirm sichtbar macht. Der Baum ging ueberhaupt nicht auf.

## Wie es zusammenhängt

`ziehen.lua` lädt die echte `shared/config.lua` der Anzeige und schreibt
Elementliste, Auswahlmöglichkeiten und Standardeinstellung als JSON heraus.
So zeigen die Bilder immer den aktuellen Stand und nicht eine Handabschrift,
die irgendwann veraltet.

`hud.js` setzt einen dunklen Grund hinter das durchsichtige NUI, ersetzt
`fetch` (die NUI-Rückrufe gehen im Spiel an den Client, hier ins Leere) und
schickt der Reihe nach `hud:setup`, `hud:settings`, `hud:update`,
`hud:vehicle` und `hud:menu`.

## Was es nicht kann

Alles, was am Spiel hängt: echte Werte, echte Straßennamen, das Verhalten
beim Fahren, den Gurt. Die Bilder zeigen das Layout, nicht die Mechanik.
