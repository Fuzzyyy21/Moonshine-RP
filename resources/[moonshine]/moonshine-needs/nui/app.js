/* Moonshine Klassenbeduerfnis - kleiner Balken, mehr nicht. */

let data = null;
let visible = false;

const $ = (id) => document.getElementById(id);

const BAND_TEXT = {
    satt:    'gesättigt',
    normal:  'in Ordnung',
    warnung: 'lässt nach',
    schwach: 'schwach',
    leer:    'am Ende',
};

/** Der Balken wird zum Ende hin blasser und schließlich grau. */
function farbe(basis, wert) {
    if (wert > 50) return basis;

    // Unter 50 % Richtung Grau ausbleichen
    const anteil = Math.max(0, wert) / 50;
    const hex = basis.replace('#', '');
    const kanaele = [0, 2, 4].map((i) => parseInt(hex.substr(i, 2), 16));

    const gemischt = kanaele.map((k) => Math.round(k * anteil + 90 * (1 - anteil)));

    return `#${gemischt.map((k) => k.toString(16).padStart(2, '0')).join('')}`;
}

function zeichnen() {
    const widget = $('widget');

    if (!data || !visible) {
        widget.classList.add('hidden');
        return;
    }

    widget.classList.remove('hidden');

    widget.classList.remove('satt', 'normal', 'warnung', 'schwach', 'leer');
    widget.classList.add(data.band || 'normal');

    document.documentElement.style.setProperty('--need', data.colour || '#a3232c');

    $('icon').textContent = data.icon || '✦';
    $('label').textContent = data.label || 'Bedürfnis';
    $('band').textContent = BAND_TEXT[data.band] || '';
    $('value').textContent = String(Math.floor(data.value || 0));

    const fill = $('fill');
    fill.style.width = `${Math.max(0, Math.min(100, data.value || 0))}%`;
    fill.style.background = farbe(data.colour || '#a3232c', data.value || 0);
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'needs:sync':
            data = message.data || null;
            if (message.visible !== undefined) visible = message.visible === true;
            zeichnen();
            break;

        case 'needs:visible':
            visible = message.value === true;
            zeichnen();
            break;

        case 'needs:zone': {
            const box = $('zone');

            if (message.label) {
                box.classList.remove('hidden');
                $('zone-icon').textContent = message.icon || '✦';
                $('zone-label').textContent = message.label;
            } else {
                box.classList.add('hidden');
            }
            break;
        }

        case 'needs:progress': {
            const wert = message.value || 0;
            const box = $('progress');

            if (wert <= 0) {
                box.classList.add('hidden');
                break;
            }

            box.classList.remove('hidden');
            $('progress-fill').style.width = `${Math.round(wert * 100)}%`;
            break;
        }

        case 'needs:drain': {
            const widget = $('widget');
            widget.classList.add('blut-effekt');
            setTimeout(() => widget.classList.remove('blut-effekt'), 700);
            break;
        }

        default:
            break;
    }
});
