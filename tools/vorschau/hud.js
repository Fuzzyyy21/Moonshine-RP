/* Rendert das echte NUI von moonshine-hud und schiesst Bilder davon.
   Kein Mockup: geladen wird nui/index.html samt style.css und app.js,
   gefuettert mit genau den Nachrichten, die client/main.lua schickt. */

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const WURZEL = path.resolve(__dirname, '..', '..');
const NUI = 'file://' + path.join(WURZEL,
    'resources', '[moonshine]', 'moonshine-hud', 'nui', 'index.html');

// Wohin die Bilder kommen (Standard: tools/vorschau/bilder).
const AUSGABE = process.argv[2] || path.join(__dirname, 'bilder');

/* Was der Server-/Client-Code schickt. */
const SETUP = {
    elemente: require('./daten/elemente.json'),
    auswahl: require('./daten/auswahl.json'),
    grenzen: {
        groesse:   { min: 0.70, max: 1.40, step: 0.05 },
        deckkraft: { min: 0.30, max: 1.00, step: 0.05 },
    },
    gruppen: ['Spieler', 'Zustand', 'Welt', 'Fahrzeug'],
    schwellen: {
        leben: 95, weste: 1, hunger: 80, durst: 80, ausdauer: 95,
        sauerstoff: 99, essenz: 95, beduerfnis: 80,
    },
};

const STANDARD = require('./daten/standard.json');

const WERTE = {
    name: 'Anna Voss', id: 12,
    job: 'Postdienst · Fahrerin',
    geld: { bargeld: 1240, bank: 48900, schwarz: 3500 },
    fraktion: { name: 'Zirkel des Blutmonds', tag: 'ZDB', farbe: '#9b6bd8' },
    leben: 78, weste: 45, hunger: 62, durst: 41,
    ausdauer: 88, sauerstoff: 100,
    essenz: { wert: 64, jetzt: 64, max: 100, label: 'Blut', farbe: '#a3232c',
              icon: '🩸', klasse: 'Vampir', stufe: 7 },
    welt: {
        zeit: '21:14', nacht: true,
        mond: { label: 'Blutmond', icon: '🌕' },
        ereignis: { label: 'Blutmond', icon: '🌕' },
    },
    ort: { strasse: 'Vinewood Blvd / Meteor St', bezirk: 'Vinewood' },
    richtung: 'NO',
    mikrofon: true,
    delta: { bargeld: 250 },
};

const FAHRZEUG = {
    fahrer: true, tempo: 87, einheit: 'km/h',
    drehzahl: 0.62, gang: 4,
    tank: 43, motor: 71,
    blinker: 'rechts', licht: 'an',
    gurt: true, tempomat: 90,
};

async function schuss(seite, datei, nachrichten, breite, hoehe) {
    for (const nachricht of nachrichten) {
        await seite.evaluate((m) => window.postMessage(m, '*'), nachricht);
    }
    await seite.waitForTimeout(450);
    await seite.screenshot({ path: datei, clip: { x: 0, y: 0, width: breite, height: hoehe } });
    console.log('  ' + path.basename(datei));
}

(async () => {
    fs.mkdirSync(AUSGABE, { recursive: true });

    const browser = await chromium.launch({
        // Playwright findet den Browser ueber PLAYWRIGHT_BROWSERS_PATH selbst.
        // Nur wenn das fehlschlaegt, hilft ein Pfad in CHROMIUM_PFAD.
        executablePath: process.env.CHROMIUM_PFAD || undefined,
    });

    const seite = await browser.newPage({ viewport: { width: 1600, height: 900 } });

    // Das NUI ist durchsichtig und liegt sonst ueber dem Spiel. Damit die
    // Bilder nicht auf Weiss stehen, kommt ein dunkler Grund dahinter -
    // in etwa so hell wie Los Santos bei Nacht.
    await seite.addInitScript(() => {
        window.addEventListener('DOMContentLoaded', () => {
            document.body.style.background =
                'linear-gradient(160deg, #1a2230 0%, #2a2438 45%, #171a24 100%)';

            // Die NUI-Rueckrufe gehen im Spiel an den Client. Hier ins Leere.
            window.fetch = () => Promise.resolve({ json: () => Promise.resolve({}) });
        });
    });

    await seite.goto(NUI);
    await seite.waitForTimeout(300);

    const grund = [
        { action: 'hud:setup', data: SETUP },
        { action: 'hud:settings', data: STANDARD },
        { action: 'hud:visible', value: true },
        { action: 'hud:update', data: WERTE },
    ];

    console.log('Bilder:');

    await schuss(seite, path.join(AUSGABE, '1-ringe.png'),
        [...grund, { action: 'hud:vehicle', data: null }], 1600, 900);

    await schuss(seite, path.join(AUSGABE, '2-fahrzeug.png'),
        [{ action: 'hud:vehicle', data: FAHRZEUG }], 1600, 900);

    // Ein Bild je Variante, damit sich die Stile vergleichen lassen.
    const VARIANTEN = [
        { datei: '3-balken.png',   stil: 'balken',   akzent: '#e0a642' },
        { datei: '4-segmente.png', stil: 'segmente', akzent: '#4caf7d' },
        { datei: '5-boegen.png',   stil: 'bogen',    akzent: '#3d8bd4' },
        { datei: '6-zahlen.png',   stil: 'zahlen',   akzent: '#c0392f' },
        { datei: '7-minimal.png',  stil: 'minimal',  akzent: '#d0d4dd',
          dynamisch: true, groesse: 0.9 },
    ];

    for (const variante of VARIANTEN) {
        const einstellung = JSON.parse(JSON.stringify(STANDARD));
        einstellung.stil = variante.stil;
        einstellung.akzent = variante.akzent;
        if (variante.dynamisch) einstellung.dynamisch = true;
        if (variante.groesse) einstellung.groesse = variante.groesse;

        await schuss(seite, path.join(AUSGABE, variante.datei),
            [{ action: 'hud:settings', data: einstellung },
             { action: 'hud:update', data: WERTE }], 1600, 900);
    }

    await schuss(seite, path.join(AUSGABE, '8-menue.png'),
        [{ action: 'hud:settings', data: STANDARD },
         { action: 'hud:update', data: WERTE },
         { action: 'hud:menu', data: STANDARD }], 1600, 900);

    await browser.close();
})();
