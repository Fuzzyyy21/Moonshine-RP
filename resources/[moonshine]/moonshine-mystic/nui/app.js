/* Moonshine Mystik - NUI Logik */

const RESOURCE = 'moonshine-mystic';
const $ = (id) => document.getElementById(id);

/* Rasterabstaende des Baums in Pixeln */
const GRID = { colWidth: 150, rowHeight: 132, paddingX: 90, paddingY: 40 };

const state = {
    bar: { slots: [], visible: false },
    tree: null,
    selected: null,
    cooldowns: {},
};

function post(name, data = {}) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
}

const number = (value) => new Intl.NumberFormat('de-DE').format(Math.floor(value || 0));

/* ------------------------------------------------------------ Skillleiste */

function renderBar() {
    const data = state.bar;
    $('skillbar').classList.toggle('hidden', !data.visible);
    if (!data.visible) return;

    if (data.raceColor) setClassColor(data.raceColor);

    $('essence-label').textContent = data.essenceLabel || 'Essenz';
    const percent = data.maxEssence > 0 ? (data.essence / data.maxEssence) * 100 : 0;
    $('essence-fill').style.width = Math.max(0, Math.min(100, percent)) + '%';
    $('essence-value').textContent = `${Math.floor(data.essence)} / ${data.maxEssence}`;
    $('bar-race').textContent = data.raceLabel ? `${data.raceIcon || ''} ${data.raceLabel}` : '';

    const container = $('bar-slots');
    container.innerHTML = '';

    (data.slots || []).forEach((slot) => {
        const element = document.createElement('div');
        element.className = 'bar-slot' + (slot.id ? ' filled' : '');
        element.innerHTML = `
            <span class="key"></span>
            <span class="icon"></span>
            <span class="name"></span>
            <span class="rank"></span>
            <span class="cost"></span>`;

        element.querySelector('.key').textContent = slot.key || slot.slot;
        element.querySelector('.icon').textContent = slot.icon || '·';
        element.querySelector('.name').textContent = slot.label || '';
        element.querySelector('.rank').textContent = slot.id && slot.maxRank > 1
            ? `${slot.rank}/${slot.maxRank}` : '';
        element.querySelector('.cost').textContent = slot.id ? slot.cost : '';

        const remaining = slot.id ? (state.cooldowns[slot.id] || 0) : 0;
        if (remaining > 0) {
            const overlay = document.createElement('div');
            overlay.className = 'cooldown';
            overlay.textContent = Math.ceil(remaining);
            element.appendChild(overlay);
        }

        container.appendChild(element);
    });
}

setInterval(() => {
    const ids = Object.keys(state.cooldowns);
    if (ids.length === 0) return;

    ids.forEach((id) => {
        state.cooldowns[id] -= 1;
        if (state.cooldowns[id] <= 0) delete state.cooldowns[id];
    });

    if (state.bar.visible) renderBar();
}, 1000);

/* ---------------------------------------------------------------- Farbton */

function setClassColor(hex) {
    document.documentElement.style.setProperty('--class', hex);

    const match = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex || '');
    if (match) {
        const [r, g, b] = [1, 2, 3].map((index) => parseInt(match[index], 16));
        document.documentElement.style.setProperty('--class-dim', `rgba(${r}, ${g}, ${b}, 0.28)`);
    }
}

/* ------------------------------------------------------------------- Tabs */

document.querySelectorAll('.tab').forEach((tab) => {
    tab.onclick = () => {
        document.querySelectorAll('.tab').forEach((other) => other.classList.remove('active'));
        tab.classList.add('active');

        ['tree', 'perks', 'bar', 'stones'].forEach((name) => {
            $('panel-' + name).classList.toggle('hidden', name !== tab.dataset.tab);
        });
    };
});

/* -------------------------------------------------------------- Klassen */

