/* Findet den Browser.
 *
 * Playwright sucht ueber PLAYWRIGHT_BROWSERS_PATH selbst, greift dabei aber
 * nach einer Versionsnummer, die zur eingebauten Playwright-Fassung passt.
 * Liegt im Ordner eine andere, schlaegt das fehl - mit dem Hinweis, man
 * solle Browser nachladen, obwohl einer danebenliegt.
 *
 * Deshalb hier: erst CHROMIUM_PFAD, dann selbst nachsehen, dann Playwright
 * machen lassen. */

const fs = require('fs');
const path = require('path');

const ORTE = ['/opt/pw-browsers', process.env.PLAYWRIGHT_BROWSERS_PATH]
    .filter(Boolean);

function finden() {
    if (process.env.CHROMIUM_PFAD) return process.env.CHROMIUM_PFAD;

    for (const ort of ORTE) {
        if (!fs.existsSync(ort)) continue;

        for (const eintrag of fs.readdirSync(ort).sort().reverse()) {
            if (!eintrag.startsWith('chromium')) continue;

            for (const rest of [['chrome-linux', 'chrome'],
                                ['chrome-linux', 'headless_shell']]) {
                const pfad = path.join(ort, eintrag, ...rest);
                if (fs.existsSync(pfad)) return pfad;
            }
        }
    }

    return undefined;   // dann sucht Playwright selbst
}

module.exports = { finden };
