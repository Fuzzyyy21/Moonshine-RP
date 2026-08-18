/* Moonshine Fraktionen - Wappen, Raenge, Skilltree, Gebiete und mehr. */

const RESOURCE = 'moonshine-factions';
const SVG_NS = 'http://www.w3.org/2000/svg';

let state = null;          // eigene Fraktion
let factionList = [];      // alle Fraktionen
let territories = [];      // Gebietsuebersicht
let inventory = [];        // eigenes Inventar (fuer den Tresor)
let activeTab = 'overview';
let draft = null;          // Wappen im Bearbeitungszustand
let rankDraft = null;      // Raenge im Bearbeitungszustand
let selectedSkill = null;
let controlEntry = null;

/* Bausteine der Wappen - kommen beim Start vom Client. */
let SHAPES = [];
let SYMBOLS = [];

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

function svg(tag, attributes) {
    const node = document.createElementNS(SVG_NS, tag);
    Object.entries(attributes || {}).forEach(([key, value]) => {
        node.setAttribute(key, value);
    });
    return node;
}

function clear(node) {
    while (node && node.firstChild) node.removeChild(node.firstChild);
}

function money(amount) {
    return `${Math.floor(amount || 0).toLocaleString('de-DE')} $`;
}

/** Mischt eine Hexfarbe mit Schwarz oder Weiss. */
function shade(hex, amount) {
    const value = hex.replace('#', '');
    const channels = [0, 2, 4].map((index) => parseInt(value.substr(index, 2), 16));

    const mixed = channels.map((channel) => {
        const target = amount < 0 ? 0 : 255;
        const ratio = Math.abs(amount);
        return Math.round(channel + (target - channel) * ratio);
    });

    return `#${mixed.map((channel) => channel.toString(16).padStart(2, '0')).join('')}`;
}

/* ---------------------------------------------------------- Wappen zeichnen */

let uid = 0;

/** Baut das SVG eines Wappens. */
function buildCrest(emblem, options) {
    const shapes = (options && options.shapes) || SHAPES;
    const symbols = (options && options.symbols) || SYMBOLS;

    const shape = shapes.find((entry) => entry.id === emblem.shape) || shapes[0];
    const symbol = symbols.find((entry) => entry.id === emblem.symbol);

    const id = `crest${uid += 1}`;
    const primary = emblem.primary || '#9b6bd8';
    const secondary = emblem.secondary || '#1a1424';

    const root = svg('svg', { viewBox: '0 0 100 120' });
    const defs = svg('defs');

    // Fuellung je nach Muster.
    let fill = primary;

    if (emblem.pattern === 'verlauf') {
        const gradient = svg('linearGradient', { id: `${id}g`, x1: '0', y1: '0', x2: '0', y2: '1' });
        gradient.appendChild(svg('stop', { offset: '0', 'stop-color': shade(primary, 0.25) }));
        gradient.appendChild(svg('stop', { offset: '1', 'stop-color': shade(secondary, -0.1) }));
        defs.appendChild(gradient);
        fill = `url(#${id}g)`;
    } else if (emblem.pattern !== 'voll') {
        const pattern = svg('pattern', {
            id: `${id}p`, width: '100', height: '120',
            patternUnits: 'userSpaceOnUse',
        });

        pattern.appendChild(svg('rect', { width: '100', height: '120', fill: secondary }));

        if (emblem.pattern === 'geteilt') {
            pattern.appendChild(svg('rect', { width: '100', height: '60', fill: primary }));
        } else if (emblem.pattern === 'schraeg') {
            pattern.appendChild(svg('polygon', { points: '0,0 100,0 0,120', fill: primary }));
        } else if (emblem.pattern === 'streifen') {
            for (let index = 0; index < 6; index += 1) {
                pattern.appendChild(svg('rect', {
                    x: String(index * 17), width: '9', height: '120', fill: primary,
                }));
            }
        } else if (emblem.pattern === 'strahlen') {
            for (let index = 0; index < 8; index += 1) {
                const angle = (index / 8) * Math.PI * 2;
                const x = 50 + Math.cos(angle) * 120;
                const y = 60 + Math.sin(angle) * 120;
                const x2 = 50 + Math.cos(angle + 0.32) * 120;
                const y2 = 60 + Math.sin(angle + 0.32) * 120;
                pattern.appendChild(svg('polygon', {
                    points: `50,60 ${x},${y} ${x2},${y2}`, fill: primary,
                }));
            }
        } else if (emblem.pattern === 'karo') {
            for (let row = 0; row < 6; row += 1) {
                for (let col = 0; col < 5; col += 1) {
                    if ((row + col) % 2 === 0) continue;
                    pattern.appendChild(svg('rect', {
                        x: String(col * 20), y: String(row * 20),
                        width: '20', height: '20', fill: primary,
                    }));
                }
            }
        } else if (emblem.pattern === 'kreuz') {
            pattern.appendChild(svg('rect', { x: '38', width: '24', height: '120', fill: primary }));
            pattern.appendChild(svg('rect', { y: '42', width: '100', height: '24', fill: primary }));
        }

        defs.appendChild(pattern);
        fill = `url(#${id}p)`;
    }

    root.appendChild(defs);

    if (shape) {
        root.appendChild(svg('path', {
            d: shape.path, fill,
            stroke: shade(primary, 0.4), 'stroke-width': '3',
        }));
    }

    if (symbol) {
        const text = svg('text', {
            x: '50', y: '68',
            'text-anchor': 'middle',
            'font-size': '42',
            style: 'paint-order:stroke;filter:drop-shadow(0 2px 4px rgba(0,0,0,.6))',
        });
        text.textContent = symbol.glyph;
        root.appendChild(text);
    }

    return root;
}

