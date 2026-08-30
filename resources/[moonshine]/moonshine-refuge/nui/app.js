/* Moonshine Zuflucht - Übersicht, Lager und die Rast. */

const RESOURCE = 'moonshine-refuge';

let daten = null;          // was der Server über den Platz sagt
let lager = null;          // Inhalt des Lagers
let inventar = [];         // eigenes Inventar
let reiter = 'info';

const $ = (id) => document.getElementById(id);

const liste = (wert) => (Array.isArray(wert) ? wert : []);


function post(name, payload) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {}),
    }).catch(() => {});
}

async function ask(name, payload) {
    try {
        const antwort = await fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {}),
        });
        return await antwort.json();
    } catch (fehler) {
        return null;
    }
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
}

function clear(node) {
    while (node && node.firstChild) node.removeChild(node.firstChild);
}

const geld = (wert) => `${Math.floor(wert || 0).toLocaleString('de-DE')} $`;
const kilo = (gramm) => `${((gramm || 0) / 1000).toFixed(1)} kg`;

/* ------------------------------------------------------------------ Karten */

function karte(titel, wert, klasse) {
    const box = el('div', 'karte');
    box.appendChild(el('div', 'karte-titel', titel));
    box.appendChild(el('div', `karte-wert${klasse ? ' ' + klasse : ''}`, wert));
    return box;
}

function infoZeichnen() {
    $('beschreibung').textContent = daten.beschreibung || '';

    const karten = $('karten');
    clear(karten);

    if (daten.eigen) {
        karten.appendChild(karte('Lagerplätze', String(daten.slots || 0)));
        karten.appendChild(karte('Ausbaustufe', String(daten.stufe || 0)));
        karten.appendChild(karte('Rast',
            daten.rastFrei ? 'bereit' : 'noch nicht',
            daten.rastFrei ? 'gut' : 'warn'));
    } else {
        karten.appendChild(karte('Preis', geld(daten.preis)));
        karten.appendChild(karte('Auf dem Konto', geld(daten.balance)));
        karten.appendChild(karte('Art', daten.art || '—'));
    }

    // Passt der Ort zur Klasse? Das ist der einzige Grund, warum ein Ort
    // besser ist als ein anderer — das gehört dazugesagt.
    const hinweis = $('passt-hinweis');
    if (daten.passt) {
        hinweis.classList.remove('hidden');
        hinweis.textContent =
            `Dieser Ort passt zu dir. Wer hier rastet, steht deutlich stärker `
            + `wieder auf als anderswo.`;
    } else {
        hinweis.classList.remove('hidden');
        hinweis.textContent =
            `Dieser Ort passt nicht zu deiner Klasse. Rasten kannst du hier `
            + `trotzdem — nur nicht so tief.`;
    }

    const aktionen = $('aktionen');
    clear(aktionen);

    if (!daten.eigen && daten.frei) {
        const kaufen = el('button', 'knopf haupt',
            `Einrichten für ${geld(daten.preis)}`);
        kaufen.disabled = daten.preis > daten.balance;
        kaufen.addEventListener('click', () => post('claim', { id: daten.id }));
        aktionen.appendChild(kaufen);

        if (kaufen.disabled) {
            aktionen.appendChild(el('span', 'leise', 'Dafür reicht das Konto nicht.'));
        }
        return;
    }

    if (!daten.eigen) {
        aktionen.appendChild(el('span', 'leise', 'Hier wohnt schon jemand.'));
        return;
    }

    const rasten = el('button', 'knopf haupt', 'Rasten');
    rasten.disabled = !daten.rastFrei;
    rasten.title = daten.rastFrei
        ? 'Leben und Essenz voll, dazu ein Segen auf Zeit'
        : 'Du bist noch nicht müde';
    rasten.addEventListener('click', () => post('rest'));
    aktionen.appendChild(rasten);

    if (daten.ausbauPreis) {
        const ausbau = el('button', 'knopf', `Ausbauen (${geld(daten.ausbauPreis)})`);
        ausbau.disabled = daten.ausbauPreis > daten.balance;
        ausbau.addEventListener('click', () => post('upgrade'));
        aktionen.appendChild(ausbau);
    } else {
        aktionen.appendChild(el('span', 'leise', 'Voll ausgebaut.'));
    }

    const aufgeben = el('button', 'knopf gefahr', 'Aufgeben');
    aufgeben.title = 'Das Lager muss dafür leer sein';
    aufgeben.addEventListener('click', () => post('release'));
    aktionen.appendChild(aufgeben);

    // Umbenennen
    const feld = el('div', 'namensfeld');
    const eingabe = document.createElement('input');
    eingabe.type = 'text';
    eingabe.maxLength = 48;
    eingabe.value = daten.name || '';
    eingabe.placeholder = 'Name deines Ortes';
    feld.appendChild(eingabe);

    const sichern = el('button', 'knopf', 'Umbenennen');
    sichern.addEventListener('click', () => post('rename', { name: eingabe.value }));
    feld.appendChild(sichern);

    $('seite-info').appendChild(feld);
}

