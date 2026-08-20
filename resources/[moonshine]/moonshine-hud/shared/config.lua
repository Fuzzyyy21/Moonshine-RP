--- Die Anzeige.
---
--- Bisher lag sie verstreut: eine Karte im Core, eine Uhr in der Welt, ein
--- Balken bei den Beduerfnissen, dazu die Skillleiste. Vier Widgets, vier
--- Ecken, kein gemeinsames Aussehen und nichts davon abschaltbar. Hier
--- laeuft alles zusammen, und jeder Spieler stellt sich ein, was er sehen
--- will.

Hud = Hud or {}

HudConfig = {}

HudConfig.Debug = false

--- Wie oft die Anzeige neue Werte bekommt (Millisekunden).
--- Fahrzeugwerte laufen schneller, sonst ruckelt der Tacho.
HudConfig.Tick = 250
HudConfig.VehicleTick = 90

--- Tasten.
HudConfig.Keys = {
    toggle = 'F7',      -- Anzeige ganz aus
    menu   = '',        -- Einstellungen (im Spiel frei belegbar)
    belt   = 'B',       -- Gurt
}

-- Elemente -------------------------------------------------------------------
--- Alles, was sich einzeln abschalten laesst. Reihenfolge und Gruppen
--- bestimmen zugleich den Aufbau des Einstellungsmenues.
HudConfig.Elements = {
    -- Spieler
    { key = 'spieler',    label = 'Name und ID',      gruppe = 'Spieler', standard = true },
    { key = 'job',        label = 'Job und Rang',     gruppe = 'Spieler', standard = true },
    { key = 'bargeld',    label = 'Bargeld',          gruppe = 'Spieler', standard = true },
    { key = 'bank',       label = 'Bank',             gruppe = 'Spieler', standard = true },
    { key = 'schwarz',    label = 'Schwarzgeld',      gruppe = 'Spieler', standard = false },
    { key = 'fraktion',   label = 'Fraktion',         gruppe = 'Spieler', standard = true },

    -- Zustand
    { key = 'leben',      label = 'Leben',            gruppe = 'Zustand', standard = true },
    { key = 'weste',      label = 'Weste',            gruppe = 'Zustand', standard = true },
    { key = 'hunger',     label = 'Hunger',           gruppe = 'Zustand', standard = true },
    { key = 'durst',      label = 'Durst',            gruppe = 'Zustand', standard = true },
    { key = 'ausdauer',   label = 'Ausdauer',         gruppe = 'Zustand', standard = true },
    { key = 'sauerstoff', label = 'Sauerstoff',       gruppe = 'Zustand', standard = true },
    { key = 'mikrofon',   label = 'Mikrofon',         gruppe = 'Zustand', standard = true },

    -- Klasse: eigenes Band mit Namen und Zahlen. Blut, Mana, Hoellenfeuer
    -- und das Klassenbeduerfnis sind kein Standardzustand - sie sind das,
    -- worum es auf diesem Server geht, und stehen deshalb fuer sich.
    { key = 'essenz',       label = 'Essenz (Blut, Mana …)', gruppe = 'Klasse', standard = true },
    { key = 'klassenname',  label = 'Name der Klasse',       gruppe = 'Klasse', standard = true },
    { key = 'essenzzahl',   label = 'Essenz als Zahl',       gruppe = 'Klasse', standard = true },
    { key = 'klassenstufe', label = 'Klassenstufe',          gruppe = 'Klasse', standard = false },

    -- Welt
    { key = 'uhr',        label = 'Uhrzeit',          gruppe = 'Welt', standard = true },
    { key = 'mond',       label = 'Mondphase',        gruppe = 'Welt', standard = true },
    { key = 'ereignis',   label = 'Weltereignis',     gruppe = 'Welt', standard = true },
    { key = 'ort',        label = 'Straße und Bezirk',gruppe = 'Welt', standard = true },
    { key = 'kompass',    label = 'Kompass',          gruppe = 'Welt', standard = true },

    -- Fahrzeug
    { key = 'tacho',      label = 'Tacho',            gruppe = 'Fahrzeug', standard = true },
    { key = 'drehzahl',   label = 'Drehzahl',         gruppe = 'Fahrzeug', standard = true },
    { key = 'tank',       label = 'Tank',             gruppe = 'Fahrzeug', standard = true },
    { key = 'motor',      label = 'Motorzustand',     gruppe = 'Fahrzeug', standard = true },
    { key = 'gurt',       label = 'Gurt',             gruppe = 'Fahrzeug', standard = true },
    { key = 'blinker',    label = 'Blinker',          gruppe = 'Fahrzeug', standard = true },
    { key = 'licht',      label = 'Licht',            gruppe = 'Fahrzeug', standard = true },
    { key = 'tempomat',   label = 'Tempomat',         gruppe = 'Fahrzeug', standard = true },
}

