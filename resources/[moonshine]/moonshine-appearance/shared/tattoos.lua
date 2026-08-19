--- Taetowierungen.
---
--- GTA legt Tattoos nicht als Kleidungsteil ab, sondern als "Decoration":
--- eine Sammlung (`collection`) plus ein Aufdruck (`overlay`), beide als
--- Hash. Maenner und Frauen haben eigene Aufdrucke - deshalb steht hier je
--- Eintrag beides.
---
--- WICHTIG: Die Aufdrucknamen folgen dem Muster der GTA-DLC-Pakete. Sie
--- gehoeren auf dieselbe Liste wie die Koordinaten: einmal im Spiel
--- nachsehen, ob jedes Motiv wirklich erscheint. Ein falscher Name wirft
--- keinen Fehler - es passiert schlicht nichts.

-- Koerperzonen -----------------------------------------------------------------
--- Reihenfolge bestimmt die Anzeige im Studio.
Appearance.TattooZones = {
    { key = 'kopf',       label = 'Kopf und Hals', icon = '💀', tier = 'gross' },
    { key = 'brust',      label = 'Brust',         icon = '🫀', tier = 'gross' },
    { key = 'bauch',      label = 'Bauch',         icon = '🌀', tier = 'mittel' },
    { key = 'ruecken',    label = 'Rücken',        icon = '🦇', tier = 'gross' },
    { key = 'armLinks',   label = 'Linker Arm',    icon = '🫲', tier = 'mittel' },
    { key = 'armRechts',  label = 'Rechter Arm',   icon = '🫱', tier = 'mittel' },
    { key = 'beinLinks',  label = 'Linkes Bein',   icon = '🦵', tier = 'klein' },
    { key = 'beinRechts', label = 'Rechtes Bein',  icon = '🦿', tier = 'klein' },
}

--- Die DLC-Sammlungen, aus denen die Motive stammen.
Appearance.TattooCollections = {
    strand  = 'mpbeach_overlays',
    business= 'mpbusiness_overlays',
    hipster = 'mphipster_overlays',
    luxus   = 'mpluxe_overlays',
    luxus2  = 'mpluxe2_overlays',
    vinewood= 'mpvinewood_overlays',
}

--- Baut die Aufdrucknamen eines DLC-Pakets.
---
--- Die Pakete folgen alle demselben Muster: `<Praefix>_<M|F>_<Zone>_<NNN>`,
--- zum Beispiel `MP_Bea_M_Back_003`. Damit steht unten nur das Motiv, nicht
--- dreimal derselbe String.
---@param prefix string z. B. 'MP_Bea'
---@param teil string z. B. 'Back'
---@param nummer number
---@return string male, string female
local function namen(prefix, teil, nummer)
    local suffix = ('%s_%03d'):format(teil, nummer)

    return ('%s_M_%s'):format(prefix, suffix), ('%s_F_%s'):format(prefix, suffix)
end

--- Teilname im Aufdruck je Zone.
local TEILE = {
    kopf = 'Head', brust = 'Chest', bauch = 'Stom', ruecken = 'Back',
    armLinks = 'LeftArm', armRechts = 'RightArm',
    beinLinks = 'LeftLeg', beinRechts = 'RightLeg',
}

--- Kurzschreibweise fuer einen Katalogeintrag.
---@param id string
---@param label string
---@param zone string Schluessel aus Appearance.TattooZones
---@param sammlung string Schluessel aus Appearance.TattooCollections
---@param prefix string DLC-Praefix
---@param nummer number laufende Nummer im Paket
---@param race string|nil nur fuer diese Klasse kaufbar
local function tat(id, label, zone, sammlung, prefix, nummer, race)
    local male, female = namen(prefix, TEILE[zone], nummer)

    return {
        id = id, label = label, zone = zone,
        collection = Appearance.TattooCollections[sammlung],
        male = male, female = female,
        race = race,
    }
end

