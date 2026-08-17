--- Gegenstueck zu server/callbacks.lua.

local pending = {}
local nextRequestId = 0

---@param name string Name des Server-Callbacks
---@param callback fun(...) Antwortfunktion
function MS.TriggerServerCallback(name, callback, ...)
    nextRequestId = nextRequestId + 1
    pending[nextRequestId] = callback

    TriggerServerEvent('moonshine:server:triggerCallback', name, nextRequestId, ...)
end

RegisterNetEvent('moonshine:client:callbackResponse', function(requestId, ...)
    local callback = pending[requestId]
    if not callback then return end

    pending[requestId] = nil
    callback(...)
end)
