--- Fahrzeugbesitz: Kauf, Verkauf, Zustand.

MS = MS or exports['moonshine-core']:GetCoreObject()

--- Fahrzeuge, die gerade in der Welt stehen: [plate] = { id, owner, source }
Vehicles.Spawned = {}

local function decode(raw, fallback)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return fallback end

    local ok, value = pcall(json.decode, raw)
    if not ok or type(value) ~= 'table' then return fallback end

    return value
end

--- Erzeugt ein freies Kennzeichen.
function Vehicles.MakePlate()
    local prefix = VehicleConfig.Ownership.platePrefix
    local digits = VehicleConfig.Ownership.plateDigits
    local max = 10 ^ digits - 1

    for _ = 1, 60 do
        local plate = ('%s %0' .. digits .. 'd'):format(prefix, math.random(0, max))

        if not Vehicles.DB.PlateExists(plate) then return plate end
    end

    -- Notnagel: Zeitstempel
    return ('%s %d'):format(prefix, os.time() % (10 ^ digits))
end

--- Wandelt eine Datenbankzeile in die Form fuer die Oberflaeche.
function Vehicles.Describe(row, characterId)
    local garage = row.garage and Vehicles.GetGarage(row.garage)
    local keys = decode(row.keys, {})

    return {
        id       = row.id,
        plate    = row.plate,
        model    = row.model,
        label    = row.label,
        category = row.category,
        categoryLabel = Vehicles.GetCategoryLabel(row.category),
        price    = tonumber(row.price) or 0,
        state    = row.state,
        garage   = row.garage,
        garageLabel = garage and garage.label or nil,
        fuel     = math.floor(tonumber(row.fuel) or 0),
        engine   = math.floor((tonumber(row.engine) or 1000) / 10),
        body     = math.floor((tonumber(row.body) or 1000) / 10),
        isOwner  = row.owner_id == characterId,
        keyCount = #keys,
        resale   = math.floor((tonumber(row.price) or 0) * VehicleConfig.Ownership.resale),
    }
end

-- Kaufen --------------------------------------------------------------------------

--- Kauft ein Fahrzeug.
---@return boolean ok, string message, table|nil vehicle
function Vehicles.Buy(source, model, dealerId)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    local entry = Vehicles.GetModel(model)
    if not entry then return false, 'Dieses Fahrzeug gibt es hier nicht.' end

    local dealer = Vehicles.GetDealer(dealerId)
    if not dealer then return false, 'Unbekanntes Autohaus.' end

    -- Fuehrt dieses Autohaus das Modell ueberhaupt?
    local allowed = false
    for _, category in ipairs(dealer.categories or {}) do
        if category == entry.category then allowed = true break end
    end
    if not allowed then return false, 'Dieses Fahrzeug gibt es hier nicht.' end

    local owned = Vehicles.DB.CountOwned(player.charId)
    if owned >= VehicleConfig.Ownership.maxVehicles then
        return false, ('Du besitzt bereits %d Fahrzeuge.')
            :format(VehicleConfig.Ownership.maxVehicles)
    end

    local account = VehicleConfig.Ownership.account

    if not player:RemoveMoney(entry.price, account, 'fahrzeugkauf') then
        return false, ('Dir fehlen %s.'):format(MS.Utils.FormatMoney(
            entry.price - player:GetMoney(account)))
    end

    local plate = Vehicles.MakePlate()

    local id = Vehicles.DB.Insert({
        ownerId = player.charId, plate = plate, model = entry.model,
        label = entry.label, category = entry.category, price = entry.price,
        garage = VehicleConfig.Garages[1] and VehicleConfig.Garages[1].id or nil,
    })

    if not id then
        player:AddMoney(entry.price, account, 'fahrzeugkauf-rueckerstattung')
        return false, 'Der Kauf ist fehlgeschlagen.'
    end

    MS.Logger.Log('character', ('%s %s kauft %s (%s) fuer %s.'):format(
        player.firstname, player.lastname, entry.label, plate,
        MS.Utils.FormatMoney(entry.price)), player.license)

    TriggerEvent('vehicles:server:bought', source, id, entry.model, entry.price)

    return true, ('%s gekauft. Kennzeichen %s.'):format(entry.label, plate), {
        id = id, plate = plate, model = entry.model, spawn = dealer.spawn,
    }
end

-- Verkaufen ------------------------------------------------------------------------