function renderClasses() {
    const data = state.tree;
    const list = $('class-list');
    list.innerHTML = '';

    $('classes-caption').textContent = data.canSwitchClass ? 'Klasse waehlen' : 'Deine Klasse';

    (data.classes || []).forEach((race) => {
        const entry = document.createElement('div');
        entry.className = 'class-entry' + (race.current ? ' current' : '');
        if (!data.atRitual && !race.current) entry.classList.add('disabled');

        entry.innerHTML = '<span class="icon"></span><span class="name"></span>';
        entry.querySelector('.icon').textContent = race.icon;
        entry.querySelector('.name').textContent = race.label;
        entry.title = race.description || '';

        if (!race.current && data.canSwitchClass && data.atRitual) {
            entry.onclick = () => post('mysticAwaken', { race: race.name });
        }

        list.appendChild(entry);
    });

    const hint = $('class-hint');
    if (!data.race) {
        hint.textContent = 'Waehle an einem Ritualpunkt deine Klasse. Solange du keine Faehigkeit '
            + 'gelernt hast, kannst du sie frei wechseln.';
    } else if (data.canSwitchClass) {
        hint.textContent = 'Deine Klasse ist noch nicht endgueltig. Mit der ersten gelernten '
            + 'Faehigkeit bindest du dich dauerhaft.';
    } else {
        hint.textContent = 'Deine Klasse ist gebunden. Andere Klassen sind dir verborgen.';
    }
}

/* ---------------------------------------------------------------- Baum */

function nodePosition(node) {
    return {
        x: GRID.paddingX + node.col * GRID.colWidth,
        y: GRID.paddingY + node.row * GRID.rowHeight,
    };
}

function nodeStateClass(node) {
    if (node.maxed) return 'maxed learned';
    if (node.rank > 0) return 'learned';
    if (node.locked) return 'locked';
    if (node.affordable) return 'open';
    return '';
}

function renderTree() {
    const data = state.tree;
    const canvas = $('tree-canvas');
    const nodeLayer = $('tree-nodes');
    const svg = $('tree-links');

    nodeLayer.innerHTML = '';
    svg.innerHTML = '';

    if (!data.race) {
        nodeLayer.innerHTML = '<div class="detail-empty">Du bist noch nicht erweckt. '
            + 'Waehle links deine Klasse.</div>';
        return;
    }

    const positions = {};
    let maxX = 0;
    let maxY = 0;

    data.nodes.forEach((node) => {
        const position = nodePosition(node);
        positions[node.id] = position;
        maxX = Math.max(maxX, position.x + GRID.paddingX);
        maxY = Math.max(maxY, position.y + GRID.rowHeight);
    });

    canvas.style.width = maxX + 'px';
    canvas.style.height = maxY + 'px';
    svg.setAttribute('viewBox', `0 0 ${maxX} ${maxY}`);
    svg.setAttribute('width', maxX);
    svg.setAttribute('height', maxY);

    const byId = new Map(data.nodes.map((node) => [node.id, node]));

    // Verbindungen zuerst, damit sie hinter den Knoten liegen.
    (data.links || []).forEach((link) => {
        const from = positions[link.from];
        const to = positions[link.to];
        if (!from || !to) return;

        const target = byId.get(link.to);
        const source = byId.get(link.from);
        const active = source && source.rank > 0 && target && target.rank > 0;
        const reachable = source && source.rank > 0;

        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        const midY = (from.y + to.y) / 2;
        path.setAttribute('d', `M ${from.x} ${from.y + 31} V ${midY} H ${to.x} V ${to.y - 31}`);
        path.setAttribute('fill', 'none');
        path.setAttribute('stroke-width', active ? '2' : '1.5');
        path.setAttribute('stroke', active
            ? 'var(--class)'
            : (reachable ? 'rgba(216,178,95,.45)' : 'rgba(255,255,255,.12)'));
        svg.appendChild(path);
    });

    data.nodes.forEach((node) => {
        const position = positions[node.id];
        const element = document.createElement('div');
        element.className = 'node ' + nodeStateClass(node);
        if (state.selected === node.id) element.classList.add('selected');
        element.style.left = position.x + 'px';
        element.style.top = position.y + 'px';

        element.innerHTML = `
            <div class="ring"></div>
            <div class="label"></div>
            <div class="rank"></div>`;

        element.querySelector('.ring').textContent = node.icon || '✦';
        element.querySelector('.label').textContent = node.label;
        element.querySelector('.rank').textContent = `${node.rank}/${node.maxRank}`;

        if (node.levelLocked) {
            const lock = document.createElement('div');
            lock.className = 'lock';
            lock.textContent = '🔒';
            lock.title = `Klassenstufe ${node.levelNeeded} noetig`;
            element.appendChild(lock);
        }

        element.onclick = () => {
            state.selected = node.id;
            renderTree();
            renderDetail();
        };

        nodeLayer.appendChild(element);
    });
}

