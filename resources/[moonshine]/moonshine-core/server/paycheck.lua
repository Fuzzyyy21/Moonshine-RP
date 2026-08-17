--- Regelmaessige Gehaltszahlung auf Basis des Job-Rangs.

if not Config.Paycheck.enabled then return end

CreateThread(function()
    local interval = math.max(1, Config.Paycheck.interval) * 60000

    while true do
        Wait(interval)

        for _, player in pairs(MS.Players) do
            local salary = player.job.salary or 0
            local unemployed = player.job.name == MS.DefaultJob

            if salary > 0 and (not unemployed or Config.Paycheck.payUnemployed) then
                player:AddMoney(salary, Config.Paycheck.account, 'paycheck')
                player:Notify(
                    ('Gehalt erhalten: %s (%s)'):format(MS.Utils.FormatMoney(salary), player.job.label),
                    'success'
                )
                player.lastPaycheck = os.time()
            end
        end
    end
end)
