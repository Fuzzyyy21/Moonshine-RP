/* Moonshine Aussehen - Charaktereditor, Läden, Friseure. */

const RESOURCE = 'moonshine-appearance';

let config = null;          // was der Server geschickt hat
let state = null;           // aktuelles Aussehen
let activeGroup = null;
let outfits = [];
let counts = {};            // wie viele Varianten es je Teil gibt
let changed = { kleidung: 0, accessoires: 0 };
let touched = {};           // welche Teile angefasst wurden

const $ = (id) => document.getElementById(id);

function post(name, payload) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {}),
    }).catch(() => {});
}

async function ask(name, payload) {
    try {
        const response = await fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {}),
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

/* ------------------------------------------------------------ Farbpaletten */

/** GTA-Haarfarben grob nachgebildet — für die Vorschau reicht das. */
function hairSwatch(index) {
    const PALETTE = [
        '#1c1512', '#2b1d16', '#3d2a1c', '#4f3623', '#63432b', '#785134',
        '#8d6040', '#a2724f', '#b5855f', '#c69a74', '#d4ae8d', '#e0c2a6',
        '#e8d3bd', '#efe0d0', '#f5ece0', '#d9d9d9', '#bfbfbf', '#a6a6a6',
        '#8c8c8c', '#737373', '#595959', '#404040', '#262626', '#0d0d0d',
        '#7a1f1f', '#9c2b2b', '#bd3a3a', '#d64f4f', '#8a3d1a', '#a85423',
        '#c66a2e', '#d98544',
    ];

    return PALETTE[index % PALETTE.length];
}

function eyeSwatch(index) {
    const PALETTE = [
        '#3f6b8a', '#4b7fa3', '#5b93b8', '#6fa8c9', '#84bad6', '#4f7a52',
        '#5c8c5f', '#6b9e6e', '#7db07f', '#8fc291', '#6b5334', '#7d6240',
        '#8f724d', '#a1825b', '#b3936a', '#5a5a5a', '#6d6d6d', '#808080',
        '#3a3a3a', '#2b2b2b', '#8a5a3f', '#9c6b4d', '#7a4a6b', '#8c5a7d',
        '#b03030', '#c04040', '#d0d0d0', '#e0e0e0', '#f0f0f0', '#4a4a6b',
        '#5a5a7d', '#6b6b8f',
    ];

    return PALETTE[index % PALETTE.length];
}

/** Make-up und Bartfarben. */
function makeupSwatch(index) {
    const PALETTE = [
        '#2b1d16', '#4f3623', '#785134', '#a2724f', '#c69a74', '#e0c2a6',
        '#8c8c8c', '#595959', '#262626', '#7a1f1f', '#bd3a3a', '#d64f4f',
        '#a83a6b', '#c04d80', '#d66095', '#8a3d1a', '#c66a2e', '#5a3d7a',
        '#6b4d8c', '#7d5e9e', '#3f6b8a', '#5b93b8', '#4f7a52', '#6b9e6e',
    ];

    return PALETTE[index % PALETTE.length];
}

/* ------------------------------------------------------------------ Steuerung */

/** Ein Auswahlfeld mit Pfeilen. */
function stepper(label, value, max, onChange, formatter) {
    const box = el('div', 'control');

    const head = el('div', 'control-head');
    head.appendChild(el('div', 'control-label', label));

    const readout = el('div', 'control-value');
    head.appendChild(readout);
    box.appendChild(head);

    const row = el('div', 'stepper');

    const back = el('button', 'step', '‹');
    const display = el('div', 'step-value');
    const forward = el('button', 'step', '›');

    let current = value;

    function paint() {
        display.textContent = formatter ? formatter(current) : String(current);
        readout.textContent = max > 0 ? `${current + 1} / ${max}` : '';
    }

    function move(delta) {
        if (max <= 0) return;

        current += delta;
        if (current >= max) current = 0;
        if (current < 0) current = max - 1;

        paint();
        onChange(current);
    }

    back.addEventListener('click', () => move(-1));
    forward.addEventListener('click', () => move(1));

    row.appendChild(back);
    row.appendChild(display);
    row.appendChild(forward);
    box.appendChild(row);

    paint();
    return box;
}

/** Ein Schieberegler von -1 bis 1 oder 0 bis 1. */
function slider(label, value, min, max, step, onChange, formatter) {
    const box = el('div', 'control');

    const head = el('div', 'control-head');
    head.appendChild(el('div', 'control-label', label));

    const readout = el('div', 'control-value');
    head.appendChild(readout);
    box.appendChild(head);

    const input = document.createElement('input');
    input.type = 'range';
    input.min = String(min);
    input.max = String(max);
    input.step = String(step);
    input.value = String(value);

    function paint() {
        readout.textContent = formatter
            ? formatter(Number(input.value))
            : Number(input.value).toFixed(2);
    }

    input.addEventListener('input', () => {
        paint();
        onChange(Number(input.value));
    });

    box.appendChild(input);
    paint();

    return box;
}

/** Ein Farbraster. */
function swatches(label, count, current, colourFor, onPick) {
    const box = el('div', 'control');
    box.appendChild(el('div', 'control-label', label));

    const grid = el('div', 'swatches');
    grid.style.marginTop = '9px';

    for (let index = 0; index < count; index += 1) {
        const cell = el('div', `swatch${index === current ? ' active' : ''}`);
        cell.style.background = colourFor(index);
        cell.title = String(index);

        cell.addEventListener('click', () => {
            grid.querySelectorAll('.swatch').forEach((other) => {
                other.classList.remove('active');
            });
            cell.classList.add('active');
            onPick(index);
        });

        grid.appendChild(cell);
    }

    box.appendChild(grid);
    return box;
}

/* -------------------------------------------------------------- Gruppenliste */

/** Alle Gruppen, die dieser Ort erlaubt. */
function buildGroups() {
    const allowed = config.categories || [];
    const groups = [];

    if (allowed.includes('kopf')) {
        groups.push({ id: 'gesicht',  label: 'Gesicht',      icon: '🙂', section: 'Körper' });
        groups.push({ id: 'haare',    label: 'Haare',        icon: '💇', section: 'Körper' });

        config.data.overlays
            .filter((entry) => entry.group === 'kopf' && entry.key !== 'augenbrauen')
            .forEach((entry) => {
                groups.push({ id: `overlay:${entry.id}`, label: entry.label,
                    icon: '✦', section: 'Körper' });
            });

        groups.push({ id: 'overlay:2', label: 'Augenbrauen', icon: '👁', section: 'Körper' });
    }

    if (allowed.includes('makeup')) {
        config.data.overlays
            .filter((entry) => entry.group === 'makeup')
            .forEach((entry) => {
                groups.push({ id: `overlay:${entry.id}`, label: entry.label,
                    icon: '💄', section: 'Make-up' });
            });
    }

    if (allowed.includes('koerper')) {
        config.data.overlays
            .filter((entry) => entry.group === 'koerper')
            .forEach((entry) => {
                groups.push({ id: `overlay:${entry.id}`, label: entry.label,
                    icon: '🧍', section: 'Körper' });
            });
    }

    if (allowed.includes('kleidung')) {
        config.data.components
            .filter((entry) => entry.group === 'kleidung')
            .forEach((entry) => {
                groups.push({ id: `component:${entry.id}`, label: entry.label,
                    icon: entry.icon, section: 'Kleidung', priced: 'kleidung' });
            });
    }

    if (allowed.includes('accessoires')) {
        config.data.components
            .filter((entry) => entry.group === 'accessoires')
            .forEach((entry) => {
                groups.push({ id: `component:${entry.id}`, label: entry.label,
                    icon: entry.icon, section: 'Accessoires', priced: 'accessoires' });
            });

        config.data.props.forEach((entry) => {
            groups.push({ id: `prop:${entry.id}`, label: entry.label,
                icon: entry.icon, section: 'Accessoires', priced: 'accessoires' });
        });
    }

    return groups;
}

function renderGroups() {
    const box = $('group-list');
    clear(box);

    const groups = buildGroups();
    let section = null;

    groups.forEach((group) => {
        if (group.section !== section) {
            section = group.section;
            box.appendChild(el('div', 'group-caption', section));
        }

        const row = el('div', `group${activeGroup === group.id ? ' active' : ''}`);
        row.appendChild(el('span', 'icon', group.icon));
        row.appendChild(el('span', null, group.label));

        if (touched[group.id]) row.appendChild(el('span', 'tick', '●'));

        row.addEventListener('click', () => {
            activeGroup = group.id;
            renderGroups();
            renderControls(group);
        });

        box.appendChild(row);
    });

    if (!activeGroup && groups.length) {
        activeGroup = groups[0].id;
        renderGroups();
        renderControls(groups[0]);
    }
}

/* ------------------------------------------------------------- Werte anzeigen */

/** Merkt sich, dass eine Gruppe angefasst wurde (nur für den Punkt daneben). */
function markTouched(groupId) {
    if (!touched[groupId]) {
        touched[groupId] = true;
        renderGroups();
    }

    updateCost();
}

/**
 * Zählt genauso wie der Server: was sich vom Ausgangszustand unterscheidet.
 * Wer etwas ändert und zurücknimmt, zahlt dafür nicht.
 */
function countChanges() {
    const before = config.appearance || {};
    let kleidung = 0;
    let accessoires = 0;

    const differs = (a, b) => (a || {}).drawable !== (b || {}).drawable
        || (a || {}).texture !== (b || {}).texture;

    config.data.components.forEach((entry) => {
        const key = String(entry.id);

        if (differs((before.components || {})[key], (state.components || {})[key])) {
            if (entry.group === 'accessoires') accessoires += 1;
            else kleidung += 1;
        }
    });

    config.data.props.forEach((entry) => {
        const key = String(entry.id);
        const old = (before.props || {})[key] || { drawable: -1, texture: 0 };
        const now = (state.props || {})[key] || { drawable: -1, texture: 0 };

        if (old.drawable !== now.drawable || old.texture !== now.texture) {
            accessoires += 1;
        }
    });

    return { kleidung, accessoires };
}

function updateCost() {
    if (config.kind !== 'shop') return;

    changed = countChanges();

    const total = changed.kleidung * (config.prices.kleidung || 0)
        + changed.accessoires * (config.prices.accessoires || 0);

    $('cost').textContent = money(total);
    $('cost-box').classList.toggle('hidden', total === 0);

    const parts = changed.kleidung + changed.accessoires;
    $('cost-box').title = parts > 0 ? `${parts} geänderte Teile` : '';

    const button = $('btn-save');
    const affordable = total <= config.balance;

    button.disabled = !affordable;
    button.textContent = total === 0
        ? 'Übernehmen'
        : (affordable ? `Kaufen für ${money(total)}` : 'Zu teuer');
}

async function renderControls(group) {
    const box = $('controls');
    clear(box);

    $('group-title').textContent = group.label;
    $('group-hint').textContent = '';

    const [kind, rawId] = group.id.split(':');
    const id = Number(rawId);

    /* --- Kleidungsstück ------------------------------------------------- */
    if (kind === 'component') {
        if (!state.components[String(id)]) {
            state.components[String(id)] = { drawable: 0, texture: 0 };
        }
        const entry = state.components[String(id)];

        const result = await ask('setComponent', {
            id, drawable: entry.drawable, texture: entry.texture,
        });

        counts[group.id] = result || { drawables: 1, textures: 1 };

        box.appendChild(stepper('Modell', entry.drawable,
            counts[group.id].drawables, async (value) => {
                entry.drawable = value;
                entry.texture = 0;

                const next = await ask('setComponent',
                    { id, drawable: value, texture: 0 });

                counts[group.id] = next || counts[group.id];
                markTouched(group.id);
                renderControls(group);
            }));

        box.appendChild(stepper('Farbe', entry.texture,
            counts[group.id].textures, (value) => {
                entry.texture = value;
                post('setComponent', { id, drawable: entry.drawable, texture: value });
                markTouched(group.id);
            }));

        $('group-hint').textContent =
            `${counts[group.id].drawables} Modelle, ${counts[group.id].textures} Farben.`;
        return;
    }

    /* --- Anbauteil ------------------------------------------------------- */
    if (kind === 'prop') {
        if (!state.props[String(id)]) {
            state.props[String(id)] = { drawable: -1, texture: 0 };
        }
        const entry = state.props[String(id)];

        const result = await ask('setProp', {
            id, drawable: entry.drawable, texture: entry.texture,
        });

        counts[group.id] = result || { drawables: 1, textures: 1 };

        // -1 bedeutet "nichts". Deshalb ein Feld mehr.
        box.appendChild(stepper('Modell', entry.drawable + 1,
            counts[group.id].drawables + 1, async (value) => {
                entry.drawable = value - 1;
                entry.texture = 0;

                const next = await ask('setProp',
                    { id, drawable: entry.drawable, texture: 0 });

                counts[group.id] = next || counts[group.id];
                markTouched(group.id);
                renderControls(group);
            }, (value) => (value === 0 ? 'nichts' : String(value))));

        if (entry.drawable >= 0) {
            box.appendChild(stepper('Farbe', entry.texture,
                counts[group.id].textures, (value) => {
                    entry.texture = value;
                    post('setProp', { id, drawable: entry.drawable, texture: value });
                    markTouched(group.id);
                }));
        }

        return;
    }

    /* --- Gesichtsauflage -------------------------------------------------- */
    if (kind === 'overlay') {
        const definition = config.data.overlays.find((entry) => entry.id === id);
        if (!state.overlays[String(id)]) {
            state.overlays[String(id)] = {
                index: 255, opacity: 1.0, colour: 0, secondColour: 0,
            };
        }
        const entry = state.overlays[String(id)];

        const result = await ask('setOverlay', {
            id, index: entry.index, opacity: entry.opacity,
            colourType: definition.colourType,
            colour: entry.colour, secondColour: entry.secondColour,
        });

        const count = (result && result.count) || 1;

        // 255 heißt "keine". Als erstes Feld anzeigen.
        const display = entry.index === 255 ? 0 : entry.index + 1;

        box.appendChild(stepper('Auswahl', display, count + 1, (value) => {
            entry.index = value === 0 ? 255 : value - 1;

            post('setOverlay', {
                id, index: entry.index, opacity: entry.opacity,
                colourType: definition.colourType,
                colour: entry.colour, secondColour: entry.secondColour,
            });

            markTouched(group.id);
            renderControls(group);
        }, (value) => (value === 0 ? 'keine' : String(value))));

        if (entry.index !== 255) {
            box.appendChild(slider('Deckkraft', entry.opacity, 0, 1, 0.05, (value) => {
                entry.opacity = value;

                post('setOverlay', {
                    id, index: entry.index, opacity: value,
                    colourType: definition.colourType,
                    colour: entry.colour, secondColour: entry.secondColour,
                });

                markTouched(group.id);
            }, (value) => `${Math.round(value * 100)} %`));

            if (definition.colourType !== null && definition.colourType !== undefined) {
                const isHair = definition.colourType === 1;
                const palette = isHair ? hairSwatch : makeupSwatch;
                const total = isHair ? config.data.hairColours : 24;

                box.appendChild(swatches('Farbe', total, entry.colour, palette,
                    (value) => {
                        entry.colour = value;
                        entry.secondColour = value;

                        post('setOverlay', {
                            id, index: entry.index, opacity: entry.opacity,
                            colourType: definition.colourType,
                            colour: value, secondColour: value,
                        });

                        markTouched(group.id);
                    }));
            }
        }

        return;
    }

    /* --- Haare ------------------------------------------------------------ */
    if (group.id === 'haare') {
        if (!state.hair) {
            state.hair = { drawable: 0, texture: 0, colour: 1, highlight: 1 };
        }
        const hair = state.hair;

        const result = await ask('setHair', hair);
        const total = (result && result.drawables) || 1;

        box.appendChild(stepper('Frisur', hair.drawable, total, (value) => {
            hair.drawable = value;
            post('setHair', hair);
            markTouched(group.id);
        }));

        box.appendChild(swatches('Haarfarbe', config.data.hairColours, hair.colour,
            hairSwatch, (value) => {
                hair.colour = value;
                post('setHair', hair);
                markTouched(group.id);
            }));

        box.appendChild(swatches('Strähnchen', config.data.hairColours, hair.highlight,
            hairSwatch, (value) => {
                hair.highlight = value;
                post('setHair', hair);
                markTouched(group.id);
            }));

        return;
    }

    /* --- Gesicht ---------------------------------------------------------- */
    if (group.id === 'gesicht') {
        if (!state.headBlend) {
            state.headBlend = {
                shapeFirst: 0, shapeSecond: 0, shapeThird: 0,
                skinFirst: 0, skinSecond: 0, skinThird: 0,
                shapeMix: 0.5, skinMix: 0.5, thirdMix: 0.0,
            };
        }
        if (!state.features) state.features = {};

        const blend = state.headBlend;
        const parents = config.data.parents;

        const fathers = parents.male;
        const mothers = parents.female;

        function pushBlend() {
            post('setBlend', { blend });
            markTouched(group.id);
        }

        box.appendChild(stepper('Vater',
            Math.max(0, fathers.findIndex((entry) => entry.id === blend.shapeFirst)),
            fathers.length, (value) => {
                blend.shapeFirst = fathers[value].id;
                blend.skinFirst = fathers[value].id;
                pushBlend();
            }, (value) => fathers[value].label));

        box.appendChild(stepper('Mutter',
            Math.max(0, mothers.findIndex((entry) => entry.id === blend.shapeSecond)),
            mothers.length, (value) => {
                blend.shapeSecond = mothers[value].id;
                blend.skinSecond = mothers[value].id;
                pushBlend();
            }, (value) => mothers[value].label));

        box.appendChild(slider('Ähnlichkeit', blend.shapeMix, 0, 1, 0.02, (value) => {
            blend.shapeMix = value;
            pushBlend();
        }, (value) => (value < 0.5
            ? `${Math.round((1 - value) * 100)} % Vater`
            : `${Math.round(value * 100)} % Mutter`)));

        box.appendChild(slider('Hautton', blend.skinMix, 0, 1, 0.02, (value) => {
            blend.skinMix = value;
            pushBlend();
        }, (value) => (value < 0.5
            ? `${Math.round((1 - value) * 100)} % Vater`
            : `${Math.round(value * 100)} % Mutter`)));

        box.appendChild(swatches('Augenfarbe', config.data.eyeColours, state.eyeColour,
            eyeSwatch, (value) => {
                state.eyeColour = value;
                post('setEyes', { value });
                markTouched(group.id);
            }));

        // Gesichtszüge
        const features = el('div');
        features.appendChild(el('div', 'control-label', 'Gesichtszüge'));
        features.style.marginTop = '22px';
        features.style.marginBottom = '10px';
        box.appendChild(features);

        config.data.features.forEach((feature) => {
            const key = String(feature.id);
            const value = state.features[key] || 0;

            box.appendChild(slider(feature.label, value, -1, 1, 0.05, (next) => {
                state.features[key] = next;
                post('setFeature', { id: feature.id, value: next });
                markTouched(group.id);
            }, (next) => next.toFixed(2)));
        });

        return;
    }
}

/* ------------------------------------------------------------------- Outfits */

function renderOutfits() {
    const box = $('outfit-box');
    const showOutfits = config.maxOutfits > 0;

    box.classList.toggle('hidden', !showOutfits);
    if (!showOutfits) return;

    const list = $('outfit-list');
    clear(list);

    if (!outfits.length) {
        list.appendChild(el('div', 'muted', 'Noch keine Outfits gesichert.'));
    }

    outfits.forEach((entry) => {
        const row = el('div', 'outfit');
        row.appendChild(el('span', null, entry.label));

        const wear = el('button', null, 'Anziehen');
        wear.addEventListener('click', () => post('wearOutfit', { id: entry.id }));
        row.appendChild(wear);

        const remove = el('button', 'remove', '✕');
        remove.addEventListener('click', () => post('deleteOutfit', { id: entry.id }));
        row.appendChild(remove);

        list.appendChild(row);
    });

    $('btn-save-outfit').disabled = outfits.length >= config.maxOutfits;
}

$('btn-save-outfit').addEventListener('click', () => {
    post('saveOutfit', { label: $('outfit-name').value || 'Outfit' });
    $('outfit-name').value = '';
});

/* ------------------------------------------------------------------ Kamera */

document.querySelectorAll('.view').forEach((button) => {
    button.addEventListener('click', () => {
        document.querySelectorAll('.view').forEach((other) => {
            other.classList.toggle('active', other === button);
        });

        post('view', { view: button.dataset.view });
    });
});

/* ----------------------------------------------------------------- Aktionen */

$('btn-save').addEventListener('click', () => post('save'));

$('btn-cancel').addEventListener('click', () => post('cancel'));

/* ----------------------------------------------------------------- Rendern */

function render() {
    const ICONS = {
        shop: '👕', barber: '💇', wardrobe: '🚪', ersteErstellung: '✨',
    };

    $('crest').textContent = ICONS[config.kind] || '👤';
    $('title').textContent = config.label || 'Aussehen';

    const SUBTITLES = {
        shop: 'Bezahlt wird beim Übernehmen',
        barber: 'Bereits bezahlt — ändere, so viel du willst',
        wardrobe: 'Umziehen kostet hier nichts',
        ersteErstellung: 'Das lässt sich später beim Friseur ändern',
    };

    $('subtitle').textContent = SUBTITLES[config.kind] || '';
    $('balance').textContent = money(config.balance);
    $('cost-box').classList.toggle('hidden', config.kind !== 'shop');

    changed = { kleidung: 0, accessoires: 0 };
    touched = {};
    activeGroup = null;

    renderGroups();
    renderOutfits();
    updateCost();

    if (config.kind === 'ersteErstellung') {
        $('btn-cancel').classList.add('hidden');
        $('btn-save').textContent = 'Los geht’s';
    } else {
        $('btn-cancel').classList.remove('hidden');
    }
}

/* -------------------------------------------------------------- Nachrichten */

/* ------------------------------------------------------------ Tätowierstudio */

let tattooData = null;
let tattooZone = null;
let tattooPick = null;

function tattooZonenZeichnen() {
    const nav = $('tattoo-zones');
    clear(nav);

    (tattooData.zonen || []).forEach((zone) => {
        const motive = (tattooData.motive || []).filter((m) => m.zone === zone.key);
        const getragen = motive.filter((m) => m.getragen).length;

        const row = el('div', `group${zone.key === tattooZone ? ' active' : ''}`);
        row.appendChild(el('span', 'icon', zone.icon || '🖋'));
        row.appendChild(el('span', null, zone.label));
        row.appendChild(el('span', 'tick',
            getragen > 0 ? `${getragen}/${motive.length}` : ''));

        row.addEventListener('click', () => {
            tattooZone = zone.key;
            tattooPick = null;
            post('tattooZone', { zone: zone.key });
            tattooZeichnen();
        });

        nav.appendChild(row);
    });
}

function tattooZeichnen() {
    if (!tattooData) return;

    const zone = (tattooData.zonen || []).find((z) => z.key === tattooZone)
        || (tattooData.zonen || [])[0];

    if (zone) tattooZone = zone.key;

    $('tattoo-title').textContent = tattooData.label || 'Tätowierer';
    $('tattoo-balance').textContent = money(tattooData.balance);
    $('tattoo-count').textContent = String((tattooData.getragen || []).length);
    $('tattoo-zone-title').textContent = zone ? zone.label : '—';

    tattooZonenZeichnen();

    const liste = $('tattoo-list');
    clear(liste);

    const motive = (tattooData.motive || []).filter((m) => m.zone === tattooZone);

    if (!motive.length) {
        liste.appendChild(el('p', 'muted', 'Für diese Stelle gibt es hier nichts.'));
        $('tattoo-zone-hint').textContent = '';
        return;
    }

    const entfernung = tattooData.entfernen || 1;
    $('tattoo-zone-hint').textContent =
        `Entfernen kostet das ${entfernung.toLocaleString('de-DE')}-fache.`;

    motive.forEach((motiv) => {
        const klassen = ['motiv'];
        if (motiv.id === tattooPick) klassen.push('gewaehlt');
        if (motiv.getragen) klassen.push('getragen');
        if (motiv.mal) klassen.push('mal');

        const row = el('div', klassen.join(' '));

        const text = el('div', 'motiv-text');
        text.appendChild(el('div', 'motiv-label', motiv.label));
        text.appendChild(el('div', 'motiv-note',
            motiv.getragen ? 'gestochen' : (motiv.mal ? 'Klassenmal' : '')));
        row.appendChild(text);

        if (motiv.getragen) {
            const weg = el('button', 'entfernen', 'Entfernen');
            weg.title = money(Math.floor(motiv.preis * entfernung));
            weg.addEventListener('click', (ev) => {
                ev.stopPropagation();
                post('tattooRemove', { id: motiv.id });
            });
            row.appendChild(weg);
        } else {
            const zuTeuer = motiv.preis > (tattooData.balance || 0);

            const preis = el('span',
                `motiv-preis${zuTeuer ? ' zuteuer' : ''}`, money(motiv.preis));
            row.appendChild(preis);

            const kaufen = el('button', 'stechen', 'Stechen');
            kaufen.disabled = zuTeuer;
            kaufen.addEventListener('click', (ev) => {
                ev.stopPropagation();
                if (!zuTeuer) post('tattooBuy', { id: motiv.id });
            });
            row.appendChild(kaufen);
        }

        row.addEventListener('click', () => {
            tattooPick = motiv.id;
            post('tattooPreview', { id: motiv.id });
            tattooZeichnen();
        });

        liste.appendChild(row);
    });
}

$('tattoo-close').addEventListener('click', () => post('tattooClose'));

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'appearance:open':
            config = message.data || null;
            state = JSON.parse(JSON.stringify(config.appearance || {}));
            outfits = config.outfits || [];

            $('screen').classList.remove('hidden');
            render();
            break;

        case 'appearance:close':
            $('screen').classList.add('hidden');
            break;

        case 'appearance:outfits':
            outfits = (message.data || []).map((entry) => ({
                id: entry.id, label: entry.label,
            }));
            renderOutfits();
            break;

        case 'appearance:buyFailed':
            updateCost();
            break;

        case 'tattoo:open':
            tattooData = message.data || null;
            if (tattooData && !tattooZone) {
                tattooZone = (tattooData.zonen || [])[0]
                    ? tattooData.zonen[0].key : null;
            }
            $('tattoo').classList.remove('hidden');
            tattooZeichnen();
            break;

        case 'tattoo:close':
            $('tattoo').classList.add('hidden');
            tattooData = null;
            tattooPick = null;
            break;

        default:
            break;
    }
});
