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
        ? `\n${resourcen.length} Oberflaechen laden sauber.`
        : `\n${fehler} Fehler in ${resourcen.length} Oberflaechen.`);

    process.exit(fehler === 0 ? 0 : 1);
})();