function renderDetail() {
    const data = state.tree;
    const detail = $('detail');
    const node = (data.nodes || []).find((entry) => entry.id === state.selected);

    if (!node) {
        detail.innerHTML = '<div class="detail-empty">Waehle einen Knoten im Baum.</div>';
        return;
    }

    detail.innerHTML = `
        <div class="detail-head">
            <div class="ring"></div>
            <h2></h2>
            <div class="rank-line"></div>
            <span class="kind"></span>
        </div>
        <hr>
        <p class="desc"></p>
        <div class="stages-wrap hidden">
            <hr>
            <div class="section-caption">Stufen</div>
            <div class="stages"></div>
        </div>
        <div class="requirement"></div>`;

    detail.querySelector('.ring').textContent = node.icon || '✦';
    detail.querySelector('h2').textContent = node.label;
    detail.querySelector('.rank-line').textContent = `${node.rank} / ${node.maxRank}`;
    detail.querySelector('.kind').textContent = node.passive ? 'Passive Faehigkeit' : 'Aktive Faehigkeit';
    detail.querySelector('.desc').textContent = node.description;

    if (node.ranks && node.ranks.length > 0) {
        detail.querySelector('.stages-wrap').classList.remove('hidden');
        const stages = detail.querySelector('.stages');

        node.ranks.forEach((rank) => {
            const row = document.createElement('div');
            row.className = 'stage-row'
                + (rank.owned ? ' owned' : '')
                + (rank.current && !node.maxed ? ' current' : '');
            row.innerHTML = '<span class="num"></span><span class="text"></span>';
            row.querySelector('.num').textContent = rank.level;
            row.querySelector('.text').textContent = rank.text;
            stages.appendChild(row);
        });
    }

    const requirement = detail.querySelector('.requirement');

    if (node.maxed) {
        requirement.innerHTML = '<div class="section-caption">Maximalstufe erreicht</div>';
        if (!node.passive) addSlotButtons(requirement, node);
        return;
    }

    const caption = document.createElement('div');
    caption.className = 'section-caption';
    caption.textContent = 'Benoetigt';
    requirement.appendChild(caption);

    const cost = document.createElement('div');
    cost.className = 'cost-line' + (node.affordable ? '' : ' miss');
    cost.innerHTML = '<span class="gem">◆</span><span></span>';
    cost.querySelector('span:last-child').textContent =
        `${number(node.price)} ${data.stone.label || 'Steine'} (du hast ${number(data.stone.count)})`;
    requirement.appendChild(cost);

    if (node.levelLocked) {
        const note = document.createElement('div');
        note.className = 'note';
        note.textContent = `Klassenstufe ${node.levelNeeded} noetig (aktuell ${data.level}).`;
        requirement.appendChild(note);
    } else if (node.locked) {
        const note = document.createElement('div');
        note.className = 'note';
        note.textContent = 'Vorherige Faehigkeit fehlt.';
        requirement.appendChild(note);
    }

    if (!data.atRitual) {
        const note = document.createElement('div');
        note.className = 'note';
        note.textContent = 'Skillen geht nur an einem Ritualpunkt.';
        requirement.appendChild(note);
    }

    const button = document.createElement('button');
    button.className = 'btn primary';
    button.textContent = node.rank > 0 ? 'Stufe steigern' : 'Skillen';
    button.disabled = !data.atRitual || node.locked || !node.affordable;
    button.onclick = () => post('mysticUpgrade', { id: node.id });
    requirement.appendChild(button);

    if (node.rank > 0 && !node.passive) addSlotButtons(requirement, node);
}

