/* Moonshine Anzeige - Status, Geld, Fahrzeug, Uhr und die Einstellungen. */

const RESOURCE = 'moonshine-hud';

let setup = null;         // Elementliste und Auswahlmöglichkeiten
let settings = null;      // aktuelle Einstellung
let letzte = null;        // zuletzt gezeichnete Werte
let menueOffen = false;
let sichtbar = false;     // darf die Anzeige gerade überhaupt zu sehen sein?

const $ = (id) => document.getElementById(id);

function post(name, payload) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {}),
    }).catch(() => {});
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

const geldText = (wert) =>
    new Intl.NumberFormat('de-DE').format(Math.floor(wert || 0));

const spanne = (wert) => Math.max(0, Math.min(100, Math.round(wert || 0)));

function zeigt(key) {
    return !!(settings && settings.elemente && settings.elemente[key]);
}

/* ------------------------------------------------------------------ Status */

/** Was die Statusgruppe anzeigt, in fester Reihenfolge. */
function werteListe(data) {
    const reihe = [
        { key: 'leben',      icon: '❤️', wert: data.leben,      farbe: 'var(--leben)' },
        { key: 'weste',      icon: '🛡️', wert: data.weste,      farbe: 'var(--weste)' },
        { key: 'hunger',     icon: '🍗', wert: data.hunger,     farbe: 'var(--hunger)' },
        { key: 'durst',      icon: '💧', wert: data.durst,      farbe: 'var(--durst)' },
        { key: 'ausdauer',   icon: '🌀', wert: data.ausdauer,   farbe: 'var(--ausdauer)' },
        { key: 'sauerstoff', icon: '🫁', wert: data.sauerstoff, farbe: 'var(--sauerstoff)' },
    ];

    if (data.essenz) {
        reihe.push({
            key: 'essenz', icon: data.essenz.icon || '✦',
            wert: data.essenz.wert,
            farbe: data.essenz.farbe || 'var(--akzent)',
            titel: data.essenz.label,
        });
    }

    if (data.beduerfnis) {
        reihe.push({
            key: 'beduerfnis', icon: data.beduerfnis.icon || '🌑',
            wert: data.beduerfnis.wert,
            farbe: data.beduerfnis.farbe || 'var(--warn)',
            titel: data.beduerfnis.label,
        });
    }

    const schwellen = (setup && setup.schwellen) || {};

    return reihe.filter((eintrag) => {
        if (!zeigt(eintrag.key)) return false;
        if (eintrag.wert === undefined || eintrag.wert === null) return false;

        // Im dynamischen Modus verschwindet, was ohnehin voll ist.
        if (settings.dynamisch) {
            const grenze = schwellen[eintrag.key];
            if (grenze !== undefined && eintrag.wert >= grenze) return false;
        }

        return true;
    });
}

const UMFANG = 2 * Math.PI * 18;

function ringZeichnen(eintrag) {
    const box = el('div', `ring${eintrag.wert <= 25 ? ' knapp' : ''}`);
    box.title = `${eintrag.titel || ''} ${spanne(eintrag.wert)} %`.trim();

    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 42 42');

    const spur = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    spur.setAttribute('class', 'spur');
    spur.setAttribute('cx', '21'); spur.setAttribute('cy', '21'); spur.setAttribute('r', '18');

    const fuell = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    fuell.setAttribute('class', 'fuell');
    fuell.setAttribute('cx', '21'); fuell.setAttribute('cy', '21'); fuell.setAttribute('r', '18');
    fuell.setAttribute('stroke', eintrag.farbe);
    fuell.setAttribute('stroke-dasharray', String(UMFANG));
    fuell.setAttribute('stroke-dashoffset',
        String(UMFANG * (1 - spanne(eintrag.wert) / 100)));

    svg.appendChild(spur);
    svg.appendChild(fuell);
    box.appendChild(svg);
    box.appendChild(el('span', 'ring-icon', eintrag.icon));

    return box;
}

function balkenZeichnen(eintrag) {
    const zeile = el('div', `leiste${eintrag.wert <= 25 ? ' knapp' : ''}`);
    zeile.title = `${eintrag.titel || ''} ${spanne(eintrag.wert)} %`.trim();

    zeile.appendChild(el('span', 'leiste-icon', eintrag.icon));

    const spur = el('div', 'spur');
    const fuell = el('div', 'fuell');
    fuell.style.width = `${spanne(eintrag.wert)}%`;
    fuell.style.background = eintrag.farbe;
    spur.appendChild(fuell);
    zeile.appendChild(spur);

    return zeile;
}

