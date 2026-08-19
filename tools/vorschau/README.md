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
lua5.4 tools/vorschau/ziehen.lua    # Config -> daten/*.json
node tools/vorschau/hud.js          # Bilder -> tools/vorschau/bilder/
```

Ein anderer Zielordner geht als Argument: `node tools/vorschau/hud.js /tmp/x`.

Findet Playwright den Browser nicht von selbst, hilft `CHROMIUM_PFAD`:

```bash
CHROMIUM_PFAD=/opt/pw-browsers/chromium-1194/chrome-linux/chrome \
    node tools/vorschau/hud.js
```

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
