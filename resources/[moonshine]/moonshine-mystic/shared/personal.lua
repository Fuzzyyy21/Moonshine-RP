--- Persoenlicher Skillbaum.
---
--- Sechs Kategorien, je ein eigener Baum. Bezahlt wird mit Faehigkeitspunkten,
--- die es beim Aufstieg der persoenlichen Stufe gibt (Stufe kommt aus XP).
---
--- Jeder Knoten:
---   id / category / row / col / maxRank / requires
---   cost      Faehigkeitspunkte je Stufe (Zahl oder Liste je Stufe)
---   effect    numerische Felder duerfen Listen je Stufe sein

Mystic.PersonalCategories = {
    {
        id = 'vitalitaet', label = 'Vitalitaet', icon = '❤', color = '#a855f7',
        motto = 'Wahre Staerke kommt nicht von Muskeln, sondern vom Ueberleben.',
        description = 'Leben, Regeneration und Widerstand.',
    },
    {
        id = 'staerke', label = 'Staerke', icon = '💪', color = '#e0453c',
        motto = 'Wer zuerst trifft, trifft am haertesten.',
        description = 'Waffenschaden, Nahkampf und kritische Treffer.',
    },
    {
        id = 'ausdauer', label = 'Ausdauer', icon = '⚡', color = '#e0a642',
        motto = 'Der laengste Atem gewinnt das Rennen.',
        description = 'Sprint, Atem und Kondition.',
    },
    {
        id = 'beweglichkeit', label = 'Beweglichkeit', icon = '🏃', color = '#4ade80',
        motto = 'Was dich nicht trifft, macht dich schneller.',
        description = 'Tempo, Sprungkraft und Fallschaden.',
    },
    {
        id = 'mentalitaet', label = 'Mentalitaet', icon = '🧠', color = '#3b82f6',
        motto = 'Der Geist fuehrt, der Koerper folgt.',
        description = 'Essenz, Abklingzeiten und Erfahrung.',
    },
    {
        id = 'glueck', label = 'Glueck', icon = '🍀', color = '#eab308',
        motto = 'Glueck ist, wenn Vorbereitung auf Gelegenheit trifft.',
        description = 'Beute, Meditation und Verhandlung.',
    },
}

Mystic.PersonalNodes = {}

