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

/** Wie post(), aber mit Antwort - die Vorschau bekommt den Preis zurueck. */
async function ask(name, payload) {
    try {
        const antwort = await fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {}),
        });
        return await antwort.json();
    } catch (fehler) {
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
    liste(data.sells).forEach((entry) => sells.appendChild(tradeRow(entry, 'buy')));

    const buys = $('market-buys');
    clear(buys);
    liste(data.buys).forEach((entry) => buys.appendChild(tradeRow(entry, 'sell')));

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

/* ------------------------------------------------------------------ Tuning */

let wunsch = {};           // was angeklickt ist, noch nicht bezahlt
let reiter = 'leistung';

/** Alle Reiter des Tuningmenues. */
function tuningReiter() {
    return [
        { id: 'leistung', label: 'Leistung',  icon: '⚙' },
        { id: 'optik',    label: 'Anbauteile',icon: '🔧' },
        { id: 'lack',     label: 'Lackierung',icon: '🎨' },
        { id: 'licht',    label: 'Licht',     icon: '💡' },
        { id: 'sonstig',  label: 'Sonstiges', icon: '🪟' },
    ];
}

/** Die Stufe, die im Wunsch steht - sonst die verbaute. */
function stufeVon(entry) {
    const key = String(entry.mod);

    if (wunsch.teile && wunsch.teile[entry.id] !== undefined) {
        return wunsch.teile[entry.id];
    }

    const verbaut = (data.mods && data.mods.teile) || {};
    return verbaut[key] !== undefined ? verbaut[key] : -1;
}

/** Meldet den aktuellen Wunsch an den Client und holt den Preis zurueck. */
async function vorschau() {
    const antwort = await ask('tuningPreview', { wunsch });

    $('tuning-preis').textContent = money(antwort && antwort.preis);

    if (antwort && antwort.rabatt > 0) {
        $('tuning-rabatt').textContent =
            `Mechanikerrabatt: ${Math.round(antwort.rabatt * 100)} %`;
    } else {
        $('tuning-rabatt').textContent = '';
    }

    if (antwort && antwort.balance !== undefined) {
        $('tuning-konto').textContent = `Auf dem Konto: ${money(antwort.balance)}`;
        $('btn-tuning-kauf').disabled = antwort.preis > antwort.balance
            || antwort.preis <= 0;
    }

    zeichneTuningListe();
}

/** Ein Teil mit Stufenknöpfen. */
function teilZeile(entry, anzahl, preisFuer) {
    const box = el('div', 'teil');

    const kopf = el('div', 'teil-kopf');
    kopf.appendChild(el('span', 'tab-icon', entry.icon || '🔩'));
    kopf.appendChild(el('span', 'teil-name', entry.label));
    kopf.appendChild(el('span', 'teil-preis', preisFuer));
    box.appendChild(kopf);

    const stufen = el('div', 'stufen');
    const gewaehlt = stufeVon(entry);
    const verbaut = ((data.mods && data.mods.teile) || {})[String(entry.mod)];

    for (let stufe = -1; stufe < anzahl; stufe += 1) {
        const klassen = ['stufe'];
        if (stufe === gewaehlt) klassen.push('gewaehlt');
        else if (stufe === verbaut) klassen.push('verbaut');

        const knopf = el('button', klassen.join(' '),
            stufe < 0 ? 'Serie' : `${stufe + 1}`);

        knopf.addEventListener('click', () => {
            wunsch.teile = wunsch.teile || {};
            wunsch.teile[entry.id] = stufe;
            vorschau();
        });

        stufen.appendChild(knopf);
    }

    box.appendChild(stufen);
    return box;
}

/** Eine Reihe Lackfarben. */
function lackZeile(titel, feld) {
    const box = el('div', 'teil');

    const kopf = el('div', 'teil-kopf');
    kopf.appendChild(el('span', 'teil-name', titel));
    kopf.appendChild(el('span', 'teil-preis',
        money(feld === 'perlmutt' ? data.katalog.preise.perlmutt
            : feld === 'felgenfarbe' ? data.katalog.preise.felgenfarbe
            : data.katalog.preise.lack)));
    box.appendChild(kopf);

    const reihe = el('div', 'lacke');
    const aktiv = wunsch[feld] !== undefined ? wunsch[feld] : data.mods[feld];

    liste(data.katalog.lacke).forEach((farbe) => {
        const punkt = el('div', `lack${farbe.id === aktiv ? ' gewaehlt' : ''}`);
        punkt.style.background = farbe.hex;
        punkt.title = farbe.label;

        punkt.addEventListener('click', () => {
            wunsch[feld] = farbe.id;
            vorschau();
        });

        reihe.appendChild(punkt);
    });

    box.appendChild(reihe);
    return box;
}

/** Eine Reihe Auswahlknöpfe mit an/aus. */
function schalterZeile(titel, preis, an, eintraege, aktivId, beiWahl) {
    const box = el('div', 'teil');

    const kopf = el('div', 'teil-kopf');
    kopf.appendChild(el('span', 'teil-name', titel));
    kopf.appendChild(el('span', 'teil-preis', money(preis)));
    box.appendChild(kopf);

    const stufen = el('div', 'stufen');

    const aus = el('button', `stufe${an ? '' : ' gewaehlt'}`, 'Aus');
    aus.addEventListener('click', () => beiWahl(false, null));
    stufen.appendChild(aus);

    eintraege.forEach((eintrag) => {
        const gewaehlt = an && eintrag.id === aktivId;
        const knopf = el('button', `stufe${gewaehlt ? ' gewaehlt' : ''}`, eintrag.label);

        if (eintrag.r !== undefined) {
            knopf.style.borderColor = `rgb(${eintrag.r}, ${eintrag.g}, ${eintrag.b})`;
        }

        knopf.addEventListener('click', () => beiWahl(true, eintrag.id));
        stufen.appendChild(knopf);
    });

    box.appendChild(stufen);
    return box;
}

function zeichneTuningNav() {
    const nav = $('tuning-nav');
    clear(nav);

    tuningReiter().forEach((eintrag) => {
        const zeile = el('div', `tuning-tab${eintrag.id === reiter ? ' aktiv' : ''}`);
        zeile.appendChild(el('span', 'tab-icon', eintrag.icon));
        zeile.appendChild(el('span', null, eintrag.label));

        zeile.addEventListener('click', () => {
            reiter = eintrag.id;
            zeichneTuningNav();
            zeichneTuningListe();
        });

        nav.appendChild(zeile);
    });
}

function zeichneTuningListe() {
    const liste = $('tuning-liste');
    clear(liste);

    const verfuegbar = data.verfuegbar || {};
    const katalog = data.katalog || {};

    if (reiter === 'leistung') {
        liste(katalog.leistung).forEach((entry) => {
            const anzahl = verfuegbar[entry.id] || 0;
            if (anzahl > 0) {
                liste.appendChild(teilZeile(entry, anzahl,
                    `bis ${money(entry.preise[entry.preise.length - 1])}`));
            }
        });

        const turbo = katalog.turbo;
        if (turbo) {
            liste.appendChild(schalterZeile('Turbolader', turbo.preis,
                stufeVon(turbo) > 0, [{ id: 1, label: 'Eingebaut' }],
                1, (an) => {
                    wunsch.teile = wunsch.teile || {};
                    wunsch.teile[turbo.id] = an ? 1 : 0;
                    vorschau();
                }));
        }

        if (!liste.firstChild) {
            liste.appendChild(el('p', 'muted',
                'An diesem Fahrzeug lässt sich an der Leistung nichts machen.'));
        }
    } else if (reiter === 'optik') {
        liste(katalog.optik).forEach((entry) => {
            const anzahl = verfuegbar[entry.id] || 0;
            if (anzahl > 0) liste.appendChild(teilZeile(entry, anzahl, money(entry.preis)));
        });

        if (!liste.firstChild) {
            liste.appendChild(el('p', 'muted',
                'Für dieses Fahrzeug gibt es keine Anbauteile.'));
        }
    } else if (reiter === 'lack') {
        liste.appendChild(lackZeile('Grundfarbe', 'primaer'));
        liste.appendChild(lackZeile('Zweitfarbe', 'sekundaer'));
        liste.appendChild(lackZeile('Perlmuttschimmer', 'perlmutt'));
        liste.appendChild(lackZeile('Felgenfarbe', 'felgenfarbe'));
    } else if (reiter === 'licht') {
        const xenon = wunsch.xenon || data.mods.xenon || {};
        liste.appendChild(schalterZeile('Xenon-Scheinwerfer',
            katalog.preise.xenon, xenon.an === true,
            katalog.xenon || [], xenon.farbe,
            (an, id) => {
                wunsch.xenon = an ? { an: true, farbe: id } : { an: false };
                vorschau();
            }));

        const neon = wunsch.neon || data.mods.neon || {};
        liste.appendChild(schalterZeile('Neonbeleuchtung',
            katalog.preise.neon, neon.an === true,
            katalog.neon || [], neon.id,
            (an, id) => {
                wunsch.neon = an ? { an: true, id } : { an: false };
                vorschau();
            }));
    } else if (reiter === 'sonstig') {
        const folie = wunsch.folie !== undefined ? wunsch.folie : data.mods.folie;
        const folienBox = el('div', 'teil');
        const folienKopf = el('div', 'teil-kopf');
        folienKopf.appendChild(el('span', 'teil-name', 'Fensterfolie'));
        folienBox.appendChild(folienKopf);

        const folienReihe = el('div', 'stufen');
        liste(katalog.folien).forEach((eintrag) => {
            const knopf = el('button',
                `stufe${eintrag.id === folie ? ' gewaehlt' : ''}`,
                `${eintrag.label}${eintrag.preis > 0 ? ` · ${money(eintrag.preis)}` : ''}`);

            knopf.addEventListener('click', () => {
                wunsch.folie = eintrag.id;
                vorschau();
            });

            folienReihe.appendChild(knopf);
        });
        folienBox.appendChild(folienReihe);
        liste.appendChild(folienBox);

        const rauch = wunsch.rauch || data.mods.rauch || {};
        liste.appendChild(schalterZeile('Reifenrauch',
            katalog.preise.rauch, rauch.an === true,
            katalog.neon || [], rauch.id,
            (an, id) => {
                wunsch.rauch = an ? { an: true, id } : { an: false };
                vorschau();
            }));
    }
}

function renderTuning() {
    $('title').textContent = data.label || 'Werkstatt';
    $('subtitle').textContent = `Kennzeichen ${data.plate || '–'}`;
    $('crest').textContent = '🔧';
    $('foot-hint').textContent =
        'Angeschaut wird sofort am Fahrzeug. Bezahlt wird erst beim Einbauen.';

    zeichneTuningNav();
    zeichneTuningListe();
    vorschau();
}

$('btn-tuning-kauf').addEventListener('click', () => post('tuningBuy'));
$('btn-tuning-abbruch').addEventListener('click', () => post('tuningCancel'));

/* ----------------------------------------------------------------- Rendern */

const PANELS = ['bank', 'fuel', 'repair', 'market', 'tuning'];

function render() {
    if (!data) return;

    PANELS.forEach((key) => {
        $(`panel-${key}`).classList.toggle('hidden', key !== mode);
    });

    if (mode === 'bank') renderBank();
    else if (mode === 'fuel') renderFuel();
    else if (mode === 'repair') renderRepair();
    else if (mode === 'market') renderMarket();
    else if (mode === 'tuning') renderTuning();
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
            if (mode === 'tuning') { wunsch = {}; reiter = 'leistung'; }
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
