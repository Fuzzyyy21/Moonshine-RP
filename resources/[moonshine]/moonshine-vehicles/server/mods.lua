--- Umbauten sichern und weiterreichen.
---
--- Der Client darf keine Umbauten setzen, die er nicht bezahlt hat. Wer
--- speichern will, geht ueber die Werkstatt (moonshine-services) - die
--- prueft Naehe, Besitz und Kontostand und ruft dann hier herein.

--- Liest die gespeicherten Umbauten eines Fahrzeugs.
function Vehicles.GetMods(plate)
    local row = Vehicles.DB.GetByPlate(Vehicles.CleanPlate(plate))
    if not row or not row.mods or row.mods == '' then return {} end

    local ok, mods = pcall(json.decode, row.mods)
    if not ok or type(mods) ~= 'table' then return {} end

    return mods
end

--- Schreibt Umbauten in die Datenbank und traegt sie am Fahrzeug auf.
---@return boolean
function Vehicles.SetMods(plate, mods, target)
    plate = Vehicles.CleanPlate(plate)

    local row = Vehicles.DB.GetByPlate(plate)
    if not row then return false end

    Vehicles.DB.SaveMods(row.id, mods or {})

    -- Wer das Fahrzeug gerade sieht, soll es auch gleich anders sehen.
    if target then
        TriggerClientEvent('vehicles:client:applyMods', target, plate, mods)
    else
        TriggerClientEvent('vehicles:client:applyMods', -1, plate, mods)
    end

    TriggerEvent('vehicles:server:modsChanged', plate, mods)
    return true
end

exports('GetMods', function(plate)
    return Vehicles.GetMods(plate)
end)

exports('SetMods', function(plate, mods, target)
    return Vehicles.SetMods(plate, mods, target)
end)

--- Gehoert dieses Fahrzeug dem Spieler, oder hat er wenigstens einen
--- Schluessel? Die Werkstatt fragt danach, bevor sie etwas anschraubt.
exports('MayModify', function(source, plate)
    plate = Vehicles.CleanPlate(plate)

    local player = MS.GetPlayer(source)
    local row = Vehicles.DB.GetByPlate(plate)
    if not player or not row then return false end

    return (Vehicles.HasKey(player.charId, plate)) == true
end)