/** Buttons, um eine gelernte Faehigkeit auf einen Leistenslot zu legen. */
function addSlotButtons(container, node) {
    const wrap = document.createElement('div');
    wrap.className = 'requirement';
    wrap.innerHTML = '<div class="section-caption">Auf Slot legen</div>';

    const row = document.createElement('div');
    row.style.display = 'flex';
    row.style.flexWrap = 'wrap';
    row.style.gap = '6px';

    (state.tree.bar || []).forEach((slot) => {
        const button = document.createElement('button');
        button.className = 'btn' + (slot.id === node.id ? ' primary' : '');
        button.style.padding = '6px 11px';
        button.style.width = 'auto';
        button.style.marginTop = '0';
        button.textContent = slot.slot;
        button.onclick = () => post('mysticSetSlot', { slot: slot.slot, id: node.id });
        row.appendChild(button);
    });

    wrap.appendChild(row);
    container.appendChild(wrap);
}

/* ---------------------------------------------------------------- Perks */

function renderPerks() {
    const data = state.tree;
    const grid = $('perk-grid');
    grid.innerHTML = '';

    data.perks.forEach((perk) => {
        const card = document.createElement('div');
        card.className = 'perk';
        card.innerHTML = `
            <div class="head">
                <span class="icon"></span>
                <span class="title"></span>
                <span class="level"></span>
            </div>
            <div class="desc"></div>
            <div class="level-track"></div>
            <div class="footer">
                <span class="cost"></span>
                <button class="btn primary">Verbessern</button>
            </div>`;

        card.querySelector('.icon').textContent = perk.icon;
        card.querySelector('.title').textContent = perk.label;
        card.querySelector('.level').textContent = `${perk.level} / ${perk.maxLevel}`;
        card.querySelector('.desc').textContent = perk.description;

        const track = card.querySelector('.level-track');
        for (let index = 0; index < perk.maxLevel; index++) {
            const pip = document.createElement('div');
            pip.className = 'pip' + (index < perk.level ? ' on' : '');
            track.appendChild(pip);
        }

        const button = card.querySelector('button');
        if (perk.nextCost === null || perk.nextCost === undefined) {
            card.querySelector('.cost').textContent = 'Maximalstufe';
            button.disabled = true;
        } else {
            card.querySelector('.cost').textContent = `${perk.nextCost} Punkte`;
            button.disabled = !perk.affordable;
            button.onclick = () => post('mysticUpgradePerk', { id: perk.id });
        }

        grid.appendChild(card);
    });
}

/* ----------------------------------------------------- Leiste und Steine */

function renderBarEditor() {
    const data = state.tree;
    const container = $('bar-edit-slots');
    container.innerHTML = '';

    const active = (data.nodes || []).filter((node) => node.rank > 0 && !node.passive);

    (data.bar || []).forEach((slot) => {
        const row = document.createElement('div');
        row.className = 'bar-edit-row';
        row.innerHTML = '<span class="slot-key"></span><select></select>';
        row.querySelector('.slot-key').textContent = `Slot ${slot.slot} · ${slot.key}`;

        const select = row.querySelector('select');
        const empty = document.createElement('option');
        empty.value = '';
        empty.textContent = '— leer —';
        select.appendChild(empty);

        active.forEach((node) => {
            const option = document.createElement('option');
            option.value = node.id;
            option.textContent = `${node.icon || ''} ${node.label} (${node.rank}/${node.maxRank})`;
            if (slot.id === node.id) option.selected = true;
            select.appendChild(option);
        });

        select.onchange = () => post('mysticSetSlot', {
            slot: slot.slot,
            id: select.value === '' ? null : select.value,
        });

        container.appendChild(row);
    });
}