/** Setzt ein Wappen in einen Container. */
function paintCrest(node, emblem, options) {
    if (!node) return;
    clear(node);
    if (emblem) node.appendChild(buildCrest(emblem, options));
}

/** Hintergrund eines Banners bzw. Willkommensbildes. */
function backdropStyle(emblem) {
    const primary = emblem.primary || '#9b6bd8';
    const secondary = emblem.secondary || '#1a1424';

    const MOTIFS = {
        nebel: `radial-gradient(circle at 25% 35%, ${primary}55, transparent 60%),
                linear-gradient(120deg, ${shade(secondary, -0.3)}, ${secondary})`,
        blutmond: `radial-gradient(circle at 78% 22%, ${primary}bb, transparent 42%),
                   linear-gradient(160deg, ${shade(secondary, -0.4)}, ${primary}33)`,
        ruinen: `linear-gradient(105deg, ${secondary} 0%, ${shade(primary, -0.55)} 55%, ${secondary} 100%)`,
        sturm: `linear-gradient(70deg, ${shade(secondary, -0.2)}, ${shade(primary, -0.4)} 45%, ${secondary})`,
        asche: `radial-gradient(circle at 50% 120%, ${primary}77, transparent 55%),
                linear-gradient(180deg, ${shade(secondary, -0.35)}, ${secondary})`,
        sternen: `radial-gradient(circle at 65% 30%, ${shade(primary, 0.2)}66, transparent 45%),
                  linear-gradient(200deg, #060410, ${shade(secondary, -0.1)})`,
    };

    return MOTIFS[emblem.backdrop] || MOTIFS.nebel;
}

/* -------------------------------------------------------------------- Tabs */

const TABS = ['overview', 'members', 'ranks', 'skills', 'territory',
    'missions', 'vault', 'shop', 'garage', 'emblem'];

function activateTab(name) {
    activeTab = name;

    document.querySelectorAll('.tab').forEach((tab) => {
        tab.classList.toggle('active', tab.dataset.tab === name);
    });

    TABS.forEach((key) => {
        const panel = $(`panel-${key}`);
        if (panel) panel.classList.toggle('hidden', key !== name);
    });

    if (name === 'overview') post('requestLog');
    if (name === 'vault') loadInventory();
    if (name === 'skills') drawSkillTree();
    if (name === 'territory') drawMap();
}

document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => activateTab(tab.dataset.tab));
});

/* --------------------------------------------------------------- Uebersicht */

function renderHeader() {
    const emblem = state.emblem;

    document.documentElement.style.setProperty('--faction', emblem.primary);
    document.documentElement.style.setProperty('--faction-2', `${emblem.primary}22`);

    paintCrest($('header-crest'), emblem);

    $('faction-name').textContent = state.name;
    $('faction-tag').textContent = `[${state.tag}]`;
    $('faction-motto').textContent = emblem.motto || '';

    const rank = state.ranks[state.grade] || state.ranks[state.ranks.length - 1];
    $('faction-rank').textContent = `${rank.icon} ${rank.label}`;

    $('faction-level').textContent = String(state.level);
    $('faction-kasse').textContent = money(state.kasse);
    $('faction-members').textContent = `${state.members.length} / ${state.memberSlots}`;
    $('faction-territories').textContent = String(state.territory.owned.length);

    $('faction-xp').textContent = String(state.xp);
    $('faction-xp-needed').textContent = String(state.xpNeeded);
    $('faction-xp-fill').style.width = state.xpNeeded > 0
        ? `${Math.min(100, (state.xp / state.xpNeeded) * 100)}%`
        : '100%';
}

function renderOverview() {
    const emblem = state.emblem;

    $('banner-backdrop').style.background = backdropStyle(emblem);
    paintCrest($('banner-crest'), emblem);
    $('banner-name').textContent = state.name;
    $('banner-motto').textContent = emblem.motto || 'Kein Wahlspruch gesetzt.';

    $('kasse-value').textContent = money(state.kasse);
    $('kasse-hint').textContent = state.permissions.kasseTake
        ? `Hoechstens ${money(state.maxWithdraw)} je Abhebung.`
        : 'Du darfst nur einzahlen.';
    $('btn-withdraw').disabled = !state.permissions.kasseTake;

    // Boni
    const LABELS = {
        memberSlots: ['Mitgliederplaetze', (v) => `+${v}`],
        vaultSlots: ['Tresorplaetze', (v) => `+${v}`],
        garageSlots: ['Fahrzeugplaetze', (v) => `+${v}`],
        shopDiscount: ['Shoprabatt', (v) => `${Math.round(v * 100)} %`],
        vehicleDiscount: ['Fahrzeugrabatt', (v) => `${Math.round(v * 100)} %`],
        territoryIncome: ['Gebietseinkommen', (v) => `+${Math.round(v * 100)} %`],
        missionReward: ['Missionsbelohnung', (v) => `+${Math.round(v * 100)} %`],
        captureSpeed: ['Einnahmetempo', (v) => `+${Math.round(v * 100)} %`],
        protectionBonus: ['Schutzzeit', (v) => `+${Math.round(v * 100)} %`],
        defenceBonus: ['Verteidigung', (v) => `+${Math.round(v * 100)} %`],
        payoutBonus: ['Auszahlungsrabatt', (v) => `${Math.round(v * 100)} %`],
    };

    const box = $('modifier-list');
    clear(box);

    let any = false;
    Object.entries(LABELS).forEach(([key, [label, format]]) => {
        const value = state.modifiers[key];
        if (!value) return;

        any = true;
        const row = el('div', 'modifier-row');
        row.appendChild(el('span', null, label));
        row.appendChild(el('b', null, format(value)));
        box.appendChild(row);
    });

    if (state.modifiers.soloCapture) {
        any = true;
        const row = el('div', 'modifier-row');
        row.appendChild(el('span', null, 'Alleiniges Einnehmen'));
        row.appendChild(el('b', null, 'aktiv'));
        box.appendChild(row);
    }

    if (!any) box.appendChild(el('p', 'muted', 'Noch keine Boni. Baue den Skilltree aus.'));

    $('btn-disband').parentElement.classList.toggle('hidden', !state.isOwner);
}

