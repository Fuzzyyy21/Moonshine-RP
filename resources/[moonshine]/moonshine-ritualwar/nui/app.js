/* Moonshine Ritualkrieg - Anzeige am Punkt und die Uebersicht. */

const RESOURCE = 'moonshine-ritualwar';

let punkte = [];
let offen = false;

const $ = (id) => document.getElementById(id);

function post(name, data) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
}

/** Sekunden als "12 Min" oder "1 Std 05 Min". */
function dauer(sekunden) {
    const gesamt = Math.max(0, Math.round(sekunden || 0));
    const minuten = Math.ceil(gesamt / 60);

    if (minuten < 60) return `${minuten} Min`;

    const stunden = Math.floor(minuten / 60);
    return `${stunden} Std ${String(minuten % 60).padStart(2, '0')} Min`;
}

/* ------------------------------------------------------------ Anzeige am Punkt */

function hudZeichnen(data) {
    const hud = $('hud');

    hud.classList.remove('hidden', 'eigen', 'fremd');
    if (data.relation === 'eigen' || data.relation === 'fremd') {
        hud.classList.add(data.relation);
    }

    $('hud-label').textContent = data.label || 'Ritualpunkt';

    if (data.faction) {
        const tag = data.tag ? ` [${data.tag}]` : '';
        $('hud-owner').textContent = data.relation === 'eigen'
            ? `euer Punkt · ${data.faction}${tag}`
            : `gebunden von ${data.faction}${tag}`;
    } else {
        $('hud-owner').textContent = 'ungebunden';
    }

    const schutz = $('hud-protected');
    if (data.protected && data.protectedFor > 0) {
        schutz.classList.remove('hidden');
        $('hud-protected-text').textContent = `Bindung hält noch ${dauer(data.protectedFor)}`;
    } else {
        schutz.classList.add('hidden');
    }

    const bindung = $('hud-binding');
    if (data.binding) {
        const wert = Math.max(0, Math.min(100, data.binding.progress || 0));

        bindung.classList.remove('hidden');
        $('hud-binding-label').textContent = data.binding.eigene
            ? 'Euer Bindungsritual'
            : 'Fremdes Bindungsritual';
        $('hud-binding-value').textContent = `${Math.floor(wert)} %`;
        $('hud-binding-fill').style.width = `${wert}%`;

        $('hud-contested').classList.toggle('hidden', !data.binding.contested);
    } else {
        bindung.classList.add('hidden');
    }
}

/* ------------------------------------------------------------------- Uebersicht */

function beziehung(entry) {
    if (!entry.factionId) return 'frei';
    return entry.eigen ? 'eigen' : 'fremd';
}

function listeZeichnen() {
    const liste = $('list');
    liste.innerHTML = '';

    if (!punkte.length) {
        liste.appendChild(el('div', 'punkt-owner', 'Keine Ritualpunkte vorhanden.'));
        return;
    }

    punkte.forEach((entry) => {
        const rel = beziehung(entry);
        const zeile = el('div', `punkt ${rel}`);
        zeile.appendChild(el('span', 'punkt-mark', '✦'));

        const body = el('div', 'punkt-body');
        body.appendChild(el('div', 'punkt-label', entry.label || entry.id));

        let text = 'ungebunden – frei für ein Bindungsritual';
        if (entry.factionName) {
            const tag = entry.factionTag ? ` [${entry.factionTag}]` : '';
            text = `${entry.factionName}${tag}`;
            if (entry.protected) text += ` · geschützt (${dauer(entry.protectedFor)})`;
        }
        body.appendChild(el('div', 'punkt-owner', text));

        if (entry.binding) {
            const wert = Math.max(0, Math.min(100, entry.binding.progress || 0));
            const track = el('div', 'track punkt-bar');
            const fill = el('div', 'fill');
            fill.style.width = `${wert}%`;
            track.appendChild(fill);
            body.appendChild(track);
        }

        zeile.appendChild(body);

        const meta = el('div', 'punkt-meta');
        meta.appendChild(el('b', null, entry.factionName ? `${entry.payouts || 0}×` : '—'));
        meta.appendChild(el('span', null, entry.factionName ? 'ausgeschüttet' : 'kein Ertrag'));
        zeile.appendChild(meta);

        zeile.addEventListener('click', () => post('route', { id: entry.id }));
        liste.appendChild(zeile);
    });
}

function oeffnen(data) {
    punkte = data || punkte;
    offen = true;
    $('overlay').classList.remove('hidden');
    listeZeichnen();
}

function schliessen() {
    offen = false;
    $('overlay').classList.add('hidden');
}

/* ----------------------------------------------------------------------- Events */

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};

    if (action === 'ritualwar:hud') {
        hudZeichnen(data || {});
    } else if (action === 'ritualwar:hudOff') {
        $('hud').classList.add('hidden');
    } else if (action === 'ritualwar:open') {
        oeffnen(data);
    } else if (action === 'ritualwar:points') {
        punkte = data || [];
        if (offen) listeZeichnen();
    } else if (action === 'ritualwar:close') {
        schliessen();
    }
});

document.addEventListener('keyup', (event) => {
    if (offen && (event.key === 'Escape' || event.key === 'Backspace')) {
        post('close');
        schliessen();
    }
});

$('close').addEventListener('click', () => {
    post('close');
    schliessen();
});

$('bind').addEventListener('click', () => {
    post('bind');
    post('close');
    schliessen();
});

$('cancel').addEventListener('click', () => post('cancel'));