function renderStones() {
    const data = state.tree;
    const grid = $('stone-grid');
    grid.innerHTML = '';

    data.stones.forEach((stone) => {
        const element = document.createElement('div');
        element.className = 'stone' + (stone.isClass ? ' is-class' : '');
        element.innerHTML = '<span></span><span class="count"></span>';
        element.children[0].textContent = stone.label;
        element.children[1].textContent = stone.count;
        grid.appendChild(element);
    });

    const meditation = data.meditation || {};
    const button = $('btn-meditate');
    const info = $('meditation-state');

    if (!meditation.enabled) {
        info.textContent = 'Meditation ist auf diesem Server deaktiviert.';
        button.disabled = true;
    } else if (!data.atRitual) {
        info.textContent = 'Nur an einem Ritualpunkt moeglich.';
        button.disabled = true;
    } else if (meditation.left > 0) {
        info.textContent = `Noch ${Math.ceil(meditation.left / 60)} Minuten Ruhe noetig.`;
        button.disabled = true;
    } else {
        info.textContent = `Dauer: ${meditation.duration} Sekunden.`;
        button.disabled = false;
    }

    const conversion = data.conversion || {};
    $('conversion-text').textContent = data.race
        ? `${conversion.amount} ${conversion.fromLabel} ergeben ${conversion.result} ${data.stone.label}.`
        : 'Erst nach der Erweckung verfuegbar.';
    $('btn-convert-2').disabled = !data.atRitual || !data.race;
}

$('btn-meditate').onclick = () => post('mysticMeditate');
$('btn-convert').onclick = () => post('mysticConvert', { times: 1 });
$('btn-convert-2').onclick = () => post('mysticConvert', { times: 1 });
$('btn-reset-perks').onclick = () => post('mysticResetPerks');

/* --------------------------------------------------------------- Anzeige */

function renderTreeScreen() {
    const data = state.tree;

    if (data.raceColor) setClassColor(data.raceColor);

    $('crest').textContent = data.raceIcon || '✦';
    $('class-name').textContent = data.raceLabel || 'Nicht erweckt';
    $('class-desc').textContent = data.raceDescription || 'Waehle deine Klasse an einem Ritualpunkt.';

    $('level-caption').textContent = data.raceLabel ? `${data.raceLabel} Stufe` : 'Stufe';
    $('level-value').textContent = data.level || 1;
    $('xp-current').textContent = number(data.xpIntoLevel);
    $('xp-next').textContent = number(data.xpForNext);
    $('xp-fill').style.width = data.xpForNext > 0
        ? Math.min(100, (data.xpIntoLevel / data.xpForNext) * 100) + '%'
        : '100%';

    $('stone-caption').textContent = (data.stone && data.stone.label) || 'Steine';
    $('stone-count').textContent = number(data.stone && data.stone.count);
    $('stone-count-2').textContent = number(data.stone && data.stone.count);
    $('personal-points').textContent = number(data.personalPoints);
    $('btn-convert').disabled = !data.atRitual || !data.race;

    renderClasses();
    renderTree();
    renderDetail();
    renderPerks();
    renderBarEditor();
    renderStones();

    $('tree-screen').classList.remove('hidden');
}

function closeTree() {
    $('tree-screen').classList.add('hidden');
    post('mysticClose');
}

$('btn-close').onclick = closeTree;

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !$('tree-screen').classList.contains('hidden')) {
        closeTree();
    }
});

/* ----------------------------------------------------------- Nachrichten */

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};

    switch (action) {
        case 'mysticBar':
            state.bar = data;
            renderBar();
            break;

        case 'mysticEssence':
            state.bar.essence = data.essence;
            state.bar.maxEssence = data.maxEssence;
            renderBar();
            break;

        case 'mysticProfile':
            state.cooldowns = Object.assign({}, data.cooldowns || {});
            if (data.raceColor) setClassColor(data.raceColor);
            break;

        case 'mysticTree':
            state.tree = data;
            if (state.selected && !(data.nodes || []).some((node) => node.id === state.selected)) {
                state.selected = null;
            }
            renderTreeScreen();
            break;

        case 'mysticTreeClose':
            $('tree-screen').classList.add('hidden');
            break;
    }
});
