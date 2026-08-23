const RESOURCE = 'moonshine-shops';
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


function post(name, data = {}) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
}

const formatMoney = (value) => new Intl.NumberFormat('de-DE').format(Math.floor(value || 0));

function renderItems(items) {
    const list = $('list');
    list.innerHTML = '';

    items.forEach((item) => {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
            <div class="info">
                <div class="label"></div>
                <div class="desc"></div>
            </div>
            <div class="price"></div>
            <input type="number" min="1" max="100" value="1">
            <button>Kaufen</button>`;

        row.querySelector('.label').textContent = item.label;
        row.querySelector('.desc').textContent = item.description;
        row.querySelector('.price').textContent = formatMoney(item.price) + ' $';

        const input = row.querySelector('input');
        row.querySelector('button').onclick = () => {
            const count = Math.max(1, parseInt(input.value, 10) || 1);
            post('buy', { name: item.name, count });
        };

        list.appendChild(row);
    });
}

function close() {
    $('shop').classList.add('hidden');
    post('close');
}

$('btn-close').onclick = close;

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape') close();
});

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};

    if (action === 'openShop') {
        renderItems(liste(data.items));
        $('money').textContent = formatMoney(data.money);
        $('shop').classList.remove('hidden');
    } else if (action === 'closeShop') {
        $('shop').classList.add('hidden');
    } else if (action === 'updateMoney') {
        $('money').textContent = formatMoney(data);
    }
});
