--- Clientseitig bleibt fast nichts zu tun.
---
--- Frueher meldete diese Datei alle zwoelf Sekunden Leben, Weste und Waffe
--- an den Server. Das ist ersatzlos entfallen: der Server liest all das
--- selbst vom Ped ab (server/watch.lua). Eine Meldung, die der Gemeldete
--- selbst verschickt, ist keine Meldung.
---
--- Was bleibt, ist das Entfernen einer gesperrten Waffe - das muss auf der
--- Seite passieren, auf der die Waffe liegt.

RegisterNetEvent('admin:client:stripWeapon', function(name)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    local hash = GetHashKey(name)

    if HasPedGotWeapon(ped, hash, false) then
        RemoveWeaponFromPed(ped, hash)
    end

    -- Zur Sicherheit auch das, was gerade in der Hand liegt.
    if GetSelectedPedWeapon(ped) == hash then
        SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    end
end)
