/* Moonshine Dienste - Bank, Tankstelle, Werkstatt, Schwarzmarkt. */

const RESOURCE = 'moonshine-services';

let mode = 'bank';
let data = null;

const $ = (id) => document.getElementById(id);

function post(name, payload) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {}),
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

/** Baut eine Statistik-Kachel im Kopf. */
function stat(caption, value, className) {
    const box = el('div', 'stat');
    box.appendChild(el('span', 'stat-caption', caption));
    box.appendChild(el('span', `stat-value${className ? ' ' + className : ''}`, value));
    return box;
}

/** Schnellwahl-Knöpfe unter einem Eingabefeld. */
function quickRow(container, values, input, max) {
    clear(container);

    values.forEach((value) => {
        const chip = el('div', 'quick', value === 'max' ? 'Alles' : money(value));

        chip.addEventListener('click', () => {
            input.value = String(value === 'max' ? Math.floor(max) : value);
            input.dispatchEvent(new Event('input'));
        });

        container.appendChild(chip);
    });
}

/* -------------------------------------------------------------------- Bank */

function renderBank() {
    $('crest').textContent = data.kind === 'atm' ? '💳' : '🏦';
    $('title').textContent = data.kind === 'atm' ? 'Geldautomat' : 'Bank';
    $('subtitle').textContent = data.name || '';

    const head = $('head-stats');
    clear(head);
    head.appendChild(stat('Konto', money(data.bank)));
    head.appendChild(stat('Bargeld', money(data.cash)));

    $('withdraw-hint').textContent = data.maxWithdraw
        ? `Am Automaten höchstens ${money(data.maxWithdraw)} auf einmal.`
        : 'Vom Konto in bar.';

    quickRow($('deposit-quick'), [1000, 10000, 'max'], $('deposit-amount'), data.cash);

    const limit = data.maxWithdraw
        ? Math.min(data.bank, data.maxWithdraw)
        : data.bank;
    quickRow($('withdraw-quick'), [1000, 10000, 'max'], $('withdraw-amount'), limit);

    $('btn-deposit').disabled = !data.deposit;
    $('transfer-card').classList.toggle('hidden', !data.transfer);

    if (data.transfer) {
        $('transfer-hint').textContent =
            `Die Bank behält ${(data.fee * 100).toFixed(1)} % als Gebühr ein.`;
        updateTransferFee();
    }

    $('foot-hint').textContent = data.interest > 0
        ? `Auf dein Guthaben gibt es regelmäßig ${(data.interest * 100).toFixed(1)} % Zinsen.`
        : '';
}

function updateTransferFee() {
    if (!data || !data.transfer) return;

    const amount = Number($('transfer-amount').value) || 0;
    const fee = Math.floor(amount * data.fee);

    $('transfer-fee').textContent = amount > 0
        ? `Vom Konto gehen ${money(amount + fee)} ab — ${money(amount)} kommen an, `
          + `${money(fee)} behält die Bank.`
        : 'Betrag eingeben, um die Gebühr zu sehen.';
}

$('transfer-amount').addEventListener('input', updateTransferFee);

$('btn-deposit').addEventListener('click', () => {
    post('deposit', { amount: Number($('deposit-amount').value) || 0 });
});

$('btn-withdraw').addEventListener('click', () => {
    post('withdraw', { amount: Number($('withdraw-amount').value) || 0 });
});

$('btn-transfer').addEventListener('click', () => {
    post('transfer', {
        target: Number($('transfer-target').value) || 0,
        amount: Number($('transfer-amount').value) || 0,
    });
});

/* ------------------------------------------------------------------ Tanken */

function fuelMax() {
    if (!data) return 1;
    return Math.max(1, Math.floor(100 - data.fuel));
}

