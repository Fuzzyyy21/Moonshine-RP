/* Moonshine Adminpanel. */

const RESOURCE = 'moonshine-admin';

let data = null;
let selected = null;
let activeTab = 'players';
let logKind = 'alle';

const $ = (id) => document.getElementById(id);

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

/** Löst eine Adminaktion aus. */
function act(action, value, extra) {
    if (!selected) return;

    post('action', { action, target: selected.source, value, extra });
}

function may(action) {
    return data && data.permissions && data.permissions[action];
}

/* -------------------------------------------------------------------- Tabs */

const TABS = ['players', 'log', 'tools'];

function activateTab(name) {
    activeTab = name;

    document.querySelectorAll('.tab').forEach((tab) => {
        tab.classList.toggle('active', tab.dataset.tab === name);
    });

    TABS.forEach((key) => {
        $(`panel-${key}`).classList.toggle('hidden', key !== name);
    });

    if (name === 'log') loadLog();
    if (name === 'tools') renderWatchList();
}

document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => activateTab(tab.dataset.tab));
});

$('btn-tools').addEventListener('click', () => activateTab('tools'));

/* ----------------------------------------------------------------- Spieler */

function renderPlayers() {
    const box = $('player-list');
    clear(box);

    const needle = $('search').value.trim().toLowerCase();

    const list = data.players.filter((player) => {
        if (!needle) return true;
        return player.name.toLowerCase().includes(needle)
            || String(player.source).includes(needle);
    });

    if (!list.length) {
        box.appendChild(el('div', 'empty', 'Niemand gefunden.'));
        return;
    }

    list.forEach((player) => {
        const row = el('div', `player${selected && selected.source === player.source
            ? ' selected' : ''}${player.strikes > 0 ? ' flagged' : ''}`);

        row.appendChild(el('div', 'player-id', String(player.source)));

        const body = el('div');
        body.appendChild(el('h3', null, player.name));
        body.appendChild(el('div', 'sub',
            `${player.job} · ${player.race || 'nicht erweckt'}`));
        row.appendChild(body);

        const tags = el('div');
        if (player.adminLevel > 0) {
            tags.appendChild(el('span', 'badge admin', `A${player.adminLevel}`));
        }
        if (player.strikes > 0) {
            tags.appendChild(el('span', 'badge strike', `${player.strikes}`));
        }
        row.appendChild(tags);

        row.addEventListener('click', () => {
            selected = player;
            renderPlayers();
            renderDetail();
        });

        box.appendChild(row);
    });
}

$('search').addEventListener('input', () => renderPlayers());

/** Ein Info-Kästchen. */
function info(label, value, gold) {
    const box = el('div', 'info');
    box.appendChild(el('div', 'label', label));
    box.appendChild(el('div', `value${gold ? ' gold' : ''}`, value));
    return box;
}

/** Eine Gruppe von Knöpfen. */
function group(caption, buttons) {
    const box = el('div', 'action-group');
    box.appendChild(el('div', 'section-caption', caption));

    const row = el('div', 'action-row');
    buttons.forEach((button) => row.appendChild(button));
    box.appendChild(row);

    return box;
}

function button(label, action, className, onClick) {
    const node = el('button', `btn small${className ? ' ' + className : ''}`, label);
    node.disabled = action !== null && !may(action);
    node.addEventListener('click', onClick);
    return node;
}