local function node(definition)
    definition.maxRank  = definition.maxRank or 1
    definition.requires = definition.requires or {}
    definition.cost     = definition.cost or 1

    Mystic.PersonalNodes[#Mystic.PersonalNodes + 1] = definition
    return definition
end

-- Vitalitaet -----------------------------------------------------------------

node{ id = 'vit_leben1', category = 'vitalitaet', row = 0, col = 2, maxRank = 5,
      label = 'Mehr Leben I', icon = '❤',
      description = 'Erhoeht deine maximale Gesundheit dauerhaft.',
      effect = { healthBonus = { 8, 16, 24, 32, 45 } } }

node{ id = 'vit_verstaerkt', category = 'vitalitaet', row = 1, col = 1, maxRank = 3,
      label = 'Verstaerkte Vitalitaet', icon = '🛡',
      description = 'Dein Koerper haelt deutlich mehr aus.',
      requires = { 'vit_leben1' }, effect = { healthBonus = { 12, 25, 40 } } }

node{ id = 'vit_regen1', category = 'vitalitaet', row = 1, col = 2, maxRank = 3,
      label = 'Regeneration I', icon = '➕',
      description = 'Wunden schliessen sich von selbst.',
      requires = { 'vit_leben1' }, effect = { regenPerTick = { 1, 2, 3 } } }

node{ id = 'vit_zaeh1', category = 'vitalitaet', row = 1, col = 3, maxRank = 3,
      label = 'Zaehigkeit I', icon = '🦺',
      description = 'Du startest mit zusaetzlicher Weste.',
      requires = { 'vit_leben1' }, effect = { armorBonus = { 8, 16, 25 } } }

node{ id = 'vit_leben2', category = 'vitalitaet', row = 2, col = 0.5, maxRank = 3,
      label = 'Mehr Leben II', icon = '❤',
      description = 'Noch mehr Lebenskraft.',
      requires = { 'vit_verstaerkt' }, effect = { healthBonus = { 20, 40, 65 } } }

node{ id = 'vit_regen2', category = 'vitalitaet', row = 2, col = 1.5, maxRank = 3,
      label = 'Regeneration II', icon = '➕',
      description = 'Deine Heilung beschleunigt sich weiter.',
      requires = { 'vit_regen1' }, effect = { regenPerTick = { 2, 4, 6 } } }

node{ id = 'vit_reduktion1', category = 'vitalitaet', row = 2, col = 2.5, maxRank = 3,
      label = 'Schadensreduktion I', icon = '🛡',
      description = 'Eingehender Schaden wird abgeschwaecht.',
      requires = { 'vit_regen1' }, effect = { damageReduction = { 0.03, 0.06, 0.10 } } }

node{ id = 'vit_zaeh2', category = 'vitalitaet', row = 2, col = 3.5, maxRank = 3,
      label = 'Zaehigkeit II', icon = '🦺',
      description = 'Deine Weste haelt laenger durch.',
      requires = { 'vit_zaeh1' }, effect = { armorBonus = { 15, 30, 50 } } }

node{ id = 'vit_lebensraub', category = 'vitalitaet', row = 3, col = 0.5, maxRank = 1, cost = 3,
      label = 'Lebensraub', icon = '💧',
      description = 'Ein Teil des Nahkampfschadens kehrt als Leben zurueck.',
      requires = { 'vit_leben2' }, effect = { lifesteal = 0.15 } }

node{ id = 'vit_unzerstoerbar', category = 'vitalitaet', row = 3, col = 1.5, maxRank = 1, cost = 3,
      label = 'Unzerstoerbar', icon = '🛡',
      description = 'Dauerhaft weniger Schaden und mehr Weste.',
      requires = { 'vit_regen2', 'vit_reduktion1' },
      effect = { damageReduction = 0.08, armorBonus = 25 } }

node{ id = 'vit_lebenskern', category = 'vitalitaet', row = 3, col = 2.5, maxRank = 1, cost = 3,
      label = 'Lebenskern', icon = '💜',
      description = 'Ein Kern reiner Lebenskraft schlaegt in dir.',
      requires = { 'vit_reduktion1' }, effect = { healthBonus = 80, regenPerTick = 3 } }

node{ id = 'vit_ewig', category = 'vitalitaet', row = 3, col = 3.5, maxRank = 1, cost = 3,
      label = 'Ewige Vitalitaet', icon = '♾',
      description = 'Du erholst dich schneller als andere verletzen koennen.',
      requires = { 'vit_zaeh2' }, effect = { regenPerTick = 5, healthBonus = 40 } }

-- Staerke --------------------------------------------------------------------

node{ id = 'str_kraft1', category = 'staerke', row = 0, col = 2, maxRank = 5,
      label = 'Rohe Kraft I', icon = '💪',
      description = 'Erhoeht deinen Nahkampfschaden dauerhaft.',
      effect = { meleeMult = { 0.05, 0.10, 0.16, 0.22, 0.30 } } }

node{ id = 'str_waffen1', category = 'staerke', row = 1, col = 1, maxRank = 3,
      label = 'Waffenschaden I', icon = '🔫',
      description = 'Deine Schusswaffen richten mehr Schaden an.',
      requires = { 'str_kraft1' }, effect = { damageMult = { 0.05, 0.10, 0.16 } } }

node{ id = 'str_faust1', category = 'staerke', row = 1, col = 2, maxRank = 3,
      label = 'Faustschlag I', icon = '👊',
      description = 'Deine Schlaege sitzen schwerer.',
      requires = { 'str_kraft1' }, effect = { meleeMult = { 0.08, 0.16, 0.26 } } }

node{ id = 'str_praezision', category = 'staerke', row = 1, col = 3, maxRank = 3,
      label = 'Praezision', icon = '🎯',
      description = 'Chance auf kritische Treffer gegen Gegner.',
      requires = { 'str_kraft1' }, effect = { critChance = { 0.03, 0.06, 0.10 } } }

node{ id = 'str_waffen2', category = 'staerke', row = 2, col = 0.5, maxRank = 3,
      label = 'Waffenschaden II', icon = '🔫',
      description = 'Noch mehr Durchschlagskraft.',
      requires = { 'str_waffen1' }, effect = { damageMult = { 0.08, 0.16, 0.25 } } }

node{ id = 'str_faust2', category = 'staerke', row = 2, col = 1.5, maxRank = 3,
      label = 'Faustschlag II', icon = '👊',
      description = 'Deine Faeuste brechen Knochen.',
      requires = { 'str_faust1' }, effect = { meleeMult = { 0.12, 0.24, 0.38 } } }

node{ id = 'str_kritisch', category = 'staerke', row = 2, col = 2.5, maxRank = 3,
      label = 'Kritischer Treffer', icon = '💥',
      description = 'Kritische Treffer richten deutlich mehr Schaden an.',
      requires = { 'str_praezision' }, effect = { critBonus = { 0.25, 0.5, 0.8 } } }

node{ id = 'str_durchschlag', category = 'staerke', row = 2, col = 3.5, maxRank = 3,
      label = 'Durchschlag', icon = '🗡',
      description = 'Deine Angriffe achten weniger auf Panzerung.',
      requires = { 'str_praezision' }, effect = { damageMult = { 0.06, 0.12, 0.20 } } }

node{ id = 'str_vernichter', category = 'staerke', row = 3, col = 0.5, maxRank = 1, cost = 3,
      label = 'Vernichter', icon = '☠',
      description = 'Deine Waffen schlagen mit voller Wucht zu.',
      requires = { 'str_waffen2' }, effect = { damageMult = 0.20 } }

node{ id = 'str_berserker', category = 'staerke', row = 3, col = 1.5, maxRank = 1, cost = 3,
      label = 'Berserker', icon = '🪓',
      description = 'Im Nahkampf bist du nicht aufzuhalten.',
      requires = { 'str_faust2' }, effect = { meleeMult = 0.35 } }

node{ id = 'str_scharfschuetze', category = 'staerke', row = 3, col = 2.5, maxRank = 1, cost = 3,
      label = 'Scharfschuetze', icon = '🔭',
      description = 'Jeder Schuss kann toedlich sein.',
      requires = { 'str_kritisch' }, effect = { critChance = 0.10, critBonus = 0.5 } }

node{ id = 'str_waffenmeister', category = 'staerke', row = 3, col = 3.5, maxRank = 1, cost = 3,
      label = 'Waffenmeister', icon = '🏅',
      description = 'Jede Waffe liegt dir in der Hand.',
      requires = { 'str_durchschlag' }, effect = { damageMult = 0.12, critChance = 0.05 } }

-- Ausdauer -------------------------------------------------------------------

node{ id = 'aus_kondition1', category = 'ausdauer', row = 0, col = 2, maxRank = 5,
      label = 'Kondition I', icon = '⚡',
      description = 'Du kannst deutlich laenger sprinten.',
      effect = { stamina = { 8, 16, 24, 32, 45 } } }

node{ id = 'aus_atem', category = 'ausdauer', row = 1, col = 1, maxRank = 3,
      label = 'Langer Atem', icon = '🫁',
      description = 'Du haeltst laenger die Luft an.',
      requires = { 'aus_kondition1' }, effect = { breath = { 15, 30, 50 } } }

node{ id = 'aus_sprint1', category = 'ausdauer', row = 1, col = 2, maxRank = 3,
      label = 'Sprintkraft I', icon = '🏃',
      description = 'Dein Sprint wird schneller.',
      requires = { 'aus_kondition1' }, effect = { sprintMult = { 0.04, 0.08, 0.12 } } }

node{ id = 'aus_schwimmen1', category = 'ausdauer', row = 1, col = 3, maxRank = 3,
      label = 'Schwimmer I', icon = '🏊',
      description = 'Du kommst im Wasser schneller voran.',
      requires = { 'aus_kondition1' }, effect = { swimMult = { 0.06, 0.12, 0.20 } } }

node{ id = 'aus_kondition2', category = 'ausdauer', row = 2, col = 0.5, maxRank = 3,
      label = 'Kondition II', icon = '⚡',
      description = 'Deine Ausdauer haelt noch laenger.',
      requires = { 'aus_atem' }, effect = { stamina = { 15, 30, 50 } } }

node{ id = 'aus_sprint2', category = 'ausdauer', row = 2, col = 1.5, maxRank = 3,
      label = 'Sprintkraft II', icon = '🏃',
      description = 'Noch mehr Tempo im Sprint.',
      requires = { 'aus_sprint1' }, effect = { sprintMult = { 0.06, 0.12, 0.18 } } }

node{ id = 'aus_taucher', category = 'ausdauer', row = 2, col = 2.5, maxRank = 3,
      label = 'Taucher', icon = '🤿',
      description = 'Unter Wasser bist du zu Hause.',
      requires = { 'aus_schwimmen1' }, effect = { breath = { 25, 50, 80 }, swimMult = { 0.04, 0.08, 0.12 } } }

node{ id = 'aus_laeufer', category = 'ausdauer', row = 2, col = 3.5, maxRank = 3,
      label = 'Zaeher Laeufer', icon = '👟',
      description = 'Ausdauer und Tempo zugleich.',
      requires = { 'aus_schwimmen1' }, effect = { stamina = { 10, 20, 35 }, speedMult = { 0.01, 0.02, 0.03 } } }

node{ id = 'aus_marathon', category = 'ausdauer', row = 3, col = 0.5, maxRank = 1, cost = 3,
      label = 'Marathon', icon = '🥇',
      description = 'Dein Sprint kennt kaum noch ein Ende.',
      requires = { 'aus_kondition2' }, effect = { stamina = 60 } }

node{ id = 'aus_windlaeufer', category = 'ausdauer', row = 3, col = 1.5, maxRank = 1, cost = 3,
      label = 'Windlaeufer', icon = '🌬',
      description = 'Du laeufst schneller als der Wind.',
      requires = { 'aus_sprint2' }, effect = { sprintMult = 0.15, speedMult = 0.03 } }

node{ id = 'aus_delfin', category = 'ausdauer', row = 3, col = 2.5, maxRank = 1, cost = 3,
      label = 'Delfin', icon = '🐬',
      description = 'Im Wasser bist du kaum einzuholen.',
      requires = { 'aus_taucher' }, effect = { swimMult = 0.25, breath = 100 } }

node{ id = 'aus_unermuedlich', category = 'ausdauer', row = 3, col = 3.5, maxRank = 1, cost = 3,
      label = 'Unermuedlich', icon = '♾',
      description = 'Erschoepfung ist ein Fremdwort fuer dich.',
      requires = { 'aus_laeufer' }, effect = { stamina = 40, regenPerTick = 2 } }

-- Beweglichkeit --------------------------------------------------------------

node{ id = 'bew_fuesse1', category = 'beweglichkeit', row = 0, col = 2, maxRank = 5,
      label = 'Flinke Fuesse I', icon = '🏃',
      description = 'Du bewegst dich schneller zu Fuss.',
      effect = { speedMult = { 0.01, 0.02, 0.03, 0.04, 0.06 } } }

node{ id = 'bew_leicht', category = 'beweglichkeit', row = 1, col = 1, maxRank = 3,
      label = 'Leichter Schritt', icon = '🍃',
      description = 'Stuerze tun dir weniger weh.',
      requires = { 'bew_fuesse1' }, effect = { fallReduction = { 0.2, 0.4, 0.6 } } }

node{ id = 'bew_katze', category = 'beweglichkeit', row = 1, col = 2, maxRank = 3,
      label = 'Katzenhaft', icon = '🐈',
      description = 'Du kommst schneller wieder auf die Beine.',
      requires = { 'bew_fuesse1' }, effect = { ragdollResist = { 0.2, 0.4, 0.6 } } }

node{ id = 'bew_fuesse2', category = 'beweglichkeit', row = 1, col = 3, maxRank = 3,
      label = 'Flinke Fuesse II', icon = '🏃',
      description = 'Noch mehr Tempo.',
      requires = { 'bew_fuesse1' }, effect = { speedMult = { 0.02, 0.04, 0.06 } } }

node{ id = 'bew_sprung', category = 'beweglichkeit', row = 2, col = 0.5, maxRank = 3,
      label = 'Sprungkraft', icon = '🦿',
      description = 'Du springst hoeher als andere.',
      requires = { 'bew_leicht' }, effect = { jumpBonus = { 0.1, 0.2, 0.35 } } }

node{ id = 'bew_trittsicher', category = 'beweglichkeit', row = 2, col = 1.5, maxRank = 3,
      label = 'Trittsicher', icon = '🥾',
      description = 'Selbst tiefe Stuerze steckst du weg.',
      requires = { 'bew_leicht' }, effect = { fallReduction = { 0.25, 0.5, 0.75 } } }

node{ id = 'bew_ausweichen', category = 'beweglichkeit', row = 2, col = 2.5, maxRank = 3,
      label = 'Ausweichen', icon = '💨',
      description = 'Manche Treffer gehen an dir vorbei.',
      requires = { 'bew_katze' }, effect = { damageReduction = { 0.02, 0.04, 0.07 } } }

node{ id = 'bew_fuesse3', category = 'beweglichkeit', row = 2, col = 3.5, maxRank = 3,
      label = 'Flinke Fuesse III', icon = '🏃',
      description = 'Kaum jemand haelt mit dir mit.',
      requires = { 'bew_fuesse2' }, effect = { speedMult = { 0.03, 0.05, 0.08 } } }

node{ id = 'bew_schattenlaeufer', category = 'beweglichkeit', row = 3, col = 0.5, maxRank = 1, cost = 3,
      label = 'Schattenlaeufer', icon = '🌑',
      description = 'Dein Tempo ist nicht mehr menschlich.',
      requires = { 'bew_sprung' }, effect = { speedMult = 0.08, sprintMult = 0.08 } }

node{ id = 'bew_federleicht', category = 'beweglichkeit', row = 3, col = 1.5, maxRank = 1, cost = 3,
      label = 'Federleicht', icon = '🪶',
      description = 'Fallschaden gibt es fuer dich nicht mehr.',
      requires = { 'bew_trittsicher' }, effect = { noFallDamage = true } }

node{ id = 'bew_akrobat', category = 'beweglichkeit', row = 3, col = 2.5, maxRank = 1, cost = 3,
      label = 'Akrobat', icon = '🤸',
      description = 'Sprung und Landung sitzen immer.',
      requires = { 'bew_ausweichen' }, effect = { jumpBonus = 0.4, fallReduction = 0.5 } }

node{ id = 'bew_unfassbar', category = 'beweglichkeit', row = 3, col = 3.5, maxRank = 1, cost = 3,
      label = 'Unfassbar', icon = '👻',
      description = 'Wer dich treffen will, muss sich anstrengen.',
      requires = { 'bew_fuesse3' }, effect = { damageReduction = 0.06, ragdollResist = 0.5 } }

-- Mentalitaet ----------------------------------------------------------------

node{ id = 'men_fokus1', category = 'mentalitaet', row = 0, col = 2, maxRank = 5,
      label = 'Fokus I', icon = '🧠',
      description = 'Vergroessert deinen Essenzvorrat.',
      effect = { essenceBonus = { 8, 16, 24, 32, 45 } } }

node{ id = 'men_fluss1', category = 'mentalitaet', row = 1, col = 1, maxRank = 3,
      label = 'Essenzfluss I', icon = '🔵',
      description = 'Deine Essenz fuellt sich schneller.',
      requires = { 'men_fokus1' }, effect = { essenceRegen = { 0.3, 0.6, 1.0 } } }

node{ id = 'men_konzentration1', category = 'mentalitaet', row = 1, col = 2, maxRank = 3,
      label = 'Konzentration I', icon = '⏱',
      description = 'Verkuerzt die Abklingzeit deiner Klassenskills.',
      requires = { 'men_fokus1' }, effect = { cooldownMult = { -0.03, -0.06, -0.10 } } }

node{ id = 'men_sparsam1', category = 'mentalitaet', row = 1, col = 3, maxRank = 3,
      label = 'Sparsamkeit I', icon = '📗',
      description = 'Deine Faehigkeiten kosten weniger Essenz.',
      requires = { 'men_fokus1' }, effect = { costMult = { -0.04, -0.08, -0.12 } } }

node{ id = 'men_fokus2', category = 'mentalitaet', row = 2, col = 0.5, maxRank = 3,
      label = 'Fokus II', icon = '🧠',
      description = 'Noch mehr Essenz.',
      requires = { 'men_fluss1' }, effect = { essenceBonus = { 15, 30, 50 } } }

node{ id = 'men_fluss2', category = 'mentalitaet', row = 2, col = 1.5, maxRank = 3,
      label = 'Essenzfluss II', icon = '🔵',
      description = 'Deine Essenz stroemt spuerbar schneller.',
      requires = { 'men_fluss1' }, effect = { essenceRegen = { 0.5, 1.0, 1.6 } } }

node{ id = 'men_konzentration2', category = 'mentalitaet', row = 2, col = 2.5, maxRank = 3,
      label = 'Konzentration II', icon = '⏱',
      description = 'Deine Faehigkeiten sind schneller wieder bereit.',
      requires = { 'men_konzentration1' }, effect = { cooldownMult = { -0.04, -0.08, -0.13 } } }

node{ id = 'men_gelehrsamkeit', category = 'mentalitaet', row = 2, col = 3.5, maxRank = 3,
      label = 'Gelehrsamkeit', icon = '📘',
      description = 'Du sammelst schneller Erfahrung.',
      requires = { 'men_sparsam1' }, effect = { xpBonus = { 0.05, 0.10, 0.18 } } }

node{ id = 'men_arkan', category = 'mentalitaet', row = 3, col = 0.5, maxRank = 1, cost = 3,
      label = 'Arkaner Geist', icon = '🔮',
      description = 'Dein Vorrat wirkt beinahe unerschoepflich.',
      requires = { 'men_fokus2' }, effect = { essenceBonus = 70, essenceRegen = 1.0 } }

node{ id = 'men_schnelldenker', category = 'mentalitaet', row = 3, col = 1.5, maxRank = 1, cost = 3,
      label = 'Schnelldenker', icon = '⚙',
      description = 'Deine Faehigkeiten kennen kaum Pausen.',
      requires = { 'men_fluss2', 'men_konzentration2' }, effect = { cooldownMult = -0.12 } }

node{ id = 'men_effizienz', category = 'mentalitaet', row = 3, col = 2.5, maxRank = 1, cost = 3,
      label = 'Effizienz', icon = '📕',
      description = 'Kaum ein Tropfen Essenz geht verloren.',
      requires = { 'men_konzentration2' }, effect = { costMult = -0.15 } }

node{ id = 'men_weiser', category = 'mentalitaet', row = 3, col = 3.5, maxRank = 1, cost = 3,
      label = 'Weiser', icon = '🦉',
      description = 'Aus allem, was du tust, lernst du mehr.',
      requires = { 'men_gelehrsamkeit' }, effect = { xpBonus = 0.25 } }

-- Glueck ---------------------------------------------------------------------

node{ id = 'glu_auge1', category = 'glueck', row = 0, col = 2, maxRank = 5,
      label = 'Gutes Auge I', icon = '🍀',
      description = 'Chance auf zusaetzliche Beute beim Weltboss.',
      effect = { lootChance = { 0.04, 0.08, 0.12, 0.16, 0.22 } } }

node{ id = 'glu_sammler', category = 'glueck', row = 1, col = 1, maxRank = 3,
      label = 'Sammlerglueck', icon = '🎁',
      description = 'Noch haeufiger ein Stein extra.',
      requires = { 'glu_auge1' }, effect = { lootChance = { 0.05, 0.10, 0.16 } } }

node{ id = 'glu_meditation', category = 'glueck', row = 1, col = 2, maxRank = 3,
      label = 'Meditationsglueck', icon = '🧘',
      description = 'Meditation bringt dir mehr Punkte.',
      requires = { 'glu_auge1' }, effect = { meditationBonus = { 1, 1, 2 } } }

node{ id = 'glu_haendler', category = 'glueck', row = 1, col = 3, maxRank = 3,
      label = 'Haendlerglueck', icon = '💰',
      description = 'Rituale werfen mehr Geld ab.',
      requires = { 'glu_auge1' }, effect = { moneyBonus = { 0.05, 0.10, 0.16 } } }

node{ id = 'glu_auge2', category = 'glueck', row = 2, col = 0.5, maxRank = 3,
      label = 'Gutes Auge II', icon = '🍀',
      description = 'Dein Blick fuer Wertvolles schaerft sich.',
      requires = { 'glu_sammler' }, effect = { lootChance = { 0.06, 0.12, 0.20 } } }

node{ id = 'glu_beute', category = 'glueck', row = 2, col = 1.5, maxRank = 3,
      label = 'Reiche Beute', icon = '💎',
      description = 'Wenn du Glueck hast, dann richtig.',
      requires = { 'glu_sammler' }, effect = { lootChance = { 0.05, 0.10, 0.15 }, lootAmount = { 1, 1, 2 } } }

node{ id = 'glu_segensreich', category = 'glueck', row = 2, col = 2.5, maxRank = 3,
      label = 'Segensreich', icon = '✨',
      description = 'Deine Versenkung traegt reichere Fruechte.',
      requires = { 'glu_meditation' }, effect = { meditationBonus = { 1, 2, 3 } } }

node{ id = 'glu_verhandlung', category = 'glueck', row = 2, col = 3.5, maxRank = 3,
      label = 'Verhandlung', icon = '🤝',
      description = 'Du holst mehr aus jedem Ritual heraus.',
      requires = { 'glu_haendler' }, effect = { moneyBonus = { 0.06, 0.12, 0.20 } } }

node{ id = 'glu_glueckskind', category = 'glueck', row = 3, col = 0.5, maxRank = 1, cost = 3,
      label = 'Glueckskind', icon = '🌟',
      description = 'Das Schicksal steht auf deiner Seite.',
      requires = { 'glu_auge2' }, effect = { lootChance = 0.25 } }

node{ id = 'glu_schatzsucher', category = 'glueck', row = 3, col = 1.5, maxRank = 1, cost = 3,
      label = 'Schatzsucher', icon = '🗺',
      description = 'Du findest, was andere uebersehen.',
      requires = { 'glu_beute' }, effect = { lootChance = 0.15, lootAmount = 2 } }

node{ id = 'glu_erleuchtung', category = 'glueck', row = 3, col = 2.5, maxRank = 1, cost = 3,
      label = 'Erleuchtung', icon = '🕯',
      description = 'Jede Versenkung schenkt dir mehr.',
      requires = { 'glu_segensreich' }, effect = { meditationBonus = 3 } }

node{ id = 'glu_goldenehand', category = 'glueck', row = 3, col = 3.5, maxRank = 1, cost = 3,
      label = 'Goldene Hand', icon = '🪙',
      description = 'Alles, was du anfasst, bringt Gewinn.',
      requires = { 'glu_verhandlung' }, effect = { moneyBonus = 0.25 } }

-- Helfer ---------------------------------------------------------------------

Mystic.PersonalNodesById = {}
for _, entry in ipairs(Mystic.PersonalNodes) do
    Mystic.PersonalNodesById[entry.id] = entry
end

---@return table|nil
function Mystic.GetPersonalNode(id)
    if type(id) ~= 'string' then return nil end
    return Mystic.PersonalNodesById[id]
end

---@return table|nil
function Mystic.GetPersonalCategory(id)
    for _, category in ipairs(Mystic.PersonalCategories) do
        if category.id == id then return category end
    end
end

--- Alle Knoten einer Kategorie, nach Position sortiert.
function Mystic.GetPersonalNodesFor(categoryId)
    local result = {}

    for _, entry in ipairs(Mystic.PersonalNodes) do
        if entry.category == categoryId then result[#result + 1] = entry end
    end

    table.sort(result, function(a, b)
        if a.row == b.row then return a.col < b.col end
        return a.row < b.row
    end)
    return result
end

--- Wie viele Stufen eine Kategorie insgesamt hergibt.
function Mystic.GetCategoryMaxRanks(categoryId)
    local total = 0
    for _, entry in ipairs(Mystic.GetPersonalNodesFor(categoryId)) do
        total = total + entry.maxRank
    end
    return total
end

--- Punktekosten fuer eine bestimmte Stufe.
---@return number|nil nil ausserhalb des gueltigen Bereichs
function Mystic.GetPersonalCost(entry, rank)
    if rank < 1 or rank > entry.maxRank then return nil end
    return Mystic.PickRankValue(entry.cost, rank) or 1
end

--- Gesamte Punktekosten aller gekauften Stufen (fuer die Erstattung).
function Mystic.GetSpentPoints(entry, rank)
    local total = 0
    for step = 1, rank do
        total = total + (Mystic.GetPersonalCost(entry, step) or 0)
    end
    return total
end

function Mystic.MeetsPersonalRequirements(entry, ranks)
    for _, requiredId in ipairs(entry.requires or {}) do
        if (ranks[requiredId] or 0) < 1 then return false end
    end
    return true
end

--- Werte eines Knotens auf einer bestimmten Stufe.
function Mystic.ResolvePersonal(entry, rank)
    local resolved = {}
    for key, value in pairs(entry.effect or {}) do
        resolved[key] = Mystic.PickRankValue(value, rank)
    end
    return resolved
end

--- Summiert alle gelernten Knoten zu einem Modifikatorenblock.
---@param ranks table { [nodeId] = rank }
function Mystic.SumPersonal(ranks)
    local total = {
        healthBonus = 0, armorBonus = 0, stamina = 0, regenPerTick = 0,
        damageMult = 0, meleeMult = 0, speedMult = 0, sprintMult = 0,
        swimMult = 0, breath = 0, jumpBonus = 0,
        damageReduction = 0, fallReduction = 0, ragdollResist = 0,
        lifesteal = 0, critChance = 0, critBonus = 0,
        essenceBonus = 0, essenceRegen = 0, cooldownMult = 0, costMult = 0,
        xpBonus = 0, moneyBonus = 0, lootChance = 0, lootAmount = 0,
        meditationBonus = 0, noFallDamage = false,
    }

    for nodeId, rank in pairs(ranks or {}) do
        local entry = Mystic.GetPersonalNode(nodeId)

        if entry and type(rank) == 'number' and rank > 0 then
            local effect = Mystic.ResolvePersonal(entry, math.min(rank, entry.maxRank))

            for key, value in pairs(effect) do
                if key == 'noFallDamage' then
                    total.noFallDamage = total.noFallDamage or value == true
                elseif type(value) == 'number' then
                    total[key] = (total[key] or 0) + value
                end
            end
        end
    end

    -- Obergrenzen, damit nichts entgleist.
    total.damageReduction = math.min(total.damageReduction, 0.6)
    total.fallReduction   = math.min(total.fallReduction, 1.0)
    total.ragdollResist   = math.min(total.ragdollResist, 1.0)
    total.critChance      = math.min(total.critChance, 0.6)
    total.cooldownMult    = math.max(total.cooldownMult, -0.5)
    total.costMult        = math.max(total.costMult, -0.5)

    return total
end

--- Beschreibt die Wirkung eines Knotens auf einer Stufe.
function Mystic.DescribePersonalRank(entry, rank)
    local effect = Mystic.ResolvePersonal(entry, rank)
    local parts = {}

    local function percent(value) return math.floor(value * 100 + 0.5) end
    local labels = {
        healthBonus     = function(v) return ('+%d max. Leben'):format(v) end,
        armorBonus      = function(v) return ('+%d Weste'):format(v) end,
        stamina         = function(v) return ('+%d%% Ausdauer'):format(v) end,
        regenPerTick    = function(v) return ('+%d Leben alle 5 s'):format(v) end,
        damageMult      = function(v) return ('+%d%% Waffenschaden'):format(percent(v)) end,
        meleeMult       = function(v) return ('+%d%% Nahkampfschaden'):format(percent(v)) end,
        speedMult       = function(v) return ('+%d%% Tempo'):format(percent(v)) end,
        sprintMult      = function(v) return ('+%d%% Sprinttempo'):format(percent(v)) end,
        swimMult        = function(v) return ('+%d%% Schwimmtempo'):format(percent(v)) end,
        breath          = function(v) return ('+%d%% Atemluft'):format(v) end,
        jumpBonus       = function(v) return ('+%d%% Sprungkraft'):format(percent(v)) end,
        damageReduction = function(v) return ('%d%% weniger Schaden'):format(percent(v)) end,
        fallReduction   = function(v) return ('%d%% weniger Fallschaden'):format(percent(v)) end,
        ragdollResist   = function(v) return ('%d%% Standfestigkeit'):format(percent(v)) end,
        lifesteal       = function(v) return ('%d%% Lebensraub im Nahkampf'):format(percent(v)) end,
        critChance      = function(v) return ('%d%% kritische Chance'):format(percent(v)) end,
        critBonus       = function(v) return ('+%d%% kritischer Schaden'):format(percent(v)) end,
        essenceBonus    = function(v) return ('+%d max. Essenz'):format(v) end,
        essenceRegen    = function(v) return ('+%.1f Essenz/Tick'):format(v) end,
        cooldownMult    = function(v) return ('%d%% Abklingzeit'):format(percent(v)) end,
        costMult        = function(v) return ('%d%% Essenzkosten'):format(percent(v)) end,
        xpBonus         = function(v) return ('+%d%% Erfahrung'):format(percent(v)) end,
        moneyBonus      = function(v) return ('+%d%% Ritualgeld'):format(percent(v)) end,
        lootChance      = function(v) return ('%d%% Chance auf Extrabeute'):format(percent(v)) end,
        lootAmount      = function(v) return ('+%d Steine bei Extrabeute'):format(v) end,
        meditationBonus = function(v) return ('+%d Meditationspunkte'):format(v) end,
        noFallDamage    = function() return 'kein Fallschaden' end,
    }

    for key, value in pairs(effect) do
        local formatter = labels[key]
        if formatter and (value ~= false) then
            parts[#parts + 1] = formatter(value)
        end
    end

    table.sort(parts)
    if #parts == 0 then return 'Wirkung' end
    return table.concat(parts, ' · ')
end