function updateFuel() {
    const range = $('fuel-range');
    const amount = Number(range.value) || 0;

    $('fuel-amount').textContent = String(amount);
    $('fuel-price').textContent = money(amount * data.price);

    const affordable = amount * data.price <= data.cash;
    $('btn-refuel').disabled = amount < 1 || !affordable;
    $('btn-refuel').textContent = affordable
        ? 'Tanken'
        : `Dir fehlen ${money(amount * data.price - data.cash)}`;
}

function renderFuel() {
    $('crest').textContent = '⛽';
    $('title').textContent = data.label || 'Tankstelle';
    $('subtitle').textContent = `${data.price} $ je Prozentpunkt`;

    const head = $('head-stats');
    clear(head);
    head.appendChild(stat('Bargeld', money(data.cash)));

    $('fuel-fill').style.width = `${Math.max(0, Math.min(100, data.fuel))}%`;
    $('fuel-value').textContent = String(Math.floor(data.fuel));
    $('fuel-plate').textContent = data.plate || '–';

    const max = fuelMax();
    const range = $('fuel-range');
    range.max = String(max);
    range.value = String(max);

    quickRow($('fuel-quick'),
        [10, 25, 50, 'max'].filter((value) => value === 'max' || value <= max),
        range, max);

    $('canister-hint').textContent =
        `Ein Kanister kostet ${money(data.canister.price)} und füllt etwa `
        + `${data.canister.amount} Prozentpunkte.`;

    $('foot-hint').textContent = 'Der Tank leert sich nur bei laufendem Motor.';

    updateFuel();
}

$('fuel-range').addEventListener('input', () => {
    if (mode === 'fuel') updateFuel();
});

$('btn-refuel').addEventListener('click', () => {
    post('refuel', { plate: data.plate, amount: Number($('fuel-range').value) || 0 });
});

$('btn-canister').addEventListener('click', () => {
    post('buyCanister', { count: Number($('canister-count').value) || 1 });
});

/* --------------------------------------------------------------- Werkstatt */

function renderRepair() {
    $('crest').textContent = '🔧';
    $('title').textContent = data.label || 'Werkstatt';
    $('subtitle').textContent = '';

    const head = $('head-stats');
    clear(head);
    head.appendChild(stat('Konto', money(data.balance)));

    $('engine-bar').style.width = `${data.engine}%`;
    $('engine-value').textContent = `${data.engine} %`;
    $('body-bar').style.width = `${data.body}%`;
    $('body-value').textContent = `${data.body} %`;
    $('repair-plate').textContent = data.plate || '–';

    $('repair-price').textContent = money(data.price);

    $('repair-discount').textContent = data.discount > 0
        ? `Als Mechaniker zahlst du ${Math.round(data.discount * 100)} % weniger.`
        : '';

    const fine = data.engine >= 100 && data.body >= 100;
    const affordable = data.balance >= data.price;

    const button = $('btn-repair');
    button.disabled = fine || !affordable;
    button.textContent = fine
        ? 'Alles in Ordnung'
        : (affordable ? 'Reparieren lassen'
            : `Dir fehlen ${money(data.price - data.balance)}`);

    $('foot-hint').textContent = 'Ein Reparaturkit im Inventar hilft unterwegs, '
        + 'macht aber nicht alles heil.';
}

$('btn-repair').addEventListener('click', () => {
    post('repair', { plate: data.plate, engine: data.engine, body: data.body });
});

/* ------------------------------------------------------------ Schwarzmarkt */

