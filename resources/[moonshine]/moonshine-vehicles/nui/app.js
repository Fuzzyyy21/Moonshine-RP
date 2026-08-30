/* Moonshine Fahrzeuge - Garage, Autohaus, Verwahrstelle. */

const RESOURCE = 'moonshine-vehicles';

let mode = 'garage';
let owned = null;
let dealer = null;
let filter = 'garage';
let category = null;
let selected = null;

const $ = (id) => document.getElementById(id);

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
    while (node && node.firstChild) node.removeChild(node.firstChild);
}

function money(amount) {
    return `${Math.floor(amount || 0).toLocaleString('de-DE')} $`;
}

const CATEGORY_ICONS = {
    kompakt: '🚗', limousine: '🚙', suv: '🚐', sport: '🏎',
    muscle: '🔧', gelaende: '🛻', motorrad: '🏍', nutzfahrzeug: '🚚',
};

function iconFor(category) {
    return CATEGORY_ICONS[category] || '🚗';
}

const STATE_LABELS = {
    garage: 'Eingeparkt',
    draussen: 'Unterwegs',
    verwahrt: 'Verwahrt',
};

/* ------------------------------------------------------------------ Garage */

document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
        filter = tab.dataset.filter;

        document.querySelectorAll('.tab').forEach((other) => {
            other.classList.toggle('active', other === tab);
        });

        renderGarage();
    });
});

/** Eine Balkenzeile. */
function barRow(label, value, className) {
    const row = el('div', 'bar-row');
    row.appendChild(el('span', 'label', label));

    const bar = el('div', 'bar');
    const fill = el('i', className);
    fill.style.width = `${Math.max(0, Math.min(100, value))}%`;
    bar.appendChild(fill);
    row.appendChild(bar);

    row.appendChild(el('span', 'value', `${Math.round(value)}%`));
    return row;
}

function vehicleRow(vehicle) {
    const row = el('div', `vehicle ${vehicle.state}`);

    row.appendChild(el('div', 'vehicle-icon', iconFor(vehicle.category)));

    const body = el('div');
    const title = el('div', 'vehicle-title');
    title.appendChild(el('span', null, vehicle.label));
    title.appendChild(el('span', 'plate', vehicle.plate));
    title.appendChild(el('span', `state-tag ${vehicle.state}`,
        STATE_LABELS[vehicle.state] || vehicle.state));
    body.appendChild(title);

    const parts = [vehicle.categoryLabel];
    if (vehicle.garageLabel) parts.push(vehicle.garageLabel);
    if (vehicle.keyCount > 0) parts.push(`${vehicle.keyCount} Zweitschluessel`);
    body.appendChild(el('div', 'vehicle-sub', parts.join(' · ')));

    row.appendChild(body);

    const bars = el('div', 'bars');
    bars.appendChild(barRow('Tank', vehicle.fuel, 'fuel'));
    bars.appendChild(barRow('Motor', vehicle.engine, 'engine'));
    bars.appendChild(barRow('Karosse', vehicle.body, 'body'));
    row.appendChild(bars);

    const actions = el('div', 'vehicle-actions');

    if (vehicle.state === 'garage') {
        const take = el('button', 'btn small primary', 'Ausparken');
        take.addEventListener('click', () => post('take', { id: vehicle.id }));
        actions.appendChild(take);

        if (vehicle.isOwner) {
            const keyRow = el('div', 'action-row');

            const target = document.createElement('input');
            target.type = 'number';
            target.placeholder = 'ID';
            keyRow.appendChild(target);

            const key = el('button', 'btn small', 'Schluessel');
            key.title = 'Zweitschluessel an eine Server-ID geben';
            key.addEventListener('click', () => {
                post('giveKey', { id: vehicle.id, target: Number(target.value) || 0 });
            });
            keyRow.appendChild(key);

            actions.appendChild(keyRow);

            const more = el('div', 'action-row');

            const sell = el('button', 'btn small danger', `Verkaufen ${money(vehicle.resale)}`);
            sell.addEventListener('click', () => post('sell', { id: vehicle.id }));
            more.appendChild(sell);

            if (vehicle.keyCount > 0) {
                const revoke = el('button', 'btn small', 'Schluessel einziehen');
                revoke.addEventListener('click', () => post('clearKeys', { id: vehicle.id }));
                more.appendChild(revoke);
            }

            actions.appendChild(more);
        }
    } else if (vehicle.state === 'verwahrt') {
        const release = el('button', 'btn small primary',
            `Ausloesen ${money(owned ? owned.impoundFee : 0)}`);
        release.addEventListener('click', () => post('release', { id: vehicle.id }));
        actions.appendChild(release);
        actions.appendChild(el('div', 'muted', 'Nur an der Verwahrstelle.'));
    } else {
        actions.appendChild(el('div', 'muted',
            'Steht draussen. Fahr es zu einer Garage und parke es ein.'));
    }

    row.appendChild(actions);
    return row;
}

function renderGarage() {
    if (!owned) return;

    $('money').textContent = money(owned.money);
    $('slots').textContent = `${owned.vehicles.length} / ${owned.maxVehicles}`;

    const impounded = liste(owned.vehicles).filter((entry) => entry.state === 'verwahrt').length;
    const badge = $('badge-impound');
    badge.textContent = String(impounded);
    badge.classList.toggle('hidden', impounded === 0);

    const list = filter === 'alle'
        ? owned.vehicles
        : liste(owned.vehicles).filter((entry) => entry.state === filter);

    const hint = $('garage-hint');
    if (filter === 'verwahrt') {
        hint.textContent = 'Verwahrte Fahrzeuge holst du an der Verwahrstelle ab. '
            + `Die Ausloesung kostet ${money(owned.impoundFee)}.`;
    } else if (filter === 'draussen') {
        hint.textContent = 'Diese Fahrzeuge stehen irgendwo in der Welt. '
            + 'Beim Ausloggen wandern sie automatisch zurueck in die Garage.';
    } else {
        hint.textContent = 'Ein Fahrzeug parkst du ein, indem du damit an eine '
            + 'Garage faehrst und E drueckst.';
    }

    const box = $('vehicle-list');
    clear(box);

    if (!list.length) {
        box.appendChild(el('div', 'empty', filter === 'garage'
            ? 'Hier steht nichts. Kauf dir etwas beim Autohaus.'
            : 'Keine Fahrzeuge in dieser Ansicht.'));
        return;
    }

    list.forEach((vehicle) => box.appendChild(vehicleRow(vehicle)));
}

