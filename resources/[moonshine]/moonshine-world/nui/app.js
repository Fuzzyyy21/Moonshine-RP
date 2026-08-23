/* Moonshine Welt - Uhr, Mondphase und Weltereignisse. */

let setup = { showClock: true, showMoon: true, visible: true };
let event = null;
let remaining = 0;
let duration = 1;

const $ = (id) => document.getElementById(id);

/** Eine Liste vom Server, verlaesslich als Feld.
 *
 * Lua kennt keinen Unterschied zwischen leerer Liste und leerer Tabelle -
 * beides kommt hier als {} an, nicht als []. Der uebliche Schutz
 * "x || []" greift dagegen nicht, weil {} wahr ist; das naechste forEach
 * wirft dann. Auf einem frischen Server ist genau das der Normalfall:
 * keine Auktionen, keine Auftraege, kein Fahrzeug.
 */
const liste = (wert) => (Array.isArray(wert) ? wert : []);


function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function clear(node) {
    while (node && node.firstChild) node.removeChild(node.firstChild);
}

function pad(value) {
    return String(value).padStart(2, '0');
}

/** Tageszeit als Wort. */
function daypart(hour) {
    if (hour < 5) return 'Nacht';
    if (hour < 8) return 'Morgen';
    if (hour < 12) return 'Vormittag';
    if (hour < 14) return 'Mittag';
    if (hour < 18) return 'Nachmittag';
    if (hour < 21) return 'Abend';
    return 'Nacht';
}

function formatRemaining(seconds) {
    if (seconds <= 0) return 'endet gleich';

    const minutes = Math.ceil(seconds / 60);
    return minutes > 1 ? `noch ${minutes} Min.` : 'noch unter 1 Min.';
}

function applyVisibility() {
    $('widget').classList.toggle('hidden', !setup.visible);
    $('moon-row').classList.toggle('hidden', !setup.showMoon);
    $('clock').parentElement.classList.toggle('hidden', !setup.showClock);
}

/* -------------------------------------------------------------------- Uhr */

function setClock(hour, minute) {
    $('clock').textContent = `${pad(hour)}:${pad(minute)}`;
    $('daypart').textContent = daypart(hour);
}

function setPhase(phase) {
    if (!phase) return;

    $('moon-icon').textContent = phase.icon;
    $('moon-label').textContent = phase.label;
}

/* ---------------------------------------------------------------- Ereignis */

function setEvent(payload) {
    event = payload && payload.active ? payload : null;

    const row = $('event-row');

    if (!event) {
        row.classList.add('hidden');
        document.documentElement.style.setProperty('--event', '#9b6bd8');
        return;
    }

    row.classList.remove('hidden');

    document.documentElement.style.setProperty('--event', event.tint || '#9b6bd8');

    $('event-icon').textContent = event.icon;
    $('event-label').textContent = event.label;

    remaining = event.remaining || 0;
    duration = Math.max(1, event.duration || 1);

    updateEventBar();
}

function updateEventBar() {
    if (!event) return;

    $('event-fill').style.width = `${Math.max(0, (remaining / duration) * 100)}%`;
    $('event-time').textContent = formatRemaining(remaining);
}

/** Grosse Einblendung beim Start eines Ereignisses. */
function showBanner(payload) {
    const banner = $('banner');

    $('banner-icon').textContent = payload.icon;
    $('banner-label').textContent = payload.label;
    $('banner-headline').textContent = payload.headline || '';
    $('banner-description').textContent = payload.description || '';

    const box = $('banner-effects');
    clear(box);

    liste(payload.effects).forEach((entry) => {
        const pill = el('div', `effect-pill${entry.scope !== 'alle' ? ' own' : ''}`);
        pill.textContent = entry.scope !== 'alle'
            ? `${entry.text} (${entry.scope})`
            : entry.text;
        box.appendChild(pill);
    });

    banner.classList.remove('hidden');
    setTimeout(() => banner.classList.add('hidden'), 7000);
}

/* -------------------------------------------------------------- Nachrichten */

window.addEventListener('message', (message) => {
    const data = message.data || {};

    switch (data.action) {
        case 'world:setup':
            setup = Object.assign(setup, data.data || {});
            applyVisibility();
            break;

        case 'world:visible':
            setup.visible = data.value === true;
            applyVisibility();
            break;

        case 'world:time': {
            const payload = data.data || {};
            setClock(payload.hour || 0, payload.minute || 0);
            setPhase(payload.phase);
            break;
        }

        case 'world:tick': {
            const payload = data.data || {};
            setClock(payload.hour || 0, payload.minute || 0);
            break;
        }

        case 'world:phase':
            setPhase(data.data);
            break;

        case 'world:weather':
            $('weather-label').textContent = (data.data || {}).label || '';
            break;

        case 'world:event': {
            const previous = event && event.id;
            setEvent(data.data);

            if (event && event.id !== previous) showBanner(event);
            break;
        }

        case 'world:warning': {
            const payload = data.data || {};

            document.documentElement.style.setProperty('--event', payload.tint || '#9b6bd8');
            $('warning-icon').textContent = payload.icon;
            $('warning-label').textContent = payload.label;
            $('warning-text').textContent = payload.headline || '';
            $('warning-time').textContent =
                `in etwa ${Math.ceil((payload.seconds || 0) / 60)} Minuten`;

            $('warning').classList.remove('hidden');
            setTimeout(() => $('warning').classList.add('hidden'), 12000);
            break;
        }

        default:
            break;
    }
});

/* Die Restzeit laeuft auch zwischen zwei Syncs weiter. */
setInterval(() => {
    if (event && remaining > 0) {
        remaining -= 1;
        updateEventBar();
    }
}, 1000);

applyVisibility();
