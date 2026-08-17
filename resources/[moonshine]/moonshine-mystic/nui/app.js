/* Moonshine Mystik - NUI Logik */

const RESOURCE = 'moonshine-mystic';
const $ = (id) => document.getElementById(id);

const state = {
    bar: { slots: [], visible: false },
    ritual: null,
    selectedSkill: null,
    cooldowns: {},       // { skillId: verbleibende Sekunden }
};

function post(name, data = {}) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
}

/* ------------------------------------------------------------ Skillleiste */

function renderBar() {
    const data = state.bar;
    $('skillbar').classList.toggle('hidden', !data.visible);
    if (!data.visible) return;

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
            <span class="cost"></span>`;

        element.querySelector('.key').textContent = slot.key || slot.slot;
        element.querySelector('.icon').textContent = slot.icon || '·';
        element.querySelector('.name').textContent = slot.label || '';
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

/** Zaehlt die Abklingzeiten lokal herunter. */
setInterval(() => {
    let changed = false;

    Object.keys(state.cooldowns).forEach((id) => {
        state.cooldowns[id] -= 1;
        changed = true;
        if (state.cooldowns[id] <= 0) delete state.cooldowns[id];
    });

    if (changed && state.bar.visible) renderBar();
}, 1000);

/* ----------------------------------------------------------------- Tabs */

document.querySelectorAll('.tab').forEach((tab) => {
    tab.onclick = () => {
        document.querySelectorAll('.tab').forEach((other) => other.classList.remove('active'));
        tab.classList.add('active');

        ['tree', 'perks', 'bar', 'stones', 'races'].forEach((name) => {
            $('panel-' + name).classList.toggle('hidden', name !== tab.dataset.tab);
        });
    };
});

/* ------------------------------------------------------------- Skilltree */

function renderTree() {
    const data = state.ritual;
    const container = $('tree');
    container.innerHTML = '';

    if (!data.race) {
        container.innerHTML = '<div class="detail-empty">Du bist noch nicht erweckt. '
            + 'Waehle im Reiter "Erweckung" deinen Pfad.</div>';
        return;
    }

    const tiers = [1, 2, 3, 4];
    tiers.forEach((tier) => {
        const skills = data.skills.filter((skill) => skill.tier === tier);
        if (skills.length === 0) return;

        const column = document.createElement('div');
        column.className = 'tier';

        const title = document.createElement('div');
        title.className = 'tier-title';
        title.textContent = 'Stufe ' + tier;
        column.appendChild(title);

        skills.forEach((skill) => {
            const node = document.createElement('div');
            node.className = 'node';
            if (skill.unlocked) node.classList.add('unlocked');
            else if (!skill.available) node.classList.add('locked');
            if (state.selectedSkill === skill.id) node.classList.add('selected');

            node.innerHTML = `
                <div class="head">
                    <span class="icon"></span>
                    <span class="title"></span>
                </div>
                <div class="meta"></div>
                <div class="state"></div>`;

            node.querySelector('.icon').textContent = skill.icon || '✦';
            node.querySelector('.title').textContent = skill.label;
            node.querySelector('.meta').textContent = skill.passive
                ? 'Passiv'
                : `${skill.cost} Essenz · ${skill.cooldown}s`;

            const status = node.querySelector('.state');
            if (skill.unlocked) {
                status.textContent = 'Freigeschaltet';
                status.classList.add('ok');
            } else if (!skill.available) {
                status.textContent = 'Voraussetzung fehlt';
                status.classList.add('blocked');
            } else if (skill.affordable) {
                status.textContent = 'Bereit zum Einloesen';
                status.classList.add('open');
            } else {
                status.textContent = 'Kosten fehlen';
                status.classList.add('blocked');
            }

            node.onclick = () => {
                state.selectedSkill = skill.id;
                renderTree();
                renderDetail();
            };

            column.appendChild(node);
        });

        container.appendChild(column);
    });
}

function renderDetail() {
    const data = state.ritual;
    const detail = $('detail');
    const skill = data.skills.find((entry) => entry.id === state.selectedSkill);

    if (!skill) {
        detail.innerHTML = '<div class="detail-empty">Waehle einen Skill aus dem Baum.</div>';
        return;
    }

    detail.innerHTML = `
        <h3></h3>
        <p class="desc"></p>
        <div class="stats"></div>
        <div class="cost-list"></div>
        <div class="actions"></div>
        <div class="slot-buttons"></div>`;

    detail.querySelector('h3').textContent = `${skill.icon || '✦'}  ${skill.label}`;
    detail.querySelector('.desc').textContent = skill.description;

    const stats = detail.querySelector('.stats');
    const rows = [['Stufe', String(skill.tier)], ['Art', skill.passive ? 'Passiv' : 'Aktiv']];
    if (!skill.passive) {
        rows.push(['Essenzkosten', String(skill.cost)]);
        rows.push(['Abklingzeit', skill.cooldown + ' s']);
    }
    rows.push(['Skillpunkte', String(skill.points)]);

    rows.forEach(([label, value]) => {
        const row = document.createElement('div');
        row.className = 'stat-row';
        row.innerHTML = '<span></span><span></span>';
        row.children[0].textContent = label;
        row.children[1].textContent = value;
        stats.appendChild(row);
    });

    const costList = detail.querySelector('.cost-list');
    skill.stones.forEach((stone) => {
        const item = document.createElement('div');
        item.className = 'cost-item ' + (stone.have >= stone.count ? 'ok' : 'miss');
        item.innerHTML = '<span></span><span></span>';
        item.children[0].textContent = stone.label;
        item.children[1].textContent = `${stone.have} / ${stone.count}`;
        costList.appendChild(item);
    });

    const actions = detail.querySelector('.actions');
    if (!skill.unlocked) {
        const button = document.createElement('button');
        button.className = 'btn primary';
        button.textContent = 'Einloesen';
        button.disabled = !data.atRitual || !skill.available || !skill.affordable;
        button.onclick = () => post('mysticUnlock', { id: skill.id });
        actions.appendChild(button);

        if (!data.atRitual) {
            const hint = document.createElement('p');
            hint.className = 'muted';
            hint.style.marginTop = '8px';
            hint.textContent = 'Einloesen ist nur an einem Ritualpunkt moeglich.';
            actions.appendChild(hint);
        }
    } else if (!skill.passive) {
        const buttons = detail.querySelector('.slot-buttons');
        const title = document.createElement('p');
        title.className = 'muted';
        title.style.width = '100%';
        title.textContent = 'Auf Slot legen:';
        buttons.appendChild(title);

        data.bar.forEach((slot) => {
            const button = document.createElement('button');
            button.className = 'btn' + (slot.id === skill.id ? ' primary' : '');
            button.textContent = slot.slot;
            button.onclick = () => post('mysticSetSlot', { slot: slot.slot, id: skill.id });
            buttons.appendChild(button);
        });
    }
}

/* ----------------------------------------------------------------- Perks */

function renderPerks() {
    const data = state.ritual;
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

$('btn-reset-perks').onclick = () => post('mysticResetPerks');

/* ------------------------------------------------------------ Leiste/Steine */

function renderBarEditor() {
    const data = state.ritual;
    const container = $('bar-edit-slots');
    container.innerHTML = '';

    const active = data.skills.filter((skill) => skill.unlocked && !skill.passive);

    data.bar.forEach((slot) => {
        const row = document.createElement('div');
        row.className = 'bar-edit-row';
        row.innerHTML = '<span class="slot-key"></span><select></select>';
        row.querySelector('.slot-key').textContent = `Slot ${slot.slot} · ${slot.key}`;

        const select = row.querySelector('select');
        const empty = document.createElement('option');
        empty.value = '';
        empty.textContent = '— leer —';
        select.appendChild(empty);

        active.forEach((skill) => {
            const option = document.createElement('option');
            option.value = skill.id;
            option.textContent = `${skill.icon || ''} ${skill.label}`;
            if (slot.id === skill.id) option.selected = true;
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
    const data = state.ritual;
    const grid = $('stone-grid');
    grid.innerHTML = '';

    data.stones.forEach((stone) => {
        const element = document.createElement('div');
        element.className = 'stone';
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
}

$('btn-meditate').onclick = () => post('mysticMeditate');

/* ---------------------------------------------------------------- Rassen */

function renderRaces() {
    const data = state.ritual;
    const grid = $('race-grid');
    grid.innerHTML = '';

    data.races.forEach((race) => {
        const card = document.createElement('div');
        card.className = 'race-card' + (data.race === race.name ? ' current' : '');
        card.style.borderLeftColor = race.color;
        card.innerHTML = `
            <div class="head"><span class="icon"></span><h3></h3></div>
            <div class="desc"></div>
            <ul></ul>
            <button class="btn primary"></button>`;

        card.querySelector('.icon').textContent = race.icon;
        card.querySelector('h3').textContent = race.label;
        card.querySelector('.desc').textContent = race.description;

        const list = card.querySelector('ul');
        (race.traits || []).forEach((trait) => {
            const item = document.createElement('li');
            item.textContent = trait;
            list.appendChild(item);
        });

        const essence = document.createElement('li');
        essence.textContent = 'Ressource: ' + race.essence;
        list.appendChild(essence);

        const button = card.querySelector('button');
        if (data.race === race.name) {
            button.textContent = 'Aktuelle Rasse';
            button.disabled = true;
        } else if (data.race && !data.canChangeRace) {
            button.textContent = 'Wechsel gesperrt';
            button.disabled = true;
        } else {
            button.textContent = data.race ? 'Wechseln' : 'Erwecken';
            button.disabled = !data.atRitual;
            button.onclick = () => post('mysticAwaken', { race: race.name });
        }

        grid.appendChild(card);
    });
}

/* ------------------------------------------------------------------ Ritual */

function renderRitual() {
    const data = state.ritual;

    $('race-icon').textContent = data.raceIcon || '✦';
    $('race-name').textContent = data.raceLabel || 'Nicht erweckt';
    $('race-sub').textContent = data.race
        ? `${data.essenceLabel} · ${data.atRitual ? 'am Ritualpunkt' : 'Uebersicht'}`
        : 'Waehle deinen Pfad im Reiter Erweckung';
    $('skill-points').textContent = data.skillPoints;
    $('personal-points').textContent = data.personalPoints;

    renderTree();
    renderDetail();
    renderPerks();
    renderBarEditor();
    renderStones();
    renderRaces();

    $('ritual').classList.remove('hidden');
}

function closeRitual() {
    $('ritual').classList.add('hidden');
    post('mysticClose');
}

$('btn-close').onclick = closeRitual;

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !$('ritual').classList.contains('hidden')) {
        closeRitual();
    }
});

/* ------------------------------------------------------------- Nachrichten */

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
            break;

        case 'mysticRitual':
            state.ritual = data;
            if (state.selectedSkill && !data.skills.some((s) => s.id === state.selectedSkill)) {
                state.selectedSkill = null;
            }
            renderRitual();
            break;

        case 'mysticRitualClose':
            $('ritual').classList.add('hidden');
            break;
    }
});