/* ---------------------------------------------------------------- Autohaus */

function renderCategories() {
    const box = $('category-list');
    clear(box);

    const counts = {};
    liste(dealer.vehicles).forEach((entry) => {
        counts[entry.category] = (counts[entry.category] || 0) + 1;
    });

    const available = liste(dealer.categories).filter((entry) => counts[entry.id]);

    if (!category || !counts[category]) {
        category = available.length ? available[0].id : null;
    }

    available.forEach((entry) => {
        const row = el('div', `category${category === entry.id ? ' active' : ''}`);
        row.appendChild(el('span', null, entry.icon));
        row.appendChild(el('span', null, entry.label));
        row.appendChild(el('span', 'count', String(counts[entry.id])));

        row.addEventListener('click', () => {
            category = entry.id;
            selected = null;
            renderDealer();
        });

        box.appendChild(row);
    });
}

function renderCatalogue() {
    const box = $('catalogue');
    clear(box);

    const list = liste(dealer.vehicles).filter((entry) => entry.category === category);

    list.forEach((entry) => {
        const card = el('div',
            `car-card${selected && selected.model === entry.model ? ' selected' : ''}`);

        card.appendChild(el('h3', null, entry.label));
        card.appendChild(el('div', 'category-label', entry.categoryLabel));
        card.appendChild(el('div', 'price', money(entry.price)));

        const speed = el('div', 'speed-row');
        for (let index = 1; index <= 5; index += 1) {
            speed.appendChild(el('div', `pip${index <= entry.speed ? ' on' : ''}`));
        }
        card.appendChild(speed);

        card.addEventListener('click', () => {
            selected = entry;
            renderDealer();
        });

        box.appendChild(card);
    });
}

function renderDetail() {
    const box = $('detail');
    clear(box);

    if (!selected) {
        box.appendChild(el('div', 'detail-empty', 'Waehle ein Fahrzeug.'));
        return;
    }

    box.appendChild(el('h2', null, selected.label));
    box.appendChild(el('div', 'muted', selected.categoryLabel));
    box.appendChild(el('div', 'detail-price', money(selected.price)));

    const SPECS = [
        ['Sitzplaetze', String(selected.seats)],
        ['Leistung', `${selected.speed} / 5`],
        ['Modell', selected.model],
    ];

    SPECS.forEach(([label, value]) => {
        const row = el('div', 'spec-row');
        row.appendChild(el('span', null, label));
        row.appendChild(el('span', null, value));
        box.appendChild(row);
    });

    const full = dealer.owned >= dealer.maxOwned;
    const broke = dealer.money < selected.price;

    const button = el('button', 'btn primary', 'Kaufen');
    button.disabled = full || broke;
    button.addEventListener('click', () => post('buy', { model: selected.model }));
    box.appendChild(button);

    if (full) {
        box.appendChild(el('p', 'muted', 'Du hast keinen Fahrzeugplatz mehr frei. '
            + 'Verkauf zuerst etwas in der Garage.'));
    } else if (broke) {
        box.appendChild(el('p', 'muted',
            `Dir fehlen ${money(selected.price - dealer.money)}.`));
    }
}

function renderDealer() {
    if (!dealer) return;

    $('money').textContent = money(dealer.money);
    $('slots').textContent = `${dealer.owned} / ${dealer.maxOwned}`;

    renderCategories();
    renderCatalogue();
    renderDetail();
}

/* ---------------------------------------------------------------- Aktionen */

$('btn-close').addEventListener('click', () => post('close'));

document.addEventListener('keyup', (message) => {
    if (message.key === 'Escape') post('close');
});

/* -------------------------------------------------------------- Nachrichten */

window.addEventListener('message', (message) => {
    const data = message.data || {};

    switch (data.action) {
        case 'vehicles:open':
            mode = data.mode === 'dealer' ? 'dealer' : 'garage';

            $('screen').classList.remove('hidden');
            $('view-garage').classList.toggle('hidden', mode === 'dealer');
            $('view-dealer').classList.toggle('hidden', mode !== 'dealer');

            $('title').textContent = data.label || 'Garage';
            $('crest').textContent = mode === 'dealer' ? '🏷' : '🚗';
            $('subtitle').textContent = mode === 'dealer'
                ? 'Neuwagen und Motorraeder'
                : 'Deine Fahrzeuge';

            $('foot-hint').textContent = mode === 'dealer'
                ? 'Gekaufte Fahrzeuge stehen direkt vor dem Autohaus bereit.'
                : 'Fahrzeuge stehen in der Garage, in der du sie zuletzt abgestellt hast.';
            break;

        case 'vehicles:close':
            $('screen').classList.add('hidden');
            selected = null;
            break;

        case 'vehicles:owned':
            owned = data.data || null;
            if (mode !== 'dealer') renderGarage();
            break;

        case 'vehicles:dealer':
            dealer = data.data || null;
            category = null;
            selected = null;
            renderDealer();
            break;

        default:
            break;
    }
});