function renderLog(entries) {
    const box = $('log-list');
    clear(box);

    if (!entries.length) {
        box.appendChild(el('p', 'muted', 'Noch nichts passiert.'));
        return;
    }

    entries.forEach((entry) => {
        const row = el('div', 'log-row');
        row.appendChild(el('span', 'log-kind', entry.kind));
        row.appendChild(el('span', null, entry.text));

        const stamp = String(entry.created_at || '').replace('T', ' ').substr(5, 11);
        row.appendChild(el('span', 'log-time', stamp));

        box.appendChild(row);
    });
}

/* -------------------------------------------------------------- Mitglieder */

function renderMembers() {
    $('member-count').textContent = String(state.members.length);
    $('member-slots').textContent = String(state.memberSlots);
    $('invite-row').classList.toggle('hidden', !state.permissions.invite);

    const list = $('member-list');
    clear(list);

    state.members.forEach((member) => {
        const row = el('div', `member${member.online ? '' : ' offline'}`);

        row.appendChild(el('div', 'member-icon', member.rankIcon));

        const body = el('div');
        const name = el('div', 'member-name');
        if (member.online) name.appendChild(el('i', 'online-dot'));
        name.appendChild(el('span', null, member.name));
        if (member.owner) name.appendChild(el('span', 'owner-badge', 'Fuehrung'));
        body.appendChild(name);
        body.appendChild(el('div', 'member-sub',
            `${member.rankLabel} · eingezahlt ${money(member.contribution)}`));
        row.appendChild(body);

        // Rangauswahl
        const select = document.createElement('select');
        state.ranks.forEach((rank, index) => {
            const option = document.createElement('option');
            option.value = String(index);
            option.textContent = `${rank.icon} ${rank.label}`;
            select.appendChild(option);
        });
        select.value = String(member.grade);
        select.disabled = !state.permissions.promote || member.owner;
        select.addEventListener('change', () => {
            post('setGrade', { characterId: member.characterId, grade: Number(select.value) });
        });
        row.appendChild(select);

        const actions = el('div', 'member-actions');

        if (state.isOwner && !member.owner) {
            const transfer = el('button', 'btn small', 'Fuehrung');
            transfer.title = 'Fuehrung uebergeben';
            transfer.addEventListener('click', () => {
                post('transferOwner', { characterId: member.characterId });
            });
            actions.appendChild(transfer);
        }

        if (state.permissions.kick && !member.owner) {
            const kick = el('button', 'btn small danger', 'Entfernen');
            kick.addEventListener('click', () => {
                post('kick', { characterId: member.characterId });
            });
            actions.appendChild(kick);
        }

        row.appendChild(actions);
        list.appendChild(row);
    });
}

/* ------------------------------------------------------------------ Raenge */

function renderRanks() {
    if (!rankDraft) rankDraft = JSON.parse(JSON.stringify(state.ranks));

    const editable = state.isOwner;
    $('btn-rank-add').disabled = !editable || rankDraft.length >= 8;
    $('btn-rank-save').disabled = !editable;

    const box = $('rank-editor');
    clear(box);

    rankDraft.forEach((rank, index) => {
        const top = index === rankDraft.length - 1;
        const card = el('div', 'rank-card');

        const head = el('div', 'rank-card-head');
        head.appendChild(el('div', 'grade', String(index)));

        const input = document.createElement('input');
        input.type = 'text';
        input.maxLength = 24;
        input.value = rank.label;
        input.disabled = !editable;
        input.addEventListener('input', () => { rank.label = input.value; });
        head.appendChild(input);

        if (top) head.appendChild(el('span', 'chip', 'Fuehrung · alle Rechte'));

        if (editable && !top && rankDraft.length > 2) {
            const remove = el('button', 'btn small danger', 'Entfernen');
            remove.addEventListener('click', () => {
                rankDraft.splice(index, 1);
                renderRanks();
            });
            head.appendChild(remove);
        }

        card.appendChild(head);

        // Icons
        const picker = el('div', 'icon-picker');
        (state.rankIcons || []).forEach((icon) => {
            const option = el('div', `icon-option${rank.icon === icon ? ' active' : ''}`, icon);
            if (editable) {
                option.addEventListener('click', () => {
                    rank.icon = icon;
                    renderRanks();
                });
            }
            picker.appendChild(option);
        });
        card.appendChild(picker);

        // Rechte
        const grid = el('div', 'permission-grid');
        const owned = Array.isArray(rank.permissions) ? rank.permissions : [];

        state.permissionList.forEach((entry) => {
            const on = top || owned.includes(entry.id);
            const cell = el('div',
                `permission${on ? ' on' : ''}${(!editable || top) ? ' locked' : ''}`);
            cell.appendChild(el('span', null, entry.icon));
            cell.appendChild(el('span', null, entry.label));

            if (editable && !top) {
                cell.addEventListener('click', () => {
                    if (!Array.isArray(rank.permissions)) rank.permissions = [];

                    const position = rank.permissions.indexOf(entry.id);
                    if (position >= 0) rank.permissions.splice(position, 1);
                    else rank.permissions.push(entry.id);

                    renderRanks();
                });
            }

            grid.appendChild(cell);
        });

        card.appendChild(grid);
        box.appendChild(card);
    });
}

