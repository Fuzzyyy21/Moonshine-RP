--- Zufluchtsorte: kaufen, aufgeben, ausbauen, oeffnen.

MS = MS or exports['moonshine-core']:GetCoreObject()

--- [placeId] = { characterId, name, stufe, stash, lastRest, lastRefuge }
Refuge.Owned = {}

--- Klasse eines Spielers, falls moonshine-mystic laeuft.
function Refuge.RaceOf(source)
    local race = nil
    pcall(function() race = exports['moonshine-mystic']:GetRace(source) end)

    return race
end

--- Steht der Spieler an diesem Platz?
function Refuge.AtPlace(source, placeId)
    local place = Refuge.GetPlace(placeId)
    if not place then return false end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end

    return #(GetEntityCoords(ped) - place.zutritt) <= RefugeConfig.Range + 3.0
end

--- Der Zufluchtsort eines Charakters, falls er einen hat.
---@return string|nil placeId, table|nil eintrag
function Refuge.Of(characterId)
    for placeId, entry in pairs(Refuge.Owned) do
        if entry.characterId == characterId then return placeId, entry end
    end

    return nil, nil
end

--- Dasselbe fuer einen Spieler am Server.
function Refuge.OfPlayer(source)
    local player = MS.GetPlayer(source)
    if not player then return nil, nil end

    return Refuge.Of(player.charId)
end

-- Laden -------------------------------------------------------------------------