function statusZeichnen(data) {
    const karteAn = zeigt('spieler') || zeigt('job') || zeigt('bargeld')
        || zeigt('bank') || zeigt('schwarz') || zeigt('fraktion');

    $('karte').classList.toggle('hidden', !karteAn || settings.stil === 'minimal');

    $('s-name').textContent = zeigt('spieler') ? (data.name || '—') : '';
    $('s-id').textContent = zeigt('spieler') ? `#${data.id}` : '';
    $('s-job').classList.toggle('hidden', !zeigt('job'));
    $('s-job').textContent = data.job || '';

    const fraktion = zeigt('fraktion') && data.fraktion;
    $('s-fraktion').classList.toggle('hidden', !fraktion);
    if (fraktion) {
        $('s-fraktion').textContent = data.fraktion.tag
            ? `${data.fraktion.name} [${data.fraktion.tag}]` : data.fraktion.name;
    }

    const konten = [
        ['bargeld', 'g-bargeld'], ['bank', 'g-bank'], ['schwarz', 'g-schwarz'],
    ];

    konten.forEach(([key, id]) => {
        const knoten = $(id);
        knoten.classList.toggle('hidden', !zeigt(key));
        knoten.querySelector('b').textContent = geldText((data.geld || {})[key]);

        const delta = data.delta && data.delta[key];
        if (delta) {
            knoten.classList.remove('hoch', 'runter');
            void knoten.offsetWidth;               // Neustart der Animation
            knoten.classList.add(delta > 0 ? 'hoch' : 'runter');
        }
    });

    const ringe = $('ringe');
    const balken = $('balken');
    const werte = werteListe(data);

    const alsRing = settings.stil === 'ringe';
    ringe.classList.toggle('hidden', !alsRing);
    balken.classList.toggle('hidden', alsRing);

    const ziel = alsRing ? ringe : balken;
    clear(ziel);
    werte.forEach((eintrag) => {
        ziel.appendChild(alsRing ? ringZeichnen(eintrag) : balkenZeichnen(eintrag));
    });

    $('mikro').classList.toggle('hidden', !(zeigt('mikrofon') && data.mikrofon));
}

/* -------------------------------------------------------------------- Kopf */

function kopfZeichnen(data) {
    const uhr = zeigt('uhr') && data.welt;
    $('k-uhr').classList.toggle('hidden', !uhr);

    if (uhr) {
        $('k-zeit').textContent = data.welt.zeit || '--:--';

        const mond = zeigt('mond') && data.welt.mond;
        $('k-mond').classList.toggle('hidden', !mond);
        if (mond) {
            $('k-mond').textContent = data.welt.mond.icon || '🌙';
            $('k-mond').title = data.welt.mond.label || '';
        }
    }

    const ort = zeigt('ort') && data.ort;
    $('k-ort').classList.toggle('hidden', !ort);
    if (ort) {
        $('k-strasse').textContent = data.ort.strasse || '—';
        $('k-bezirk').textContent = data.ort.bezirk || '';
    }

    $('k-kompass').classList.toggle('hidden', !zeigt('kompass'));
    $('k-richtung').textContent = data.richtung || 'N';

    const ereignis = zeigt('ereignis') && data.welt && data.welt.ereignis;
    $('k-ereignis').classList.toggle('hidden', !ereignis);
    if (ereignis) {
        $('k-ereignis-icon').textContent = data.welt.ereignis.icon || '✦';
        $('k-ereignis-label').textContent = data.welt.ereignis.label || '';
    }

    const etwas = uhr || ort || zeigt('kompass') || ereignis;
    $('kopf').classList.toggle('hidden', !(sichtbar && etwas));
}

/* ---------------------------------------------------------------- Fahrzeug */

const TACHO_UMFANG = 2 * Math.PI * 50 * 0.75;   // Dreiviertelkreis

