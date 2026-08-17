--- Rassenskills und Skilltree.
---
--- Jeder Skill:
---   id          eindeutiger Schluessel
---   race        zugehoerige Rasse
---   tier        Stufe im Baum (1-4)
---   requires    Liste von Skill-IDs, die vorher freigeschaltet sein muessen
---   unlock      { points = Skillpunkte, stones = { item = anzahl } }
---   cooldown    Sekunden
---   cost        Essenzkosten
---   effect      Wirkung, siehe client/abilities.lua
---   passive     true = wirkt dauerhaft, kann nicht auf die Leiste gelegt werden
---
--- Effekt-Arten:
---   drain, heal_self, heal_target, revive_target, aoe_damage, projectile,
---   curse, poison, self_buff, shield, blink, leap, stealth, reveal,
---   nightvision, transform, fear, passive

local T = {
    [1] = { points = 1, stones = { runenstein = 2 } },
    [2] = { points = 1, stones = { runenstein = 4, seelenstein = 1 } },
    [3] = { points = 2, stones = { runenstein = 6 } },
    [4] = { points = 3, stones = { runenstein = 10, seelenstein = 2 } },
}

--- Baut die Freischaltkosten einer Stufe inkl. rassenspezifischem Stein.
local function cost(tier, raceStone, raceStoneCount)
    local stones = {}
    for item, count in pairs(T[tier].stones) do stones[item] = count end
    if raceStone then stones[raceStone] = raceStoneCount or 1 end

    return { points = T[tier].points, stones = stones }
end

