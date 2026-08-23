/* Moonshine Arbeit - Jobcenter, Auftraege und Schicht-Anzeige. */

const RESOURCE = 'moonshine-jobs';

let center = null;
let shift = null;
let activeTab = 'contracts';
let boardJob = null;

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


function post(name, payload) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {}),
    }).catch(() => {});
}

async function ask(name, payload) {
    try {
        const response = await fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {}),
        });
        return await response.json();
    } catch (error) {
        return null;
    }
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function clear(node) {
    while (node && node.firstChild) node.removeChild(node.firstChild);
}

function money(amount) {
    return `${Math.floor(amount || 0).toLocaleString('de-DE')} $`;
}

/* -------------------------------------------------------------- Schicht-HUD */

function renderShift() {
    const hud = $('hud');

    if (!shift || !shift.active) {
        hud.classList.add('hidden');
        return;
    }

    hud.classList.remove('hidden');
    hud.style.setProperty('--job', shift.colour || '#5fc98a');

    $('hud-icon').textContent = shift.icon || '💼';
    $('hud-label').textContent = shift.label || 'Arbeit';

    let target = 'Nächste Station';
    if (shift.phase === 'abmelden') {
        target = 'Zurück zum Auftraggeber';
    } else if (shift.phase === 'aufnehmen' && shift.pickup) {
        target = `Fahrgast: ${shift.pickup.label}`;
    } else if (shift.stop) {
        target = shift.stop.label;
    }

    $('hud-target').textContent = target;

    const done = Math.max(0, shift.index - 1);
    $('hud-progress').textContent = `${done} / ${shift.total}`;
    $('hud-fill').style.width = `${(done / Math.max(1, shift.total)) * 100}%`;
    $('hud-earned').textContent = money(shift.earned);
}

/* -------------------------------------------------------------------- Tabs */

const TABS = ['contracts', 'jobs', 'board'];

function activateTab(name) {
    activeTab = name;

    document.querySelectorAll('.tab').forEach((tab) => {
        tab.classList.toggle('active', tab.dataset.tab === name);
    });

    TABS.forEach((key) => {
        $(`panel-${key}`).classList.toggle('hidden', key !== name);
    });

    if (name === 'board') renderBoardTabs();
}

document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => activateTab(tab.dataset.tab));
});

/* --------------------------------------------------------------- Auftraege */

function contractCard(entry) {
    // Zwei Gründe, warum ein Auftrag gerade nicht geht: falsche Anstellung
    // oder falsche Tageszeit. Beide sperren die Karte, sagen aber
    // Verschiedenes.
    const zu = entry.locked || entry.gesperrt;
    const card = el('div', `contract${zu ? ' locked' : ''}`);
    card.style.setProperty('--job', entry.colour || '#5fc98a');

    const head = el('div', 'contract-head');
    head.appendChild(el('div', 'contract-icon', entry.icon));

    const title = el('div');
    title.appendChild(el('h3', null, entry.label));
    title.appendChild(el('div', 'where', `Anmeldung: ${entry.start}`));
    head.appendChild(title);
    card.appendChild(head);

    card.appendChild(el('p', 'muted', entry.description));

    const specs = el('div', 'contract-specs');

    const rows = [
        ['Je Station', money(entry.pay), true],
        ['Abschluss', money(entry.finalPay), true],
        ['Stationen', String(entry.stops), false],
    ];

    if (entry.vehicle) rows.push(['Fahrzeug', entry.vehicle, false]);
    if (entry.nurNachts) rows.push(['Dienstzeit', 'nur nachts', false]);

    rows.forEach(([label, value, gold]) => {
        const row = el('div', 'spec');
        row.appendChild(el('span', null, label));

        if (gold) {
            const bold = el('b', null, value);
            row.appendChild(bold);
        } else {
            row.appendChild(el('span', null, value));
        }

        specs.appendChild(row);
    });

    card.appendChild(specs);

    if (entry.stats) {
        card.appendChild(el('div', 'contract-stats',
            `${entry.stats.shifts} Schichten · ${entry.stats.stops} Stationen · `
            + `${money(entry.stats.earned)} verdient`));
    }

    const actions = el('div', 'contract-actions');

    if (entry.locked) {
        actions.appendChild(el('div', 'muted',
            `Braucht die Anstellung „${entry.requiresLabel || entry.requiresJob}“.`));
    } else if (entry.gesperrt) {
        actions.appendChild(el('div', 'muted',
            'Diese Schicht gibt es erst wieder, wenn es dunkel wird.'));
    } else {
        const route = el('button', 'btn small', 'Wegpunkt');
        route.addEventListener('click', () => post('route', { coords: entry.startCoords }));
        actions.appendChild(route);

        const start = el('button', 'btn small primary', 'Schicht beginnen');
        start.title = 'Geht nur direkt am Anmeldepunkt';
        start.addEventListener('click', () => post('start', { id: entry.id }));
        actions.appendChild(start);
    }

    card.appendChild(actions);
    return card;
}

