/* Moonshine Mystik - NUI Logik */

const RESOURCE = 'moonshine-mystic';
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

    liste(data.slots).forEach((slot) => {
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

function activateTab(name) {
    document.querySelectorAll('.tab').forEach((tab) => {
        tab.classList.toggle('active', tab.dataset.tab === name);
    });

    ['tree', 'perks', 'bar', 'stones', 'ritual'].forEach((panel) => {
        $('panel-' + panel).classList.toggle('hidden', panel !== name);
    });

    // Der persoenliche Baum hat eine eigene Kopfzeile und Seitenleiste.
    const personal = name === 'perks';
    $('head-class').classList.toggle('hidden', personal);
    $('head-personal').classList.toggle('hidden', !personal);
    $('sidebar-classes').classList.toggle('hidden', personal);
    $('sidebar-categories').classList.toggle('hidden', !personal);
    $('legend').classList.toggle('hidden', personal);
    $('statistics').classList.toggle('hidden', !personal);

    $('class-name').textContent = personal
        ? 'Personal Skills'
        : (state.tree && state.tree.raceLabel) || 'Nicht erweckt';
    $('subtitle').textContent = personal ? 'Skillbaum' : 'Skilltree';
    $('class-desc').textContent = personal
        ? 'Staerke dich. Werde legendaer.'
        : (state.tree && state.tree.raceDescription) || 'Waehle deine Klasse an einem Ritualpunkt.';

    if (personal) {
        renderPersonal();
    } else if (state.tree) {
        setClassColor(state.tree.raceColor || '#c0392f');
        renderDetail();
    }
}

document.querySelectorAll('.tab').forEach((tab) => {
    tab.onclick = () => activateTab(tab.dataset.tab);
});

/* -------------------------------------------------------------- Klassen */

function renderClasses() {
    const data = state.tree;
    const list = $('class-list');
    list.innerHTML = '';

    $('classes-caption').textContent = data.canSwitchClass ? 'Klasse waehlen' : 'Deine Klasse';

    liste(data.classes).forEach((race) => {
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

    liste(data.nodes).forEach((node) => {
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

    const byId = new Map(liste(data.nodes).map((node) => [node.id, node]));

    // Verbindungen zuerst, damit sie hinter den Knoten liegen.
    liste(data.links).forEach((link) => {
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

    liste(data.nodes).forEach((node) => {
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
            lock.title = `Klassenstufe ${node.levelNeeded} noetig (geskillte Stufen im Baum)`;
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
    const node = liste(data.nodes).find((entry) => entry.id === state.selected);

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
        note.textContent = `Klassenstufe ${node.levelNeeded} noetig - das sind `
            + `${node.levelNeeded} geskillte Stufen im Baum (aktuell ${data.level}).`;
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

    liste(state.tree.bar).forEach((slot) => {
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

/* ------------------------------------------------- Persoenlicher Baum */

state.category = 'vitalitaet';
state.personalSelected = null;

function setCategoryColor(hex) {
    document.documentElement.style.setProperty('--cat', hex);

    const match = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex || '');
    if (match) {
        const [r, g, b] = [1, 2, 3].map((index) => parseInt(match[index], 16));
        document.documentElement.style.setProperty('--cat-dim', `rgba(${r}, ${g}, ${b}, 0.28)`);
    }
}

function currentCategory() {
    const data = state.tree;
    return liste(data.categories).find((entry) => entry.id === state.category)
        || liste(data.categories)[0];
}

function renderCategories() {
    const data = state.tree;
    const list = $('category-list');
    list.innerHTML = '';

    liste(data.categories).forEach((category) => {
        const entry = document.createElement('div');
        entry.className = 'category-entry' + (category.id === state.category ? ' active' : '');
        entry.style.setProperty('--cat', category.color);
        entry.innerHTML = `
            <span class="icon"></span>
            <div class="info">
                <div class="name"></div>
                <div class="progress"></div>
            </div>`;

        entry.querySelector('.icon').textContent = category.icon;
        entry.querySelector('.name').textContent = category.label;
        entry.querySelector('.progress').textContent = `${category.spent} / ${category.max}`;
        entry.title = category.description || '';

        entry.onclick = () => {
            state.category = category.id;
            state.personalSelected = null;
            renderPersonal();
        };

        list.appendChild(entry);
    });

    $('p-spent').textContent = number(data.spentPoints);
}

function personalNodeState(node) {
    if (node.maxed) return 'maxed learned';
    if (node.rank > 0) return 'learned';
    if (node.locked) return 'locked';
    if (node.affordable) return 'open';
    return '';
}

function renderPersonalTree() {
    const data = state.tree;
    const canvas = $('personal-canvas');
    const layer = $('personal-nodes');
    const svg = $('personal-links');
    const category = currentCategory();

    layer.innerHTML = '';
    svg.innerHTML = '';
    if (!category) return;

    const nodes = liste((data.personalNodes && data.personalNodes.nodes[category.id]));
    const links = liste((data.personalNodes && data.personalNodes.links[category.id]));

    const positions = {};
    let maxX = 0;
    let maxY = 0;

    nodes.forEach((node) => {
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

    const byId = new Map(nodes.map((node) => [node.id, node]));

    links.forEach((link) => {
        const from = positions[link.from];
        const to = positions[link.to];
        if (!from || !to) return;

        const source = byId.get(link.from);
        const target = byId.get(link.to);
        const active = source && source.rank > 0 && target && target.rank > 0;
        const reachable = source && source.rank > 0;

        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        const midY = (from.y + to.y) / 2;
        path.setAttribute('d', `M ${from.x} ${from.y + 31} V ${midY} H ${to.x} V ${to.y - 31}`);
        path.setAttribute('fill', 'none');
        path.setAttribute('stroke-width', active ? '2' : '1.5');
        path.setAttribute('stroke', active
            ? 'var(--cat)'
            : (reachable ? 'rgba(216,178,95,.45)' : 'rgba(255,255,255,.12)'));
        svg.appendChild(path);
    });

    nodes.forEach((node) => {
        const position = positions[node.id];
        const element = document.createElement('div');
        element.className = 'node personal ' + personalNodeState(node);
        if (state.personalSelected === node.id) element.classList.add('selected');
        element.style.left = position.x + 'px';
        element.style.top = position.y + 'px';

        element.innerHTML = `
            <div class="ring"></div>
            <div class="label"></div>
            <div class="rank"></div>`;

        element.querySelector('.ring').textContent = node.icon || '✦';
        element.querySelector('.label').textContent = node.label;
        element.querySelector('.rank').textContent = `${node.rank}/${node.maxRank}`;

        if (node.locked) {
            const lock = document.createElement('div');
            lock.className = 'lock';
            lock.textContent = '🔒';
            lock.title = 'Vorherige Faehigkeit fehlt';
            element.appendChild(lock);
        }

        element.onclick = () => {
            state.personalSelected = node.id;
            renderPersonalTree();
            renderPersonalDetail();
        };

        layer.appendChild(element);
    });
}

function renderPersonalDetail() {
    const data = state.tree;
    const detail = $('detail');
    const category = currentCategory();
    const nodes = liste((data.personalNodes && category && data.personalNodes.nodes[category.id]));
    const node = nodes.find((entry) => entry.id === state.personalSelected);

    if (!node) {
        detail.innerHTML = '<div class="detail-empty">Waehle einen Knoten im Baum.</div>';
        return;
    }

    detail.innerHTML = `
        <div class="detail-head">
            <div class="ring"></div>
            <h2></h2>
            <div class="rank-line"></div>
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
        requirement.innerHTML = '<div class="section-caption">Max. Stufe erreicht</div>';
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
        `${node.price} Faehigkeitspunkt${node.price === 1 ? '' : 'e'} `
        + `(du hast ${number(data.skillPoints)})`;
    requirement.appendChild(cost);

    if (node.locked) {
        const note = document.createElement('div');
        note.className = 'note';
        note.textContent = 'Die vorherige Faehigkeit fehlt noch.';
        requirement.appendChild(note);
    }

    const button = document.createElement('button');
    button.className = 'btn primary';
    button.textContent = node.rank > 0 ? 'Stufe steigern' : 'Skillen';
    button.disabled = node.locked || !node.affordable;
    button.onclick = () => post('mysticUpgradePersonal', { id: node.id });
    requirement.appendChild(button);
}

function renderStatistics() {
    const data = state.tree;
    const container = $('stat-rows');
    container.innerHTML = '';

    liste(data.statistics).forEach((row) => {
        const element = document.createElement('div');
        element.className = 'stat-row';
        element.innerHTML = '<span class="icon"></span><span class="label"></span><span class="value"></span>';
        element.querySelector('.icon').textContent = row.icon;
        element.querySelector('.label').textContent = row.label;
        element.querySelector('.value').textContent = row.value;
        container.appendChild(element);
    });

    if (liste(data.statistics).length === 0) {
        container.innerHTML = '<div class="muted">Noch keine Boni geskillt.</div>';
    }

    const category = currentCategory();
    $('stat-motto').textContent = category ? `„${category.motto}"` : '';
}

/** Alles rund um den persoenlichen Baum neu zeichnen. */
function renderPersonal() {
    const data = state.tree;
    const category = currentCategory();
    if (category) setCategoryColor(category.color);

    $('p-level').textContent = data.personalLevel || 1;
    $('p-xp-into').textContent = number(data.xpIntoLevel);
    $('p-xp-next').textContent = number(data.xpForNext);
    $('p-xp-fill').style.width = data.xpForNext > 0
        ? Math.min(100, (data.xpIntoLevel / data.xpForNext) * 100) + '%'
        : '100%';
    $('p-points').textContent = number(data.skillPoints);
    $('p-reset-cost').textContent = number(data.resetCost && data.resetCost.amount);
    $('btn-reset-personal').disabled = (data.spentPoints || 0) === 0;

    renderCategories();
    renderPersonalTree();
    renderPersonalDetail();
    renderStatistics();
}

$('btn-reset-personal').onclick = () => post('mysticResetPersonal');

/* ----------------------------------------------------- Leiste und Steine */

function renderBarEditor() {
    const data = state.tree;
    const container = $('bar-edit-slots');
    container.innerHTML = '';

    const active = liste(data.nodes).filter((node) => node.rank > 0 && !node.passive);

    liste(data.bar).forEach((slot) => {
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

    liste(data.stones).forEach((stone) => {
        const element = document.createElement('div');
        element.className = 'stone' + (stone.isClass ? ' is-class' : '');
        element.innerHTML = '<span></span><span class="count"></span>';
        element.children[0].textContent = stone.label;
        element.children[1].textContent = stone.count;
        grid.appendChild(element);
    });

    renderRecipe();
}

/** Ritualpunkt: Meditation, Ritual und Segen. */
function renderRitualTab() {
    const data = state.tree;
    const meditation = data.meditation || {};
    const ritual = data.ritual || {};

    $('med-points').textContent = number(data.meditationPoints);
    $('med-points-2').textContent = number(data.meditationPoints);

    const medButton = $('btn-meditate');
    const medInfo = $('meditation-state');

    if (!meditation.enabled) {
        medInfo.textContent = 'Meditation ist auf diesem Server deaktiviert.';
        medButton.disabled = true;
    } else if (!data.atRitual) {
        medInfo.textContent = 'Nur an einem Ritualpunkt moeglich.';
        medButton.disabled = true;
    } else if (meditation.left > 0) {
        medInfo.textContent = `Noch ${Math.ceil(meditation.left / 60)} Minuten Ruhe noetig.`;
        medButton.disabled = true;
    } else {
        const points = meditation.points || {};
        medInfo.textContent = `${meditation.duration} Sekunden, ergibt `
            + `${points.min}-${points.max} Punkte.`;
        medButton.disabled = false;
    }

    const ritButton = $('btn-ritual');
    const ritInfo = $('ritual-state');
    $('ritual-reward').textContent = number(ritual.reward) + ' $';

    if (!ritual.enabled) {
        ritInfo.textContent = 'Rituale sind auf diesem Server deaktiviert.';
        ritButton.disabled = true;
    } else if (!data.atRitual) {
        ritInfo.textContent = 'Nur an einem Ritualpunkt moeglich.';
        ritButton.disabled = true;
    } else if (ritual.left > 0) {
        ritInfo.textContent = `Der Ort erholt sich noch ${Math.ceil(ritual.left / 60)} Minuten.`;
        ritButton.disabled = true;
    } else {
        ritInfo.textContent = `${ritual.duration} Sekunden`
            + (ritual.cost > 0 ? `, Einsatz ${ritual.cost} Meditationspunkte.` : '.');
        ritButton.disabled = false;
    }

    const grid = $('blessing-grid');
    grid.innerHTML = '';

    liste(data.blessings).forEach((blessing) => {
        const card = document.createElement('div');
        card.className = 'blessing';
        card.innerHTML = `
            <div class="head">
                <span class="icon"></span>
                <span class="title"></span>
                <span class="cost"></span>
            </div>
            <div class="desc"></div>
            <button class="btn primary">Wirken</button>`;

        card.querySelector('.icon').textContent = blessing.icon || '✦';
        card.querySelector('.title').textContent = blessing.label;
        card.querySelector('.cost').textContent = `${blessing.cost} P`;
        card.querySelector('.desc').textContent = blessing.description;

        const button = card.querySelector('button');
        button.disabled = !data.atRitual || !blessing.affordable;
        button.onclick = () => post('mysticBlessing', { id: blessing.id });

        grid.appendChild(card);
    });
}

/** Rezept fuer den Klassenstein. */
function renderRecipe() {
    const data = state.tree;
    const recipe = data.recipe || { ingredients: [], result: 1, craftable: 0 };
    const list = $('recipe');
    list.innerHTML = '';

    liste(recipe.ingredients).forEach((ingredient) => {
        const row = document.createElement('div');
        row.className = 'recipe-row ' + (ingredient.have >= ingredient.need ? 'ok' : 'miss');
        row.innerHTML = '<span></span><span></span>';
        row.children[0].textContent = `${ingredient.need}x ${ingredient.label}`;
        row.children[1].textContent = `${number(ingredient.have)} vorhanden`;
        list.appendChild(row);
    });

    $('recipe-result').textContent = data.race
        ? `ergibt ${recipe.result}x ${data.stone.label}`
        : 'Erst nach der Erweckung verfuegbar.';

    const amount = $('craft-amount');
    amount.max = Math.max(1, recipe.craftable || 1);

    const blocked = !data.atRitual || !data.race || (recipe.craftable || 0) < 1;
    $('btn-craft').disabled = blocked;
    $('btn-craft-2').disabled = blocked;
}

function craft() {
    const value = parseInt($('craft-amount').value, 10);
    post('mysticCraft', { times: Number.isInteger(value) && value > 0 ? value : 1 });
}

$('btn-meditate').onclick = () => post('mysticMeditate');
$('btn-ritual').onclick = () => post('mysticRitual');
$('btn-craft').onclick = craft;
$('btn-craft-2').onclick = () => {
    document.querySelector('.tab[data-tab="stones"]').click();
    craft();
};


/* ------------------------------------------------------------- Haendler */

const merchant = { price: 1000, maximum: 20, stones: [] };

function renderMerchant() {
    const list = $('merchant-list');
    list.innerHTML = '';

    merchant.stones.forEach((stone) => {
        const row = document.createElement('div');
        row.className = 'merchant-row';
        row.innerHTML = `
            <div class="info">
                <div class="label"></div>
                <div class="desc"></div>
            </div>
            <div class="owned"></div>
            <input type="number" min="1" value="1">
            <div class="price"></div>
            <button class="btn primary">Kaufen</button>`;

        row.querySelector('.label').textContent = stone.label;
        row.querySelector('.desc').textContent = stone.description || '';
        row.querySelector('.owned').textContent = `${number(stone.count)} dabei`;
        row.querySelector('.price').textContent = `${number(merchant.price)} $`;

        const input = row.querySelector('input');
        input.max = merchant.maximum;

        row.querySelector('button').onclick = () => {
            const value = parseInt(input.value, 10);
            post('mysticBuyStone', {
                item: stone.name,
                amount: Math.min(merchant.maximum, Number.isInteger(value) && value > 0 ? value : 1),
            });
        };

        list.appendChild(row);
    });
}

function closeMerchant() {
    $('merchant').classList.add('hidden');
    post('mysticMerchantClose');
}

$('btn-merchant-close').onclick = closeMerchant;

/* --------------------------------------------------------------- Anzeige */

function renderTreeScreen() {
    const data = state.tree;

    if (data.raceColor) setClassColor(data.raceColor);

    $('crest').textContent = data.raceIcon || '✦';
    $('class-name').textContent = data.raceLabel || 'Nicht erweckt';
    $('class-desc').textContent = data.raceDescription || 'Waehle deine Klasse an einem Ritualpunkt.';

    $('level-caption').textContent = data.raceLabel ? `${data.raceLabel} Stufe` : 'Stufe';
    $('level-value').textContent = data.level || 0;
    $('ranks-current').textContent = number(data.level);
    $('ranks-max').textContent = number(data.maxRanks);
    $('ranks-fill').style.width = data.maxRanks > 0
        ? Math.min(100, (data.level / data.maxRanks) * 100) + '%'
        : '0%';

    $('stone-caption').textContent = (data.stone && data.stone.label) || 'Steine';
    $('stone-count').textContent = number(data.stone && data.stone.count);
    $('stone-count-2').textContent = number(data.stone && data.stone.count);


    // Erfahrung gehoert allein zum persoenlichen Baum - renderPersonal()
    // weiter unten zeichnet sie. Hier standen dieselben vier Zuweisungen
    // noch einmal, aber auf die alten Element-Namen von vor dem Umbau. Die
    // gibt es nicht mehr: $('personal-level') war null, und die Zuweisung
    // darauf hat renderTreeScreen mitten drin abgebrochen. Alles danach -
    // Klassen, Baum, Detail, Leiste, Steine, Rituale - lief nie, und die
    // letzte Zeile der Funktion macht den Bildschirm sichtbar. Der Skilltree
    // ging also ueberhaupt nicht auf.
    $('xp-balance-2').textContent = number(data.skillPoints);

    renderClasses();
    renderTree();
    renderDetail();
    renderBarEditor();
    renderStones();
    renderRitualTab();
    renderPersonal();

    $('tree-screen').classList.remove('hidden');
}

function closeTree() {
    $('tree-screen').classList.add('hidden');
    post('mysticClose');
}

$('btn-close').onclick = closeTree;

document.addEventListener('keyup', (event) => {
    if (event.key !== 'Escape') return;

    if (!$('merchant').classList.contains('hidden')) {
        closeMerchant();
    } else if (!$('tree-screen').classList.contains('hidden')) {
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
            if (state.selected && !liste(data.nodes).some((node) => node.id === state.selected)) {
                state.selected = null;
            }
            renderTreeScreen();
            break;

        case 'mysticTreeClose':
            $('tree-screen').classList.add('hidden');
            break;

        case 'mysticMerchant':
            merchant.price = data.price;
            merchant.maximum = data.maximum;
            merchant.stones = data.stones || [];
            $('merchant-money').textContent = number(data.money) + ' $';
            $('merchant-hint').textContent = data.recipe
                ? `${data.recipe.runenstein}x Runenstein + ${data.recipe.seelenstein}x `
                  + 'Seelenstein ergeben am Ritualpunkt einen Klassenstein.'
                : '';
            renderMerchant();
            $('merchant').classList.remove('hidden');
            break;

        case 'mysticMerchantUpdate':
            $('merchant-money').textContent = number(data.money) + ' $';
            merchant.stones.forEach((stone) => {
                if (data.stones[stone.name] !== undefined) stone.count = data.stones[stone.name];
            });
            renderMerchant();
            break;

        case 'mysticMerchantClose':
            $('merchant').classList.add('hidden');
            break;
    }
});
