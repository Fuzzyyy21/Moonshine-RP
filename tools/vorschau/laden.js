/* Laedt jedes NUI im Browser und horcht auf Fehler.
 *
 * Ohne Daten - geprueft wird nur, was beim Laden selbst passiert. Das ist
 * mehr als es klingt: die meisten dieser Dateien haengen schon auf oberster
 * Ebene Klick-Handler an Elemente ($('btn-close').onclick = ...). Fehlt so
 * ein Element, wirft die Zeile, und alles danach in der Datei laeuft nie -
 * Handler, Nachrichtenempfang, alles.
 *
 * Aufruf:  node tools/vorschau/laden.js
 * Rueckgabe: 0 wenn alles sauber laedt, 1 bei Fehlern. */

const { chromium } = require('playwright');
const browserPfad = require('./browser');
const path = require('path');
const fs = require('fs');

const WURZEL = path.resolve(__dirname, '..', '..');
const BASIS = path.join(WURZEL, 'resources', '[moonshine]');

(async () => {
    const resourcen = fs.readdirSync(BASIS)
        .filter((name) => name.startsWith('moonshine-'))
        .filter((name) => fs.existsSync(path.join(BASIS, name, 'nui', 'index.html')))
        .sort();

    const browser = await chromium.launch({
        executablePath: browserPfad.finden(),
    });

    let fehler = 0;
    let mit = 0;

    for (const resource of resourcen) {
        const seite = await browser.newPage({ viewport: { width: 1600, height: 900 } });
        const meldungen = [];

        // Die NUI-Rueckrufe gehen im Spiel an den Client. Hier ins Leere -
        // ein fehlgeschlagenes fetch waere sonst der einzige Fund.
        await seite.addInitScript(() => {
            window.fetch = () => Promise.resolve({ json: () => Promise.resolve({}) });
        });

        seite.on('pageerror', (err) => meldungen.push(String(err)));
        seite.on('console', (msg) => {
            if (msg.type() === 'error') meldungen.push(msg.text());
        });

        await seite.goto('file://' + path.join(BASIS, resource, 'nui', 'index.html'));
        await seite.waitForTimeout(250);

        // Wenn es Nutzlasten gibt, dieselben Nachrichten schicken, die der
        // Client schickt. Ohne Daten laeuft keine Zeichenfunktion - und
        // genau darin steckten die Fehler.
        const daten = path.join(__dirname, 'daten', resource + '.json');

        if (fs.existsSync(daten)) {
            const nachrichten = JSON.parse(fs.readFileSync(daten, 'utf8'));

            for (const nachricht of nachrichten) {
                await seite.evaluate((inhalt) => {
                    window.dispatchEvent(new MessageEvent('message', { data: inhalt }));
                }, nachricht);
            }

            await seite.waitForTimeout(250);
            mit += 1;

            // Zweiter Durchgang: derselbe Aufbau, aber alle Listen leer.
            //
            // Das ist der Zustand eines frischen Servers - keine Auktionen,
            // keine Auftraege, kein Fahrzeug. Und es ist die Stelle, an der
            // FiveM eine Falle stellt: Lua kennt keinen Unterschied zwischen
            // leerer Liste und leerer Tabelle, also kommt beides als {} im
            // NUI an. Der uebliche Schutz "x || []" greift dagegen nicht -
            // {} ist wahr -, und {}.forEach wirft.
            for (const nachricht of nachrichten) {
                await seite.evaluate((inhalt) => {
                    const leeren = (wert) => {
                        if (Array.isArray(wert)) return {};
                        if (wert && typeof wert === 'object') {
                            const raus = {};
                            for (const name of Object.keys(wert)) {
                                raus[name] = leeren(wert[name]);
                            }
                            return raus;
                        }
                        return wert;
                    };

                    window.dispatchEvent(new MessageEvent('message',
                        { data: leeren(inhalt) }));
                }, nachricht);
            }

            await seite.waitForTimeout(250);
        }

        // Quer scrollen darf keine Oberflaeche.
        const quer = await seite.evaluate(() =>
            document.documentElement.scrollWidth - document.documentElement.clientWidth);

        if (quer > 0) meldungen.push(`Seite scrollt ${quer} px zur Seite`);

        if (meldungen.length === 0) {
            console.log(`  ok      ${resource}`);
        } else {
            fehler += meldungen.length;
            console.log(`  FEHLER  ${resource}`);
            for (const text of meldungen) console.log(`            ${text}`);
        }

        await seite.close();
    }

    await browser.close();

    console.log(fehler === 0
        ? `\n${resourcen.length} Oberflaechen laden sauber, ${mit} davon mit Daten.`
        : `\n${fehler} Fehler in ${resourcen.length} Oberflaechen `
          + `(${mit} mit Daten geprueft).`);

    process.exit(fehler === 0 ? 0 : 1);
})();
