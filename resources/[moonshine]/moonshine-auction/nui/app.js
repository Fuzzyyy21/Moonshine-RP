/* Moonshine Auktionshaus. */

const RESOURCE = 'moonshine-auction';

let state = null;
let mail = [];
let inventory = [];
let activeTab = 'browse';
let category = 'alle';
let selected = null;

/* ------------------------------------------------------------------ Hilfen */

const $ = (id) => document.getElementById(id);

function post(name, data) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

async function ask(name, data) {
    try {
        const response = await fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
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

function remaining(seconds) {
    if (seconds <= 0) return 'endet gleich';

    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (hours > 0) return `noch ${hours} Std. ${minutes} Min.`;
    if (minutes > 0) return `noch ${minutes} Min.`;

    return `noch ${seconds} Sek.`;
}

/** Symbol zu einem Item. */
function iconFor(name) {
    if (name.startsWith('kiste_')) return '📦';

    const ICONS = {
        runenstein: '◆', seelenstein: '◈',
        bread: '🍞', water: '💧', burger: '🍔', cola: '🥤',
        bandage: '🩹', medikit: '🧰', phone: '📱', radio: '📻',
        lockpick: '🗝', repairkit: '🔧', money_roll: '💵',
    };

    return ICONS[name] || '❖';
}

/* -------------------------------------------------------------------- Tabs */

const TABS = ['browse', 'sell', 'own', 'bids', 'mail'];

function activateTab(name) {
    activeTab = name;

    document.querySelectorAll('.tab').forEach((tab) => {
        tab.classList.toggle('active', tab.dataset.tab === name);
    });

    TABS.forEach((key) => {
        $(`panel-${key}`).classList.toggle('hidden', key !== name);
    });

    if (name === 'sell') loadInventory();
}

document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => activateTab(tab.dataset.tab));
});

/* --------------------------------------------------------------- Auktionen */

/** Baut eine Auktionszeile. */
function auctionRow(auction, mode) {
    const soon = auction.remaining <= 300;

    const row = el('div', `auction${auction.isOwn ? ' own' : ''}` +
        `${auction.isBidder ? ' leading' : ''}${soon ? ' ending' : ''}`);

    row.dataset.id = String(auction.id);

    row.appendChild(el('div', 'auction-icon', iconFor(auction.item)));

    const body = el('div');
    const title = el('div', 'auction-title');
    title.appendChild(el('span', null, auction.label));
    title.appendChild(el('span', 'auction-count', `${auction.count}x`));
    if (auction.isBidder) title.appendChild(el('span', 'auction-count', 'Hoechstgebot'));
    body.appendChild(title);

    body.appendChild(el('div', 'auction-sub', auction.bidder
        ? `${auction.seller} · Hoechstbietend: ${auction.bidder}`
        : `${auction.seller} · noch kein Gebot`));
    row.appendChild(body);

    const price = el('div', 'auction-price');
    price.appendChild(el('div', 'price-label', auction.bid > 0 ? 'Aktuelles Gebot' : 'Startpreis'));
    price.appendChild(el('div', 'price-value', money(auction.bid > 0 ? auction.bid : auction.startPrice)));
    if (auction.buyout) {
        price.appendChild(el('div', 'price-buyout', `Sofortkauf ${money(auction.buyout)}`));
    }
    row.appendChild(price);

    const actions = el('div', 'auction-actions');

    const time = el('div', `time${soon ? ' soon' : ''}`, remaining(auction.remaining));
    actions.appendChild(time);

    if (mode === 'own') {
        const cancel = el('button', 'btn small danger', 'Abbrechen');
        cancel.disabled = Boolean(auction.bidder);
        cancel.title = auction.bidder ? 'Es liegt ein Gebot vor.' : '';
        cancel.addEventListener('click', () => post('cancel', { id: auction.id }));
        actions.appendChild(cancel);
    } else if (!auction.isOwn) {
        const bidRow = el('div', 'bid-row');

        const input = document.createElement('input');
        input.type = 'number';
        input.min = String(auction.minimum);
        input.value = String(auction.minimum);
        bidRow.appendChild(input);

        const bid = el('button', 'btn small primary', 'Bieten');
        bid.addEventListener('click', () => {
            post('bid', { id: auction.id, amount: Number(input.value) || auction.minimum });
        });
        bidRow.appendChild(bid);

        actions.appendChild(bidRow);

        if (auction.buyout) {
            const buy = el('button', 'btn small', `Sofort ${money(auction.buyout)}`);
            buy.addEventListener('click', () => post('buyout', { id: auction.id }));
            actions.appendChild(buy);
        }
    } else {
        actions.appendChild(el('div', 'muted', 'Deine Auktion'));
    }

    row.appendChild(actions);
    return row;
}

