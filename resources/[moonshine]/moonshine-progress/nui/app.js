/* Moonshine Fortschritt - Spielzeit, Missionen, Battle Pass und Kisten. */

const RESOURCE = 'moonshine-progress';

let state = null;
let activeTab = 'playtime';
let selectedCase = null;
let resetSeconds = 0;

/* ------------------------------------------------------------------ Hilfen */

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
    if (text !== undefined) node.textContent = text;
    return node;
}

function clear(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
}

function formatMinutes(minutes) {
    if (minutes < 60) return `${minutes} Min.`;

    const hours = Math.floor(minutes / 60);
    const rest = minutes % 60;

    return rest === 0 ? `${hours} Std.` : `${hours} Std. ${rest} Min.`;
}

function formatCountdown(seconds) {
    if (seconds <= 0) return '–';

    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);

    return h > 0 ? `${h} Std. ${m} Min.` : `${m} Min.`;
}

/** Baut die Pillen einer Belohnung. */
function rewardPills(reward) {
    const wrap = el('div', 'reward-list');

    liste(reward).forEach((part) => {
        const pill = el('div', 'reward-pill');
        pill.appendChild(el('span', null, part.icon || '◆'));
        pill.appendChild(el('span', null, part.text));
        wrap.appendChild(pill);
    });

    return wrap;
}

function toast(title, text, tone) {
    const node = el('div', `toast ${tone || ''}`);
    node.appendChild(el('strong', null, title));
    node.appendChild(el('span', null, text || ''));

    $('toasts').appendChild(node);
    setTimeout(() => node.remove(), 6000);
}

/* -------------------------------------------------------------------- Tabs */

function activateTab(name) {
    activeTab = name;

    document.querySelectorAll('.tab').forEach((tab) => {
        tab.classList.toggle('active', tab.dataset.tab === name);
    });

    ['playtime', 'missions', 'pass', 'cases'].forEach((key) => {
        $(`panel-${key}`).classList.toggle('hidden', key !== name);
    });
}

document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => activateTab(tab.dataset.tab));
});

/* --------------------------------------------------------------- Spielzeit */

function renderPlaytime(data) {
    $('playtime-total').textContent = `${Math.floor(data.total / 60)} Std.`;
    $('head-playtime').textContent = formatMinutes(data.minutes);

    const entries = liste(data.entries);
    const last = entries.length ? entries[entries.length - 1].minutes : 1;

    $('timeline-fill').style.width = `${Math.min(100, (data.minutes / last) * 100)}%`;

    const marks = $('timeline-marks');
    clear(marks);

    entries.forEach((entry) => {
        const mark = el('div', `timeline-mark${entry.reached ? ' reached' : ''}`,
            `${entry.minutes} Min.`);
        mark.style.left = `${(entry.minutes / last) * 100}%`;
        marks.appendChild(mark);
    });

    const grid = $('milestone-grid');
    clear(grid);

    entries.forEach((entry) => {
        const ready = entry.reached && !entry.claimed;
        const card = el('div', `milestone${ready ? ' ready' : ''}${entry.claimed ? ' claimed' : ''}`);

        const top = el('div', 'milestone-top');
        const left = el('div');
        left.appendChild(el('div', 'milestone-time', formatMinutes(entry.minutes)));
        left.appendChild(el('div', 'milestone-label', entry.label));
        top.appendChild(left);

        const button = el('button', 'btn small');
        if (entry.claimed) {
            button.textContent = 'Abgeholt';
            button.disabled = true;
        } else if (entry.reached) {
            button.textContent = 'Abholen';
            button.className = 'btn small ok';
            button.addEventListener('click', () => post('claimMilestone', { minutes: entry.minutes }));
        } else {
            button.textContent = 'Gesperrt';
            button.disabled = true;
        }
        top.appendChild(button);
        card.appendChild(top);

        const bar = el('div', 'milestone-bar');
        const fill = el('i');
        fill.style.width = `${Math.round(entry.progress * 100)}%`;
        bar.appendChild(fill);
        card.appendChild(bar);

        card.appendChild(rewardPills(entry.reward));
        grid.appendChild(card);
    });
}

