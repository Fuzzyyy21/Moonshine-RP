--- Wappen, Logo, Banner und Willkommensbild.
---
--- Statt fertiger Bilddateien setzt sich alles aus Bausteinen zusammen:
--- Schildform, Symbol, Muster und zwei Farben. Die Oberflaeche zeichnet
--- daraus ein SVG - so braucht der Server keine Uploads und jede Fraktion
--- bekommt trotzdem ein eigenes Wappen.

--- Schildformen (SVG-Pfad in einem 100x120-Feld).
Factions.Shapes = {
    { id = 'wappen',   label = 'Wappen',
      path = 'M50 4 L96 20 L96 62 C96 92 74 110 50 116 C26 110 4 92 4 62 L4 20 Z' },
    { id = 'spitz',    label = 'Spitzschild',
      path = 'M50 2 L96 24 L84 96 L50 118 L16 96 L4 24 Z' },
    { id = 'rund',     label = 'Rundschild',
      path = 'M50 4 C86 4 96 30 96 58 C96 92 74 112 50 118 C26 112 4 92 4 58 C4 30 14 4 50 4 Z' },
    { id = 'kreis',    label = 'Siegel',
      path = 'M50 6 A54 54 0 1 1 49.9 6 Z' },
    { id = 'raute',    label = 'Raute',
      path = 'M50 2 L98 60 L50 118 L2 60 Z' },
    { id = 'banner',   label = 'Banner',
      path = 'M8 4 H92 V96 L50 118 L8 96 Z' },
    { id = 'sechseck', label = 'Sechseck',
      path = 'M50 2 L94 28 L94 92 L50 118 L6 92 L6 28 Z' },
    { id = 'klaue',    label = 'Klaue',
      path = 'M50 2 L92 18 L98 60 L72 104 L50 118 L28 104 L2 60 L8 18 Z' },
}

--- Symbole in der Mitte des Wappens.
Factions.Symbols = {
    { id = 'wolf',    label = 'Wolf',       glyph = '🐺' },
    { id = 'fledermaus', label = 'Fledermaus', glyph = '🦇' },
    { id = 'schaedel', label = 'Schaedel',  glyph = '💀' },
    { id = 'auge',    label = 'Auge',       glyph = '👁' },
    { id = 'mond',    label = 'Mond',       glyph = '🌙' },
    { id = 'flamme',  label = 'Flamme',     glyph = '🔥' },
    { id = 'blitz',   label = 'Blitz',      glyph = '⚡' },
    { id = 'krone',   label = 'Krone',      glyph = '👑' },
    { id = 'dolch',   label = 'Dolch',      glyph = '🗡' },
    { id = 'kelch',   label = 'Kelch',      glyph = '🍷' },
    { id = 'rabe',    label = 'Rabe',       glyph = '🐦' },
    { id = 'stern',   label = 'Stern',      glyph = '✦' },
    { id = 'runen',   label = 'Rune',       glyph = 'ᛟ' },
    { id = 'schlange', label = 'Schlange',  glyph = '🐍' },
    { id = 'baum',    label = 'Weltenbaum', glyph = '🌳' },
    { id = 'kristall', label = 'Kristall',  glyph = '🔮' },
    { id = 'zahnrad', label = 'Zahnrad',    glyph = '⚙' },
    { id = 'anker',   label = 'Anker',      glyph = '⚓' },
}

--- Hintergrundmuster des Wappens.
Factions.Patterns = {
    { id = 'voll',      label = 'Einfarbig' },
    { id = 'verlauf',   label = 'Verlauf' },
    { id = 'geteilt',   label = 'Geteilt' },
    { id = 'schraeg',   label = 'Schraeg geteilt' },
    { id = 'streifen',  label = 'Streifen' },
    { id = 'strahlen',  label = 'Strahlen' },
    { id = 'karo',      label = 'Karo' },
    { id = 'kreuz',     label = 'Kreuz' },
}

--- Motive fuer Banner und Willkommensbild.
Factions.Backdrops = {
    { id = 'nebel',    label = 'Nebelwald' },
    { id = 'blutmond', label = 'Blutmond' },
    { id = 'ruinen',   label = 'Ruinen' },
    { id = 'sturm',    label = 'Sturm' },
    { id = 'asche',    label = 'Ascheregen' },
    { id = 'sternen',  label = 'Sternenhimmel' },
}

--- Vorgeschlagene Farben.
Factions.Palette = {
    '#c0392f', '#9b6bd8', '#3d8bd4', '#4caf7d', '#d8b25f',
    '#e07b39', '#8c8c9a', '#d94f8a', '#2f8f8f', '#7a5230',
    '#1a1424', '#f0f0f5',
}

--- Standardwappen fuer neue Fraktionen.
function Factions.DefaultEmblem()
    return {
        shape     = 'wappen',
        symbol    = 'stern',
        pattern   = 'verlauf',
        backdrop  = 'nebel',
        primary   = FactionConfig.DefaultColors.primary,
        secondary = FactionConfig.DefaultColors.secondary,
        motto     = '',
        welcome   = '',
    }
end

local function isKnown(list, id)
    for _, entry in ipairs(list) do
        if entry.id == id then return true end
    end
    return false
end

local function isColor(value)
    return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

--- Prueft und bereinigt ein Wappen aus der Oberflaeche.
function Factions.SanitizeEmblem(input, current)
    local base = current or Factions.DefaultEmblem()
    if type(input) ~= 'table' then return base end

    local emblem = {
        shape     = isKnown(Factions.Shapes, input.shape) and input.shape or base.shape,
        symbol    = isKnown(Factions.Symbols, input.symbol) and input.symbol or base.symbol,
        pattern   = isKnown(Factions.Patterns, input.pattern) and input.pattern or base.pattern,
        backdrop  = isKnown(Factions.Backdrops, input.backdrop) and input.backdrop or base.backdrop,
        primary   = isColor(input.primary) and input.primary or base.primary,
        secondary = isColor(input.secondary) and input.secondary or base.secondary,
        motto     = base.motto or '',
        welcome   = base.welcome or '',
    }

    if type(input.motto) == 'string' then
        emblem.motto = input.motto:sub(1, 64)
    end

    if type(input.welcome) == 'string' then
        emblem.welcome = input.welcome:sub(1, 240)
    end

    return emblem
end

--- Glyph eines Symbols.
function Factions.GetSymbolGlyph(id)
    for _, entry in ipairs(Factions.Symbols) do
        if entry.id == id then return entry.glyph end
    end
    return '✦'
end

--- Alle Bausteine fuer die Oberflaeche.
function Factions.GetEmblemOptions()
    return {
        shapes    = Factions.Shapes,
        symbols   = Factions.Symbols,
        patterns  = Factions.Patterns,
        backdrops = Factions.Backdrops,
        palette   = Factions.Palette,
    }
end