$('btn-rank-add').addEventListener('click', () => {
    if (!rankDraft || rankDraft.length >= 8) return;

    rankDraft.splice(rankDraft.length - 1, 0, {
        label: `Rang ${rankDraft.length}`,
        icon: '●',
        permissions: [],
    });

    renderRanks();
});

$('btn-rank-save').addEventListener('click', () => {
    if (rankDraft) post('setRanks', { ranks: rankDraft });
});

/* --------------------------------------------------------------- Skilltree */

function drawSkillTree() {
    if (!state) return;

    const nodes = state.skillTree || [];
    const canvas = $('skill-canvas');
    const links = $('skill-links');
    const box = $('skill-nodes');

    clear(links);
    clear(box);

    $('skill-points').textContent = String(state.points);
    $('skill-spent').textContent = String(state.spent);
    $('btn-skill-reset').disabled = !state.isOwner || state.spent === 0;

    const rows = Math.max(...nodes.map((node) => node.row)) + 1;
    const cols = Math.max(...nodes.map((node) => node.col)) + 1;

    const width = canvas.clientWidth || 800;
    const height = Math.max(canvas.clientHeight || 480, rows * 130);
    canvas.style.minHeight = `${rows * 130}px`;

    const position = (node) => ({
        x: ((node.col + 0.5) / cols) * width,
        y: ((node.row + 0.6) / rows) * height,
    });

    const byId = {};
    nodes.forEach((node) => { byId[node.id] = node; });

    // Verbindungen
    nodes.forEach((node) => {
        (node.requires || []).forEach((requiredId) => {
            const parent = byId[requiredId];
            if (!parent) return;

            const from = position(parent);
            const to = position(node);

            links.appendChild(svg('line', {
                x1: from.x, y1: from.y, x2: to.x, y2: to.y,
                stroke: node.unlocked ? state.emblem.primary : 'rgba(255,255,255,.12)',
                'stroke-width': node.unlocked ? '3' : '2',
            }));
        });
    });

    // Knoten
    nodes.forEach((node) => {
        const point = position(node);

        const item = el('div', 'node');
        if (node.unlocked) item.classList.add('unlocked');
        if (node.available) item.classList.add('available');
        if (node.blocked) item.classList.add('blocked');
        if (selectedSkill === node.id) item.classList.add('selected');

        item.style.left = `${point.x}px`;
        item.style.top = `${point.y}px`;

        item.appendChild(el('div', 'node-icon', node.icon));
        item.appendChild(el('div', 'node-rank', `${node.rank} / ${node.maxRank}`));
        item.appendChild(el('div', 'node-label', node.label));

        item.addEventListener('click', () => {
            selectedSkill = node.id;
            drawSkillTree();
            renderSkillDetail(node);
        });

        box.appendChild(item);
    });

    const selected = nodes.find((node) => node.id === selectedSkill);
    renderSkillDetail(selected);
}

function renderSkillDetail(node) {
    const box = $('skill-detail');
    clear(box);

    if (!node) {
        box.appendChild(el('div', 'detail-empty', 'Waehle einen Knoten.'));
        return;
    }

    box.appendChild(el('h3', null, `${node.icon} ${node.label}`));
    box.appendChild(el('p', 'muted', node.description));

    if (node.current.length) {
        box.appendChild(el('div', 'section-caption', `Aktuell (Stufe ${node.rank})`));
        const list = el('div', 'effect-list');
        node.current.forEach((line) => list.appendChild(el('div', 'effect', line)));
        box.appendChild(list);
    }

    if (node.next.length) {
        box.appendChild(el('div', 'section-caption', `Naechste Stufe (${node.rank + 1})`));
        const list = el('div', 'effect-list');
        node.next.forEach((line) => list.appendChild(el('div', 'effect', line)));
        box.appendChild(list);
    }

    if (node.rank >= node.maxRank) {
        box.appendChild(el('p', 'muted', 'Vollstaendig ausgebaut.'));
        return;
    }

    if (node.blocked) {
        box.appendChild(el('p', 'muted', node.reason));
        return;
    }

    const button = el('button', 'btn primary', `Ausbauen (${node.cost} Punkte)`);
    button.disabled = !state.permissions.skills || state.points < node.cost;
    button.addEventListener('click', () => post('upgradeSkill', { id: node.id }));
    box.appendChild(button);
}

$('btn-skill-reset').addEventListener('click', () => post('resetSkills'));

/* ------------------------------------------------------------------ Gebiete */

/** Weltkoordinaten auf die Karte projizieren. */
function project(coords) {
    return {
        x: ((coords.x + 4000) / 8500) * 1000,
        y: ((8000 - coords.y) / 12000) * 1000,
    };
}