/* --------------------------------------------------------------- Missionen */

function missionCard(mission) {
    const card = el('div', `mission${mission.done ? ' done' : ''}${mission.claimed ? ' claimed' : ''}`);

    card.appendChild(el('div', 'mission-icon', mission.icon || '📜'));

    const body = el('div', 'mission-body');
    body.appendChild(el('h3', null, mission.label));
    body.appendChild(el('p', null, mission.description));

    const progress = el('div', 'mission-progress');
    const bar = el('div', 'mission-bar');
    const fill = el('i');
    fill.style.width = `${Math.min(100, (mission.progress / mission.goal) * 100)}%`;
    bar.appendChild(fill);
    progress.appendChild(bar);
    progress.appendChild(el('span', 'mission-count', `${mission.progress} / ${mission.goal}`));
    body.appendChild(progress);

    body.appendChild(rewardPills(mission.reward));
    card.appendChild(body);

    const button = el('button', 'btn small');
    if (mission.claimed) {
        button.textContent = 'Abgeholt';
        button.disabled = true;
    } else if (mission.done) {
        button.textContent = 'Abholen';
        button.className = 'btn small ok';
        button.addEventListener('click', () => post('claimMission', { id: mission.id }));
    } else {
        button.textContent = 'Laeuft';
        button.disabled = true;
    }
    card.appendChild(button);

    return card;
}

function renderMissions(data) {
    const daily = liste(data.daily);
    const weekly = liste(data.weekly);

    const dailyList = $('daily-list');
    const weeklyList = $('weekly-list');
    clear(dailyList);
    clear(weeklyList);

    daily.forEach((mission) => dailyList.appendChild(missionCard(mission)));
    weekly.forEach((mission) => weeklyList.appendChild(missionCard(mission)));

    if (!daily.length) dailyList.appendChild(el('p', 'muted', 'Keine Missionen aktiv.'));
    if (!weekly.length) weeklyList.appendChild(el('p', 'muted', 'Keine Missionen aktiv.'));

    resetSeconds = data.dailyReset || 0;
    updateCountdown();

    const open = daily.concat(weekly).filter((m) => m.done && !m.claimed).length;
    const badge = $('badge-missions');
    badge.textContent = String(open);
    badge.classList.toggle('hidden', open === 0);
}

function updateCountdown() {
    const text = formatCountdown(resetSeconds);
    $('daily-reset').textContent = `Reset in ${text}`;
    $('head-reset').textContent = text;
}

/* ------------------------------------------------------------- Battle Pass */

function tierSlot(tier, track) {
    const rewards = track === 'premium' ? tier.premium : tier.free;
    const claimed = track === 'premium' ? tier.premiumClaimed : tier.freeClaimed;
    const locked = !tier.unlocked || (track === 'premium' && !state.battlepass.premium);
    const claimable = !locked && !claimed;

    const slot = el('div', `tier-slot ${track}${locked ? ' locked' : ''}` +
        `${claimed ? ' claimed' : ''}${claimable ? ' claimable' : ''}`);

    const list = el('div', 'tier-rewards');
    liste(rewards).forEach((part) => {
        const row = el('div', 'tier-reward');
        row.appendChild(el('span', null, part.icon || '◆'));
        row.appendChild(el('span', null, part.text));
        list.appendChild(row);
    });
    slot.appendChild(list);

    const button = el('button', 'btn small');
    if (claimed) {
        button.textContent = 'Abgeholt';
        button.disabled = true;
    } else if (locked) {
        button.textContent = tier.unlocked ? 'Premium' : 'Gesperrt';
        button.disabled = true;
    } else {
        button.textContent = 'Abholen';
        button.className = 'btn small ok';
        button.addEventListener('click', () => post('claimTier', { level: tier.level, track }));
    }
    slot.appendChild(button);

    return slot;
}