-- Katalog --------------------------------------------------------------------------
--- Was das Studio fuehrt. Die Bezeichnungen sind fuer diesen Server gewaehlt,
--- die Motive dahinter sind die des jeweiligen DLC-Pakets.
Appearance.Tattoos = {
    -- Kopf und Hals
    tat('kopf_ranken',   'Ranken am Hals',      'kopf', 'strand',   'MP_Bea', 0),
    tat('kopf_kreuz',    'Kreuz hinterm Ohr',   'kopf', 'business', 'MP_Buis', 0),
    tat('kopf_traene',   'Träne',               'kopf', 'hipster',  'MP_Hip', 0),
    tat('kopf_dornen',   'Dornenband',          'kopf', 'luxus',    'MP_LUXE', 0),

    -- Brust
    tat('brust_fluegel', 'Flügel über der Brust', 'brust', 'strand',  'MP_Bea', 0),
    tat('brust_schaedel','Schädel',               'brust', 'business','MP_Buis', 0),
    tat('brust_anker',   'Anker',                 'brust', 'hipster', 'MP_Hip', 0),
    tat('brust_wolf',    'Wolfskopf',             'brust', 'luxus',   'MP_LUXE', 0),
    tat('brust_uhr',     'Zerbrochene Uhr',       'brust', 'vinewood','MP_Vin', 0),

    -- Bauch
    tat('bauch_schrift', 'Schriftzug',          'bauch', 'strand',   'MP_Bea', 0),
    tat('bauch_schlange','Schlange',            'bauch', 'business', 'MP_Buis', 0),
    tat('bauch_rosen',   'Rosen',               'bauch', 'luxus2',   'MP_LUXE2', 0),

    -- Ruecken
    tat('ruecken_adler', 'Adler',               'ruecken', 'strand',   'MP_Bea', 0),
    tat('ruecken_engel', 'Gefallener Engel',    'ruecken', 'business', 'MP_Buis', 0),
    tat('ruecken_drache','Drache',              'ruecken', 'hipster',  'MP_Hip', 0),
    tat('ruecken_baum',  'Lebensbaum',          'ruecken', 'luxus',    'MP_LUXE', 0),
    tat('ruecken_stern', 'Sternbild',           'ruecken', 'vinewood', 'MP_Vin', 0),

    -- Arme
    tat('arml_sleeve',   'Halbes Sleeve links', 'armLinks', 'strand',   'MP_Bea', 0),
    tat('arml_runen',    'Runenreihe links',    'armLinks', 'hipster',  'MP_Hip', 0),
    tat('arml_kette',    'Kette links',         'armLinks', 'luxus',    'MP_LUXE', 0),
    tat('armr_sleeve',   'Halbes Sleeve rechts','armRechts','strand',   'MP_Bea', 0),
    tat('armr_runen',    'Runenreihe rechts',   'armRechts','hipster',  'MP_Hip', 0),
    tat('armr_kette',    'Kette rechts',        'armRechts','luxus',    'MP_LUXE', 0),

    -- Beine
    tat('beinl_dolch',   'Dolch links',         'beinLinks', 'business', 'MP_Buis', 0),
    tat('beinl_muster',  'Muster links',        'beinLinks', 'luxus2',   'MP_LUXE2', 0),
    tat('beinr_dolch',   'Dolch rechts',        'beinRechts','business', 'MP_Buis', 0),
    tat('beinr_muster',  'Muster rechts',       'beinRechts','luxus2',   'MP_LUXE2', 0),
}

-- Klassenmale ------------------------------------------------------------------------
--- Nur wer erweckt ist, bekommt sein Mal - und nur das der eigenen Klasse.
--- Kostet mehr, ist aber das einzige sichtbare Zeichen der Zugehoerigkeit,
--- das man nicht ausziehen kann.
local MALE = {
    { race = 'vampir',    label = 'Mal des Blutes',    prefix = 'MP_Bea',   sammlung = 'strand' },
    { race = 'werwolf',   label = 'Mal der Wut',       prefix = 'MP_Buis',  sammlung = 'business' },
    { race = 'daemon',    label = 'Mal der Hölle',     prefix = 'MP_Hip',   sammlung = 'hipster' },
    { race = 'fee',       label = 'Mal des Staubs',    prefix = 'MP_LUXE',  sammlung = 'luxus' },
    { race = 'magier',    label = 'Mal des Mana',      prefix = 'MP_LUXE2', sammlung = 'luxus2' },
    { race = 'hexer',     label = 'Mal des Zirkels',   prefix = 'MP_Vin',   sammlung = 'vinewood' },
    { race = 'nekromant', label = 'Mal der Toten',     prefix = 'MP_Bea',   sammlung = 'strand' },
    { race = 'jaeger',    label = 'Mal der Jagd',      prefix = 'MP_Buis',  sammlung = 'business' },
}

for index, entry in ipairs(MALE) do
    Appearance.Tattoos[#Appearance.Tattoos + 1] = tat(
        ('mal_%s'):format(entry.race), entry.label, 'brust',
        entry.sammlung, entry.prefix, index, entry.race)
end

-- Zugriff ---------------------------------------------------------------------------------

--- Motiv nach Id.
function Appearance.GetTattoo(id)
    for _, entry in ipairs(Appearance.Tattoos) do
        if entry.id == id then return entry end
    end

    return nil
end

--- Zone nach Schluessel.
function Appearance.GetTattooZone(key)
    for _, zone in ipairs(Appearance.TattooZones) do
        if zone.key == key then return zone end
    end

    return nil
end

--- Alle Motive einer Zone.
function Appearance.TattoosInZone(key)
    local list = {}

    for _, entry in ipairs(Appearance.Tattoos) do
        if entry.zone == key then list[#list + 1] = entry end
    end

    return list
end

--- Was ein Motiv kostet. Klassenmale kosten den Aufschlag.
---@param id string
---@return number
function Appearance.TattooPrice(id)
    local entry = Appearance.GetTattoo(id)
    if not entry then return 0 end

    local zone = Appearance.GetTattooZone(entry.zone)
    local preise = AppearanceConfig.Prices.tattoo or {}
    local preis = preise[zone and zone.tier or 'klein'] or 0

    if entry.race then
        preis = math.floor(preis * (AppearanceConfig.Prices.tattooMal or 1))
    end

    return preis
end

--- Der Aufdruck fuer ein Geschlecht.
---@param gender string 'm' oder 'w'
function Appearance.TattooOverlay(entry, gender)
    if type(entry) ~= 'table' then return nil end

    return gender == 'w' and entry.female or entry.male
end

--- Wirft alles aus einer Liste, was es nicht gibt oder doppelt vorkommt.
---@param list table
---@return table
function Appearance.SanitizeTattoos(list)
    if type(list) ~= 'table' then return {} end

    local gesehen, clean = {}, {}

    for _, id in ipairs(list) do
        if type(id) == 'string' and not gesehen[id] and Appearance.GetTattoo(id) then
            gesehen[id] = true
            clean[#clean + 1] = id
        end
    end

    return clean
end

--- Traegt der Charakter dieses Motiv schon?
function Appearance.HasTattoo(list, id)
    for _, entry in ipairs(type(list) == 'table' and list or {}) do
        if entry == id then return true end
    end

    return false
end