Mystic.Skills = {

    -- Vampir -----------------------------------------------------------------
    { id = 'vampir_blutdurst', race = 'vampir', tier = 1, label = 'Blutdurst', icon = '🩸',
      description = 'Entzieht allen Wesen im Umkreis Lebenskraft und heilt dich.',
      cooldown = 45, cost = 25, requires = {}, unlock = cost(1),
      effect = { kind = 'drain', radius = 6.0, damage = 22, heal = 28 } },

    { id = 'vampir_nachtsicht', race = 'vampir', tier = 1, label = 'Nachtsicht', icon = '👁',
      description = 'Deine Augen durchdringen die Dunkelheit.',
      cooldown = 60, cost = 15, requires = {}, unlock = cost(1),
      effect = { kind = 'nightvision', duration = 60 } },

    { id = 'vampir_nebelform', race = 'vampir', tier = 2, label = 'Nebelform', icon = '🌫',
      description = 'Du loest dich in Nebel auf und wirst beinahe unsichtbar.',
      cooldown = 90, cost = 40, requires = { 'vampir_nachtsicht' }, unlock = cost(2, 'blutstein'),
      effect = { kind = 'stealth', duration = 12, alpha = 40, speedMult = 1.15 } },

    { id = 'vampir_fledermausschritt', race = 'vampir', tier = 3, label = 'Fledermausschritt', icon = '🦇',
      description = 'Du loest dich auf und erscheinst weiter vorn wieder.',
      cooldown = 30, cost = 30, requires = { 'vampir_nebelform' }, unlock = cost(3, 'blutstein', 2),
      effect = { kind = 'blink', distance = 22.0 } },

    { id = 'vampir_kind_der_nacht', race = 'vampir', tier = 4, label = 'Kind der Nacht', icon = '🌒',
      description = 'Das Sonnenlicht verliert seinen Schrecken, dein Blut wird staerker.',
      passive = true, requires = { 'vampir_blutdurst', 'vampir_fledermausschritt' },
      unlock = cost(4, 'blutstein', 3),
      effect = { kind = 'passive', sunImmune = true, healthBonus = 20, meleeMult = 0.15 } },

    -- Werwolf ----------------------------------------------------------------
    { id = 'werwolf_wittern', race = 'werwolf', tier = 1, label = 'Wittern', icon = '👃',
      description = 'Du nimmst die Faehrte aller Wesen in der Umgebung auf.',
      cooldown = 45, cost = 15, requires = {}, unlock = cost(1),
      effect = { kind = 'reveal', radius = 90.0, duration = 20 } },

    { id = 'werwolf_krallenhieb', race = 'werwolf', tier = 1, label = 'Krallenhieb', icon = '🐾',
      description = 'Ein Hieb, der alles vor dir zerfetzt.',
      cooldown = 20, cost = 20, requires = {}, unlock = cost(1),
      effect = { kind = 'aoe_damage', radius = 4.0, damage = 35, ragdoll = true } },

    { id = 'werwolf_blutrausch', race = 'werwolf', tier = 2, label = 'Blutrausch', icon = '💢',
      description = 'Die Wut uebernimmt: mehr Nahkampfschaden, mehr Tempo.',
      cooldown = 100, cost = 35, requires = { 'werwolf_krallenhieb' }, unlock = cost(2, 'mondstein'),
      effect = { kind = 'self_buff', duration = 20, meleeMult = 1.8, speedMult = 1.25, armor = 25 } },

    { id = 'werwolf_verwandlung', race = 'werwolf', tier = 3, label = 'Verwandlung', icon = '🐺',
      description = 'Du nimmst deine wahre Gestalt an.',
      cooldown = 240, cost = 60, requires = { 'werwolf_blutrausch' }, unlock = cost(3, 'mondstein', 2),
      effect = { kind = 'transform', duration = 45, model = 'a_c_rottweiler',
                 healthBonus = 60, meleeMult = 2.0, speedMult = 1.3 } },

    { id = 'werwolf_mondgesegnet', race = 'werwolf', tier = 4, label = 'Mondgesegnet', icon = '🌕',
      description = 'Der Mond staerkt dich dauerhaft.',
      passive = true, requires = { 'werwolf_verwandlung', 'werwolf_wittern' },
      unlock = cost(4, 'mondstein', 3),
      effect = { kind = 'passive', healthBonus = 40, meleeMult = 0.25, regenPerTick = 2 } },

    -- Daemon -----------------------------------------------------------------
    { id = 'daemon_feuerball', race = 'daemon', tier = 1, label = 'Feuerball', icon = '☄',
      description = 'Schleudert eine Flammenkugel auf dein Ziel.',
      cooldown = 12, cost = 20, requires = {}, unlock = cost(1),
      effect = { kind = 'projectile', damage = 45, element = 'fire', range = 60.0 } },

    { id = 'daemon_schwefelhaut', race = 'daemon', tier = 1, label = 'Schwefelhaut', icon = '🛡',
      description = 'Deine Haut verhaertet sich zu Schwefelgestein.',
      cooldown = 90, cost = 30, requires = {}, unlock = cost(1),
      effect = { kind = 'shield', armor = 75, duration = 30 } },

    { id = 'daemon_hoellenschlag', race = 'daemon', tier = 2, label = 'Hoellenschlag', icon = '🔥',
      description = 'Der Boden birst und Flammen schlagen empor.',
      cooldown = 60, cost = 45, requires = { 'daemon_feuerball' }, unlock = cost(2, 'flammenstein'),
      effect = { kind = 'aoe_damage', radius = 8.0, damage = 55, fire = true, ragdoll = true } },

    { id = 'daemon_furcht', race = 'daemon', tier = 3, label = 'Furcht', icon = '😱',
      description = 'Wer dich ansieht, verliert die Kontrolle.',
      cooldown = 75, cost = 40, requires = { 'daemon_hoellenschlag' }, unlock = cost(3, 'flammenstein', 2),
      effect = { kind = 'fear', radius = 12.0, duration = 8 } },

    { id = 'daemon_hoellenblut', race = 'daemon', tier = 4, label = 'Hoellenblut', icon = '🩸',
      description = 'Feuer kann dir nichts mehr anhaben.',
      passive = true, requires = { 'daemon_furcht', 'daemon_schwefelhaut' },
      unlock = cost(4, 'flammenstein', 3),
      effect = { kind = 'passive', fireImmune = true, healthBonus = 30, regenPerTick = 2 } },

    -- Fee --------------------------------------------------------------------
    { id = 'fee_bluete', race = 'fee', tier = 1, label = 'Heilende Bluete', icon = '🌸',
      description = 'Naturkraft schliesst deine Wunden.',
      cooldown = 40, cost = 25, requires = {}, unlock = cost(1),
      effect = { kind = 'heal_self', amount = 45 } },

    { id = 'fee_flatterschritt', race = 'fee', tier = 1, label = 'Flatterschritt', icon = '🍃',
      description = 'Ein Flügelschlag traegt dich in die Hoehe.',
      cooldown = 15, cost = 15, requires = {}, unlock = cost(1),
      effect = { kind = 'leap', force = 9.0, noFallDamage = true } },

    { id = 'fee_segen', race = 'fee', tier = 2, label = 'Segen', icon = '✨',
      description = 'Heilt das Wesen vor dir.',
      cooldown = 45, cost = 35, requires = { 'fee_bluete' }, unlock = cost(2, 'feenstaub'),
      effect = { kind = 'heal_target', range = 12.0, amount = 60 } },

    { id = 'fee_schimmer', race = 'fee', tier = 3, label = 'Schimmer', icon = '💫',
      description = 'Du verschwimmst zu einem Lichtschimmer.',
      cooldown = 80, cost = 40, requires = { 'fee_flatterschritt' }, unlock = cost(3, 'feenstaub', 2),
      effect = { kind = 'stealth', duration = 15, alpha = 25, speedMult = 1.25 } },

    { id = 'fee_naturkind', race = 'fee', tier = 4, label = 'Naturkind', icon = '🌿',
      description = 'Die Natur haelt dich auf den Beinen.',
      passive = true, requires = { 'fee_segen', 'fee_schimmer' },
      unlock = cost(4, 'feenstaub', 3),
      effect = { kind = 'passive', noFallDamage = true, essenceRegen = 1.0, healthBonus = 20 } },

    -- Magier -----------------------------------------------------------------
    { id = 'magier_arkanschlag', race = 'magier', tier = 1, label = 'Arkanschlag', icon = '🔮',
      description = 'Ein gebuendelter Energiestoss.',
      cooldown = 10, cost = 18, requires = {}, unlock = cost(1),
      effect = { kind = 'projectile', damage = 40, element = 'arcane', range = 70.0 } },

    { id = 'magier_blinzeln', race = 'magier', tier = 1, label = 'Blinzeln', icon = '🌀',
      description = 'Kurzer Sprung durch den Raum.',
      cooldown = 20, cost = 22, requires = {}, unlock = cost(1),
      effect = { kind = 'blink', distance = 28.0 } },

    { id = 'magier_schild', race = 'magier', tier = 2, label = 'Arkanes Schild', icon = '🛡',
      description = 'Eine Barriere aus reiner Energie.',
      cooldown = 75, cost = 40, requires = { 'magier_arkanschlag' }, unlock = cost(2, 'arkanstein'),
      effect = { kind = 'shield', armor = 100, duration = 25 } },

    { id = 'magier_zeitdehnung', race = 'magier', tier = 3, label = 'Zeitdehnung', icon = '⏳',
      description = 'Die Welt wird langsam, du bleibst schnell.',
      cooldown = 120, cost = 55, requires = { 'magier_blinzeln' }, unlock = cost(3, 'arkanstein', 2),
      effect = { kind = 'self_buff', duration = 12, speedMult = 1.4, damageMult = 1.2, timeScale = 0.7 } },

    { id = 'magier_fokus', race = 'magier', tier = 4, label = 'Arkaner Fokus', icon = '📘',
      description = 'Deine Zauber kosten weniger und wirken oefter.',
      passive = true, requires = { 'magier_schild', 'magier_zeitdehnung' },
      unlock = cost(4, 'arkanstein', 3),
      effect = { kind = 'passive', costMult = 0.75, cooldownMult = 0.8, essenceBonus = 40 } },

    -- Hexer ------------------------------------------------------------------
    { id = 'hexer_fluch', race = 'hexer', tier = 1, label = 'Fluch der Schwaeche', icon = '🜏',
      description = 'Verlangsamt dein Ziel und zehrt an seinen Kraeften.',
      cooldown = 35, cost = 25, requires = {}, unlock = cost(1),
      effect = { kind = 'curse', range = 25.0, duration = 12, slow = 0.65, damageOverTime = 3 } },

    { id = 'hexer_giftwolke', race = 'hexer', tier = 1, label = 'Giftwolke', icon = '🧪',
      description = 'Eine aetzende Wolke breitet sich aus.',
      cooldown = 50, cost = 35, requires = {}, unlock = cost(1),
      effect = { kind = 'poison', radius = 7.0, duration = 10, damagePerTick = 5 } },

    { id = 'hexer_kessel', race = 'hexer', tier = 2, label = 'Hexenkessel', icon = '⚗',
      description = 'Ein Trank aus dem Kessel heilt und reinigt dich.',
      cooldown = 60, cost = 30, requires = { 'hexer_giftwolke' }, unlock = cost(2, 'schattenstein'),
      effect = { kind = 'heal_self', amount = 50, cleanse = true } },

    { id = 'hexer_bann', race = 'hexer', tier = 3, label = 'Bann', icon = '⛓',
      description = 'Entwaffnet dein Ziel und laehmt es kurzzeitig.',
      cooldown = 90, cost = 45, requires = { 'hexer_fluch' }, unlock = cost(3, 'schattenstein', 2),
      effect = { kind = 'curse', range = 20.0, duration = 6, slow = 0.4, disarm = true } },

    { id = 'hexer_wissen', race = 'hexer', tier = 4, label = 'Dunkles Wissen', icon = '📕',
      description = 'Jahre des Studiums zahlen sich aus.',
      passive = true, requires = { 'hexer_kessel', 'hexer_bann' },
      unlock = cost(4, 'schattenstein', 3),
      effect = { kind = 'passive', costMult = 0.7, essenceRegen = 0.8, healthBonus = 15 } },

    -- Nekromant --------------------------------------------------------------
    { id = 'nekro_seelenentzug', race = 'nekromant', tier = 1, label = 'Seelenentzug', icon = '💀',
      description = 'Reisst deinem Ziel die Lebenskraft heraus.',
      cooldown = 30, cost = 28, requires = {}, unlock = cost(1),
      effect = { kind = 'drain', range = 25.0, single = true, damage = 35, heal = 35 } },

    { id = 'nekro_totenblick', race = 'nekromant', tier = 1, label = 'Totenblick', icon = '👁',
      description = 'Dein Blick laesst Lebende erstarren.',
      cooldown = 70, cost = 30, requires = {}, unlock = cost(1),
      effect = { kind = 'fear', radius = 10.0, duration = 6 } },

    { id = 'nekro_knochenschild', race = 'nekromant', tier = 2, label = 'Knochenschild', icon = '🦴',
      description = 'Gebeine der Gefallenen schuetzen dich.',
      cooldown = 80, cost = 35, requires = { 'nekro_seelenentzug' }, unlock = cost(2, 'schattenstein'),
      effect = { kind = 'shield', armor = 80, duration = 30 } },

    { id = 'nekro_wiedererweckung', race = 'nekromant', tier = 3, label = 'Wiedererweckung', icon = '⚰',
      description = 'Holt einen Gefallenen zurueck ins Leben.',
      cooldown = 300, cost = 70, requires = { 'nekro_knochenschild' }, unlock = cost(3, 'schattenstein', 2),
      effect = { kind = 'revive_target', range = 6.0, health = 120 } },

    { id = 'nekro_seelenernte', race = 'nekromant', tier = 4, label = 'Seelenernte', icon = '🕯',
      description = 'Jede geerntete Seele staerkt dich dauerhaft.',
      passive = true, requires = { 'nekro_wiedererweckung', 'nekro_totenblick' },
      unlock = cost(4, 'schattenstein', 3),
      effect = { kind = 'passive', healthBonus = 25, essenceBonus = 30, essenceRegen = 0.6 } },

    -- Jaeger -----------------------------------------------------------------
    { id = 'jaeger_wesensblick', race = 'jaeger', tier = 1, label = 'Wesensblick', icon = '🔎',
      description = 'Zeigt dir alle Wesen in der Umgebung.',
      cooldown = 50, cost = 15, requires = {}, unlock = cost(1),
      effect = { kind = 'reveal', radius = 120.0, duration = 25 } },

    { id = 'jaeger_silbermunition', race = 'jaeger', tier = 1, label = 'Silbermunition', icon = '🥈',
      description = 'Gesegnete Kugeln richten deutlich mehr Schaden an.',
      cooldown = 90, cost = 30, requires = {}, unlock = cost(1),
      effect = { kind = 'self_buff', duration = 30, damageMult = 1.6 } },

    { id = 'jaeger_fangeisen', race = 'jaeger', tier = 2, label = 'Fangeisen', icon = '🪤',
      description = 'Dein Ziel sitzt fest.',
      cooldown = 60, cost = 30, requires = { 'jaeger_wesensblick' }, unlock = cost(2, 'silberstein'),
      effect = { kind = 'curse', range = 22.0, duration = 8, slow = 0.35 } },

    { id = 'jaeger_adrenalin', race = 'jaeger', tier = 3, label = 'Adrenalin', icon = '💉',
      description = 'Ein Stich, der dich wieder auf die Beine bringt.',
      cooldown = 100, cost = 40, requires = { 'jaeger_silbermunition' }, unlock = cost(3, 'silberstein', 2),
      effect = { kind = 'heal_self', amount = 55, buff = { duration = 15, speedMult = 1.2 } } },

    { id = 'jaeger_veteran', race = 'jaeger', tier = 4, label = 'Veteran', icon = '🎖',
      description = 'Jahre der Jagd haben dich abgehaertet.',
      passive = true, requires = { 'jaeger_fangeisen', 'jaeger_adrenalin' },
      unlock = cost(4, 'silberstein', 3),
      effect = { kind = 'passive', healthBonus = 35, damageMult = 0.2, cooldownMult = 0.85 } },
}

-- Nachschlagetabellen ---------------------------------------------------------

Mystic.SkillsById = {}
for _, skill in ipairs(Mystic.Skills) do
    Mystic.SkillsById[skill.id] = skill
end

---@return table|nil
function Mystic.GetSkill(id)
    if type(id) ~= 'string' then return nil end
    return Mystic.SkillsById[id]
end

--- Alle Skills einer Rasse, nach Stufe sortiert.
function Mystic.GetSkillsForRace(race)
    local result = {}

    for _, skill in ipairs(Mystic.Skills) do
        if skill.race == race then result[#result + 1] = skill end
    end

    table.sort(result, function(a, b)
        if a.tier == b.tier then return a.label < b.label end
        return a.tier < b.tier
    end)
    return result
end

--- Prueft ob alle Voraussetzungen eines Skills freigeschaltet sind.
---@param unlocked table Menge freigeschalteter IDs { [id] = true }
function Mystic.MeetsRequirements(skill, unlocked)
    for _, requiredId in ipairs(skill.requires or {}) do
        if not unlocked[requiredId] then return false end
    end
    return true
end