function renderBattlePass(data) {
    $('season-label').textContent = data.seasonLabel || `Saison ${data.season}`;
    $('pass-season').textContent = data.seasonLabel || `Saison ${data.season}`;
    $('pass-level').textContent = String(data.level);
    $('head-level').textContent = String(data.level);
    $('pass-xp').textContent = String(data.xp);
    $('pass-xp-needed').textContent = String(data.xpNeeded);

    const ratio = data.xpNeeded > 0 ? data.xp / data.xpNeeded : 1;
    $('pass-xp-fill').style.width = `${Math.round(ratio * 100)}%`;

    const premiumState = $('premium-state');
    premiumState.textContent = data.premium ? 'Premium aktiv' : 'Kostenlose Spur';
    premiumState.classList.toggle('active', data.premium);

    const premiumButton = $('btn-premium');
    premiumButton.classList.toggle('hidden', data.premium);
    premiumButton.textContent = `Premium fuer ${data.premiumPrice.toLocaleString('de-DE')} $`;

    const rail = $('pass-rail');
    clear(rail);

    liste(data.tiers).forEach((tier) => {
        const column = el('div', `tier${tier.unlocked ? ' unlocked' : ''}${tier.highlight ? ' highlight' : ''}`);

        const head = el('div', 'tier-head', `Stufe ${tier.level}`);
        column.appendChild(head);
        column.appendChild(tierSlot(tier, 'free'));
        column.appendChild(tierSlot(tier, 'premium'));

        rail.appendChild(column);
    });

    let open = 0;
    liste(data.tiers).forEach((tier) => {
        if (!tier.unlocked) return;
        if (!tier.freeClaimed) open += 1;
        if (data.premium && !tier.premiumClaimed) open += 1;
    });

    const badge = $('badge-pass');
    badge.textContent = String(open);
    badge.classList.toggle('hidden', open === 0);
}

/* ------------------------------------------------------------------ Kisten */

function renderCaseDetail(entry) {
    const box = $('case-detail');
    clear(box);

    if (!entry) {
        box.appendChild(el('p', 'muted', 'Waehle eine Kiste, um ihre Chancen zu sehen.'));
        return;
    }

    box.appendChild(el('h3', null, entry.label));
    box.appendChild(el('p', 'muted', entry.description));

    const list = el('div');
    list.style.marginTop = '14px';

    const best = liste(entry.loot).reduce((max, loot) => Math.max(max, loot.chance), 0) || 1;

    liste(entry.loot).forEach((loot) => {
        const row = el('div', 'chance-row');
        row.appendChild(el('span', null, loot.label));

        const bar = el('div', 'chance-bar');
        const fill = el('i');
        fill.style.width = `${Math.round((loot.chance / best) * 100)}%`;
        bar.appendChild(fill);
        row.appendChild(bar);

        row.appendChild(el('span', 'chance-value', `${(loot.chance * 100).toFixed(1)} %`));
        list.appendChild(row);
    });

    box.appendChild(list);
}

function renderCases(entries) {
    const grid = $('case-grid');
    clear(grid);

    let total = 0;

    entries.forEach((entry) => {
        total += entry.count;

        const card = el('div', `case-card${entry.count === 0 ? ' empty' : ''}` +
            `${selectedCase === entry.name ? ' selected' : ''}`);

        const icon = el('div', 'case-icon', entry.icon || '📦');
        icon.style.background = `${entry.color}22`;
        icon.style.borderColor = entry.color;
        card.appendChild(icon);

        card.appendChild(el('h3', null, entry.label));
        card.appendChild(el('div', 'case-count', `${entry.count} vorhanden`));

        const buttons = el('div', 'case-buttons');

        const openButton = el('button', 'btn small primary', 'Oeffnen');
        openButton.disabled = entry.count === 0;
        openButton.addEventListener('click', (event) => {
            event.stopPropagation();
            post('openCase', { name: entry.name });
        });
        buttons.appendChild(openButton);

        const packButton = el('button', 'btn small', 'Einpacken');
        packButton.disabled = entry.count === 0;
        packButton.title = 'Als Item ins Inventar legen';
        packButton.addEventListener('click', (event) => {
            event.stopPropagation();
            post('packCase', { name: entry.name, amount: 1 });
        });
        buttons.appendChild(packButton);

        card.appendChild(buttons);

        card.addEventListener('click', () => {
            selectedCase = entry.name;
            renderCases(entries);
            renderCaseDetail(entry);
        });

        grid.appendChild(card);
    });

    $('head-cases').textContent = String(total);

    if (selectedCase) {
        const entry = entries.find((item) => item.name === selectedCase);
        renderCaseDetail(entry);
    }
}