function renderContracts() {
    const grid = $('contract-grid');
    clear(grid);

    liste(center.contracts).forEach((entry) => grid.appendChild(contractCard(entry)));
}

/* -------------------------------------------------------------- Anstellung */

function renderJobs() {
    const list = $('job-list');
    clear(list);

    liste(center.jobs).forEach((job) => {
        const current = center.job.name === job.name;
        const row = el('div', `job-row${current ? ' current' : ''}`);

        const body = el('div');
        body.appendChild(el('h3', null, job.label));
        body.appendChild(el('div', 'grades',
            current
                ? `Aktuell · ${center.job.gradeLabel}`
                : `${job.grades} Rangstufen`));
        row.appendChild(body);

        const salary = el('div', 'salary', money(job.salary));
        salary.appendChild(el('small', null, 'Einstiegsgehalt'));
        row.appendChild(salary);

        const button = el('button', `btn small${current ? '' : ' primary'}`,
            current ? 'Aktuell' : 'Annehmen');
        button.disabled = current || center.cooldown > 0;
        button.addEventListener('click', () => post('setJob', { name: job.name }));
        row.appendChild(button);

        list.appendChild(row);
    });

    $('cooldown-hint').textContent = center.cooldown > 0
        ? `Nächster Wechsel in ${Math.ceil(center.cooldown / 60)} Minuten möglich.`
        : '';
}

/* ------------------------------------------------------------- Bestenliste */

function renderBoardTabs() {
    const box = $('board-tabs');
    clear(box);

    const entries = liste(center.contracts);
    if (!boardJob && entries.length) boardJob = entries[0].id;

    entries.forEach((entry) => {
        const chip = el('div', `board-tab${boardJob === entry.id ? ' active' : ''}`);
        chip.appendChild(el('span', null, entry.icon));
        chip.appendChild(el('span', null, entry.label));

        chip.addEventListener('click', () => {
            boardJob = entry.id;
            renderBoardTabs();
        });

        box.appendChild(chip);
    });

    loadBoard();
}

async function loadBoard() {
    if (!boardJob) return;

    const rows = await ask('leaderboard', { id: boardJob });
    const box = $('board');
    clear(box);

    if (!rows || !rows.length) {
        box.appendChild(el('div', 'empty', 'Hier hat noch niemand gearbeitet.'));
        return;
    }

    rows.forEach((entry, index) => {
        const row = el('div', `board-row${index < 3 ? ' top' : ''}`);

        row.appendChild(el('div', 'rank', String(index + 1)));
        row.appendChild(el('div', null, entry.name));
        row.appendChild(el('div', 'earned', money(entry.earned)));
        row.appendChild(el('div', 'count',
            `${entry.shifts} Schichten · ${entry.stops} Stationen`));

        box.appendChild(row);
    });
}

/* ----------------------------------------------------------------- Rendern */

function render() {
    if (!center) return;

    $('current-job').textContent =
        `${center.job.label} · ${center.job.gradeLabel} · ${money(center.job.salary)} Gehalt`;

    $('total-earned').textContent = money(center.totals.earned);
    $('total-shifts').textContent = String(center.totals.shifts);
    $('total-stops').textContent = String(center.totals.stops);

    renderContracts();
    renderJobs();

    if (activeTab === 'board') renderBoardTabs();
}

$('btn-close').addEventListener('click', () => post('close'));

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !$('screen').classList.contains('hidden')) {
        post('close');
    }
});

/* -------------------------------------------------------------- Nachrichten */

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'work:open':
            center = message.data || null;
            $('screen').classList.remove('hidden');
            activateTab(activeTab);
            render();
            break;

        case 'work:center':
            center = message.data || center;
            render();
            break;

        case 'work:close':
            $('screen').classList.add('hidden');
            break;

        case 'work:shift':
            shift = message.data || null;
            renderShift();
            break;

        case 'work:progress': {
            const value = message.value || 0;
            const box = $('progress');

            if (value <= 0) {
                box.classList.add('hidden');
                break;
            }

            box.classList.remove('hidden');
            $('progress-label').textContent = shift && shift.actionLabel
                ? `${shift.actionLabel} …`
                : 'Arbeitet …';
            $('progress-fill').style.width = `${Math.round(value * 100)}%`;
            break;
        }

        default:
            break;
    }
});
