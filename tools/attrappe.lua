--- Minimale FiveM-Attrappe, damit sich die shared-Dateien ausserhalb des
--- Spiels laden lassen. Deckt nur ab, was beim Laden gebraucht wird - keine
--- Spiellogik.

local meta = {}
meta.__index = meta

meta.__sub = function(a, b)
    return setmetatable({ x = a.x - b.x, y = a.y - b.y,
                          z = (a.z or 0) - (b.z or 0) }, meta)
end

meta.__add = function(a, b)
    return setmetatable({ x = a.x + b.x, y = a.y + b.y,
                          z = (a.z or 0) + (b.z or 0) }, meta)
end

meta.__len = function(v)
    return math.sqrt(v.x ^ 2 + v.y ^ 2 + (v.z or 0) ^ 2)
end

meta.__eq = function(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z
end

meta.__tostring = function(v)
    return ('vector(%.1f, %.1f, %.1f)'):format(v.x, v.y, v.z or 0)
end

function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, meta) end
function vector4(x, y, z, w) return setmetatable({ x = x, y = y, z = z, w = w }, meta) end

function CreateThread() end
function Wait() end
function SetTimeout() end
function GetGameTimer() return 0 end
function TriggerEvent() end
function TriggerClientEvent() end
function TriggerServerEvent() end
function RegisterNetEvent() end
function AddEventHandler() end
function RegisterCommand() end
function RegisterKeyMapping() end
function GetCurrentResourceName() return 'test' end
function print_(...) end

exports = setmetatable({}, {
    __index = function()
        return setmetatable({}, {
            __index = function() return function() return nil end end,
        })
    end,
    __call = function() end,
})

json = {
    encode = function() return '{}' end,
    decode = function() return {} end,
}

MS = MS or {
    Utils = { FormatMoney = function(n) return tostring(n) .. ' $' end },
    Jobs = {}, Items = {},
    GetItem = function(name) return { label = name, weight = 100 } end,
    GetJob = function(name) return { label = name, grades = { [0] = {} } } end,
}