/* ----------------------------------------------------------- Kistenanimation */

function playCase(data) {
    const overlay = $('case-overlay');
    const reel = $('case-reel');
    const result = $('case-result');

    overlay.classList.remove('hidden');
    result.classList.add('hidden');

    $('case-title').textContent = data.label;
    $('case-box').textContent = data.icon || '📦';
    $('case-glow').style.background =
        `radial-gradient(circle, ${data.color}88, transparent 68%)`;

    // Eine Rolle aus zufaelligen Losen, das Gewinnerlos sitzt fest.
    const pool = liste(state && state.cases)
        .find((entry) => entry.name === data.case);
    const labels = pool ? pool.loot.map((loot) => loot.label) : [data.result];

    clear(reel);
    const strip = el('div', 'case-strip');

    const WIN_INDEX = 28;
    for (let index = 0; index < 40; index += 1) {
        const label = index === WIN_INDEX
            ? data.result
            : labels[Math.floor(Math.random() * labels.length)];

        const slot = el('div', `case-slot${index === WIN_INDEX ? ' win' : ''}`, label);
        strip.appendChild(slot);
    }

    reel.appendChild(strip);

    // Nach einem Frame die Fahrt starten, damit die Transition greift.
    requestAnimationFrame(() => {
        const SLOT = 160;                          // 150px + 10px Abstand
        const centre = reel.clientWidth / 2 - SLOT / 2;
        strip.style.transform = `translateX(${centre - WIN_INDEX * SLOT}px)`;
    });

    setTimeout(() => {
        result.classList.remove('hidden');
        $('case-result-label').textContent = data.result;

        const rewardBox = $('case-result-reward');
        clear(rewardBox);
        rewardBox.appendChild(rewardPills(data.reward));
    }, 3100);

    setTimeout(() => overlay.classList.add('hidden'), 6000);
}

/* ------------------------------------------------------------------ Rendern */

function render(data) {
    state = data;

    $('reset-hour').textContent = '4';

    renderPlaytime(data.playtime || { minutes: 0, total: 0, entries: [] });
    renderMissions(data.missions || { daily: [], weekly: [] });
    renderBattlePass(data.battlepass || { tiers: [], level: 1, xp: 0, xpNeeded: 0, premiumPrice: 0 });
    renderCases(liste(data.cases));
}

/* ------------------------------------------------------------------ Aktionen */

$('btn-close').addEventListener('click', () => post('close'));
$('btn-claim-all').addEventListener('click', () => post('claimAll'));
$('btn-premium').addEventListener('click', () => post('buyPremium'));

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape') post('close');
});

/* -------------------------------------------------------------- Nachrichten */

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'progress:open':
            $('screen').classList.remove('hidden');
            activateTab(activeTab);
            break;

        case 'progress:close':
            $('screen').classList.add('hidden');
            $('case-overlay').classList.add('hidden');
            break;

        case 'progress:data':
            render(message.data || {});
            break;

        case 'progress:milestone':
            toast('Spielzeit-Belohnung', `${message.minutes} Minuten erreicht.`, 'gold');
            break;

        case 'progress:missionDone':
            toast('Mission erfuellt', 'Hol dir deine Belohnung ab.', 'ok');
            break;

        case 'progress:levelUp':
            toast('Battle Pass', `Stufe ${message.level} erreicht.`, 'gold');
            break;

        case 'progress:caseResult':
            playCase(message.data || {});
            break;

        default:
            break;
    }
});

/* Der Countdown laeuft auch ohne neuen Sync weiter. */
setInterval(() => {
    if (resetSeconds > 0) {
        resetSeconds -= 1;
        updateCountdown();
    }
}, 1000);