--- Verkauft ein Fahrzeug ans Autohaus.
function Vehicles.Sell(source, vehicleId)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    local row = Vehicles.DB.GetById(tonumber(vehicleId) or -1)
    if not row or row.owner_id ~= player.charId then
        return false, 'Das ist nicht dein Fahrzeug.'
    end

    if row.state ~= 'garage' then
        return false, 'Das Fahrzeug muss eingeparkt sein.'
    end

    local refund = math.floor((tonumber(row.price) or 0) * VehicleConfig.Ownership.resale)

    Vehicles.DB.Delete(row.id)
    player:AddMoney(refund, VehicleConfig.Ownership.account, 'fahrzeugverkauf')

    MS.Logger.Log('character', ('%s %s verkauft %s (%s) fuer %s.'):format(
        player.firstname, player.lastname, row.label, row.plate,
        MS.Utils.FormatMoney(refund)), player.license)

    TriggerEvent('vehicles:server:sold', source, row.id, refund)

    return true, ('%s verkauft. Du bekommst %s.'):format(
        row.label, MS.Utils.FormatMoney(refund))
end

--- Uebertraegt ein Fahrzeug auf einen anderen Spieler.
function Vehicles.Transfer(source, vehicleId, targetId)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    local target = MS.GetPlayer(tonumber(targetId) or -1)
    if not target then return false, 'Dieser Spieler ist nicht online.' end

    if target.charId == player.charId then return false, 'Das bringt nichts.' end

    local row = Vehicles.DB.GetById(tonumber(vehicleId) or -1)
    if not row or row.owner_id ~= player.charId then
        return false, 'Das ist nicht dein Fahrzeug.'
    end

    if row.state ~= 'garage' then
        return false, 'Das Fahrzeug muss eingeparkt sein.'
    end

    if Vehicles.DB.CountOwned(target.charId) >= VehicleConfig.Ownership.maxVehicles then
        return false, 'Der Empfaenger hat keinen Platz mehr.'
    end

    Vehicles.DB.SetOwner(row.id, target.charId)
    TriggerClientEvent('vehicles:client:forgetKeys', -1)

    target:Notify(('Du besitzt jetzt %s (%s).'):format(row.label, row.plate),
        'success', 9000)

    MS.Logger.Log('character', ('%s %s ueberschreibt %s (%s) an %s %s.'):format(
        player.firstname, player.lastname, row.label, row.plate,
        target.firstname, target.lastname), player.license)

    TriggerEvent('vehicles:server:transferred', row.id, player.charId, target.charId)

    return true, ('%s an %s %s ueberschrieben.'):format(
        row.label, target.firstname, target.lastname)
end

-- Zustand --------------------------------------------------------------------------

--- Der Client meldet den Zustand eines Fahrzeugs.
RegisterNetEvent('vehicles:server:report', function(plate, fuel, engine, body)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    plate = Vehicles.CleanPlate(plate)

    local entry = Vehicles.Spawned[plate]
    if not entry then return end

    -- Nur der Fahrer darf melden.
    if entry.source ~= source then return end

    fuel   = math.max(0.0, math.min(100.0, tonumber(fuel) or 0))
    engine = math.max(0.0, math.min(1000.0, tonumber(engine) or 1000))
    body   = math.max(0.0, math.min(1000.0, tonumber(body) or 1000))

    Vehicles.DB.SaveCondition(entry.id, fuel, engine, body)
end)

--- Tanken.
RegisterNetEvent('vehicles:server:refuel', function(plate, amount)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    plate = Vehicles.CleanPlate(plate)
    amount = math.max(1, math.min(100, math.floor(tonumber(amount) or 0)))

    local row = Vehicles.DB.GetByPlate(plate)
    if not row then return end

    local current = tonumber(row.fuel) or 0
    local missing = math.max(0, 100 - current)
    if missing <= 0 then
        player:Notify('Der Tank ist voll.', 'info')
        return
    end

    amount = math.min(amount, math.floor(missing))
    local cost = amount * VehicleConfig.State.fuelPrice

    if not player:RemoveMoney(cost, 'cash', 'tanken') then
        player:Notify(('Dir fehlen %s in bar.'):format(MS.Utils.FormatMoney(
            cost - player:GetMoney('cash'))), 'error')
        return
    end

    Vehicles.DB.SaveCondition(row.id, current + amount,
        tonumber(row.engine) or 1000, tonumber(row.body) or 1000)

    TriggerClientEvent('vehicles:client:setFuel', source, plate, current + amount)
    player:Notify(('%d Prozent getankt fuer %s.'):format(
        amount, MS.Utils.FormatMoney(cost)), 'success')
end)

--- Der Client fragt den Tankstand eines Fahrzeugs ab, das er nicht selbst
--- erzeugt hat (Beifahrer wird Fahrer, Fahrzeugwechsel).
MS.RegisterServerCallback('vehicles:fuel', function(player, cb, plate)
    if not player then return cb(nil) end

    local row = Vehicles.DB.GetByPlate(Vehicles.CleanPlate(plate))
    cb(row and (tonumber(row.fuel) or 100.0) or nil)
end)
