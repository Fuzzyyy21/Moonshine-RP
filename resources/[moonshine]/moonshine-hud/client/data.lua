--- Sammelt zusammen, was die Anzeige braucht.
---
--- Jede fremde Resource wird ueber `pcall` gefragt. Laeuft eine davon nicht,
--- fehlt genau ihr Wert und sonst nichts - die Anzeige darf nicht davon
--- abhaengen, dass der ganze Server geladen ist.

local MS = exports['moonshine-core']:GetCoreObject()

--- Was moonshine-world zuletzt angekuendigt hat. Ereignisgesteuert statt
--- abgefragt: die Welt schickt beides von selbst, wenn es sich aendert.
Hud.Mond = nil
Hud.Ereignis = nil
Hud.Nacht = false

RegisterNetEvent('world:client:time', function(payload)
    if type(payload) ~= 'table' then return end

    Hud.Nacht = payload.night == true
    if payload.phase then Hud.Mond = payload.phase end
end)

RegisterNetEvent('world:client:phase', function(phase)
    if type(phase) == 'table' then Hud.Mond = phase end
end)

RegisterNetEvent('world:client:event', function(payload)
    if type(payload) ~= 'table' or payload.active ~= true then
        Hud.Ereignis = nil
        return
    end

    Hud.Ereignis = { label = payload.label, icon = payload.icon }
end)

--- Fragt einen Export ab, ohne dass ein Fehler den Tick reisst.
local function frag(resource, methode, ...)
    local ergebnis = nil
    local ok = pcall(function(...)
        ergebnis = exports[resource][methode](exports[resource], ...)
    end, ...)

    if not ok then return nil end
    return ergebnis
end

-- Zustand ---------------------------------------------------------------------

--- Leben in Prozent. GTA zaehlt von 100 bis 200.
local function lebenProzent(ped)
    local leben = GetEntityHealth(ped) - 100
    local max = math.max(1, GetEntityMaxHealth(ped) - 100)

    return math.max(0, math.min(100, math.floor(leben / max * 100)))
end

--- Sauerstoff nur unter Wasser, sonst voll.
local function sauerstoffProzent(ped)
    if not IsPedSwimmingUnderWater(ped) then return 100 end

    local rest = GetPlayerUnderwaterTimeRemaining(PlayerId())
    return math.max(0, math.min(100, math.floor((rest or 10) * 10)))
end

--- Ausdauer: GTA fuehrt sie umgekehrt als "verbraucht".
local function ausdauerProzent()
    local verbraucht = GetPlayerSprintStaminaRemaining(PlayerId())
    return math.max(0, math.min(100, math.floor(100 - (verbraucht or 0))))
end

-- Klasse und Beduerfnis ----------------------------------------------------------

--- Essenz der mystischen Klasse, mit Namen, Zahlen und Farbe.
---
--- Das ist der Wert, um den sich auf diesem Server alles dreht - Blut beim
--- Vampir, Mana beim Magier, Hoellenfeuer beim Daemon. Er bekommt deshalb
--- Zahlen und einen Namen mit, nicht nur einen Prozentwert.
local function essenz()
    local profil = frag('moonshine-mystic', 'GetProfileData')
    if type(profil) ~= 'table' or not profil.race then return nil end

    local max = math.max(1, math.floor(tonumber(profil.maxEssence) or 1))
    local jetzt = math.max(0, math.floor(tonumber(profil.essence) or 0))

    return {
        wert   = math.max(0, math.min(100, math.floor(jetzt / max * 100))),
        jetzt  = math.min(jetzt, max),
        max    = max,
        label  = profil.essenceLabel or 'Essenz',
        farbe  = profil.raceColor,
        icon   = profil.raceIcon,
        klasse = profil.raceLabel or profil.race,
        stufe  = tonumber(profil.level),
    }
end

--- Klassenbeduerfnis aus moonshine-needs.
local function beduerfnis()
    local daten = frag('moonshine-needs', 'GetNeedData')
    if type(daten) ~= 'table' then return nil end

    return {
        wert  = math.max(0, math.min(100, math.floor(tonumber(daten.value) or 100))),
        label = daten.label or 'Bedürfnis',
        icon  = daten.icon,
        farbe = daten.colour,
    }
end

-- Welt -----------------------------------------------------------------------------

--- Uhrzeit, Mondphase und laufendes Ereignis.
---
--- Die Uhr kommt aus der Spielzeit selbst: moonshine-world setzt sie ohnehin
--- ueber NetworkOverrideClockTime. So laeuft sie fluessig weiter, auch
--- zwischen zwei Serversynchronisationen.
local function welt()
    local stunde, minute = GetClockHours(), GetClockMinutes()

    return {
        zeit     = ('%02d:%02d'):format(stunde, minute),
        nacht    = Hud.Nacht,
        mond     = Hud.Mond and { label = Hud.Mond.label, icon = Hud.Mond.icon } or nil,
        ereignis = Hud.Ereignis,
    }
end

--- Fraktion des Spielers.
local function fraktion()
    local daten = frag('moonshine-factions', 'GetFactionData')
    if type(daten) ~= 'table' then return nil end

    return { name = daten.name, tag = daten.tag,
             farbe = daten.emblem and daten.emblem.primary or nil }
end

-- Ort und Richtung -----------------------------------------------------------------

--- Strasse und Bezirk an einer Position.
local function ort(coords)
    local strasse, kreuzung = GetStreetNameAtCoord(coords.x, coords.y, coords.z)

    local name = GetStreetNameFromHashKey(strasse)
    if kreuzung and kreuzung ~= 0 then
        local zweite = GetStreetNameFromHashKey(kreuzung)
        if zweite and zweite ~= '' then name = ('%s / %s'):format(name, zweite) end
    end

    return {
        strasse = name,
        bezirk  = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)),
    }
end

-- Alles zusammen ---------------------------------------------------------------------

--- Baut die Nutzdaten fuer die Anzeige.
function Hud.Collect()
    local ped = PlayerPedId()
    local daten = MS.PlayerData or {}
    local coords = GetEntityCoords(ped)

    local nutz = {
        name = daten.fullname or '',
        id   = GetPlayerServerId(PlayerId()),
        job  = daten.job and ('%s · %s'):format(daten.job.label, daten.job.gradeLabel) or '',

        geld = {
            bargeld = daten.accounts and daten.accounts.cash or 0,
            bank    = daten.accounts and daten.accounts.bank or 0,
            schwarz = daten.accounts and daten.accounts.black or 0,
        },

        leben      = lebenProzent(ped),
        weste      = math.max(0, math.min(100, GetPedArmour(ped))),
        hunger     = math.floor(daten.metadata and daten.metadata.hunger or 100),
        durst      = math.floor(daten.metadata and daten.metadata.thirst or 100),
        ausdauer   = ausdauerProzent(),
        sauerstoff = sauerstoffProzent(ped),

        tot        = IsEntityDead(ped),
        mikrofon   = NetworkIsPlayerTalking(PlayerId()),

        richtung   = Hud.Direction(GetEntityHeading(ped)),
    }

    nutz.essenz = essenz()
    nutz.beduerfnis = beduerfnis()
    nutz.welt = welt()
    nutz.fraktion = fraktion()

    if Hud.Shows('ort') then nutz.ort = ort(coords) end

    return nutz
end