function tradeRow(entry, kind) {
    const row = el('div', 'trade');

    const body = el('div');
    body.appendChild(el('h3', null, entry.label));
    body.appendChild(el('div', 'trade-price',
        `${money(entry.price)} ${kind === 'buy' ? 'je Stück' : 'Schwarzgeld'}`));

    if (kind === 'sell') {
        body.appendChild(el('div', 'have', `${entry.count} im Inventar`));
    }

    row.appendChild(body);

    const count = document.createElement('input');
    count.type = 'number';
    count.min = '1';
    count.value = '1';
    if (kind === 'sell') count.max = String(Math.max(1, entry.count));
    row.appendChild(count);

    const button = el('button', `btn small${kind === 'buy' ? ' primary' : ''}`,
        kind === 'buy' ? 'Kaufen' : 'Verkaufen');

    if (kind === 'sell') button.disabled = entry.count < 1;

    button.addEventListener('click', () => {
        post(kind === 'buy' ? 'marketBuy' : 'marketSell', {
            name: entry.name,
            count: Number(count.value) || 1,
        });
    });

    row.appendChild(button);
    return row;
}

function renderMarket() {
    $('crest').textContent = '🕶';
    $('title').textContent = 'Schwarzmarkt';
    $('subtitle').textContent = data.label || '';

    const head = $('head-stats');
    clear(head);
    head.appendChild(stat('Schwarzgeld', money(data.black), 'black'));
    head.appendChild(stat('Bargeld', money(data.cash)));

    const sells = $('market-sells');
    clear(sells);
    (data.sells || []).forEach((entry) => sells.appendChild(tradeRow(entry, 'buy')));

    const buys = $('market-buys');
    clear(buys);
    (data.buys || []).forEach((entry) => buys.appendChild(tradeRow(entry, 'sell')));

    const laundry = $('laundry-card');
    laundry.classList.toggle('hidden', !data.laundering);

    if (data.laundering) {
        $('laundry-hint').textContent =
            `Aus Schwarzgeld wird Bargeld – ${Math.round(data.laundering.rate * 100)} % `
            + `kommen an, höchstens ${money(data.laundering.maximum)} je Vorgang.`;
        updateLaundry();
    }

    const minutes = Math.ceil((data.movesIn || 0) / 60);
    $('foot-hint').textContent = minutes > 0
        ? `Der Markt zieht in etwa ${minutes} Minuten weiter.`
        : 'Der Markt zieht gleich weiter.';
}

function updateLaundry() {
    if (!data || !data.laundering) return;

    const amount = Number($('laundry-amount').value) || 0;
    const clean = Math.floor(amount * data.laundering.rate);

    $('laundry-result').textContent = amount > 0
        ? `${money(amount)} rein, ${money(clean)} raus — `
          + `${money(amount - clean)} bleiben hier.`
        : 'Betrag eingeben, um die Auszahlung zu sehen.';
}

$('laundry-amount').addEventListener('input', updateLaundry);

$('btn-launder').addEventListener('click', () => {
    post('launder', { amount: Number($('laundry-amount').value) || 0 });
});

/* ----------------------------------------------------------------- Rendern */

const PANELS = ['bank', 'fuel', 'repair', 'market'];

function render() {
    if (!data) return;

    PANELS.forEach((key) => {
        $(`panel-${key}`).classList.toggle('hidden', key !== mode);
    });

    if (mode === 'bank') renderBank();
    else if (mode === 'fuel') renderFuel();
    else if (mode === 'repair') renderRepair();
    else if (mode === 'market') renderMarket();
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
        case 'services:open':
            mode = message.mode || 'bank';
            data = message.data || null;

            $('screen').classList.remove('hidden');
            render();
            break;

        case 'services:data':
            if (message.mode === mode) {
                data = message.data || data;
                render();
            }
            break;

        case 'services:close':
            $('screen').classList.add('hidden');
            break;

        case 'services:fuelProgress':
        case 'services:repairProgress': {
            const value = message.value || 0;
            const box = $('progress');

            if (value <= 0) {
                box.classList.add('hidden');
                break;
            }

            box.classList.remove('hidden');
            $('progress-label').textContent =
                message.action === 'services:fuelProgress'
                    ? 'Wird getankt …'
                    : 'Wird repariert …';
            $('progress-fill').style.width = `${Math.round(value * 100)}%`;
            break;
        }

        default:
            break;
    }
});