function drawMap() {
    const canvas = $('map-svg');
    clear(canvas);

    const list = (state && state.territory.list) || territories;

    // Grober Umriss als Orientierung.
    canvas.appendChild(svg('rect', {
        x: '0', y: '0', width: '1000', height: '1000', fill: 'transparent',
    }));

    list.forEach((entry) => {
        const point = project(entry.coords);
        const radius = Math.max(14, (entry.radius / 12000) * 1000 * 3.2);
        const colour = entry.emblem ? entry.emblem.primary : '#6d6a7a';

        const group = svg('g', { class: 'map-zone' });

        group.appendChild(svg('circle', {
            cx: point.x, cy: point.y, r: radius,
            fill: `${colour}33`,
            stroke: colour,
            'stroke-width': entry.factionId ? '2.5' : '1.5',
            'stroke-dasharray': entry.factionId ? '' : '6 5',
        }));

        const label = svg('text', {
            x: point.x, y: point.y + 4,
            'text-anchor': 'middle',
            'font-size': '17',
            fill: '#ece9f5',
        });
        label.textContent = entry.icon;
        group.appendChild(label);

        const name = svg('text', {
            x: point.x, y: point.y + radius + 16,
            'text-anchor': 'middle',
            'font-size': '13',
            fill: entry.factionId ? colour : '#8b8399',
        });
        name.textContent = entry.factionTag ? `${entry.label} [${entry.factionTag}]` : entry.label;
        group.appendChild(name);

        if (entry.progress > 0) {
            group.appendChild(svg('circle', {
                cx: point.x, cy: point.y, r: radius + 6,
                fill: 'none', stroke: '#d8b25f', 'stroke-width': '3',
                'stroke-dasharray': `${(entry.progress / 100) * radius * 6.28} 999`,
                transform: `rotate(-90 ${point.x} ${point.y})`,
            }));
        }

        canvas.appendChild(group);
    });

    renderTerritoryList(list);
}

function renderTerritoryList(list) {
    if (state) {
        $('territory-income').textContent = money(state.territory.income);
        $('territory-interval').textContent = String(state.territory.interval);
    }

    const box = $('territory-list');
    clear(box);

    list.forEach((entry) => {
        const own = state && entry.factionId === state.id;
        const card = el('div', `territory${own ? ' own' : ''}`);

        const head = el('div', 'territory-head');
        head.appendChild(el('span', null, entry.icon));
        head.appendChild(el('h3', null, entry.label));

        const owner = el('span', `territory-owner${entry.factionId ? '' : ' free'}`,
            entry.factionName ? `[${entry.factionTag}] ${entry.factionName}` : 'frei');
        if (entry.emblem) owner.style.color = entry.emblem.primary;
        head.appendChild(owner);

        card.appendChild(head);
        card.appendChild(el('p', 'muted', entry.description));

        const meta = el('div', 'territory-meta');
        meta.appendChild(el('span', null, `${money(entry.income)} je Ausschuettung`));
        if (entry.protected) {
            meta.appendChild(el('span', null,
                `geschuetzt noch ${Math.ceil(entry.protectedFor / 60)} Min.`));
        }
        if (entry.contested) meta.appendChild(el('span', null, 'umkaempft'));
        card.appendChild(meta);

        if (entry.progress > 0) {
            const track = el('div', 'capture-track');
            const fill = el('i');
            fill.style.width = `${Math.min(100, entry.progress)}%`;
            track.appendChild(fill);
            card.appendChild(track);
        }

        box.appendChild(card);
    });
}

/* ---------------------------------------------------------------- Missionen */

function renderMissions() {
    const box = $('faction-mission-list');
    clear(box);

    const missions = state.missions || [];
    if (!missions.length) {
        box.appendChild(el('p', 'muted', 'Aktuell laufen keine Missionen.'));
        return;
    }

    missions.forEach((mission) => {
        const card = el('div',
            `mission${mission.done ? ' done' : ''}${mission.claimed ? ' claimed' : ''}`);

        card.appendChild(el('div', 'mission-icon', mission.icon));

        const body = el('div', 'mission-body');
        body.appendChild(el('h3', null, mission.label));
        body.appendChild(el('p', null, mission.description));

        const progress = el('div', 'mission-progress');
        const bar = el('div', 'mission-bar');
        const fill = el('i');
        fill.style.width = `${Math.min(100, (mission.progress / mission.goal) * 100)}%`;
        bar.appendChild(fill);
        progress.appendChild(bar);
        progress.appendChild(el('span', 'mission-count',
            `${mission.progress.toLocaleString('de-DE')} / ${mission.goal.toLocaleString('de-DE')}`));
        body.appendChild(progress);

        body.appendChild(el('div', 'mission-reward',
            `${money(mission.kasse)} für die Kasse · ${mission.xp} Fraktions-XP`));
        card.appendChild(body);

        const button = el('button', 'btn small');
        if (mission.claimed) {
            button.textContent = 'Abgerechnet';
            button.disabled = true;
        } else if (mission.done) {
            button.textContent = 'Abrechnen';
            button.className = 'btn small ok';
            button.disabled = !state.permissions.missions;
            button.addEventListener('click', () => post('claimMission', { id: mission.id }));
        } else {
            button.textContent = 'Laeuft';
            button.disabled = true;
        }
        card.appendChild(button);

        box.appendChild(card);
    });
}

/* ------------------------------------------------------------------- Tresor */

async function loadInventory() {
    const result = await ask('requestInventory');
    inventory = Array.isArray(result) ? result : Object.values(result || {});
    renderVault();
}