function fahrzeugZeichnen(data) {
    if (!data || !settings || !settings.an || !sichtbar) {
        $('fahrzeug').classList.add('hidden');
        return;
    }

    $('fahrzeug').classList.remove('hidden');

    $('f-tempo').textContent = zeigt('tacho') ? String(data.tempo || 0) : '';
    $('f-einheit').textContent = zeigt('tacho') ? (data.einheit || 'km/h') : '';

    const rpm = $('f-rpm');
    rpm.setAttribute('stroke-dasharray', `${TACHO_UMFANG} ${TACHO_UMFANG * 2}`);
    rpm.setAttribute('stroke-dashoffset', String(
        zeigt('drehzahl') ? TACHO_UMFANG * (1 - (data.drehzahl || 0)) : TACHO_UMFANG));
    rpm.classList.toggle('rot', (data.drehzahl || 0) > 0.88);

    const gang = $('f-gang');
    gang.classList.toggle('hidden', !zeigt('drehzahl'));
    gang.textContent = data.gang === 0 ? 'R' : String(data.gang || 'N');

    $('f-tank-box').classList.toggle('hidden', !zeigt('tank'));
    const tank = $('f-tank');
    tank.style.width = `${spanne(data.tank)}%`;
    tank.classList.toggle('knapp', (data.tank || 0) <= 15);

    $('f-motor-box').classList.toggle('hidden', !zeigt('motor'));
    const motor = $('f-motor');
    motor.style.width = `${spanne(data.motor)}%`;
    motor.classList.toggle('knapp', (data.motor || 0) <= 30);

    const links = zeigt('blinker') && (data.blinker === 'links' || data.blinker === 'warn');
    const rechts = zeigt('blinker') && (data.blinker === 'rechts' || data.blinker === 'warn');
    $('f-links').classList.toggle('hidden', !links);
    $('f-rechts').classList.toggle('hidden', !rechts);

    const gurt = $('f-gurt');
    gurt.classList.toggle('hidden', !zeigt('gurt'));
    gurt.classList.toggle('zu', data.gurt === true);
    gurt.classList.toggle('offen', data.gurt !== true);
    gurt.textContent = data.gurt ? '🔒' : '🔓';
    gurt.title = data.gurt ? 'Angeschnallt' : 'Nicht angeschnallt';

    const licht = $('f-licht');
    licht.classList.toggle('hidden', !(zeigt('licht') && data.licht));
    licht.classList.toggle('fern', data.licht === 'fern');

    const tempomat = $('f-tempomat');
    tempomat.classList.toggle('hidden', !(zeigt('tempomat') && data.tempomat));
    if (data.tempomat) tempomat.title = `Tempomat ${data.tempomat} km/h`;
}

/* ------------------------------------------------------------ Einstellungen */

/** #rrggbb zu rgba(r, g, b, a) - fuer die abgeschwaechte Akzentfarbe. */
function schwach(hex, deckkraft) {
    const sauber = String(hex || '').replace('#', '');
    if (sauber.length !== 6) return `rgba(155, 107, 216, ${deckkraft})`;

    const [r, g, b] = [0, 2, 4].map((i) => parseInt(sauber.substr(i, 2), 16));
    return `rgba(${r}, ${g}, ${b}, ${deckkraft})`;
}

function stilAnwenden() {
    if (!settings) return;

    const wurzel = document.documentElement;
    wurzel.style.setProperty('--akzent', settings.akzent);
    wurzel.style.setProperty('--akzent-schwach', schwach(settings.akzent, 0.3));
    wurzel.style.setProperty('--skala', String(settings.groesse));
    wurzel.style.setProperty('--deck', String(settings.deckkraft));

    const status = $('status');
    status.className = `ecke-${settings.ecke} stil-${settings.stil}`;
    if (!sichtbar || !settings.an) status.classList.add('hidden');
}

/** Eine Zeile mit Schalter. */
function schalterZeile(name, an, beiKlick) {
    const zeile = el('div', 'zeile');
    zeile.appendChild(el('span', 'zeile-name', name));

    const schalter = el('div', `schalter${an ? ' an' : ''}`);
    schalter.addEventListener('click', () => {
        const neu = !schalter.classList.contains('an');
        schalter.classList.toggle('an', neu);
        beiKlick(neu);
    });

    zeile.appendChild(schalter);
    return zeile;
}

/** Eine Zeile mit Auswahlknöpfen. */
function auswahlZeile(name, feld, aktiv) {
    const zeile = el('div', 'zeile');
    zeile.appendChild(el('span', 'zeile-name', name));

    const box = el('div', 'auswahl');

    ((setup.auswahl || {})[feld] || []).forEach((eintrag) => {
        const knopf = el('button', eintrag.value === aktiv ? 'aktiv' : null, eintrag.label);
        knopf.addEventListener('click', () => {
            setzen(feld, eintrag.value);
            menueZeichnen();
        });
        box.appendChild(knopf);
    });

    zeile.appendChild(box);
    return zeile;
}

/** Eine Zeile mit Regler. */
function reglerZeile(name, feld, wert, formatieren) {
    const grenze = (setup.grenzen || {})[feld] || { min: 0, max: 1, step: 0.05 };

    const zeile = el('div', 'zeile');
    zeile.appendChild(el('span', 'zeile-name', name));

    const regler = document.createElement('input');
    regler.type = 'range';
    regler.min = String(grenze.min);
    regler.max = String(grenze.max);
    regler.step = String(grenze.step);
    regler.value = String(wert);

    const anzeige = el('span', 'zeile-wert', formatieren(wert));

    // Beim Ziehen nur ansehen, beim Loslassen festschreiben.
    regler.addEventListener('input', () => {
        anzeige.textContent = formatieren(parseFloat(regler.value));
        setzen(feld, parseFloat(regler.value), true);
    });
    regler.addEventListener('change', () => {
        setzen(feld, parseFloat(regler.value));
    });

    zeile.appendChild(regler);
    zeile.appendChild(anzeige);
    return zeile;
}