function renderCategories() {
    const box = $('category-row');
    clear(box);

    (state.categories || []).forEach((entry) => {
        const chip = el('div', `category${category === entry.id ? ' active' : ''}`);
        chip.appendChild(el('span', null, entry.icon));
        chip.appendChild(el('span', null, entry.label));

        chip.addEventListener('click', () => {
            category = entry.id;
            renderCategories();
            renderMarket();
        });

        box.appendChild(chip);
    });
}

function sortAuctions(list) {
    const mode = $('sort').value;
    const copy = list.slice();

    if (mode === 'priceAsc') {
        copy.sort((a, b) => (a.bid || a.startPrice) - (b.bid || b.startPrice));
    } else if (mode === 'priceDesc') {
        copy.sort((a, b) => (b.bid || b.startPrice) - (a.bid || a.startPrice));
    } else if (mode === 'name') {
        copy.sort((a, b) => a.label.localeCompare(b.label));
    } else {
        copy.sort((a, b) => a.remaining - b.remaining);
    }

    return copy;
}

function renderMarket() {
    const box = $('market-list');
    clear(box);

    const needle = $('search').value.trim().toLowerCase();

    let list = state.auctions.filter((auction) => {
        if (category !== 'alle' && auction.category !== category) return false;
        if (!needle) return true;

        return auction.label.toLowerCase().includes(needle)
            || auction.seller.toLowerCase().includes(needle);
    });

    list = sortAuctions(list);

    if (!list.length) {
        box.appendChild(el('div', 'empty', 'Hier wird gerade nichts angeboten.'));
        return;
    }

    list.forEach((auction) => box.appendChild(auctionRow(auction, 'market')));
}

function renderOwn() {
    const box = $('own-list');
    clear(box);

    const list = state.auctions.filter((auction) => auction.isOwn);

    const badge = $('badge-own');
    badge.textContent = String(list.length);
    badge.classList.toggle('hidden', list.length === 0);

    if (!list.length) {
        box.appendChild(el('div', 'empty', 'Du hast nichts eingestellt.'));
        return;
    }

    sortAuctions(list).forEach((auction) => box.appendChild(auctionRow(auction, 'own')));
}

function renderBids() {
    const box = $('bid-list');
    clear(box);

    const list = state.auctions.filter((auction) => auction.isBidder);

    const badge = $('badge-bids');
    badge.textContent = String(list.length);
    badge.classList.toggle('hidden', list.length === 0);

    if (!list.length) {
        box.appendChild(el('div', 'empty', 'Du hast auf nichts das Hoechstgebot.'));
        return;
    }

    sortAuctions(list).forEach((auction) => box.appendChild(auctionRow(auction, 'market')));
}

/* ---------------------------------------------------------------- Verkaufen */

async function loadInventory() {
    const result = await ask('inventory');
    inventory = Array.isArray(result) ? result : [];
    renderInventory();
}

function renderInventory() {
    const box = $('sell-inventory');
    clear(box);

    if (!inventory.length) {
        box.appendChild(el('div', 'empty', 'Dein Inventar ist leer.'));
        return;
    }

    inventory.forEach((entry) => {
        const row = el('div',
            `item-row${selected && selected.slot === entry.slot ? ' active' : ''}`);

        const left = el('div');
        left.appendChild(el('div', null, `${iconFor(entry.name)}  ${entry.label}`));
        left.appendChild(el('div', 'count', `Slot ${entry.slot}`));
        row.appendChild(left);

        row.appendChild(el('span', 'count', `${entry.count}x`));

        row.addEventListener('click', () => {
            selected = entry;
            renderInventory();
            renderSellForm();
        });

        box.appendChild(row);
    });
}

function renderSellForm() {
    const box = $('selected-item');
    clear(box);

    const button = $('btn-sell');

    if (!selected) {
        box.appendChild(el('p', 'muted', 'Waehle links einen Gegenstand.'));
        button.disabled = true;
        return;
    }

    box.appendChild(el('h3', null, `${iconFor(selected.name)}  ${selected.label}`));
    box.appendChild(el('div', 'muted', `${selected.count}x verfuegbar`));

    const count = $('sell-count');
    count.max = String(selected.count);
    if (Number(count.value) > selected.count) count.value = String(selected.count);

    button.disabled = false;
    updateFeeNote();
}

