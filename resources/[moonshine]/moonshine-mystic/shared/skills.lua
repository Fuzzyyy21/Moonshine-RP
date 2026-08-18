--- Klassen-Skilltrees.
---
--- Jeder Knoten:
---   id          eindeutiger Schluessel
---   race        Klasse
---   row / col   Position im Baum (col darf halbe Schritte nutzen)
---   maxRank     Anzahl der Stufen (1, 3 oder 5)
---   requires    Liste von Knoten-IDs, die mindestens Stufe 1 haben muessen
---   level       benoetigte Klassenstufe = Anzahl der bereits im Baum
---               gekauften Stufen (der Baum kostet nur Klassensteine, keine XP)
---   stones      Klassensteine je Stufe: { base, step } oder { 10, 16, 22 }
---   essence     Essenzkosten (Zahl oder Liste je Stufe)
---   cooldown    Sekunden (Zahl oder Liste je Stufe)
---   effect      Wirkung; numerische Felder duerfen Listen je Stufe sein
---   passive     true = wirkt dauerhaft, nicht auf der Skillleiste
---
--- Effekt-Arten siehe docs/MYSTIC.md.

Mystic.Skills = {}

--- Haengt einen Knoten an den Baum.
local function node(definition)
    definition.level   = definition.level or 1
    definition.maxRank = definition.maxRank or 1
    definition.requires = definition.requires or {}
    definition.stones  = definition.stones or { base = 4, step = 2 }

    Mystic.Skills[#Mystic.Skills + 1] = definition
    return definition
end

-- Vampir ---------------------------------------------------------------------

node{ id = 'vampir_blutdurst', race = 'vampir', row = 0, col = 2, maxRank = 1,
      label = 'Blutdurst', icon = '🩸',
      description = 'Entfessle deinen Durst: Alle Wesen im Umkreis verlieren Blut, du gewinnst es.',
      stones = { 5 }, essence = 25, cooldown = 45,
      effect = { kind = 'drain', radius = 6.0, damage = 22, heal = 28 } }

node{ id = 'vampir_blutsinn', race = 'vampir', row = 1, col = 1, maxRank = 5,
      label = 'Blutsinn', icon = '👁',
      description = 'Erhoeht deine Wahrnehmung und laesst dich Lebensenergie in der Umgebung spueren.',
      requires = { 'vampir_blutdurst' }, stones = { base = 5, step = 2 },
      essence = 15, cooldown = 60,
      effect = { kind = 'reveal', radius = { 60, 75, 90, 105, 120 }, duration = { 12, 15, 18, 21, 25 } } }

node{ id = 'vampir_lebensentzug', race = 'vampir', row = 1, col = 2, maxRank = 5,
      label = 'Lebensentzug', icon = '💉',
      description = 'Reisst einem einzelnen Ziel auf Distanz die Lebenskraft heraus.',
      requires = { 'vampir_blutdurst' }, stones = { base = 6, step = 2 },
      essence = { 24, 26, 28, 30, 32 }, cooldown = { 30, 28, 26, 24, 20 },
      effect = { kind = 'drain', single = true, range = 25.0,
                 damage = { 20, 26, 32, 38, 45 }, heal = { 20, 26, 32, 38, 45 } } }

node{ id = 'vampir_schattenhuelle', race = 'vampir', row = 1, col = 3, maxRank = 5,
      label = 'Schattenhuelle', icon = '🌫',
      description = 'Du loest dich in Nebel auf und bist kaum noch zu sehen.',
      requires = { 'vampir_blutdurst' }, stones = { base = 6, step = 2 },
      essence = 40, cooldown = { 90, 84, 78, 72, 65 },
      effect = { kind = 'stealth', duration = { 8, 10, 12, 14, 17 },
                 alpha = { 90, 75, 60, 45, 30 }, speedMult = 1.15 } }

node{ id = 'vampir_blitztritt', race = 'vampir', row = 2, col = 1, maxRank = 3,
      label = 'Blitztritt', icon = '⚡',
      description = 'Du loest dich auf und erscheinst weiter vorn wieder.',
      requires = { 'vampir_blutsinn' }, stones = { base = 8, step = 3 },
      essence = 30, cooldown = { 30, 26, 22 },
      effect = { kind = 'blink', distance = { 18.0, 24.0, 30.0 } } }

node{ id = 'vampir_blutschild', race = 'vampir', row = 2, col = 2, maxRank = 5,
      label = 'Blutschild', icon = '🛡',
      description = 'Geronnenes Blut legt sich schuetzend um deinen Koerper.',
      requires = { 'vampir_lebensentzug' }, stones = { base = 7, step = 3 },
      essence = 35, cooldown = 80,
      effect = { kind = 'shield', armor = { 30, 45, 60, 75, 95 }, duration = { 20, 22, 24, 27, 30 } } }

node{ id = 'vampir_fledermausschwarm', race = 'vampir', row = 2, col = 3, maxRank = 3,
      label = 'Fledermausschwarm', icon = '🦇',
      description = 'Ein Schwarm faehrt aus dir heraus und zerfetzt alles in der Naehe.',
      requires = { 'vampir_schattenhuelle' }, stones = { base = 8, step = 3 },
      essence = 45, cooldown = { 60, 54, 46 },
      effect = { kind = 'aoe_damage', radius = { 6.0, 7.5, 9.0 },
                 damage = { 30, 42, 55 }, ragdoll = true } }

node{ id = 'vampir_raserei', race = 'vampir', row = 3, col = 0.5, maxRank = 5,
      label = 'Raserei', icon = '💢', passive = true, level = 8,
      description = 'Der Durst treibt dich an: dauerhaft mehr Nahkampfschaden und Tempo.',
      requires = { 'vampir_blitztritt' }, stones = { base = 10, step = 4 },
      effect = { kind = 'passive', meleeMult = { 0.08, 0.16, 0.24, 0.32, 0.45 },
                 speedMult = { 0.01, 0.02, 0.03, 0.04, 0.06 } } }

node{ id = 'vampir_regeneration', race = 'vampir', row = 3, col = 2, maxRank = 3,
      label = 'Regeneration', icon = '➕', passive = true, level = 8,
      description = 'Dein Koerper flickt sich selbst zusammen.',
      requires = { 'vampir_blutschild' }, stones = { base = 10, step = 5 },
      effect = { kind = 'passive', regenPerTick = { 2, 4, 7 }, healthBonus = { 10, 20, 35 } } }

node{ id = 'vampir_unsichtbarkeit', race = 'vampir', row = 3, col = 3.5, maxRank = 5,
      label = 'Unsichtbarkeit', icon = '👻', level = 12,
      description = 'Du verschwindest vollstaendig aus der Sicht der Lebenden.',
      requires = { 'vampir_fledermausschwarm' }, stones = { base = 12, step = 5 },
      essence = 55, cooldown = { 150, 140, 130, 120, 105 },
      effect = { kind = 'stealth', duration = { 10, 13, 16, 19, 24 },
                 alpha = { 40, 32, 25, 18, 0 }, speedMult = 1.25 } }

node{ id = 'vampir_urvampir', race = 'vampir', row = 4, col = 2, maxRank = 1,
      label = 'Ur-Vampir', icon = '🧛', passive = true, level = 18,
      description = 'Das Sonnenlicht verliert seinen Schrecken und dein Blut wird uralt.',
      requires = { 'vampir_raserei', 'vampir_regeneration', 'vampir_unsichtbarkeit' },
      stones = { 40 },
      effect = { kind = 'passive', sunImmune = true, healthBonus = 60, meleeMult = 0.35,
                 essenceBonus = 40, regenPerTick = 3 } }

-- Werwolf --------------------------------------------------------------------

node{ id = 'werwolf_krallenhieb', race = 'werwolf', row = 0, col = 2, maxRank = 1,
      label = 'Krallenhieb', icon = '🐾',
      description = 'Ein Hieb, der alles vor dir zerfetzt.',
      stones = { 5 }, essence = 20, cooldown = 20,
      effect = { kind = 'aoe_damage', radius = 4.0, damage = 32, ragdoll = true } }

node{ id = 'werwolf_wittern', race = 'werwolf', row = 1, col = 1, maxRank = 5,
      label = 'Wittern', icon = '👃',
      description = 'Du nimmst die Faehrte aller Wesen in der Umgebung auf.',
      requires = { 'werwolf_krallenhieb' }, stones = { base = 5, step = 2 },
      essence = 15, cooldown = 45,
      effect = { kind = 'reveal', radius = { 70, 90, 110, 130, 150 }, duration = { 15, 18, 21, 24, 30 } } }

node{ id = 'werwolf_blutrausch', race = 'werwolf', row = 1, col = 2, maxRank = 5,
      label = 'Blutrausch', icon = '🩸',
      description = 'Die Wut uebernimmt: mehr Nahkampfschaden, mehr Tempo, mehr Weste.',
      requires = { 'werwolf_krallenhieb' }, stones = { base = 6, step = 2 },
      essence = 35, cooldown = { 100, 95, 90, 85, 75 },
      effect = { kind = 'self_buff', duration = { 12, 15, 18, 21, 25 },
                 meleeMult = { 1.3, 1.45, 1.6, 1.75, 2.0 },
                 speedMult = { 1.1, 1.14, 1.18, 1.22, 1.3 },
                 armor = { 15, 20, 25, 30, 40 } } }

node{ id = 'werwolf_fell', race = 'werwolf', row = 1, col = 3, maxRank = 5,
      label = 'Dickes Fell', icon = '🧥', passive = true,
      description = 'Dein Fell schluckt Schlaege, die andere umwerfen wuerden.',
      requires = { 'werwolf_krallenhieb' }, stones = { base = 6, step = 2 },
      effect = { kind = 'passive', healthBonus = { 15, 30, 45, 60, 80 },
                 armorBonus = { 5, 10, 15, 20, 30 } } }

node{ id = 'werwolf_satzsprung', race = 'werwolf', row = 2, col = 1, maxRank = 3,
      label = 'Satzsprung', icon = '🦿',
      description = 'Ein gewaltiger Satz nach vorn, Landung ohne Schaden.',
      requires = { 'werwolf_wittern' }, stones = { base = 8, step = 3 },
      essence = 20, cooldown = { 18, 15, 12 },
      effect = { kind = 'leap', force = { 8.0, 10.0, 12.5 }, noFallDamage = true } }

node{ id = 'werwolf_zerfleischen', race = 'werwolf', row = 2, col = 2, maxRank = 5,
      label = 'Zerfleischen', icon = '🦷',
      description = 'Du gehst in die Mitte und reisst alles um dich herum nieder.',
      requires = { 'werwolf_blutrausch' }, stones = { base = 7, step = 3 },
      essence = 40, cooldown = { 45, 42, 39, 36, 30 },
      effect = { kind = 'aoe_damage', radius = { 5.0, 5.5, 6.0, 6.5, 7.5 },
                 damage = { 35, 45, 55, 65, 80 }, ragdoll = true } }

node{ id = 'werwolf_heulen', race = 'werwolf', row = 2, col = 3, maxRank = 3,
      label = 'Heulen', icon = '🌕',
      description = 'Dein Heulen laesst allen in Hoerweite die Knie weich werden.',
      requires = { 'werwolf_fell' }, stones = { base = 8, step = 3 },
      essence = 35, cooldown = { 75, 68, 60 },
      effect = { kind = 'fear', radius = { 10.0, 14.0, 18.0 }, duration = { 5, 7, 9 } } }

node{ id = 'werwolf_rudelfuehrer', race = 'werwolf', row = 3, col = 0.5, maxRank = 5,
      label = 'Rudelfuehrer', icon = '🏅', passive = true, level = 8,
      description = 'Du fuehrst das Rudel an: mehr Schaden, mehr Ausdauer.',
      requires = { 'werwolf_satzsprung' }, stones = { base = 10, step = 4 },
      effect = { kind = 'passive', meleeMult = { 0.1, 0.2, 0.3, 0.4, 0.55 },
                 stamina = { 10, 20, 30, 40, 55 } } }

node{ id = 'werwolf_wildherz', race = 'werwolf', row = 3, col = 2, maxRank = 3,
      label = 'Wildherz', icon = '❤‍🔥', passive = true, level = 8,
      description = 'Dein Herz schlaegt schneller und heilt schneller.',
      requires = { 'werwolf_zerfleischen' }, stones = { base = 10, step = 5 },
      effect = { kind = 'passive', regenPerTick = { 3, 5, 8 }, healthBonus = { 20, 35, 55 } } }

node{ id = 'werwolf_verwandlung', race = 'werwolf', row = 3, col = 3.5, maxRank = 3,
      label = 'Verwandlung', icon = '🐺', level = 12,
      description = 'Du nimmst deine wahre Gestalt an.',
      requires = { 'werwolf_heulen' }, stones = { base = 13, step = 7 },
      essence = 60, cooldown = { 240, 210, 180 },
      effect = { kind = 'transform', duration = { 30, 45, 60 }, model = 'a_c_rottweiler',
                 healthBonus = { 40, 60, 90 }, meleeMult = { 1.7, 2.0, 2.4 },
                 speedMult = { 1.2, 1.3, 1.4 } } }

node{ id = 'werwolf_alpha', race = 'werwolf', row = 4, col = 2, maxRank = 1,
      label = 'Alpha', icon = '👑', passive = true, level = 18,
      description = 'Du bist das Alpha. Der Mond gehoert dir.',
      requires = { 'werwolf_rudelfuehrer', 'werwolf_wildherz', 'werwolf_verwandlung' },
      stones = { 40 },
      effect = { kind = 'passive', healthBonus = 80, meleeMult = 0.4, speedMult = 0.06,
                 regenPerTick = 4, cooldownMult = 0.85 } }

-- Daemon ---------------------------------------------------------------------

node{ id = 'daemon_feuerball', race = 'daemon', row = 0, col = 2, maxRank = 1,
      label = 'Feuerball', icon = '☄',
      description = 'Schleudert eine Flammenkugel auf dein Ziel.',
      stones = { 5 }, essence = 20, cooldown = 12,
      effect = { kind = 'projectile', damage = 40, element = 'fire', range = 60.0 } }

node{ id = 'daemon_schwefelhaut', race = 'daemon', row = 1, col = 1, maxRank = 5,
      label = 'Schwefelhaut', icon = '🛡',
      description = 'Deine Haut verhaertet sich zu Schwefelgestein.',
      requires = { 'daemon_feuerball' }, stones = { base = 5, step = 2 },
      essence = 30, cooldown = 90,
      effect = { kind = 'shield', armor = { 40, 55, 70, 85, 100 }, duration = { 20, 24, 28, 32, 40 } } }

node{ id = 'daemon_hoellenschlag', race = 'daemon', row = 1, col = 2, maxRank = 5,
      label = 'Hoellenschlag', icon = '🔥',
      description = 'Der Boden birst und Flammen schlagen empor.',
      requires = { 'daemon_feuerball' }, stones = { base = 6, step = 2 },
      essence = { 40, 43, 46, 49, 52 }, cooldown = { 60, 56, 52, 48, 42 },
      effect = { kind = 'aoe_damage', radius = { 6.0, 7.0, 8.0, 9.0, 11.0 },
                 damage = { 40, 50, 60, 70, 85 }, fire = true, ragdoll = true } }

node{ id = 'daemon_sengenderblick', race = 'daemon', row = 1, col = 3, maxRank = 5,
      label = 'Sengender Blick', icon = '👁‍🗨',
      description = 'Dein Blick brennt sich ins Ziel und laesst es taumeln.',
      requires = { 'daemon_feuerball' }, stones = { base = 6, step = 2 },
      essence = 28, cooldown = { 35, 33, 31, 29, 25 },
      effect = { kind = 'curse', range = 25.0, duration = { 8, 10, 12, 14, 17 },
                 slow = { 0.75, 0.7, 0.65, 0.6, 0.5 },
                 damageOverTime = { 3, 4, 5, 6, 8 } } }

node{ id = 'daemon_aschesprung', race = 'daemon', row = 2, col = 1, maxRank = 3,
      label = 'Aschesprung', icon = '💨',
      description = 'Du zerfaellst zu Asche und setzt dich neu zusammen.',
      requires = { 'daemon_schwefelhaut' }, stones = { base = 8, step = 3 },
      essence = 30, cooldown = { 28, 24, 20 },
      effect = { kind = 'blink', distance = { 18.0, 24.0, 30.0 } } }

node{ id = 'daemon_feuersbrunst', race = 'daemon', row = 2, col = 2, maxRank = 5,
      label = 'Feuersbrunst', icon = '🌋',
      description = 'Eine Wand aus Hitze, die weiter brennt.',
      requires = { 'daemon_hoellenschlag' }, stones = { base = 7, step = 3 },
      essence = 45, cooldown = { 70, 66, 62, 58, 50 },
      effect = { kind = 'poison', radius = { 6.0, 7.0, 8.0, 9.0, 10.0 },
                 duration = { 8, 10, 12, 14, 16 }, damagePerTick = { 4, 5, 6, 7, 9 } } }

node{ id = 'daemon_furcht', race = 'daemon', row = 2, col = 3, maxRank = 3,
      label = 'Furcht', icon = '😱',
      description = 'Wer dich ansieht, verliert die Kontrolle.',
      requires = { 'daemon_sengenderblick' }, stones = { base = 8, step = 3 },
      essence = 40, cooldown = { 75, 68, 60 },
      effect = { kind = 'fear', radius = { 10.0, 14.0, 18.0 }, duration = { 5, 7, 9 } } }

node{ id = 'daemon_daemonenblut', race = 'daemon', row = 3, col = 0.5, maxRank = 5,
      label = 'Daemonenblut', icon = '🩸', passive = true, level = 8,
      description = 'Schwefel statt Blut: mehr Leben, schnellere Heilung.',
      requires = { 'daemon_aschesprung' }, stones = { base = 10, step = 4 },
      effect = { kind = 'passive', healthBonus = { 15, 30, 45, 60, 80 },
                 regenPerTick = { 1, 2, 3, 4, 6 } } }

node{ id = 'daemon_brandmal', race = 'daemon', row = 3, col = 2, maxRank = 3,
      label = 'Brandmal', icon = '🔱', passive = true, level = 8,
      description = 'Deine Angriffe brennen sich dauerhaft tiefer ein.',
      requires = { 'daemon_feuersbrunst' }, stones = { base = 10, step = 5 },
      effect = { kind = 'passive', damageMult = { 0.1, 0.2, 0.35 }, meleeMult = { 0.1, 0.2, 0.3 } } }

node{ id = 'daemon_hoellentor', race = 'daemon', row = 3, col = 3.5, maxRank = 3,
      label = 'Hoellentor', icon = '🚪', level = 12,
      description = 'Ein Riss in die Unterwelt reisst alles in der Naehe mit.',
      requires = { 'daemon_furcht' }, stones = { base = 13, step = 7 },
      essence = 70, cooldown = { 180, 165, 150 },
      effect = { kind = 'aoe_damage', radius = { 12.0, 15.0, 18.0 },
                 damage = { 70, 90, 115 }, fire = true, ragdoll = true } }

node{ id = 'daemon_erzdaemon', race = 'daemon', row = 4, col = 2, maxRank = 1,
      label = 'Erzdaemon', icon = '😈', passive = true, level = 18,
      description = 'Feuer kann dir nichts mehr anhaben. Du bist das Feuer.',
      requires = { 'daemon_daemonenblut', 'daemon_brandmal', 'daemon_hoellentor' },
      stones = { 40 },
      effect = { kind = 'passive', fireImmune = true, healthBonus = 60, damageMult = 0.3,
                 armorBonus = 40, regenPerTick = 3 } }

-- Fee ------------------------------------------------------------------------

node{ id = 'fee_bluete', race = 'fee', row = 0, col = 2, maxRank = 1,
      label = 'Heilende Bluete', icon = '🌸',
      description = 'Naturkraft schliesst deine Wunden.',
      stones = { 5 }, essence = 25, cooldown = 40,
      effect = { kind = 'heal_self', amount = 45 } }

node{ id = 'fee_flatterschritt', race = 'fee', row = 1, col = 1, maxRank = 5,
      label = 'Flatterschritt', icon = '🍃',
      description = 'Ein Fluegelschlag traegt dich in die Hoehe.',
      requires = { 'fee_bluete' }, stones = { base = 5, step = 2 },
      essence = 15, cooldown = { 15, 14, 13, 12, 10 },
      effect = { kind = 'leap', force = { 7.0, 8.0, 9.0, 10.0, 12.0 }, noFallDamage = true } }

node{ id = 'fee_segen', race = 'fee', row = 1, col = 2, maxRank = 5,
      label = 'Segen', icon = '✨',
      description = 'Heilt das Wesen vor dir.',
      requires = { 'fee_bluete' }, stones = { base = 6, step = 2 },
      essence = 35, cooldown = { 45, 42, 39, 36, 30 },
      effect = { kind = 'heal_target', range = { 10.0, 12.0, 14.0, 16.0, 20.0 },
                 amount = { 40, 55, 70, 85, 110 } } }

node{ id = 'fee_naturschild', race = 'fee', row = 1, col = 3, maxRank = 5,
      label = 'Naturschild', icon = '🛡',
      description = 'Ranken legen sich schuetzend um dich.',
      requires = { 'fee_bluete' }, stones = { base = 6, step = 2 },
      essence = 30, cooldown = 80,
      effect = { kind = 'shield', armor = { 25, 40, 55, 70, 90 }, duration = { 20, 23, 26, 29, 35 } } }

node{ id = 'fee_schimmer', race = 'fee', row = 2, col = 1, maxRank = 3,
      label = 'Schimmer', icon = '💫',
      description = 'Du verschwimmst zu einem Lichtschimmer.',
      requires = { 'fee_flatterschritt' }, stones = { base = 8, step = 3 },
      essence = 40, cooldown = { 80, 72, 62 },
      effect = { kind = 'stealth', duration = { 10, 14, 18 }, alpha = { 45, 30, 15 }, speedMult = 1.25 } }

node{ id = 'fee_pollen', race = 'fee', row = 2, col = 2, maxRank = 5,
      label = 'Pollenwolke', icon = '🌼',
      description = 'Betaeubender Bluetenstaub legt sich ueber alles.',
      requires = { 'fee_segen' }, stones = { base = 7, step = 3 },
      essence = 35, cooldown = { 55, 52, 49, 46, 40 },
      effect = { kind = 'poison', radius = { 5.0, 6.0, 7.0, 8.0, 9.5 },
                 duration = { 8, 9, 10, 11, 13 }, damagePerTick = { 3, 4, 5, 6, 7 } } }

node{ id = 'fee_elfenlicht', race = 'fee', row = 2, col = 3, maxRank = 3,
      label = 'Elfenlicht', icon = '🔆',
      description = 'Irrlichter zeigen dir jedes Wesen in der Naehe.',
      requires = { 'fee_naturschild' }, stones = { base = 8, step = 3 },
      essence = 15, cooldown = { 50, 45, 40 },
      effect = { kind = 'reveal', radius = { 80, 110, 140 }, duration = { 15, 20, 26 } } }

node{ id = 'fee_lebenshauch', race = 'fee', row = 3, col = 0.5, maxRank = 5,
      label = 'Lebenshauch', icon = '💚', passive = true, level = 8,
      description = 'Die Natur haelt dich dauerhaft am Leben.',
      requires = { 'fee_schimmer' }, stones = { base = 10, step = 4 },
      effect = { kind = 'passive', regenPerTick = { 2, 3, 4, 5, 7 },
                 essenceRegen = { 0.3, 0.6, 0.9, 1.2, 1.6 }, noFallDamage = true } }

node{ id = 'fee_windgeist', race = 'fee', row = 3, col = 2, maxRank = 3,
      label = 'Windgeist', icon = '🌬', passive = true, level = 8,
      description = 'Der Wind traegt dich schneller als alle anderen.',
      requires = { 'fee_pollen' }, stones = { base = 10, step = 5 },
      effect = { kind = 'passive', speedMult = { 0.03, 0.06, 0.1 }, stamina = { 15, 30, 50 } } }

node{ id = 'fee_wiedergeburt', race = 'fee', row = 3, col = 3.5, maxRank = 3,
      label = 'Wiedergeburt', icon = '🌱', level = 12,
      description = 'Holt ein gefallenes Wesen zurueck ins Leben.',
      requires = { 'fee_elfenlicht' }, stones = { base = 13, step = 7 },
      essence = 70, cooldown = { 300, 260, 220 },
      effect = { kind = 'revive_target', range = { 5.0, 7.0, 9.0 }, health = { 100, 140, 180 } } }

node{ id = 'fee_waldherrin', race = 'fee', row = 4, col = 2, maxRank = 1,
      label = 'Herrin des Waldes', icon = '🌳', passive = true, level = 18,
      description = 'Die Natur selbst steht auf deiner Seite.',
      requires = { 'fee_lebenshauch', 'fee_windgeist', 'fee_wiedergeburt' },
      stones = { 40 },
      effect = { kind = 'passive', healthBonus = 45, essenceBonus = 60, essenceRegen = 2.0,
                 regenPerTick = 4, noFallDamage = true, speedMult = 0.08 } }

-- Magier ---------------------------------------------------------------------

node{ id = 'magier_arkanschlag', race = 'magier', row = 0, col = 2, maxRank = 1,
      label = 'Arkanschlag', icon = '🔮',
      description = 'Ein gebuendelter Energiestoss.',
      stones = { 5 }, essence = 18, cooldown = 10,
      effect = { kind = 'projectile', damage = 38, element = 'arcane', range = 70.0 } }

node{ id = 'magier_blinzeln', race = 'magier', row = 1, col = 1, maxRank = 5,
      label = 'Blinzeln', icon = '🌀',
      description = 'Kurzer Sprung durch den Raum.',
      requires = { 'magier_arkanschlag' }, stones = { base = 5, step = 2 },
      essence = 22, cooldown = { 20, 18, 16, 14, 11 },
      effect = { kind = 'blink', distance = { 18.0, 22.0, 26.0, 30.0, 36.0 } } }

node{ id = 'magier_schild', race = 'magier', row = 1, col = 2, maxRank = 5,
      label = 'Arkanes Schild', icon = '🛡',
      description = 'Eine Barriere aus reiner Energie.',
      requires = { 'magier_arkanschlag' }, stones = { base = 6, step = 2 },
      essence = 40, cooldown = 75,
      effect = { kind = 'shield', armor = { 40, 55, 70, 85, 100 }, duration = { 20, 24, 28, 32, 40 } } }

node{ id = 'magier_manafluss', race = 'magier', row = 1, col = 3, maxRank = 5,
      label = 'Manafluss', icon = '🔷', passive = true,
      description = 'Dein Vorrat waechst und fuellt sich schneller.',
      requires = { 'magier_arkanschlag' }, stones = { base = 6, step = 2 },
      effect = { kind = 'passive', essenceBonus = { 15, 30, 45, 60, 85 },
                 essenceRegen = { 0.4, 0.8, 1.2, 1.6, 2.2 } } }

node{ id = 'magier_frostnova', race = 'magier', row = 2, col = 1, maxRank = 5,
      label = 'Frostnova', icon = '❄',
      description = 'Eis breitet sich aus und friert alles in der Naehe ein.',
      requires = { 'magier_blinzeln' }, stones = { base = 7, step = 3 },
      essence = 40, cooldown = { 50, 47, 44, 41, 35 },
      effect = { kind = 'curse', radius = { 6.0, 7.0, 8.0, 9.0, 11.0 },
                 duration = { 6, 7, 8, 9, 11 },
                 slow = { 0.6, 0.55, 0.5, 0.45, 0.35 }, damageOverTime = { 2, 3, 4, 5, 6 } } }

node{ id = 'magier_kettenblitz', race = 'magier', row = 2, col = 2, maxRank = 5,
      label = 'Kettenblitz', icon = '⚡',
      description = 'Ein Blitz springt von Ziel zu Ziel.',
      requires = { 'magier_schild' }, stones = { base = 7, step = 3 },
      essence = 45, cooldown = { 40, 38, 36, 34, 28 },
      effect = { kind = 'aoe_damage', radius = { 8.0, 9.0, 10.0, 11.0, 13.0 },
                 damage = { 35, 45, 55, 65, 80 } } }

node{ id = 'magier_zeitdehnung', race = 'magier', row = 2, col = 3, maxRank = 3,
      label = 'Zeitdehnung', icon = '⏳',
      description = 'Die Welt wird langsam, du bleibst schnell.',
      requires = { 'magier_manafluss' }, stones = { base = 8, step = 3 },
      essence = 55, cooldown = { 120, 108, 95 },
      effect = { kind = 'self_buff', duration = { 8, 11, 14 }, speedMult = { 1.25, 1.35, 1.45 },
                 damageMult = { 1.1, 1.2, 1.3 }, timeScale = { 0.8, 0.72, 0.65 } } }

node{ id = 'magier_arkanemacht', race = 'magier', row = 3, col = 0.5, maxRank = 5,
      label = 'Arkane Macht', icon = '📘', passive = true, level = 8,
      description = 'Deine Zauber schlagen dauerhaft haerter ein.',
      requires = { 'magier_frostnova' }, stones = { base = 10, step = 4 },
      effect = { kind = 'passive', damageMult = { 0.08, 0.16, 0.24, 0.32, 0.45 } } }

node{ id = 'magier_fokus', race = 'magier', row = 3, col = 2, maxRank = 3,
      label = 'Fokus', icon = '🎯', passive = true, level = 8,
      description = 'Zauber kosten weniger und sind schneller wieder bereit.',
      requires = { 'magier_kettenblitz' }, stones = { base = 10, step = 5 },
      effect = { kind = 'passive', costMult = { 0.92, 0.85, 0.75 },
                 cooldownMult = { 0.95, 0.9, 0.82 } } }

node{ id = 'magier_sphaere', race = 'magier', row = 3, col = 3.5, maxRank = 3,
      label = 'Arkane Sphaere', icon = '🔵', level = 12,
      description = 'Eine Sphaere reiner Magie zerreisst alles im Umkreis.',
      requires = { 'magier_zeitdehnung' }, stones = { base = 13, step = 7 },
      essence = 75, cooldown = { 160, 145, 130 },
      effect = { kind = 'aoe_damage', radius = { 11.0, 13.0, 16.0 }, damage = { 70, 90, 115 } } }

node{ id = 'magier_erzmagier', race = 'magier', row = 4, col = 2, maxRank = 1,
      label = 'Erzmagier', icon = '🧙', passive = true, level = 18,
      description = 'Die arkanen Kuenste haben keine Geheimnisse mehr fuer dich.',
      requires = { 'magier_arkanemacht', 'magier_fokus', 'magier_sphaere' },
      stones = { 40 },
      effect = { kind = 'passive', essenceBonus = 100, essenceRegen = 2.5, damageMult = 0.35,
                 costMult = 0.8, cooldownMult = 0.8 } }

-- Hexer ----------------------------------------------------------------------

node{ id = 'hexer_fluch', race = 'hexer', row = 0, col = 2, maxRank = 1,
      label = 'Fluch der Schwaeche', icon = '🜏',
      description = 'Verlangsamt dein Ziel und zehrt an seinen Kraeften.',
      stones = { 5 }, essence = 25, cooldown = 35,
      effect = { kind = 'curse', range = 25.0, duration = 12, slow = 0.65, damageOverTime = 3 } }

node{ id = 'hexer_giftwolke', race = 'hexer', row = 1, col = 1, maxRank = 5,
      label = 'Giftwolke', icon = '🧪',
      description = 'Eine aetzende Wolke breitet sich aus.',
      requires = { 'hexer_fluch' }, stones = { base = 5, step = 2 },
      essence = 35, cooldown = { 50, 47, 44, 41, 35 },
      effect = { kind = 'poison', radius = { 5.0, 6.0, 7.0, 8.0, 9.5 },
                 duration = { 8, 9, 10, 12, 14 }, damagePerTick = { 4, 5, 6, 7, 9 } } }

node{ id = 'hexer_kessel', race = 'hexer', row = 1, col = 2, maxRank = 5,
      label = 'Hexenkessel', icon = '⚗',
      description = 'Ein Trank aus dem Kessel heilt und reinigt dich.',
      requires = { 'hexer_fluch' }, stones = { base = 6, step = 2 },
      essence = 30, cooldown = { 60, 56, 52, 48, 42 },
      effect = { kind = 'heal_self', amount = { 35, 45, 55, 70, 90 }, cleanse = true } }

node{ id = 'hexer_wissen', race = 'hexer', row = 1, col = 3, maxRank = 5,
      label = 'Dunkles Wissen', icon = '📕', passive = true,
      description = 'Jahre des Studiums senken die Kosten deiner Kuenste.',
      requires = { 'hexer_fluch' }, stones = { base = 6, step = 2 },
      effect = { kind = 'passive', costMult = { 0.94, 0.88, 0.82, 0.76, 0.68 },
                 essenceRegen = { 0.2, 0.4, 0.6, 0.8, 1.1 } } }

node{ id = 'hexer_bann', race = 'hexer', row = 2, col = 1, maxRank = 3,
      label = 'Bann', icon = '⛓',
      description = 'Entwaffnet dein Ziel und laehmt es kurzzeitig.',
      requires = { 'hexer_giftwolke' }, stones = { base = 8, step = 3 },
      essence = 45, cooldown = { 90, 82, 72 },
      effect = { kind = 'curse', range = 20.0, duration = { 5, 7, 9 },
                 slow = { 0.45, 0.4, 0.3 }, disarm = true } }

node{ id = 'hexer_blutopfer', race = 'hexer', row = 2, col = 2, maxRank = 5,
      label = 'Blutopfer', icon = '🕯',
      description = 'Du nimmst dem Umfeld Leben und gibst es dir selbst.',
      requires = { 'hexer_kessel' }, stones = { base = 7, step = 3 },
      essence = 40, cooldown = { 55, 52, 49, 46, 40 },
      effect = { kind = 'drain', radius = { 5.0, 6.0, 7.0, 8.0, 9.0 },
                 damage = { 18, 24, 30, 36, 45 }, heal = { 20, 27, 34, 41, 52 } } }

node{ id = 'hexer_schattenschritt', race = 'hexer', row = 2, col = 3, maxRank = 3,
      label = 'Schattenschritt', icon = '🌑',
      description = 'Du trittst durch den Schatten an einen anderen Ort.',
      requires = { 'hexer_wissen' }, stones = { base = 8, step = 3 },
      essence = 30, cooldown = { 30, 26, 22 },
      effect = { kind = 'blink', distance = { 18.0, 24.0, 30.0 } } }

node{ id = 'hexer_verderben', race = 'hexer', row = 3, col = 0.5, maxRank = 5,
      label = 'Verderben', icon = '☠', passive = true, level = 8,
      description = 'Alles, was du beruehrst, verdirbt schneller.',
      requires = { 'hexer_bann' }, stones = { base = 10, step = 4 },
      effect = { kind = 'passive', damageMult = { 0.08, 0.16, 0.24, 0.32, 0.45 } } }

node{ id = 'hexer_zaehigkeit', race = 'hexer', row = 3, col = 2, maxRank = 3,
      label = 'Alte Knochen', icon = '🦴', passive = true, level = 8,
      description = 'Zaeher, als dein Aussehen vermuten laesst.',
      requires = { 'hexer_blutopfer' }, stones = { base = 10, step = 5 },
      effect = { kind = 'passive', healthBonus = { 20, 40, 65 }, regenPerTick = { 1, 2, 4 } } }

node{ id = 'hexer_massenfluch', race = 'hexer', row = 3, col = 3.5, maxRank = 3,
      label = 'Massenfluch', icon = '🌀', level = 12,
      description = 'Der Fluch springt auf alle in deiner Naehe ueber.',
      requires = { 'hexer_schattenschritt' }, stones = { base = 13, step = 7 },
      essence = 70, cooldown = { 150, 135, 120 },
      effect = { kind = 'curse', radius = { 10.0, 13.0, 16.0 }, duration = { 10, 13, 16 },
                 slow = { 0.55, 0.45, 0.35 }, damageOverTime = { 5, 7, 9 } } }

node{ id = 'hexer_erzhexer', race = 'hexer', row = 4, col = 2, maxRank = 1,
      label = 'Erzhexer', icon = '🔮', passive = true, level = 18,
      description = 'Die alten Kuenste gehorchen dir vollstaendig.',
      requires = { 'hexer_verderben', 'hexer_zaehigkeit', 'hexer_massenfluch' },
      stones = { 40 },
      effect = { kind = 'passive', healthBonus = 45, damageMult = 0.3, costMult = 0.7,
                 cooldownMult = 0.8, essenceBonus = 50 } }

-- Nekromant ------------------------------------------------------------------

node{ id = 'nekro_seelenentzug', race = 'nekromant', row = 0, col = 2, maxRank = 1,
      label = 'Seelenentzug', icon = '💀',
      description = 'Reisst deinem Ziel die Lebenskraft heraus.',
      stones = { 5 }, essence = 28, cooldown = 30,
      effect = { kind = 'drain', single = true, range = 25.0, damage = 32, heal = 32 } }

node{ id = 'nekro_totenblick', race = 'nekromant', row = 1, col = 1, maxRank = 5,
      label = 'Totenblick', icon = '👁',
      description = 'Dein Blick laesst Lebende erstarren.',
      requires = { 'nekro_seelenentzug' }, stones = { base = 5, step = 2 },
      essence = 30, cooldown = { 70, 66, 62, 58, 50 },
      effect = { kind = 'fear', radius = { 8.0, 10.0, 12.0, 14.0, 17.0 },
                 duration = { 4, 5, 6, 7, 9 } } }

node{ id = 'nekro_knochenschild', race = 'nekromant', row = 1, col = 2, maxRank = 5,
      label = 'Knochenschild', icon = '🦴',
      description = 'Gebeine der Gefallenen schuetzen dich.',
      requires = { 'nekro_seelenentzug' }, stones = { base = 6, step = 2 },
      essence = 35, cooldown = 80,
      effect = { kind = 'shield', armor = { 35, 50, 65, 80, 100 }, duration = { 20, 24, 28, 32, 40 } } }

node{ id = 'nekro_seelenspeicher', race = 'nekromant', row = 1, col = 3, maxRank = 5,
      label = 'Seelenspeicher', icon = '🏺', passive = true,
      description = 'Jede gefangene Seele vergroessert deinen Vorrat.',
      requires = { 'nekro_seelenentzug' }, stones = { base = 6, step = 2 },
      effect = { kind = 'passive', essenceBonus = { 15, 30, 45, 60, 80 },
                 essenceRegen = { 0.3, 0.6, 0.9, 1.2, 1.6 } } }

node{ id = 'nekro_verwesung', race = 'nekromant', row = 2, col = 1, maxRank = 5,
      label = 'Verwesung', icon = '🪦',
      description = 'Fauliger Nebel zersetzt alles im Umkreis.',
      requires = { 'nekro_totenblick' }, stones = { base = 7, step = 3 },
      essence = 40, cooldown = { 55, 52, 49, 46, 40 },
      effect = { kind = 'poison', radius = { 5.0, 6.0, 7.0, 8.0, 10.0 },
                 duration = { 8, 10, 12, 14, 16 }, damagePerTick = { 4, 5, 6, 7, 9 } } }

node{ id = 'nekro_schattenriss', race = 'nekromant', row = 2, col = 2, maxRank = 3,
      label = 'Schattenriss', icon = '🌑',
      description = 'Ein Riss im Diesseits bringt dich woanders hin.',
      requires = { 'nekro_knochenschild' }, stones = { base = 8, step = 3 },
      essence = 30, cooldown = { 30, 26, 22 },
      effect = { kind = 'blink', distance = { 18.0, 24.0, 30.0 } } }

node{ id = 'nekro_grabesruf', race = 'nekromant', row = 2, col = 3, maxRank = 3,
      label = 'Grabesruf', icon = '📿',
      description = 'Die Toten fluestern dir zu, wer sich in der Naehe bewegt.',
      requires = { 'nekro_seelenspeicher' }, stones = { base = 8, step = 3 },
      essence = 15, cooldown = { 50, 45, 40 },
      effect = { kind = 'reveal', radius = { 80, 110, 140 }, duration = { 15, 20, 26 } } }

node{ id = 'nekro_todesmagie', race = 'nekromant', row = 3, col = 0.5, maxRank = 5,
      label = 'Todesmagie', icon = '☠', passive = true, level = 8,
      description = 'Der Tod arbeitet fuer dich, nicht gegen dich.',
      requires = { 'nekro_verwesung' }, stones = { base = 10, step = 4 },
      effect = { kind = 'passive', damageMult = { 0.08, 0.16, 0.24, 0.32, 0.45 } } }

node{ id = 'nekro_untotesfleisch', race = 'nekromant', row = 3, col = 2, maxRank = 3,
      label = 'Untotes Fleisch', icon = '🧟', passive = true, level = 8,
      description = 'Was schon tot ist, stirbt nicht so schnell.',
      requires = { 'nekro_schattenriss' }, stones = { base = 10, step = 5 },
      effect = { kind = 'passive', healthBonus = { 25, 45, 70 }, regenPerTick = { 2, 3, 5 } } }

node{ id = 'nekro_wiedererweckung', race = 'nekromant', row = 3, col = 3.5, maxRank = 3,
      label = 'Wiedererweckung', icon = '⚰', level = 12,
      description = 'Holt einen Gefallenen zurueck ins Leben.',
      requires = { 'nekro_grabesruf' }, stones = { base = 13, step = 7 },
      essence = 70, cooldown = { 300, 260, 220 },
      effect = { kind = 'revive_target', range = { 5.0, 7.0, 9.0 }, health = { 110, 150, 190 } } }

node{ id = 'nekro_herrdertoten', race = 'nekromant', row = 4, col = 2, maxRank = 1,
      label = 'Herr der Toten', icon = '👑', passive = true, level = 18,
      description = 'Zwischen Leben und Tod entscheidest nur noch du.',
      requires = { 'nekro_todesmagie', 'nekro_untotesfleisch', 'nekro_wiedererweckung' },
      stones = { 40 },
      effect = { kind = 'passive', healthBonus = 55, essenceBonus = 70, damageMult = 0.3,
                 regenPerTick = 3, cooldownMult = 0.85 } }

-- Jaeger ---------------------------------------------------------------------

node{ id = 'jaeger_wesensblick', race = 'jaeger', row = 0, col = 2, maxRank = 1,
      label = 'Wesensblick', icon = '🔎',
      description = 'Zeigt dir alle Wesen in der Umgebung.',
      stones = { 5 }, essence = 15, cooldown = 50,
      effect = { kind = 'reveal', radius = 110.0, duration = 20 } }

node{ id = 'jaeger_silbermunition', race = 'jaeger', row = 1, col = 1, maxRank = 5,
      label = 'Silbermunition', icon = '🥈',
      description = 'Gesegnete Kugeln richten deutlich mehr Schaden an.',
      requires = { 'jaeger_wesensblick' }, stones = { base = 5, step = 2 },
      essence = 30, cooldown = { 90, 86, 82, 78, 70 },
      effect = { kind = 'self_buff', duration = { 20, 24, 28, 32, 40 },
                 damageMult = { 1.3, 1.4, 1.5, 1.6, 1.8 } } }

node{ id = 'jaeger_fangeisen', race = 'jaeger', row = 1, col = 2, maxRank = 5,
      label = 'Fangeisen', icon = '🪤',
      description = 'Dein Ziel sitzt fest.',
      requires = { 'jaeger_wesensblick' }, stones = { base = 6, step = 2 },
      essence = 30, cooldown = { 60, 56, 52, 48, 42 },
      effect = { kind = 'curse', range = 22.0, duration = { 5, 6, 7, 8, 10 },
                 slow = { 0.5, 0.45, 0.4, 0.35, 0.25 }, damageOverTime = { 2, 3, 4, 5, 6 } } }

node{ id = 'jaeger_abhaertung', race = 'jaeger', row = 1, col = 3, maxRank = 5,
      label = 'Abhaertung', icon = '🎽', passive = true,
      description = 'Jahre im Feld haben dich zaeh gemacht.',
      requires = { 'jaeger_wesensblick' }, stones = { base = 6, step = 2 },
      effect = { kind = 'passive', healthBonus = { 15, 30, 45, 60, 80 },
                 armorBonus = { 5, 10, 15, 20, 30 } } }

node{ id = 'jaeger_adrenalin', race = 'jaeger', row = 2, col = 1, maxRank = 3,
      label = 'Adrenalin', icon = '💉',
      description = 'Ein Stich, der dich wieder auf die Beine bringt.',
      requires = { 'jaeger_silbermunition' }, stones = { base = 8, step = 3 },
      essence = 40, cooldown = { 100, 90, 80 },
      effect = { kind = 'heal_self', amount = { 45, 60, 80 },
                 buff = { duration = 15, speedMult = 1.2 } } }

node{ id = 'jaeger_splitter', race = 'jaeger', row = 2, col = 2, maxRank = 5,
      label = 'Splittergranate', icon = '💣',
      description = 'Splitter fuer alles, was zu nah kommt.',
      requires = { 'jaeger_fangeisen' }, stones = { base = 7, step = 3 },
      essence = 40, cooldown = { 60, 57, 54, 51, 45 },
      effect = { kind = 'aoe_damage', radius = { 7.0, 8.0, 9.0, 10.0, 12.0 },
                 damage = { 40, 50, 60, 70, 85 }, ragdoll = true } }

node{ id = 'jaeger_rauchbombe', race = 'jaeger', row = 2, col = 3, maxRank = 3,
      label = 'Rauchbombe', icon = '💨',
      description = 'Im Rauch verlierst du dich aus jeder Sicht.',
      requires = { 'jaeger_abhaertung' }, stones = { base = 8, step = 3 },
      essence = 35, cooldown = { 80, 72, 62 },
      effect = { kind = 'stealth', duration = { 8, 11, 14 }, alpha = { 50, 35, 20 }, speedMult = 1.1 } }

node{ id = 'jaeger_scharfschuetze', race = 'jaeger', row = 3, col = 0.5, maxRank = 5,
      label = 'Scharfschuetze', icon = '🎯', passive = true, level = 8,
      description = 'Jeder Schuss sitzt dauerhaft besser.',
      requires = { 'jaeger_adrenalin' }, stones = { base = 10, step = 4 },
      effect = { kind = 'passive', damageMult = { 0.1, 0.2, 0.3, 0.4, 0.55 } } }

node{ id = 'jaeger_feldarzt', race = 'jaeger', row = 3, col = 2, maxRank = 3,
      label = 'Feldarzt', icon = '🩹', level = 8,
      description = 'Du versorgst auch andere im Feld.',
      requires = { 'jaeger_splitter' }, stones = { base = 10, step = 5 },
      essence = 35, cooldown = { 60, 52, 45 },
      effect = { kind = 'heal_target', range = { 8.0, 11.0, 14.0 }, amount = { 45, 65, 90 } } }

node{ id = 'jaeger_weihwasser', race = 'jaeger', row = 3, col = 3.5, maxRank = 3,
      label = 'Weihwasser', icon = '⚱', level = 12,
      description = 'Geweihtes Wasser verbrennt alles Uebernatuerliche.',
      requires = { 'jaeger_rauchbombe' }, stones = { base = 13, step = 7 },
      essence = 60, cooldown = { 120, 108, 95 },
      effect = { kind = 'aoe_damage', radius = { 8.0, 10.0, 12.0 }, damage = { 55, 75, 100 } } }

node{ id = 'jaeger_veteran', race = 'jaeger', row = 4, col = 2, maxRank = 1,
      label = 'Veteran', icon = '🎖', passive = true, level = 18,
      description = 'Du hast alles gejagt, was es zu jagen gibt.',
      requires = { 'jaeger_scharfschuetze', 'jaeger_feldarzt', 'jaeger_weihwasser' },
      stones = { 40 },
      effect = { kind = 'passive', healthBonus = 70, damageMult = 0.4, armorBonus = 50,
                 cooldownMult = 0.85, stamina = 40 } }

-- Nachschlagetabellen und Helfer ---------------------------------------------

Mystic.SkillsById = {}
for _, skill in ipairs(Mystic.Skills) do
    Mystic.SkillsById[skill.id] = skill
end

---@return table|nil
function Mystic.GetSkill(id)
    if type(id) ~= 'string' then return nil end
    return Mystic.SkillsById[id]
end

--- Alle Knoten einer Klasse, nach Position sortiert.
function Mystic.GetSkillsForRace(race)
    local result = {}

    for _, skill in ipairs(Mystic.Skills) do
        if skill.race == race then result[#result + 1] = skill end
    end

    table.sort(result, function(a, b)
        if a.row == b.row then return a.col < b.col end
        return a.row < b.row
    end)
    return result
end

--- Waehlt den Wert einer Stufe: Listen werden indiziert, Skalare bleiben.
local function pick(value, rank)
    if type(value) ~= 'table' then return value end
    return value[math.min(math.max(rank, 1), #value)]
end

Mystic.PickRankValue = pick

--- Loest alle Effektwerte fuer eine Stufe auf.
---@return table flacher Effekt
function Mystic.ResolveEffect(skill, rank)
    local resolved = {}

    for key, value in pairs(skill.effect or {}) do
        if key == 'buff' and type(value) == 'table' then
            local buff = {}
            for buffKey, buffValue in pairs(value) do
                buff[buffKey] = pick(buffValue, rank)
            end
            resolved.buff = buff
        else
            resolved[key] = pick(value, rank)
        end
    end

    return resolved
end

function Mystic.GetEssenceCost(skill, rank)
    return pick(skill.essence, rank) or 0
end

function Mystic.GetCooldown(skill, rank)
    return pick(skill.cooldown, rank) or 10
end

--- Klassensteine fuer den Sprung auf die angegebene Stufe.
---@return number|nil nil wenn die Stufe ausserhalb liegt
function Mystic.GetRankCost(skill, rank)
    if rank < 1 or rank > skill.maxRank then return nil end

    local stones = skill.stones
    if stones.base then
        return math.floor(stones.base + (rank - 1) * (stones.step or 0))
    end
    return stones[math.min(rank, #stones)]
end

--- Gesamtkosten aller bereits gekauften Stufen (fuer die Erstattung).
function Mystic.GetSpentStones(skill, rank)
    local total = 0
    for step = 1, rank do
        total = total + (Mystic.GetRankCost(skill, step) or 0)
    end
    return total
end

--- Sind alle Voraussetzungen mindestens auf Stufe 1?
---@param ranks table { [skillId] = rank }
function Mystic.MeetsRequirements(skill, ranks)
    for _, requiredId in ipairs(skill.requires or {}) do
        if (ranks[requiredId] or 0) < 1 then return false end
    end
    return true
end

--- Kurzbeschreibung der Wirkung auf einer bestimmten Stufe.
--- Wird fuer die Stufenliste im Skilltree verwendet.
---@return string
function Mystic.DescribeRank(skill, rank)
    local e = Mystic.ResolveEffect(skill, rank)
    local kind = e.kind
    local parts = {}

    local function add(text) parts[#parts + 1] = text end
    local function percent(value) return math.floor((value or 0) * 100 + 0.5) end

    if kind == 'drain' then
        add(('%d Schaden'):format(e.damage or 0))
        add(('%d Leben zurueck'):format(e.heal or 0))
        add(e.single and ('%d m Reichweite'):format(e.range or 0)
                      or ('%.1f m Umkreis'):format(e.radius or 0))

    elseif kind == 'aoe_damage' then
        add(('%d Schaden'):format(e.damage or 0))
        add(('%.1f m Umkreis'):format(e.radius or 0))

    elseif kind == 'projectile' then
        add(('%d Schaden'):format(e.damage or 0))
        add(('%d m Reichweite'):format(e.range or 0))

    elseif kind == 'curse' then
        add(('Tempo auf %d%%'):format(percent(e.slow or 1)))
        add(('%d s'):format(e.duration or 0))
        if e.damageOverTime then add(('%d Schaden/Tick'):format(e.damageOverTime)) end
        if e.disarm then add('entwaffnet') end
        if e.radius then add(('%.1f m Umkreis'):format(e.radius)) end

    elseif kind == 'poison' then
        add(('%d Schaden/Tick'):format(e.damagePerTick or 0))
        add(('%d s'):format(e.duration or 0))
        add(('%.1f m Umkreis'):format(e.radius or 0))

    elseif kind == 'fear' then
        add(('%d s Panik'):format(e.duration or 0))
        add(('%.1f m Umkreis'):format(e.radius or 0))

    elseif kind == 'heal_self' then
        add(('+%d Leben'):format(e.amount or 0))
        if e.cleanse then add('reinigt Flueche') end

    elseif kind == 'heal_target' then
        add(('+%d Leben beim Ziel'):format(e.amount or 0))
        add(('%.1f m Reichweite'):format(e.range or 0))

    elseif kind == 'revive_target' then
        add(('belebt mit %d Leben wieder'):format(e.health or 0))
        add(('%.1f m Reichweite'):format(e.range or 0))

    elseif kind == 'shield' then
        add(('+%d Weste'):format(e.armor or 0))
        add(('%d s'):format(e.duration or 0))

    elseif kind == 'self_buff' then
        if e.damageMult then add(('%+d%% Schaden'):format(percent(e.damageMult) - 100)) end
        if e.meleeMult then add(('%+d%% Nahkampf'):format(percent(e.meleeMult) - 100)) end
        if e.speedMult then add(('%+d%% Tempo'):format(percent(e.speedMult) - 100)) end
        if e.armor then add(('+%d Weste'):format(e.armor)) end
        add(('%d s'):format(e.duration or 0))

    elseif kind == 'blink' then
        add(('%.0f m Sprungweite'):format(e.distance or 0))

    elseif kind == 'leap' then
        add(('Sprungkraft %.1f'):format(e.force or 0))
        if e.noFallDamage then add('kein Fallschaden') end

    elseif kind == 'stealth' then
        add(('%d%% sichtbar'):format(math.floor((e.alpha or 0) / 255 * 100 + 0.5)))
        add(('%d s'):format(e.duration or 0))

    elseif kind == 'reveal' then
        add(('%d m Reichweite'):format(e.radius or 0))
        add(('%d s'):format(e.duration or 0))

    elseif kind == 'nightvision' then
        add(('%d s Nachtsicht'):format(e.duration or 0))

    elseif kind == 'transform' then
        add(('%d s Gestaltwandel'):format(e.duration or 0))
        add(('+%d Leben'):format(e.healthBonus or 0))
        add(('%+d%% Nahkampf'):format(percent(e.meleeMult or 1) - 100))

    elseif kind == 'passive' then
        if e.healthBonus then add(('+%d max. Leben'):format(e.healthBonus)) end
        if e.armorBonus then add(('+%d Weste'):format(e.armorBonus)) end
        if e.essenceBonus then add(('+%d max. Essenz'):format(e.essenceBonus)) end
        if e.essenceRegen then add(('+%.1f Essenz/Tick'):format(e.essenceRegen)) end
        if e.regenPerTick then add(('+%d Leben/Tick'):format(e.regenPerTick)) end
        if e.damageMult then add(('+%d%% Schaden'):format(percent(e.damageMult))) end
        if e.meleeMult then add(('+%d%% Nahkampf'):format(percent(e.meleeMult))) end
        if e.speedMult then add(('+%d%% Tempo'):format(percent(e.speedMult))) end
        if e.stamina then add(('+%d%% Ausdauer'):format(e.stamina)) end
        if e.costMult then add(('%d%% Essenzkosten'):format(percent(e.costMult))) end
        if e.cooldownMult then add(('%d%% Abklingzeit'):format(percent(e.cooldownMult))) end
        if e.sunImmune then add('immun gegen Sonnenlicht') end
        if e.fireImmune then add('immun gegen Feuer') end
        if e.noFallDamage then add('kein Fallschaden') end
    end

    if #parts == 0 then return 'Wirkung' end
    return table.concat(parts, ' · ')
end