function renderVault() {
    const vault = state.vault;

    $('vault-used').textContent = String(vault.used);
    $('vault-slots').textContent = String(vault.slots);
    $('vault-weight').textContent = vault.weight.toLocaleString('de-DE');

    // Eigenes Inventar
    const own = $('inventory-list');
    clear(own);

    const items = inventory.filter((entry) => entry && entry.name);

    if (!items.length) {
        own.appendChild(el('p', 'muted', 'Dein Inventar ist leer.'));
    }

    items.forEach((entry) => {
        const row = el('div', 'item-row');

        const body = el('div');
        body.appendChild(el('div', null, entry.label || entry.name));
        body.appendChild(el('div', 'count', `${entry.count}x · Slot ${entry.slot}`));
        row.appendChild(body);

        const amount = document.createElement('input');
        amount.type = 'number';
        amount.min = '1';
        amount.max = String(entry.count);
        amount.value = '1';
        row.appendChild(amount);

        const button = el('button', 'btn small', 'Einlagern');
        button.disabled = !state.permissions.vaultPut;
        button.addEventListener('click', () => {
            post('vaultPut', { slot: entry.slot, count: Number(amount.value) || 1 });
            setTimeout(loadInventory, 400);
        });
        row.appendChild(button);

        own.appendChild(row);
    });

    // Tresor
    const box = $('vault-list');
    clear(box);

    if (!vault.entries.length) {
        box.appendChild(el('p', 'muted', 'Der Tresor ist leer.'));
    }

    vault.entries.forEach((entry) => {
        const row = el('div', 'item-row');

        const body = el('div');
        body.appendChild(el('div', null, entry.label));
        body.appendChild(el('div', 'count', `${entry.count}x · ${entry.weight} g`));
        row.appendChild(body);

        const amount = document.createElement('input');
        amount.type = 'number';
        amount.min = '1';
        amount.max = String(entry.count);
        amount.value = '1';
        row.appendChild(amount);

        const button = el('button', 'btn small', 'Entnehmen');
        button.disabled = !state.permissions.vaultTake;
        button.addEventListener('click', () => {
            post('vaultTake', { index: entry.index, count: Number(amount.value) || 1 });
            setTimeout(loadInventory, 400);
        });
        row.appendChild(button);

        box.appendChild(row);
    });
}

/* --------------------------------------------------------------------- Shop */

function renderShop() {
    const shop = state.shop;

    $('shop-discount').textContent = shop.discount > 0
        ? `Dank Handelsnetz ${Math.round(shop.discount * 100)} % guenstiger.`
        : '';

    const grid = $('shop-grid');
    clear(grid);

    if (!shop.enabled) {
        grid.appendChild(el('p', 'muted', 'Der Shop ist abgeschaltet.'));
        return;
    }

    shop.items.forEach((entry) => {
        const card = el('div', 'shop-card');
        card.appendChild(el('h3', null, entry.label));

        const price = el('div', 'shop-price', money(entry.price));
        if (entry.price < entry.base) {
            const old = document.createElement('s');
            old.textContent = money(entry.base);
            price.appendChild(old);
        }
        card.appendChild(price);

        const row = el('div', 'shop-row');
        const amount = document.createElement('input');
        amount.type = 'number';
        amount.min = '1';
        amount.max = '50';
        amount.value = '1';
        row.appendChild(amount);

        const button = el('button', 'btn small primary', 'Kaufen');
        button.disabled = !state.permissions.shop;
        button.addEventListener('click', () => {
            post('buyItem', { name: entry.name, amount: Number(amount.value) || 1 });
        });
        row.appendChild(button);

        card.appendChild(row);
        grid.appendChild(card);
    });
}

/* ------------------------------------------------------------------- Garage */

function renderGarage() {
    const garage = state.garage;

    $('garage-used').textContent = String(garage.used);
    $('garage-slots').textContent = String(garage.slots);

    const select = $('garage-point');
    const previous = select.value;
    clear(select);

    (garage.points || []).forEach((point) => {
        const option = document.createElement('option');
        option.value = String(point.index);
        option.textContent = point.label;
        select.appendChild(option);
    });
    if (previous) select.value = previous;

    // Eigene Fahrzeuge
    const own = $('vehicle-list');
    clear(own);

    if (!garage.vehicles.length) {
        own.appendChild(el('p', 'muted', 'Noch keine Fahrzeuge gekauft.'));
    }

    garage.vehicles.forEach((vehicle) => {
        const row = el('div', 'vehicle');

        const body = el('div');
        const title = el('h3', null, vehicle.label);
        if (!vehicle.stored) title.appendChild(el('span', 'out', 'unterwegs'));
        body.appendChild(title);
        body.appendChild(el('span', 'plate', vehicle.plate));
        row.appendChild(body);

        const actions = el('div', 'vehicle-actions');

        const grade = document.createElement('select');
        state.ranks.forEach((rank, index) => {
            const option = document.createElement('option');
            option.value = String(index);
            option.textContent = rank.icon;
            option.title = rank.label;
            grade.appendChild(option);
        });
        grade.value = String(vehicle.minGrade);
        grade.disabled = !state.permissions.manage;
        grade.title = 'Mindestrang';
        grade.addEventListener('change', () => {
            post('setVehicleGrade', { id: vehicle.id, grade: Number(grade.value) });
        });
        actions.appendChild(grade);

        const take = el('button', 'btn small primary', 'Ausparken');
        take.disabled = !vehicle.available;
        take.addEventListener('click', () => {
            post('takeVehicle', { id: vehicle.id, point: Number(select.value) || 1 });
            post('close');
        });
        actions.appendChild(take);

        if (state.permissions.garageBuy) {
            const sell = el('button', 'btn small danger', 'Verkaufen');
            sell.disabled = !vehicle.stored;
            sell.addEventListener('click', () => post('sellVehicle', { id: vehicle.id }));
            actions.appendChild(sell);
        }

        row.appendChild(actions);
        own.appendChild(row);
    });

    // Haendler
    const catalogue = $('catalogue-list');
    clear(catalogue);

    garage.catalogue.forEach((entry) => {
        const row = el('div', 'vehicle');

        const body = el('div');
        body.appendChild(el('h3', null, entry.label));
        body.appendChild(el('div', 'muted',
            `${money(entry.price)} · ab Rang ${entry.minRank}`));
        row.appendChild(body);

        const button = el('button', 'btn small primary', 'Kaufen');
        button.disabled = !state.permissions.garageBuy || garage.used >= garage.slots;
        button.addEventListener('click', () => post('buyVehicle', { value: entry.model }));
        row.appendChild(button);

        catalogue.appendChild(row);
    });
}