CreateThread(function()
    while not Refuge.DB.Ready do Wait(500) end

    for _, row in ipairs(Refuge.DB.LoadAll()) do
        -- Ein Platz, den es in der Config nicht mehr gibt, wird uebersprungen
        -- statt zu stoeren. Die Zeile bleibt in der Datenbank stehen.
        if Refuge.GetPlace(row.place_id) then
            local stash = {}

            if row.stash and row.stash ~= '' then
                local ok, gelesen = pcall(json.decode, row.stash)
                if ok and type(gelesen) == 'table' then stash = gelesen end
            end

            Refuge.Owned[row.place_id] = {
                characterId = row.character_id,
                name        = row.name,
                stufe       = tonumber(row.stufe) or 0,
                stash       = stash,
                lastRest    = tonumber(row.last_rest) or 0,
                lastRefuge  = tonumber(row.last_refuge) or 0,
            }
        end
    end

    local belegt = 0
    for _ in pairs(Refuge.Owned) do belegt = belegt + 1 end

    print(('^5[Zuflucht]^7 %d von %d Plaetzen sind vergeben.'):format(
        belegt, #Refuge.Places))
end)

-- Anzeige -------------------------------------------------------------------------

--- Was der Client ueber einen Platz wissen darf.
local function placePayload(source, place, player)
    local entry = Refuge.Owned[place.id]
    local eigen = entry ~= nil and player ~= nil and entry.characterId == player.charId
    local race = Refuge.RaceOf(source)
    local kind = Refuge.GetKind(race)

    return {
        id           = place.id,
        label        = place.label,
        art          = place.art,
        beschreibung = place.beschreibung,
        preis        = place.preis,

        frei     = entry == nil,
        eigen    = eigen,
        passt    = Refuge.Fits(race, place.art),

        artLabel = kind.label,
        artIcon  = kind.icon,

        name  = eigen and entry.name or nil,
        stufe = eigen and entry.stufe or nil,
        slots = eigen and Refuge.GetSlots(entry.stufe) or nil,
        ausbauPreis = eigen and Refuge.GetUpgradePrice(entry.stufe) or nil,

        rastFrei = eigen and Refuge.RestReady(entry) or nil,
        balance  = player and player:GetMoney(RefugeConfig.Account) or 0,
    }
end

--- Ist die Rast wieder frei?
function Refuge.RestReady(entry)
    return (os.time() - (entry.lastRest or 0)) >= RefugeConfig.Rest.cooldown * 60
end

--- Schickt den Zustand eines Platzes an den Client.
function Refuge.Open(source, placeId)
    local place = Refuge.GetPlace(placeId)
    local player = MS.GetPlayer(source)
    if not place or not player then return end

    if not Refuge.AtPlace(source, placeId) then return end

    TriggerClientEvent('refuge:client:open', source,
        placePayload(source, place, player))
end

RegisterNetEvent('refuge:server:open', function(placeId)
    local source = source
    if not MS.RateLimit(source, 'refuge:open', 10, 10) then return end

    Refuge.Open(source, placeId)
end)

--- Beim Laden: welche Plaetze belegt sind, damit die Blips stimmen.
local function overview()
    local list = {}

    for _, place in ipairs(Refuge.Places) do
        list[#list + 1] = {
            id = place.id, frei = Refuge.Owned[place.id] == nil,
        }
    end

    return list
end

RegisterNetEvent('refuge:server:request', function()
    local source = source
    local eigener = Refuge.OfPlayer(source)

    TriggerClientEvent('refuge:client:overview', source, overview(), eigener)
end)

--- Alle Clients auf denselben Stand bringen.
function Refuge.Broadcast()
    for _, player in pairs(MS.GetPlayers()) do
        local eigener = Refuge.Of(player.charId)
        TriggerClientEvent('refuge:client:overview', player.source, overview(), eigener)
    end
end

-- Kaufen ---------------------------------------------------------------------------

RegisterNetEvent('refuge:server:claim', function(placeId)
    local source = source
    if not MS.RateLimit(source, 'refuge:claim', 5, 30) then return end

    local player = MS.GetPlayer(source)
    local place = Refuge.GetPlace(placeId)
    if not player or not place then return end

    if not Refuge.AtPlace(source, placeId) then
        player:Notify('Du stehst nicht an diesem Ort.', 'error')
        return
    end

    if Refuge.Owned[placeId] then
        player:Notify('Hier wohnt schon jemand.', 'error')
        return
    end

    local vorhanden = Refuge.Of(player.charId)
    if vorhanden then
        local anderer = Refuge.GetPlace(vorhanden)
        player:Notify(('Du hast bereits einen Ort: %s. Gib ihn erst auf.'):format(
            anderer and anderer.label or vorhanden), 'error', 9000)
        return
    end

    if not player:RemoveMoney(place.preis, RefugeConfig.Account, 'zuflucht') then
        player:Notify(('Das kostet %s.'):format(
            MS.Utils.FormatMoney(place.preis)), 'error')
        return
    end

    local kind = Refuge.GetKind(Refuge.RaceOf(source))
    local name = kind.label

    Refuge.Owned[placeId] = {
        characterId = player.charId, name = name, stufe = 0,
        stash = {}, lastRest = 0, lastRefuge = 0,
    }

    Refuge.DB.Claim(placeId, player.charId, name)

    player:Notify(('%s gehoert jetzt dir.'):format(place.label), 'success', 9000)
    MS.Logger.Log('zuflucht', ('%s hat %s fuer %s gekauft.'):format(
        player.fullname, place.label, MS.Utils.FormatMoney(place.preis)), player.license)

    Refuge.Broadcast()
    Refuge.Open(source, placeId)

    TriggerEvent('refuge:server:claimed', source, placeId)
end)

-- Aufgeben ---------------------------------------------------------------------------

RegisterNetEvent('refuge:server:release', function()
    local source = source
    if not MS.RateLimit(source, 'refuge:release', 5, 30) then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    local placeId, entry = Refuge.Of(player.charId)
    if not placeId then return end

    if not Refuge.AtPlace(source, placeId) then
        player:Notify('Dafuer musst du dort sein.', 'error')
        return
    end

    -- Was im Lager liegt, wuerde sonst verschwinden.
    if #entry.stash > 0 then
        player:Notify('Raeum erst dein Lager leer.', 'error', 8000)
        return
    end

    local place = Refuge.GetPlace(placeId)

    Refuge.Owned[placeId] = nil
    Refuge.DB.Release(placeId)

    player:Notify(('%s ist wieder frei.'):format(
        place and place.label or placeId), 'info', 8000)

    TriggerClientEvent('refuge:client:close', source)
    Refuge.Broadcast()

    TriggerEvent('refuge:server:released', source, placeId)
end)

-- Ausbauen ------------------------------------------------------------------------------

RegisterNetEvent('refuge:server:upgrade', function()
    local source = source
    if not MS.RateLimit(source, 'refuge:upgrade', 5, 30) then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    local placeId, entry = Refuge.Of(player.charId)
    if not placeId or not Refuge.AtPlace(source, placeId) then return end

    local preis = Refuge.GetUpgradePrice(entry.stufe)
    if not preis then
        player:Notify('Weiter geht es nicht.', 'info')
        return
    end

    if not player:RemoveMoney(preis, RefugeConfig.Account, 'zuflucht-ausbau') then
        player:Notify(('Der Ausbau kostet %s.'):format(
            MS.Utils.FormatMoney(preis)), 'error')
        return
    end

    entry.stufe = entry.stufe + 1
    Refuge.DB.SetStufe(placeId, entry.stufe)

    player:Notify(('Ausgebaut: %d Plaetze.'):format(Refuge.GetSlots(entry.stufe)),
        'success', 8000)

    Refuge.Open(source, placeId)
end)

-- Umbenennen ------------------------------------------------------------------------------

RegisterNetEvent('refuge:server:rename', function(name)
    local source = source
    if not MS.RateLimit(source, 'refuge:rename', 5, 30) then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    local placeId, entry = Refuge.Of(player.charId)
    if not placeId or not Refuge.AtPlace(source, placeId) then return end

    name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 48)
    if name == '' then name = Refuge.GetKind(Refuge.RaceOf(source)).label end

    entry.name = name
    Refuge.DB.SetName(placeId, name)

    Refuge.Open(source, placeId)
end)

-- Schnittstelle ------------------------------------------------------------------------------

--- Wo dieser Spieler aufwachen wuerde. nil = hat keinen Ort oder er ist
--- noch erschoepft.
exports('GetRespawnPoint', function(source)
    if not RefugeConfig.Respawn.enabled then return nil end

    local placeId, entry = Refuge.OfPlayer(source)
    if not placeId then return nil end

    if (os.time() - (entry.lastRefuge or 0)) < RefugeConfig.Respawn.cooldown * 60 then
        return nil
    end

    local place = Refuge.GetPlace(placeId)
    if not place then return nil end

    return {
        placeId  = placeId,
        label    = entry.name or place.label,
        ort      = place.label,
        coords   = { x = place.aufwachen.x, y = place.aufwachen.y,
                     z = place.aufwachen.z, w = place.aufwachen.w },
        kostenlos = RefugeConfig.Respawn.kostenlos == true,
    }
end)

--- Der Ort ist benutzt worden - Abklingzeit setzen.
exports('MarkRefugeUsed', function(source)
    local placeId, entry = Refuge.OfPlayer(source)
    if not placeId then return false end

    entry.lastRefuge = os.time()
    Refuge.DB.Touch(placeId, 'last_refuge', entry.lastRefuge)

    return true
end)

exports('GetRefuge', function(source)
    local placeId, entry = Refuge.OfPlayer(source)
    if not placeId then return nil end

    return { placeId = placeId, name = entry.name, stufe = entry.stufe }
end)

-- Commands ------------------------------------------------------------------------------------

RegisterCommand('zuflucht', function(source)
    if source == 0 then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    local placeId, entry = Refuge.Of(player.charId)

    if not placeId then
        player:Notify('Du hast keinen Zufluchtsort.', 'info')
        return
    end

    local place = Refuge.GetPlace(placeId)
    player:Notify(('%s - %s, %d Plaetze im Lager.'):format(
        entry.name or 'Zuflucht', place and place.label or placeId,
        Refuge.GetSlots(entry.stufe)), 'info', 9000)
end, false)

RegisterCommand('zuflucht_freigeben', function(source, args)
    local player = source > 0 and MS.GetPlayer(source) or nil
    if source > 0 and (not player or (player.adminLevel or 0) < 3) then return end

    local placeId = args[1]
    if not placeId or not Refuge.Owned[placeId] then
        print('Verwendung: /zuflucht_freigeben [platzId]')
        return
    end

    Refuge.Owned[placeId] = nil
    Refuge.DB.Release(placeId)
    Refuge.Broadcast()

    print(('[Zuflucht] %s ist wieder frei.'):format(placeId))
end, false)