function renderDetail() {
    const box = $('detail');
    clear(box);

    if (!selected) {
        box.appendChild(el('div', 'detail-empty', 'Waehle links einen Spieler.'));
        return;
    }

    // Immer den frischen Datensatz nehmen.
    const player = data.players.find((entry) => entry.source === selected.source);
    if (!player) {
        selected = null;
        box.appendChild(el('div', 'detail-empty', 'Der Spieler ist offline.'));
        return;
    }

    selected = player;

    box.appendChild(el('h2', null, player.name));
    box.appendChild(el('div', 'subtitle',
        `ID ${player.source} · Charakter ${player.charId} · ${player.ping} ms`));

    const grid = el('div', 'info-grid');
    grid.appendChild(info('Job', `${player.job} (${player.jobGrade})`));
    grid.appendChild(info('Klasse', player.race || '—'));
    grid.appendChild(info('Fraktion', player.faction || '—'));
    grid.appendChild(info('Leben', `${player.health} / ${player.armour} Weste`));
    grid.appendChild(info('Bar', money(player.cash), true));
    grid.appendChild(info('Bank', money(player.bank), true));
    grid.appendChild(info('Schwarz', money(player.black), true));
    grid.appendChild(info('Adminlevel', String(player.adminLevel)));
    grid.appendChild(info('Strikes', String(player.strikes)));
    box.appendChild(grid);

    // Bewegung
    box.appendChild(group('Bewegung', [
        button('Hin', 'tpTo', null, () => act('tpTo')),
        button('Herholen', 'tpHere', null, () => act('tpHere')),
        button('Beobachten', 'spectate', null, () => act('spectate')),
        button('Wegpunkt', null, null, () => post('waypoint', { coords: player.coords })),
    ]));

    // Zustand
    box.appendChild(group('Zustand', [
        button('Heilen', 'heal', 'ok', () => act('heal')),
        button('Wiederbeleben', 'revive', 'ok', () => act('revive')),
        button('Einfrieren', 'freeze', null, () => act('freeze', true)),
        button('Auftauen', 'freeze', null, () => act('freeze', false)),
    ]));

    // Geld
    if (may('givemoney') || may('setmoney')) {
        const box2 = el('div', 'action-group');
        box2.appendChild(el('div', 'section-caption', 'Geld'));

        const row = el('div', 'form-row');

        const account = document.createElement('select');
        (data.accounts || []).forEach((name) => {
            const option = document.createElement('option');
            option.value = name;
            option.textContent = name;
            account.appendChild(option);
        });
        row.appendChild(account);

        const amount = document.createElement('input');
        amount.type = 'number';
        amount.placeholder = 'Betrag';
        row.appendChild(amount);

        row.appendChild(button('Geben', 'givemoney', null, () => {
            act('givemoney', Number(amount.value) || 0, account.value);
        }));

        row.appendChild(button('Setzen', 'setmoney', null, () => {
            act('setmoney', Number(amount.value) || 0, account.value);
        }));

        box2.appendChild(row);
        box.appendChild(box2);
    }

    // Items
    if (may('giveitem')) {
        const box2 = el('div', 'action-group');
        box2.appendChild(el('div', 'section-caption', 'Item geben'));

        const row = el('div', 'form-row');

        const item = document.createElement('select');
        (data.items || []).forEach((entry) => {
            const option = document.createElement('option');
            option.value = entry.name;
            option.textContent = entry.label;
            item.appendChild(option);
        });
        row.appendChild(item);

        const count = document.createElement('input');
        count.type = 'number';
        count.min = '1';
        count.value = '1';
        row.appendChild(count);

        row.appendChild(button('Geben', 'giveitem', null, () => {
            act('giveitem', item.value, Number(count.value) || 1);
        }));

        box2.appendChild(row);
        box.appendChild(box2);
    }

    // Job
    if (may('setjob')) {
        const box2 = el('div', 'action-group');
        box2.appendChild(el('div', 'section-caption', 'Job setzen'));

        const row = el('div', 'form-row');

        const job = document.createElement('select');
        (data.jobs || []).forEach((entry) => {
            const option = document.createElement('option');
            option.value = entry.name;
            option.textContent = entry.label;
            job.appendChild(option);
        });
        row.appendChild(job);

        const grade = document.createElement('input');
        grade.type = 'number';
        grade.min = '0';
        grade.value = '0';
        row.appendChild(grade);

        row.appendChild(button('Setzen', 'setjob', null, () => {
            act('setjob', job.value, Number(grade.value) || 0);
        }));

        box2.appendChild(row);
        box.appendChild(box2);
    }

    // Adminlevel
    if (may('setadmin')) {
        const box2 = el('div', 'action-group');
        box2.appendChild(el('div', 'section-caption', 'Adminlevel'));

        const row = el('div', 'form-row');

        const level = document.createElement('select');
        [0, 1, 2, 3, 4].forEach((value) => {
            const option = document.createElement('option');
            option.value = String(value);
            option.textContent = `Level ${value}`;
            level.appendChild(option);
        });
        level.value = String(player.adminLevel);
        row.appendChild(level);

        row.appendChild(button('Setzen', 'setadmin', null, () => {
            act('setadmin', Number(level.value) || 0);
        }));

        box2.appendChild(row);
        box.appendChild(box2);
    }

    // Massnahmen
    const box3 = el('div', 'action-group');
    box3.appendChild(el('div', 'section-caption', 'Massnahmen'));

    const reasonRow = el('div', 'form-row');
    const reason = document.createElement('input');
    reason.type = 'text';
    reason.placeholder = 'Grund';
    reasonRow.appendChild(reason);

    const hours = document.createElement('input');
    hours.type = 'number';
    hours.min = '0';
    hours.value = '24';
    hours.title = 'Bannstunden, 0 = dauerhaft';
    hours.style.maxWidth = '90px';
    reasonRow.appendChild(hours);

    box3.appendChild(reasonRow);

    const row3 = el('div', 'action-row');
    row3.style.marginTop = '9px';

    row3.appendChild(button('Verwarnen', 'warn', null, () => {
        act('warn', reason.value || 'Bitte Regeln lesen.');
    }));

    row3.appendChild(button('Kicken', 'kick', 'danger', () => {
        act('kick', reason.value || 'Kein Grund angegeben');
    }));

    row3.appendChild(button('Bannen', 'ban', 'danger', () => {
        act('ban', reason.value || 'Kein Grund angegeben', Number(hours.value) || 0);
    }));

    box3.appendChild(row3);
    box.appendChild(box3);
}