/* ------------------------------------------------------------------- Wappen */

function optionRow(container, entries, current, onPick, render) {
    clear(container);

    entries.forEach((entry) => {
        const option = el('div', `option${entry.id === current ? ' active' : ''}`);
        if (render) render(option, entry);
        else option.textContent = entry.label;

        option.title = entry.label;
        option.addEventListener('click', () => onPick(entry.id));
        container.appendChild(option);
    });
}

function renderEmblemEditor() {
    if (!draft) draft = JSON.parse(JSON.stringify(state.emblem));

    const options = state.options;

    paintCrest($('emblem-preview'), draft, options);
    paintCrest($('emblem-banner-crest'), draft, options);
    $('emblem-banner-backdrop').style.background = backdropStyle(draft);
    $('emblem-banner-name').textContent = $('emblem-name').value || state.name;
    $('emblem-banner-motto').textContent = draft.motto || '';

    optionRow($('shape-row'), options.shapes, draft.shape, (id) => {
        draft.shape = id;
        renderEmblemEditor();
    }, (option, entry) => {
        const preview = el('div', 'mini');
        preview.appendChild(buildCrest({ ...draft, shape: entry.id }, options));
        option.appendChild(preview);
    });

    optionRow($('symbol-row'), options.symbols, draft.symbol, (id) => {
        draft.symbol = id;
        renderEmblemEditor();
    }, (option, entry) => { option.textContent = entry.glyph; });

    optionRow($('pattern-row'), options.patterns, draft.pattern, (id) => {
        draft.pattern = id;
        renderEmblemEditor();
    });

    optionRow($('backdrop-row'), options.backdrops, draft.backdrop, (id) => {
        draft.backdrop = id;
        renderEmblemEditor();
    });

    const colours = options.palette.map((hex) => ({ id: hex, label: hex }));

    optionRow($('primary-row'), colours, draft.primary, (id) => {
        draft.primary = id;
        renderEmblemEditor();
    }, (option, entry) => {
        option.classList.add('colour');
        option.style.background = entry.id;
    });

    optionRow($('secondary-row'), colours, draft.secondary, (id) => {
        draft.secondary = id;
        renderEmblemEditor();
    }, (option, entry) => {
        option.classList.add('colour');
        option.style.background = entry.id;
    });

    const editable = state.permissions.manage;
    $('btn-emblem-save').disabled = !editable;
    $('emblem-motto').disabled = !editable;
    $('emblem-welcome').disabled = !editable;
    $('btn-rename').disabled = !state.isOwner;
}

$('emblem-motto').addEventListener('input', (event) => {
    if (!draft) return;
    draft.motto = event.target.value;
    $('emblem-banner-motto').textContent = draft.motto;
});

$('emblem-welcome').addEventListener('input', (event) => {
    if (draft) draft.welcome = event.target.value;
});

$('emblem-name').addEventListener('input', () => {
    $('emblem-banner-name').textContent = $('emblem-name').value;
});

$('btn-emblem-save').addEventListener('click', () => {
    if (draft) post('setEmblem', { emblem: draft });
});

$('btn-rename').addEventListener('click', () => {
    post('rename', { name: $('emblem-name').value, tag: $('emblem-tag').value });
});

/* ----------------------------------------------------------------- Rendern */

function render() {
    if (!state) {
        $('view-none').classList.remove('hidden');
        $('view-faction').classList.add('hidden');
        return;
    }

    $('view-none').classList.add('hidden');
    $('view-faction').classList.remove('hidden');

    renderHeader();
    renderOverview();
    renderMembers();

    rankDraft = null;
    renderRanks();

    drawSkillTree();
    renderMissions();
    renderVault();
    renderShop();
    renderGarage();

    draft = null;
    $('emblem-name').value = state.name;
    $('emblem-tag').value = state.tag;
    $('emblem-motto').value = state.emblem.motto || '';
    $('emblem-welcome').value = state.emblem.welcome || '';
    renderEmblemEditor();

    if (activeTab === 'territory') drawMap();
    else renderTerritoryList(state.territory.list);
}