function farbZeile() {
    const zeile = el('div', 'zeile');
    zeile.appendChild(el('span', 'zeile-name', 'Farbe'));

    const box = el('div', 'farben');

    ((setup.auswahl || {}).akzent || []).forEach((eintrag) => {
        const punkt = el('div', `farbe${eintrag.value === settings.akzent ? ' aktiv' : ''}`);
        punkt.style.background = eintrag.value;
        punkt.title = eintrag.label;
        punkt.addEventListener('click', () => {
            setzen('akzent', eintrag.value);
            menueZeichnen();
        });
        box.appendChild(punkt);
    });

    zeile.appendChild(box);
    return zeile;
}

async function setzen(feld, wert, sofort) {
    if (feld === 'element') return;

    settings[feld] = wert;
    stilAnwenden();

    await post('hudSet', { feld, wert, sofort: sofort === true });
}

function menueZeichnen() {
    if (!setup || !settings) return;

    const aussehen = $('m-aussehen');
    clear(aussehen);

    aussehen.appendChild(schalterZeile('Anzeige an', settings.an, (an) => {
        setzen('an', an);
    }));
    aussehen.appendChild(auswahlZeile('Darstellung', 'stil', settings.stil));
    aussehen.appendChild(auswahlZeile('Ecke', 'ecke', settings.ecke));
    aussehen.appendChild(farbZeile());
    aussehen.appendChild(reglerZeile('Größe', 'groesse', settings.groesse,
        (v) => `${Math.round(v * 100)} %`));
    aussehen.appendChild(reglerZeile('Deckkraft', 'deckkraft', settings.deckkraft,
        (v) => `${Math.round(v * 100)} %`));
    aussehen.appendChild(auswahlZeile('Tempo', 'einheit', settings.einheit));
    aussehen.appendChild(schalterZeile('Volle Balken ausblenden', settings.dynamisch,
        (an) => setzen('dynamisch', an)));
    aussehen.appendChild(schalterZeile('Gurtwarnung', settings.gurtWarnung,
        (an) => setzen('gurtWarnung', an)));

    const box = $('m-elemente');
    clear(box);

    (setup.gruppen || []).forEach((gruppe) => {
        box.appendChild(el('div', 'gruppe-titel', gruppe));

        (setup.elemente || [])
            .filter((element) => element.gruppe === gruppe)
            .forEach((element) => {
                box.appendChild(schalterZeile(element.label,
                    settings.elemente[element.key], (an) => {
                        settings.elemente[element.key] = an;
                        post('hudSet', { feld: 'element', key: element.key, wert: an });
                    }));
            });
    });
}

$('m-schliessen').addEventListener('click', () => post('hudMenuClose'));
$('m-fertig').addEventListener('click', () => post('hudMenuClose'));
$('m-reset').addEventListener('click', async () => {
    const antwort = await fetch(`https://${RESOURCE}/hudReset`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}',
    }).then((r) => r.json()).catch(() => null);

    if (antwort && antwort.settings) {
        settings = antwort.settings;
        stilAnwenden();
        menueZeichnen();
    }
});

/* ------------------------------------------------------------------ Events */

window.addEventListener('message', (event) => {
    const { action, data, value } = event.data || {};

    switch (action) {
        case 'hud:setup':
            setup = data || null;
            break;

        case 'hud:settings':
            settings = data || null;
            stilAnwenden();
            if (menueOffen) menueZeichnen();
            if (letzte) { statusZeichnen(letzte); kopfZeichnen(letzte); }
            break;

        case 'hud:update':
            if (!settings) break;
            letzte = data || {};
            statusZeichnen(letzte);
            kopfZeichnen(letzte);
            break;

        case 'hud:vehicle':
            fahrzeugZeichnen(data);
            break;

        case 'hud:visible':
            sichtbar = value === true;
            $('status').classList.toggle('hidden', !sichtbar);
            if (!sichtbar) {
                $('kopf').classList.add('hidden');
                $('fahrzeug').classList.add('hidden');
            }
            break;

        case 'hud:menu':
            settings = data || settings;
            menueOffen = true;
            $('menue').classList.remove('hidden');
            stilAnwenden();
            menueZeichnen();
            break;

        case 'hud:menuClose':
            menueOffen = false;
            $('menue').classList.add('hidden');
            break;

        default:
            break;
    }
});

document.addEventListener('keyup', (event) => {
    if (menueOffen && event.key === 'Escape') post('hudMenuClose');
});
