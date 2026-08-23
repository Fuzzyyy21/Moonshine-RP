/* Moonshine RP - NUI Logik */

const RESOURCE = 'moonshine-core';

const state = {
    characters: [],
    maxCharacters: 3,
    allowDeletion: true,
    inventory: { items: [], weight: 0, maxWeight: 40000, maxSlots: 40 },
    selectedSlot: null,
    inventoryOpen: false,
    charSelectOpen: false,
};

const $ = (id) => document.getElementById(id);

/** Eine Liste vom Server, verlaesslich als Feld.
 *
 * Lua kennt keinen Unterschied zwischen leerer Liste und leerer Tabelle -
 * beides kommt hier als {} an, nicht als []. Der uebliche Schutz
 * "x || []" greift dagegen nicht, weil {} wahr ist; das naechste forEach
 * wirft dann. Auf einem frischen Server ist genau das der Normalfall:
 * keine Auktionen, keine Auftraege, und beim allerersten Spieler nicht
 * einmal ein Charakter.
 */
const liste = (wert) => (Array.isArray(wert) ? wert : []);


/** Ruft einen NUI-Callback der Resource auf. */
function post(name, data = {}) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
}

const formatMoney = (value) => new Intl.NumberFormat('de-DE').format(Math.floor(value || 0));
const formatKg = (grams) => (grams / 1000).toFixed(1);

/* -------------------------------------------------------- Charakterwahl */

function renderCharacters() {
    const list = $('character-list');
    list.innerHTML = '';

    liste(state.characters).forEach((character) => {
        const card = document.createElement('div');
        card.className = 'character-card';
        card.innerHTML = `
            <h3></h3>
            <div class="meta"></div>
            <div class="job"></div>
            <div class="money"></div>
            <div class="card-actions"></div>`;

        card.querySelector('h3').textContent = `${character.firstname} ${character.lastname}`;
        card.querySelector('.meta').textContent = `Geboren am ${character.dob} · Slot ${character.slot}`;
        card.querySelector('.job').textContent = `${character.job} (${character.jobGrade})`;
        card.querySelector('.money').textContent =
            `Bar ${formatMoney(character.cash)} $ · Bank ${formatMoney(character.bank)} $`;

        const actions = card.querySelector('.card-actions');

        const play = document.createElement('button');
        play.className = 'btn primary';
        play.textContent = 'Spielen';
        play.onclick = () => post('selectCharacter', { id: character.id });
        actions.appendChild(play);

        if (state.allowDeletion) {
            const remove = document.createElement('button');
            remove.className = 'btn danger';
            remove.textContent = 'Löschen';
            remove.onclick = () => {
                if (remove.dataset.confirm === '1') {
                    post('deleteCharacter', { id: character.id });
                    return;
                }
                remove.dataset.confirm = '1';
                remove.textContent = 'Sicher?';
                setTimeout(() => {
                    remove.dataset.confirm = '0';
                    remove.textContent = 'Löschen';
                }, 4000);
            };
            actions.appendChild(remove);
        }

        list.appendChild(card);
    });

    if (state.characters.length < state.maxCharacters) {
        const empty = document.createElement('div');
        empty.className = 'character-card empty';
        empty.innerHTML = '<span>+</span><div>Neuen Charakter erstellen</div>';
        empty.onclick = () => showCreateForm(true);
        list.appendChild(empty);
    }
}

function showCreateForm(visible) {
    $('create-form').classList.toggle('hidden', !visible);
    if (visible) $('input-firstname').focus();
}

function showCharacterError(message) {
    const box = $('char-error');
    box.textContent = message;
    box.classList.remove('hidden');
    setTimeout(() => box.classList.add('hidden'), 6000);
}

$('btn-cancel-create').onclick = () => showCreateForm(false);

$('btn-submit-create').onclick = () => {
    const payload = {
        firstname: $('input-firstname').value.trim(),
        lastname: $('input-lastname').value.trim(),
        dob: $('input-dob').value.trim(),
        gender: $('input-gender').value,
    };

    if (!payload.firstname || !payload.lastname) {
        showCharacterError('Bitte Vor- und Nachnamen ausfüllen.');
        return;
    }
    if (!/^\d{2}\.\d{2}\.\d{4}$/.test(payload.dob)) {
        showCharacterError('Geburtsdatum im Format TT.MM.JJJJ angeben.');
        return;
    }

    post('createCharacter', payload);
};

/* ---------------------------------------------------------------- Inventar */