/* ------------------------------------------------------------------- Lager */

function menge() {
    return Math.max(1, Number($('menge').value) || 1);
}

function lagerZeichnen() {
    const invListe = $('inv-liste');
    clear(invListe);

    const tragbar = inventar.filter((entry) => entry && entry.name);
    $('inv-zahl').textContent = `${tragbar.length} Posten`;

    if (!tragbar.length) {
        invListe.appendChild(el('div', 'leise', 'Du trägst nichts bei dir.'));
    }

    tragbar.forEach((entry) => {
        const zeile = el('div', 'posten');
        zeile.appendChild(el('span', 'posten-name', entry.label));
        zeile.appendChild(el('span', 'posten-zahl', `×${entry.count}`));
        zeile.title = 'Einlagern';
        zeile.addEventListener('click', () => {
            post('put', { slot: entry.slot, count: Math.min(menge(), entry.count) });
        });
        invListe.appendChild(zeile);
    });

    const box = $('lager-liste');
    clear(box);

    if (!lager) {
        box.appendChild(el('div', 'leise', 'Wird geladen …'));
        return;
    }

    $('lager-zahl').textContent =
        `${lager.used}/${lager.slots} · ${kilo(lager.weight)} von ${kilo(lager.maxWeight)}`;

    if (!lager.entries.length) {
        box.appendChild(el('div', 'leise', 'Das Lager ist leer.'));
        return;
    }

    liste(lager.entries).forEach((entry) => {
        const zeile = el('div', 'posten');
        zeile.appendChild(el('span', 'posten-name', entry.label));
        zeile.appendChild(el('span', 'posten-zahl', `×${entry.count}`));
        zeile.title = 'Entnehmen';
        zeile.addEventListener('click', () => {
            post('take', { index: entry.index, count: Math.min(menge(), entry.count) });
        });
        box.appendChild(zeile);
    });
}

async function lagerLaden() {
    inventar = (await ask('requestInventory')) || [];
    post('openStash');
    lagerZeichnen();
}

/* ------------------------------------------------------------------ Reiter */

function reiterZeichnen() {
    const nav = $('reiter');
    clear(nav);

    const seiten = [{ id: 'info', label: 'Übersicht' }];
    if (daten && daten.eigen) seiten.push({ id: 'lager', label: 'Lager' });

    seiten.forEach((seite) => {
        const knopf = el('button', seite.id === reiter ? 'aktiv' : null, seite.label);
        knopf.addEventListener('click', () => {
            reiter = seite.id;
            zeichnen();
            if (seite.id === 'lager') lagerLaden();
        });
        nav.appendChild(knopf);
    });

    $('seite-info').classList.toggle('hidden', reiter !== 'info');
    $('seite-lager').classList.toggle('hidden', reiter !== 'lager');
}

function zeichnen() {
    if (!daten) return;

    $('zeichen').textContent = daten.artIcon || '🏚';
    $('titel').textContent = daten.eigen
        ? (daten.name || daten.artLabel || 'Zuflucht')
        : daten.label;
    $('untertitel').textContent = daten.eigen
        ? daten.label
        : (daten.frei ? 'Frei — hier kannst du dich einrichten' : 'Bewohnt');

    reiterZeichnen();

    // Das Namensfeld wird bei jedem Zeichnen neu gebaut; alte entfernen.
    const alt = $('seite-info').querySelector('.namensfeld');
    if (alt) alt.remove();

    if (reiter === 'info') infoZeichnen();
    else lagerZeichnen();
}

$('schliessen').addEventListener('click', () => post('close'));

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !$('overlay').classList.contains('hidden')) {
        post('close');
    }
});

/* ------------------------------------------------------------------ Events */

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};

    if (action === 'refuge:open') {
        daten = data || null;
        lager = null;
        reiter = 'info';
        $('overlay').classList.remove('hidden');
        zeichnen();
    } else if (action === 'refuge:close') {
        $('overlay').classList.add('hidden');
        daten = null;
    } else if (action === 'refuge:stash') {
        lager = data || null;
        if (reiter === 'lager') lagerZeichnen();
    } else if (action === 'refuge:resting') {
        $('rast').classList.remove('hidden');
        $('rast-text').textContent = (data && data.text) || 'Du legst dich hin.';
        $('rast-note').classList.toggle('hidden', !(data && data.passt));

        const fuell = $('rast-fuell');
        fuell.style.transition = 'none';
        fuell.style.width = '0%';

        // Ein Bild abwarten, sonst springt der Balken ohne Übergang durch.
        requestAnimationFrame(() => {
            fuell.style.transition = `width ${(data && data.dauer) || 15}s linear`;
            fuell.style.width = '100%';
        });
    } else if (action === 'refuge:restDone') {
        $('rast').classList.add('hidden');
    }
});