/* --------------------------------------------------------------- Protokoll */

const LOG_KINDS = ['alle', 'admin', 'anticheat', 'money', 'item', 'character', 'connect'];

function renderLogFilter() {
    const box = $('log-filter');
    clear(box);

    LOG_KINDS.forEach((kind) => {
        const chip = el('div', `chip${logKind === kind ? ' active' : ''}`, kind);

        chip.addEventListener('click', () => {
            logKind = kind;
            renderLogFilter();
            loadLog();
        });

        box.appendChild(chip);
    });
}

async function loadLog() {
    renderLogFilter();

    const rows = await ask('log', { kind: logKind });
    const box = $('log-list');
    clear(box);

    if (!rows || !rows.length) {
        box.appendChild(el('div', 'empty', 'Keine Eintraege.'));
        return;
    }

    rows.forEach((entry) => {
        const row = el('div', `log-row${entry.kind === 'anticheat' ? ' anticheat' : ''}`);

        row.appendChild(el('div', 'log-kind', entry.kind));
        row.appendChild(el('div', null, entry.message));
        row.appendChild(el('div', 'log-time',
            String(entry.created_at || '').replace('T', ' ').substr(5, 14)));

        box.appendChild(row);
    });
}

/* --------------------------------------------------------------- Werkzeuge */

function renderWatchList() {
    const box = $('watch-list');
    clear(box);

    const flagged = (data.players || []).filter((player) => player.strikes > 0);

    if (!flagged.length) {
        box.appendChild(el('div', 'muted', 'Gerade ist niemand auffaellig.'));
        return;
    }

    flagged.sort((a, b) => b.strikes - a.strikes);

    flagged.forEach((player) => {
        const row = el('div', 'watch-row');
        row.appendChild(el('span', null,
            `${player.name} (${player.source}) — ${player.strikes} Strikes`));

        const jump = el('button', 'btn small', 'Ansehen');
        jump.addEventListener('click', () => {
            selected = player;
            activateTab('players');
            renderPlayers();
            renderDetail();
        });
        row.appendChild(jump);

        box.appendChild(row);
    });
}

$('btn-noclip').addEventListener('click', () => post('noclip'));
$('btn-invisible').addEventListener('click', () => post('invisible'));

$('btn-unban').addEventListener('click', () => {
    post('unban', { license: $('unban-license').value.trim() });
    $('unban-license').value = '';
});

/* ----------------------------------------------------------------- Rendern */

function render() {
    if (!data) return;

    $('server-name').textContent = data.server.name;
    $('stat-players').textContent = String(data.server.players);
    $('stat-uptime').textContent = `${data.server.uptime} Min.`;
    $('stat-level').textContent = String(data.level);

    renderPlayers();
    renderDetail();

    if (activeTab === 'tools') renderWatchList();
}

$('btn-close').addEventListener('click', () => post('close'));
$('btn-refresh').addEventListener('click', () => post('refresh'));

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !$('screen').classList.contains('hidden')) {
        post('close');
    }
});

/* -------------------------------------------------------------- Nachrichten */

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'admin:open':
            data = message.data || null;
            $('screen').classList.remove('hidden');
            activateTab(activeTab);
            render();
            break;

        case 'admin:data':
            data = message.data || data;
            render();
            break;

        case 'admin:close':
            $('screen').classList.add('hidden');
            break;

        case 'admin:spectate': {
            const box = $('spectate');

            if (message.data && message.data.name) {
                box.classList.remove('hidden');
                $('spectate-name').textContent = message.data.name;
            } else {
                box.classList.add('hidden');
            }
            break;
        }

        default:
            break;
    }
});