function renderInventory() {
    const container = $('slots');
    const { items, weight, maxWeight, maxSlots } = state.inventory;

    container.innerHTML = '';
    const bySlot = new Map(items.map((item) => [item.slot, item]));

    for (let slot = 1; slot <= maxSlots; slot++) {
        const item = bySlot.get(slot);
        const element = document.createElement('div');
        element.className = 'slot ' + (item ? 'filled' : 'empty');
        element.dataset.slot = String(slot);

        if (item) {
            element.draggable = true;
            element.title = item.description || item.label;
            element.innerHTML = `
                <span class="count"></span>
                <span class="label"></span>
                <span class="weight"></span>`;
            element.querySelector('.count').textContent = item.count > 1 ? item.count : '';
            element.querySelector('.label').textContent = item.label;
            element.querySelector('.weight').textContent = formatKg(item.weight) + ' kg';

            if (state.selectedSlot === slot) element.classList.add('selected');

            element.onclick = () => {
                state.selectedSlot = state.selectedSlot === slot ? null : slot;
                renderInventory();
            };
            element.ondblclick = () => {
                if (item.usable) post('useItem', { slot });
            };
            element.ondragstart = (event) => {
                event.dataTransfer.setData('text/plain', String(slot));
            };
        }

        element.ondragover = (event) => {
            event.preventDefault();
            element.classList.add('dragover');
        };
        element.ondragleave = () => element.classList.remove('dragover');
        element.ondrop = (event) => {
            event.preventDefault();
            element.classList.remove('dragover');

            const fromSlot = parseInt(event.dataTransfer.getData('text/plain'), 10);
            if (Number.isInteger(fromSlot) && fromSlot !== slot) {
                post('moveItem', { fromSlot, toSlot: slot });
            }
        };

        container.appendChild(element);
    }

    $('weight-text').textContent = `${formatKg(weight)} / ${formatKg(maxWeight)} kg`;
    $('bar-weight').style.width = Math.min(100, (weight / maxWeight) * 100) + '%';
}

function selectedItem() {
    return liste(state.inventory.items).find((item) => item.slot === state.selectedSlot) || null;
}

function actionCount() {
    const value = parseInt($('action-count').value, 10);
    return Number.isInteger(value) && value > 0 ? value : 1;
}

$('btn-use').onclick = () => {
    const item = selectedItem();
    if (item && item.usable) post('useItem', { slot: item.slot });
};

$('btn-drop').onclick = () => {
    const item = selectedItem();
    if (item) post('dropItem', { slot: item.slot, count: Math.min(actionCount(), item.count) });
};

$('btn-give').onclick = () => {
    const item = selectedItem();
    if (item) post('giveItem', { slot: item.slot, count: Math.min(actionCount(), item.count) });
};

$('btn-close-inventory').onclick = () => closeInventory();

function closeInventory() {
    state.inventoryOpen = false;
    state.selectedSlot = null;
    $('inventory').classList.add('hidden');
    post('closeInventory');
}

/* ---------------------------------------------------- Benachrichtigungen */

function notify({ message, type = 'info', duration = 5000 }) {
    const element = document.createElement('div');
    element.className = `notification ${type}`;
    element.textContent = message;
    $('notifications').appendChild(element);

    setTimeout(() => {
        element.classList.add('leaving');
        setTimeout(() => element.remove(), 250);
    }, duration);
}

/* ------------------------------------------------------------- Nachrichten */

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};

    switch (action) {
        case 'notify':
            notify(data);
            break;

        case 'showCharSelect':
            state.charSelectOpen = !!data;
            $('charselect').classList.toggle('hidden', !data);
            if (!data) showCreateForm(false);
            break;

        case 'setCharacters':
            state.characters = data.characters || [];
            state.maxCharacters = data.maxCharacters || 3;
            state.allowDeletion = data.allowDeletion !== false;
            if (data.serverName) $('server-name').textContent = data.serverName;
            renderCharacters();
            showCreateForm(state.characters.length === 0);
            break;

        case 'characterError':
            showCharacterError(data);
            break;

        case 'showInventory':
            state.inventoryOpen = !!data;
            state.selectedSlot = null;
            $('inventory').classList.toggle('hidden', !data);
            break;

        case 'setInventory':
            state.inventory = data;
            renderInventory();
            break;
    }
});

document.addEventListener('keyup', (event) => {
    if (event.key !== 'Escape') return;
    if (state.inventoryOpen) closeInventory();
});