function renderList() {
    const box = $('faction-list');
    clear(box);

    if (!factionList.length) {
        box.appendChild(el('p', 'muted', 'Es gibt noch keine Fraktion. Sei die erste.'));
        return;
    }

    factionList.forEach((entry) => {
        const row = el('div', 'faction-row');

        const crest = el('div', 'crest-mini');
        crest.appendChild(buildCrest(entry.emblem));
        row.appendChild(crest);

        const body = el('div', 'grow');
        body.appendChild(el('h3', null, `${entry.name} [${entry.tag}]`));
        body.appendChild(el('div', 'muted',
            `Level ${entry.level} · ${entry.members} Mitglieder · ${entry.territories} Gebiete`));
        row.appendChild(body);

        if (entry.emblem.motto) {
            row.appendChild(el('span', 'motto', entry.emblem.motto));
        }

        box.appendChild(row);
    });
}

/* ---------------------------------------------------------------- Aktionen */

$('btn-close').addEventListener('click', () => post('close'));
$('btn-close-none').addEventListener('click', () => post('close'));

$('btn-create').addEventListener('click', () => {
    post('create', { name: $('create-name').value, tag: $('create-tag').value });
});

$('btn-invite').addEventListener('click', () => {
    post('invite', { value: Number($('invite-id').value) || 0 });
});

$('btn-leave').addEventListener('click', () => post('leave'));

$('btn-disband').addEventListener('click', () => {
    post('disband', { confirmation: $('disband-confirm').value });
});

$('btn-deposit').addEventListener('click', () => {
    post('deposit', { amount: Number($('kasse-amount').value) || 0 });
});

$('btn-withdraw').addEventListener('click', () => {
    post('withdraw', { amount: Number($('kasse-amount').value) || 0 });
});

$('btn-invite-accept').addEventListener('click', () => {
    post('acceptInvite');
    $('invite').classList.add('hidden');
});

$('btn-invite-decline').addEventListener('click', () => {
    post('declineInvite');
    $('invite').classList.add('hidden');
});

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !$('screen').classList.contains('hidden')) post('close');
});

/* ---------------------------------------------------- Gebietskontroll-Anzeige */

function showControl(entry) {
    controlEntry = entry;

    $('control').classList.remove('hidden');
    $('control-icon').textContent = entry.icon;
    $('control-name').textContent = entry.label;
    $('control-owner').textContent = entry.factionName
        ? `[${entry.factionTag}] ${entry.factionName}`
        : 'unbesetzt';

    updateControl(entry.progress || 0, entry.contested || false);
}

function updateControl(progress, contested) {
    $('control-fill').style.width = `${Math.min(100, progress)}%`;

    const label = $('control-state');
    label.classList.remove('contested', 'capturing');

    if (contested) {
        label.textContent = 'Umkaempft - der Balken steht still.';
        label.classList.add('contested');
    } else if (progress > 0) {
        label.textContent = `Einnahme laeuft: ${Math.floor(progress)} %`;
        label.classList.add('capturing');
    } else if (controlEntry && controlEntry.protected) {
        label.textContent = 'Geschuetzt - noch nicht angreifbar.';
    } else if (controlEntry && controlEntry.factionId) {
        label.textContent = 'Gehalten. Steht drin, um es zu uebernehmen.';
    } else {
        label.textContent = 'Unbesetzt. Steht drin, um es einzunehmen.';
    }
}

/* -------------------------------------------------------------- Nachrichten */

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'factions:open':
            $('screen').classList.remove('hidden');
            activateTab(state ? activeTab : 'overview');
            break;

        case 'factions:close':
            $('screen').classList.add('hidden');
            break;

        case 'factions:data':
            state = message.data && message.data.id ? message.data : null;
            if (state && state.options) {
                SHAPES = state.options.shapes;
                SYMBOLS = state.options.symbols;
            }
            render();
            break;

        case 'factions:options':
            SHAPES = (message.data && message.data.shapes) || [];
            SYMBOLS = (message.data && message.data.symbols) || [];
            break;

        case 'factions:list':
            factionList = message.data || [];
            renderList();
            break;

        case 'factions:log':
            renderLog(message.data || []);
            break;

        case 'factions:territories':
            territories = message.data || [];
            if (state) state.territory.list = territories;
            if (activeTab === 'territory') drawMap();
            break;

        case 'factions:invite': {
            const payload = message.data || {};
            $('invite').classList.remove('hidden');
            $('invite-title').textContent = `${payload.faction.name} [${payload.faction.tag}]`;
            $('invite-text').textContent = `${payload.by} laedt dich ein.`;
            paintCrest($('invite-crest'), payload.faction.emblem);

            setTimeout(() => $('invite').classList.add('hidden'),
                (payload.seconds || 60) * 1000);
            break;
        }

        case 'factions:welcome': {
            const payload = message.data || {};
            const emblem = payload.emblem || {};

            $('welcome').classList.remove('hidden');
            $('welcome-backdrop').style.background = backdropStyle(emblem);
            paintCrest($('welcome-crest'), emblem);
            $('welcome-name').textContent = payload.name;
            $('welcome-tag').textContent = `[${payload.tag}]`;
            $('welcome-motto').textContent = emblem.motto || '';
            $('welcome-text').textContent = emblem.welcome || '';
            $('welcome-level').textContent = String(payload.level);
            $('welcome-members').textContent = String(payload.members);

            document.documentElement.style.setProperty('--faction', emblem.primary || '#9b6bd8');

            setTimeout(() => $('welcome').classList.add('hidden'), 6500);
            break;
        }

        case 'factions:control':
            showControl(message.data || {});
            break;

        case 'factions:controlTick':
            if (controlEntry) {
                updateControl(message.data.progress || 0, message.data.contested || false);
            }
            break;

        case 'factions:controlOff':
            controlEntry = null;
            $('control').classList.add('hidden');
            break;

        default:
            break;
    }
});
