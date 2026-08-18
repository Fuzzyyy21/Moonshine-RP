--- Bank: Ein- und Auszahlung, Ueberweisung, Zinsen.

MS = MS or exports['moonshine-core']:GetCoreObject()

--- Steht der Spieler an einer Bank oder einem Geldautomaten?
---@return string|nil kind 'bank' oder 'atm'
function Services.AtBank(source)
    local coords = GetEntityCoords(GetPlayerPed(source))

    for _, bank in ipairs(Services.Banks) do
        if #(coords - bank.coords) <= ServiceConfig.Range + 2.5 then return 'bank' end
    end

    for _, atm in ipairs(Services.Atms) do
        if #(coords - atm) <= ServiceConfig.Range + 1.5 then return 'atm' end
    end

    return nil
end

--- Zustand fuer die Oberflaeche.
function Services.BankPayload(source, kind)
    local player = MS.GetPlayer(source)
    if not player then return nil end

    local config = ServiceConfig.Bank

    return {
        kind     = kind,
        bank     = player:GetMoney('bank'),
        cash     = player:GetMoney('cash'),
        name     = ('%s %s'):format(player.firstname, player.lastname),
        transfer = config.transfer.enabled
            and (kind == 'bank' or config.atm.allowTransfer),
        deposit  = kind == 'bank' or config.atm.allowDeposit,
        maxWithdraw = kind == 'atm' and config.atm.maxWithdraw or nil,
        fee      = config.transfer.fee,
        interest = config.interest.enabled and config.interest.rate or 0,
    }
end

function Services.SyncBank(source, kind)
    local payload = Services.BankPayload(source, kind or Services.AtBank(source) or 'bank')
    if payload then
        TriggerClientEvent('services:client:bank', source, payload)
    end
end

-- Einzahlen -----------------------------------------------------------------------

RegisterNetEvent('services:server:deposit', function(amount)
    local source = source
    if not MS.RateLimit(source, 'services:server:deposit', 10, 10) then return end
    local player = MS.GetPlayer(source)
    if not player then return end

    local kind = Services.AtBank(source)
    if not kind then return end

    if kind == 'atm' and not ServiceConfig.Bank.atm.allowDeposit then
        player:Notify('Am Automaten kannst du nur abheben.', 'error')
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return end

    if not player:RemoveMoney(amount, 'cash', 'einzahlung') then
        player:Notify('So viel hast du nicht dabei.', 'error')
        return
    end

    player:AddMoney(amount, 'bank', 'einzahlung')
    player:Notify(('%s eingezahlt.'):format(MS.Utils.FormatMoney(amount)), 'success')

    Services.SyncBank(source, kind)
end)

-- Abheben --------------------------------------------------------------------------

RegisterNetEvent('services:server:withdraw', function(amount)
    local source = source
    if not MS.RateLimit(source, 'services:server:withdraw', 10, 10) then return end
    local player = MS.GetPlayer(source)
    if not player then return end

    local kind = Services.AtBank(source)
    if not kind then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return end

    if kind == 'atm' and amount > ServiceConfig.Bank.atm.maxWithdraw then
        player:Notify(('Am Automaten hoechstens %s.'):format(
            MS.Utils.FormatMoney(ServiceConfig.Bank.atm.maxWithdraw)), 'error')
        return
    end

    if not player:RemoveMoney(amount, 'bank', 'auszahlung') then
        player:Notify('So viel ist nicht auf dem Konto.', 'error')
        return
    end

    player:AddMoney(amount, 'cash', 'auszahlung')
    player:Notify(('%s abgehoben.'):format(MS.Utils.FormatMoney(amount)), 'success')

    Services.SyncBank(source, kind)
end)

-- Ueberweisen ------------------------------------------------------------------------

--- Ueberweisung. Wird sowohl vom NUI als auch vom Command aufgerufen.
function Services.Transfer(source, targetId, amount)
    local player = MS.GetPlayer(source)
    if not player then return end

    local config = ServiceConfig.Bank
    if not config.transfer.enabled then return end

    local kind = Services.AtBank(source)
    if not kind then return end

    if kind == 'atm' and not config.atm.allowTransfer then
        player:Notify('Ueberweisungen gehen nur in der Filiale.', 'error')
        return
    end

    local target = MS.GetPlayer(tonumber(targetId) or -1)
    if not target then
        player:Notify('Dieser Spieler ist nicht online.', 'error')
        return
    end

    if target.source == source then
        player:Notify('An dich selbst? Wirklich?', 'error')
        return
    end

    amount = math.floor(tonumber(amount) or 0)

    if amount < config.transfer.minimum or amount > config.transfer.maximum then
        player:Notify(('Zwischen %s und %s.'):format(
            MS.Utils.FormatMoney(config.transfer.minimum),
            MS.Utils.FormatMoney(config.transfer.maximum)), 'error')
        return
    end

    local fee = math.floor(amount * config.transfer.fee)
    local total = amount + fee

    if not player:RemoveMoney(total, 'bank', 'ueberweisung') then
        player:Notify(('Mit Gebuehr waeren das %s.'):format(
            MS.Utils.FormatMoney(total)), 'error')
        return
    end

    target:AddMoney(amount, 'bank', 'ueberweisung')

    player:Notify(('%s an %s %s ueberwiesen (Gebuehr %s).'):format(
        MS.Utils.FormatMoney(amount), target.firstname, target.lastname,
        MS.Utils.FormatMoney(fee)), 'success', 9000)

    target:Notify(('%s %s hat dir %s ueberwiesen.'):format(
        player.firstname, player.lastname, MS.Utils.FormatMoney(amount)),
        'success', 9000)

    MS.Logger.Log('money', ('%s %s ueberweist %s an %s %s.'):format(
        player.firstname, player.lastname, MS.Utils.FormatMoney(amount),
        target.firstname, target.lastname), player.license)

    Services.SyncBank(source, kind)
end

RegisterNetEvent('services:server:transfer', function(targetId, amount)
    Services.Transfer(source, targetId, amount)
end)

-- Oeffnen ----------------------------------------------------------------------------

RegisterNetEvent('services:server:openBank', function()
    local source = source
    if not MS.GetPlayer(source) then return end

    local kind = Services.AtBank(source)
    if not kind then return end

    Services.SyncBank(source, kind)
end)

-- Zinsen ------------------------------------------------------------------------------

CreateThread(function()
    local config = ServiceConfig.Bank.interest
    if not config.enabled then return end

    while true do
        Wait(config.interval * 60000)

        for _, player in pairs(MS.GetPlayers()) do
            local balance = player:GetMoney('bank')

            if balance > 0 then
                local interest = math.min(config.maximum,
                    math.floor(balance * config.rate))

                if interest > 0 then
                    player:AddMoney(interest, 'bank', 'zinsen')
                    player:Notify(('Zinsen gutgeschrieben: %s.'):format(
                        MS.Utils.FormatMoney(interest)), 'info', 8000)
                end
            end
        end
    end
end)