--- Auswahlmoeglichkeiten fuer die Einstellungen.
HudConfig.Choices = {
    stil = {
        { value = 'ringe',    label = 'Ringe' },
        { value = 'balken',   label = 'Balken' },
        { value = 'segmente', label = 'Segmente' },
        { value = 'bogen',    label = 'Bögen' },
        { value = 'zahlen',   label = 'Zahlen' },
        { value = 'minimal',  label = 'Minimal' },
    },
    ecke = {
        { value = 'ul', label = 'Unten links' },
        { value = 'ur', label = 'Unten rechts' },
        { value = 'ol', label = 'Oben links' },
        { value = 'or', label = 'Oben rechts' },
    },
    klassenEcke = {
        { value = 'status', label = 'Bei der Statusgruppe' },
        { value = 'um',     label = 'Unten mittig' },
        { value = 'ur',     label = 'Unten rechts' },
        { value = 'or',     label = 'Oben rechts' },
    },
    einheit = {
        { value = 'kmh', label = 'km/h' },
        { value = 'mph', label = 'mph' },
    },
    akzent = {
        { value = '#9b6bd8', label = 'Mondviolett' },
        { value = '#e0a642', label = 'Bernstein' },
        { value = '#4caf7d', label = 'Waldgrün' },
        { value = '#3d8bd4', label = 'Nachtblau' },
        { value = '#c0392f', label = 'Blutrot' },
        { value = '#d0d4dd', label = 'Aschgrau' },
    },
}

-- Grenzen ---------------------------------------------------------------------
--- Was der Spieler an den Reglern einstellen darf.
HudConfig.Limits = {
    groesse   = { min = 0.70, max = 1.40, step = 0.05 },
    deckkraft = { min = 0.30, max = 1.00, step = 0.05 },
}

--- Ab wann ein Wert als "auffaellig" gilt und im dynamischen Modus erscheint.
HudConfig.Schwellen = {
    leben      = 95,
    weste      = 1,
    hunger     = 80,
    durst      = 80,
    ausdauer   = 95,
    sauerstoff = 99,
    essenz     = 95,
}

-- Standardeinstellung -----------------------------------------------------------
--- Womit ein Spieler startet, der noch nie etwas eingestellt hat.
function Hud.DefaultSettings()
    local elemente = {}
    for _, element in ipairs(HudConfig.Elements) do
        elemente[element.key] = element.standard
    end

    return {
        an          = true,
        stil        = 'ringe',
        ecke        = 'ul',
        groesse     = 1.0,
        deckkraft   = 0.92,
        akzent      = '#9b6bd8',

        -- Volle Balken ausblenden, bis sich etwas tut.
        dynamisch   = false,

        einheit     = 'kmh',
        gurtWarnung = true,

        -- Wo das Klassenband haengt. 'status' klebt es an die Statusgruppe,
        -- die anderen Werte setzen es frei an einen Rand.
        klassenEcke = 'status',

        elemente    = elemente,
    }
end

--- Himmelsrichtungen im Uhrzeigersinn, beginnend im Norden.
Hud.Compass = { 'N', 'NO', 'O', 'SO', 'S', 'SW', 'W', 'NW' }

--- Himmelsrichtung aus der Blickrichtung des Spielers.
---
--- GTA zaehlt die Blickrichtung gegen den Uhrzeigersinn ab Norden, deshalb
--- laeuft die Liste hier genauso. Die halbe Sektorbreite (22,5 Grad) sorgt
--- dafuer, dass Norden von 337,5 bis 22,5 Grad reicht und nicht erst ab 0.
---@param heading number
---@return string
function Hud.Direction(heading)
    local grad = (tonumber(heading) or 0) % 360
    local index = math.floor((grad + 22.5) / 45.0) % 8

    return Hud.Compass[index + 1]
end

--- Element nach Schluessel.
function Hud.GetElement(key)
    for _, element in ipairs(HudConfig.Elements) do
        if element.key == key then return element end
    end

    return nil
end

--- Alle Gruppen in der Reihenfolge, in der sie zuerst auftauchen.
function Hud.Groups()
    local reihe, gesehen = {}, {}

    for _, element in ipairs(HudConfig.Elements) do
        if not gesehen[element.gruppe] then
            gesehen[element.gruppe] = true
            reihe[#reihe + 1] = element.gruppe
        end
    end

    return reihe
end

--- Ist dieser Wert eine gueltige Auswahl?
function Hud.IsChoice(feld, value)
    for _, entry in ipairs(HudConfig.Choices[feld] or {}) do
        if entry.value == value then return true end
    end

    return false
end

--- Haelt eine Zahl in ihren Grenzen.
function Hud.ClampLimit(feld, value)
    local limit = HudConfig.Limits[feld]
    local zahl = tonumber(value)

    if not limit then return zahl end
    if not zahl then return limit.min end

    if zahl < limit.min then return limit.min end
    if zahl > limit.max then return limit.max end

    return zahl
end

--- Prueft eine ganze Einstellung und ersetzt alles Ungueltige durch den
--- Standard. Laeuft auch ueber das, was aus dem Speicher kommt - eine von
--- Hand verbogene Datei darf die Anzeige nicht zerlegen.
function Hud.Sanitize(input)
    local standard = Hud.DefaultSettings()
    if type(input) ~= 'table' then return standard end

    local result = standard

    if type(input.an) == 'boolean' then result.an = input.an end
    if type(input.dynamisch) == 'boolean' then result.dynamisch = input.dynamisch end
    if type(input.gurtWarnung) == 'boolean' then result.gurtWarnung = input.gurtWarnung end

    for _, feld in ipairs({ 'stil', 'ecke', 'einheit', 'akzent', 'klassenEcke' }) do
        if Hud.IsChoice(feld, input[feld]) then result[feld] = input[feld] end
    end

    for _, feld in ipairs({ 'groesse', 'deckkraft' }) do
        if tonumber(input[feld]) then result[feld] = Hud.ClampLimit(feld, input[feld]) end
    end

    if type(input.elemente) == 'table' then
        for _, element in ipairs(HudConfig.Elements) do
            local wert = input.elemente[element.key]
            if type(wert) == 'boolean' then result.elemente[element.key] = wert end
        end
    end

    return result
end
