--- Klassenbeduerfnisse: Verfall, Wirkung, Synchronisation.
---
--- Der Wert liegt als Metadatum am Charakter und wird damit vom Core
--- mitgespeichert.

MS = MS or exports['moonshine-core']:GetCoreObject()

local KEY = 'classNeed'

--- Wann jemand zuletzt aus einer Quellart geschoepft hat: [source][kind]
Needs.Cooldowns = {}

--- Klasse eines Spielers.
function Needs.RaceOf(source)
    local race = nil
    pcall(function() race = exports['moonshine-mystic']:GetRace(source) end)

    return race
end

--- Aktueller Wert. Ohne Klasse gibt es kein Beduerfnis.
---@return number|nil
function Needs.Get(source)
    local player = MS.GetPlayer(source)
    if not player then return nil end

    local race = Needs.RaceOf(source)
    if not race or not Needs.Definitions[race] then return nil end

    local stored = player:GetMetadata(KEY)
    if type(stored) ~= 'table' or stored.race ~= race then
        -- Klasse gewechselt oder noch nie gesetzt: voll starten.
        return 100.0
    end

    return tonumber(stored.value) or 100.0
end

--- Setzt den Wert.
function Needs.Set(source, value)
    local player = MS.GetPlayer(source)
    if not player then return false end

    local race = Needs.RaceOf(source)
    if not race then return false end

    value = MS.Utils.Clamp(MS.Utils.Round(tonumber(value) or 0, 1), 0.0, 100.0)

    player:SetMetadata(KEY, { race = race, value = value })
    Needs.Sync(source, value, race)

    return true
end

--- Veraendert den Wert relativ.
---@return number|nil neuer Wert
function Needs.Add(source, delta)
    local current = Needs.Get(source)
    if current == nil then return nil end

    local next_ = MS.Utils.Clamp(current + (tonumber(delta) or 0), 0.0, 100.0)
    Needs.Set(source, next_)

    return next_
end

--- Schickt den Zustand an den Client.
function Needs.Sync(source, value, race)
    race = race or Needs.RaceOf(source)
    value = value or Needs.Get(source)

    if not race or value == nil then
        TriggerClientEvent('needs:client:sync', source, false)
        return
    end

    local definition = Needs.Definitions[race]
    if not definition then
        TriggerClientEvent('needs:client:sync', source, false)
        return
    end

    TriggerClientEvent('needs:client:sync', source, {
        race        = race,
        id          = definition.id,
        label       = definition.label,
        icon        = definition.icon,
        colour      = definition.colour,
        description = definition.description,
        value       = value,
        band        = Needs.GetBand(value),
        sources     = definition.sources,
    })
end

--- Darf dieser Spieler gerade aus dieser Quellart schoepfen?
function Needs.CheckCooldown(source, kind)
    local entries = Needs.Cooldowns[source]
    if not entries then return true end

    local until_ = entries[kind]
    return not until_ or until_ <= os.time()
end

function Needs.SetCooldown(source, kind, seconds)
    Needs.Cooldowns[source] = Needs.Cooldowns[source] or {}
    Needs.Cooldowns[source][kind] = os.time() + (seconds or NeedsConfig.Cooldown)
end

--- Die Werte, die das Beduerfnis gerade mitbringt. Fuer moonshine-mystic.
function Needs.Modifiers(source)
    local value = Needs.Get(source)
    if value == nil then return {} end

    return Needs.GetEffects(value)
end

-- Verfall ----------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(NeedsConfig.TickInterval * 1000)

        for _, player in pairs(MS.GetPlayers()) do
            local source = player.source
            local race = Needs.RaceOf(source)
            local definition = race and Needs.Definitions[race]

            if definition then
                local vorher = Needs.Get(source) or 100.0
                local vorherBand = Needs.GetBand(vorher)

                -- Zonen fuellen auf, statt zu verbrauchen.
                local gefuellt = 0
                local ped = GetPlayerPed(source)

                if ped and ped ~= 0 then
                    local art = Needs.ZoneAt(GetEntityCoords(ped))
                    if art then gefuellt = Needs.ZoneAmount(race, art) end
                end

                local nachher = MS.Utils.Clamp(
                    vorher - definition.decayPerTick + gefuellt, 0.0, 100.0)

                Needs.Set(source, nachher)

                local band = Needs.GetBand(nachher)

                -- Nur beim Wechsel in einen schlechteren Bereich melden.
                if band ~= vorherBand then
                    if band == 'warnung' then
                        player:Notify(('%s %s laesst nach.'):format(
                            definition.icon, definition.label), 'warning', 8000)
                    elseif band == 'schwach' then
                        player:Notify(('%s Du wirst schwach. %s'):format(
                            definition.icon, definition.description), 'error', 10000)
                    elseif band == 'leer' then
                        player:Notify(('%s Es zehrt an dir.'):format(definition.icon),
                            'error', 12000)
                    elseif band == 'satt' then
                        player:Notify(('%s Du bist gesaettigt.'):format(definition.icon),
                            'success', 6000)
                    end

                    -- Die Werte haben sich geaendert, das Profil neu rechnen.
                    pcall(function()
                        exports['moonshine-mystic']:RefreshModifiers(source)
                    end)
                end

                -- Bei null zieht es Leben.
                if nachher <= 0 then
                    TriggerClientEvent('needs:client:drain', source,
                        NeedsConfig.DamagePerTick)
                end
            end
        end
    end
end)

-- Lebenszyklus -------------------------------------------------------------------

AddEventHandler('moonshine:server:playerLoaded', function(source)
    CreateThread(function()
        Wait(3000)
        Needs.Sync(source)
    end)
end)

--- Wer sich erweckt oder die Klasse wechselt, faengt satt an.
AddEventHandler('mystic:server:playerAwakened', function(source)
    CreateThread(function()
        Wait(500)
        Needs.Set(source, 100.0)
    end)
end)

AddEventHandler('playerDropped', function()
    Needs.Cooldowns[source] = nil
end)

RegisterNetEvent('needs:server:request', function()
    Needs.Sync(source)
end)

-- API ---------------------------------------------------------------------------

exports('GetNeedsObject', function()
    return Needs
end)

exports('GetNeed', function(source)
    return Needs.Get(source)
end)

exports('SetNeed', function(source, value)
    return Needs.Set(source, value)
end)

exports('AddNeed', function(source, delta)
    return Needs.Add(source, delta)
end)

--- Die Werte, die das Beduerfnis mitbringt. Holt sich moonshine-mystic.
exports('GetModifiers', function(source)
    return Needs.Modifiers(source)
end)

-- Commands ------------------------------------------------------------------------

RegisterCommand('beduerfnisinfo', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local race = Needs.RaceOf(source)
    local definition = race and Needs.Definitions[race]

    if not definition then
        player:Notify('Du hast kein Klassenbeduerfnis.', 'info')
        return
    end

    local value = Needs.Get(source) or 0

    player:Notify(('%s %s: %d %% (%s)'):format(
        definition.icon, definition.label, math.floor(value),
        Needs.GetBand(value)), 'info', 9000)
end, false)

RegisterCommand('setbeduerfnis', function(source, args)
    local player = MS.GetPlayer(source)
    if source > 0 and (not player or (player.adminLevel or 0) < 3) then return end

    local target = tonumber(args[1])
    local value = tonumber(args[2])
    if not target or not value then return end

    Needs.Set(target, value)
end, false)

print('^2[Beduerfnisse]^7 Klassenbeduerfnisse geladen.')
