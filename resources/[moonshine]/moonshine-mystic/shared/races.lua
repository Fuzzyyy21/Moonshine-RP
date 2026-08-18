--- Rassendefinitionen.
---
--- essence  = Ressource fuer Skills (Name, Maximum, Regeneration in %/Tick)
--- stats    = passive Grundwerte der Rasse
---            healthBonus  zusaetzliche max. Lebenspunkte
---            damageMult   Schaden mit Schusswaffen
---            meleeMult    Schaden im Nahkampf
---            speedMult    Bewegungstempo (1.0 = normal)
---            armorBonus   Weste beim Erwecken/Respawn
--- traits   = reine Beschreibungstexte fuer die Oberflaeche
--- weakness = Kennzeichen fuer Sondermechaniken (siehe MysticConfig.Weaknesses)

Mystic.Races = {
    vampir = {
        label = 'Vampir',
        icon  = '🩸',
        color = '#a3232c',
        description = 'Uralte Blutsauger. Stark in der Nacht, verwundbar im Sonnenlicht.',
        essence = { label = 'Blut', max = 100, regen = 1.0 },
        stats   = { healthBonus = 20, damageMult = 1.0,  meleeMult = 1.35, speedMult = 1.08, armorBonus = 0 },
        traits  = {
            'Heilt sich durch das Blut anderer',
            'Sieht im Dunkeln',
            'Nimmt Schaden bei Tageslicht',
        },
        weakness = 'sunlight',
    },

    werwolf = {
        label = 'Werwolf',
        icon  = '🐺',
        color = '#7d5a33',
        description = 'Gestaltwandler mit roher Kraft. Der Mond treibt sie an.',
        essence = { label = 'Wut', max = 100, regen = 1.2 },
        stats   = { healthBonus = 40, damageMult = 0.9, meleeMult = 1.6, speedMult = 1.12, armorBonus = 0 },
        traits  = {
            'Hoher Nahkampfschaden',
            'Nachts deutlich staerker',
            'Wittert Spieler in der Umgebung',
        },
        weakness = 'moonlight',
    },

    daemon = {
        label = 'Daemon',
        icon  = '🔥',
        color = '#c8541e',
        description = 'Aus der Unterwelt heraufbeschworen. Feuer ist ihre Sprache.',
        essence = { label = 'Hoellenfeuer', max = 120, regen = 0.9 },
        stats   = { healthBonus = 30, damageMult = 1.1, meleeMult = 1.25, speedMult = 1.0, armorBonus = 25 },
        traits  = {
            'Flaechenschaden durch Feuer',
            'Beginnt mit Weste',
            'Setzt Gegner in Brand',
        },
    },

    fee = {
        label = 'Fee',
        icon  = '🧚',
        color = '#5fc9a6',
        description = 'Naturgeister. Leicht, schnell und heilend.',
        essence = { label = 'Feenstaub', max = 90, regen = 1.5 },
        stats   = { healthBonus = -10, damageMult = 0.85, meleeMult = 0.9, speedMult = 1.2, armorBonus = 0 },
        traits  = {
            'Heilt sich und andere',
            'Springt ausserordentlich hoch',
            'Wenig Lebenspunkte',
        },
    },

    magier = {
        label = 'Magier',
        icon  = '🪄',
        color = '#4a7fd9',
        description = 'Gelehrte der arkanen Kuenste. Kontrolle statt Kraft.',
        essence = { label = 'Mana', max = 140, regen = 1.4 },
        stats   = { healthBonus = 0, damageMult = 1.0, meleeMult = 0.9, speedMult = 1.0, armorBonus = 0 },
        traits  = {
            'Groesster Essenzvorrat',
            'Teleportiert sich',
            'Arkane Schilde',
        },
    },

    hexer = {
        label = 'Hexer',
        icon  = '🜏',
        color = '#8e5bbd',
        description = 'Flueche, Gifte und Rituale. Schwaecht Gegner, statt sie zu erschlagen.',
        essence = { label = 'Hexenkraft', max = 110, regen = 1.1 },
        stats   = { healthBonus = 10, damageMult = 0.95, meleeMult = 1.0, speedMult = 1.0, armorBonus = 0 },
        traits  = {
            'Verlangsamt und schwaecht Gegner',
            'Gift ueber Zeit',
            'Braut Traenke',
        },
    },

    nekromant = {
        label = 'Nekromant',
        icon  = '💀',
        color = '#6d7f8c',
        description = 'Herrscher ueber den Tod. Nimmt Leben und gibt es zurueck.',
        essence = { label = 'Seelen', max = 100, regen = 0.9 },
        stats   = { healthBonus = 10, damageMult = 1.0, meleeMult = 1.0, speedMult = 0.98, armorBonus = 0 },
        traits  = {
            'Belebt Verbuendete wieder',
            'Zieht Leben aus der Ferne',
            'Verbreitet Furcht',
        },
    },

    jaeger = {
        label = 'Jaeger',
        icon  = '🏹',
        color = '#b8a04a',
        description = 'Mensch geblieben, aber ausgebildet gegen alles Uebernatuerliche.',
        essence = { label = 'Fokus', max = 100, regen = 1.3 },
        stats   = { healthBonus = 25, damageMult = 1.25, meleeMult = 1.1, speedMult = 1.02, armorBonus = 50 },
        traits  = {
            'Hoechster Schusswaffenschaden',
            'Erkennt Wesen in der Naehe',
            'Beginnt mit voller Weste',
        },
    },
}

--- Rassendefinition oder nil.
function Mystic.GetRace(name)
    if type(name) ~= 'string' then return nil end
    return Mystic.Races[name]
end

--- Liste aller Rassen fuer die Oberflaeche.
function Mystic.GetRaceList()
    local list = {}

    for name, race in pairs(Mystic.Races) do
        list[#list + 1] = {
            name        = name,
            label       = race.label,
            icon        = race.icon,
            color       = race.color,
            description = race.description,
            traits      = race.traits,
            essence     = race.essence.label,
        }
    end

    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end