function updateFeeNote() {
    if (!state) return;

    const start = Number($('sell-start').value) || 0;
    const buyout = Number($('sell-buyout').value) || 0;
    const reference = buyout > 0 ? buyout : start;
    const fee = Math.floor(reference * state.fee);

    $('fee-note').textContent =
        `Einstellgebuehr ${money(state.listingFee)} (faellt sofort an). `
        + `Beim Verkauf behaelt das Haus ${Math.round(state.fee * 100)} % - `
        + `bei ${money(reference)} waeren das ${money(fee)}, `
        + `du bekaemst ${money(reference - fee)}.`;
}

['sell-start', 'sell-buyout'].forEach((id) => {
    $(id).addEventListener('input', updateFeeNote);
});

$('btn-sell').addEventListener('click', () => {
    if (!selected) return;

    post('create', {
        slot: selected.slot,
        count: Number($('sell-count').value) || 1,
        startPrice: Number($('sell-start').value) || 0,
        buyout: Number($('sell-buyout').value) || 0,
        hours: Number($('sell-hours').value) || 24,
    });

    selected = null;
    setTimeout(loadInventory, 500);
    renderSellForm();
});

/* --------------------------------------------------------------- Abholfach */

function renderMail() {
    const box = $('mail-list');
    clear(box);

    const badge = $('badge-mail');
    badge.textContent = String(mail.length);
    badge.classList.toggle('hidden', mail.length === 0);

    $('btn-claim-all').disabled = mail.length === 0;

    if (!mail.length) {
        box.appendChild(el('div', 'empty', 'Im Abholfach liegt nichts.'));
        return;
    }

    mail.forEach((entry) => {
        const row = el('div', 'mail');

        row.appendChild(el('div', 'mail-icon',
            entry.kind === 'money' ? '💰' : iconFor(entry.item || '')));

        const body = el('div');
        body.appendChild(el('h3', null, entry.kind === 'money'
            ? money(entry.amount)
            : `${entry.count}x ${entry.label || entry.item}`));
        body.appendChild(el('div', 'muted', entry.reason));
        row.appendChild(body);

        const button = el('button', 'btn small primary', 'Abholen');
        button.addEventListener('click', () => post('claim', { id: entry.id }));
        row.appendChild(button);

        box.appendChild(row);
    });
}

$('btn-claim-all').addEventListener('click', () => post('claimAll'));

/* ----------------------------------------------------------------- Rendern */

function render() {
    if (!state) return;

    $('money').textContent = money(state.money);
    $('count-open').textContent = String(state.auctions.length);
    $('fee').textContent = `${Math.round(state.fee * 100)} %`;

    // Laufzeiten nur einmal fuellen.
    const hours = $('sell-hours');
    if (!hours.options.length) {
        state.durations.forEach((entry) => {
            const option = document.createElement('option');
            option.value = String(entry);
            option.textContent = entry === 1 ? '1 Stunde' : `${entry} Stunden`;
            hours.appendChild(option);
        });
        hours.value = String(state.durations[state.durations.length - 1]);
    }

    $('sell-start').min = String(state.limits.minPrice);

    renderCategories();
    renderMarket();
    renderOwn();
    renderBids();
    renderSellForm();
}

$('search').addEventListener('input', () => renderMarket());
$('sort').addEventListener('change', () => {
    renderMarket();
    renderOwn();
    renderBids();
});

$('btn-close').addEventListener('click', () => post('close'));

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape') post('close');
});

/* -------------------------------------------------------------- Nachrichten */

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'auction:open':
            $('screen').classList.remove('hidden');
            $('house-label').textContent = message.house || 'Auktionshaus';
            activateTab(activeTab);
            break;

        case 'auction:close':
            $('screen').classList.add('hidden');
            break;

        case 'auction:data':
            state = message.data || null;
            render();
            break;

        case 'auction:mail':
            mail = message.data || [];
            renderMail();
            break;

        default:
            break;
    }
});

/* Restzeiten laufen auch ohne neuen Sync weiter. Es wird nur der Text
   aktualisiert - ein Neuaufbau wuerde Eingabefelder leeren. */
setInterval(() => {
    if (!state || $('screen').classList.contains('hidden')) return;

    const byId = {};
    state.auctions.forEach((auction) => {
        if (auction.remaining > 0) auction.remaining -= 1;
        byId[auction.id] = auction;
    });

    document.querySelectorAll('.auction').forEach((row) => {
        const auction = byId[row.dataset.id];
        if (!auction) return;

        const label = row.querySelector('.time');
        if (label) {
            label.textContent = remaining(auction.remaining);
            label.classList.toggle('soon', auction.remaining <= 300);
        }

        row.classList.toggle('ending', auction.remaining <= 300);
    });
}, 1000);
