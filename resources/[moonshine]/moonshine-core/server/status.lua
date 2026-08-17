--- Hunger und Durst. Werte liegen als Metadaten (0-100) am Charakter.

local Player = MS.PlayerMethods
local STATUSES = { 'hunger', 'thirst' }

---@return number
function Player:GetStatus(name)
    return tonumber(self.metadata[name]) or 100.0
end

function Player:SetStatus(name, value)
    self.metadata[name] = MS.Utils.Clamp(MS.Utils.Round(tonumber(value) or 0, 1), 0.0, 100.0)
    self:Sync()
    self:TriggerEvent('moonshine:client:statusChanged', name, self.metadata[name])
end

--- Veraendert einen Status relativ (positiv wie negativ).
function Player:AddStatus(name, value)
    self:SetStatus(name, self:GetStatus(name) + (tonumber(value) or 0))
end

if Config.Status.enabled then
    CreateThread(function()
        local interval = math.max(5, Config.Status.tickInterval) * 1000

        while true do
            Wait(interval)

            for _, player in pairs(MS.Players) do
                local starving = false

                for _, name in ipairs(STATUSES) do
                    local decay = name == 'hunger' and Config.Status.hungerPerTick or Config.Status.thirstPerTick
                    local value = MS.Utils.Clamp(player:GetStatus(name) - decay, 0.0, 100.0)

                    player.metadata[name] = MS.Utils.Round(value, 1)
                    if value <= 0 then starving = true end

                    if value <= 20 and value + decay > 20 then
                        player:Notify(
                            name == 'hunger' and 'Du hast Hunger.' or 'Du hast Durst.',
                            'warning'
                        )
                    end
                end

                player:Sync()

                if starving and Config.Status.damagePerTick > 0 then
                    player:TriggerEvent('moonshine:client:applyStatusDamage', Config.Status.damagePerTick)
                end
            end
        end
    end)
end
