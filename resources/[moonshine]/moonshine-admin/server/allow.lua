--- Kulanz: was der Server selbst erlaubt hat.
---
--- Ein Wachhund, der die eigenen Spieler kickt, ist schlimmer als keiner.
--- Genau das wuerde hier passieren: der Charaktereditor macht den Spieler
--- unverwundbar, die Rast im Zufluchtsort auch, der Schattenschritt der
--- Mystik teleportiert ihn quer ueber die Strasse und zuendet dabei zwei
--- Explosionen. Alles davon ist erlaubt - der Wachhund weiss es nur nicht.
---
--- Deshalb sagt es ihm der Server. Nicht der Client: der duerfte sich sonst
--- selbst freischalten. Jede Ausnahme kommt von der Stelle, die die
--- Handlung ohnehin schon geprueft hat.
---
---   exports['moonshine-admin']:Allow(source, 'godmode', 30)
---
--- Arten:
---   'godmode'   - Unverwundbarkeit ist gerade in Ordnung
---   'teleport'  - ein Ortswechsel ist gerade in Ordnung
---   'explosion' - eine Explosion ist gerade in Ordnung
---   'modell'    - ein fremdes Ped-Modell ist gerade in Ordnung
---   'leben'     - mehr Leben als sonst erlaubt ist in Ordnung

--- [source] = { [art] = bisWann }
Admin.Allowed = {}

--- Erlaubt einem Spieler eine Sache fuer eine Weile.
---@param source number
---@param art string
---@param sekunden number|nil Standard: 15
function Admin.Allow(source, art, sekunden)
    if type(art) ~= 'string' then return false end

    local eintrag = Admin.Allowed[source]

    if not eintrag then
        eintrag = {}
        Admin.Allowed[source] = eintrag
    end

    local bis = os.time() + math.max(1, math.floor(tonumber(sekunden) or 15))

    -- Eine laufende Kulanz wird verlaengert, nicht verkuerzt: zwei Systeme
    -- duerfen sich nicht gegenseitig die Ausnahme wegnehmen.
    if not eintrag[art] or eintrag[art] < bis then eintrag[art] = bis end

    return true
end

--- Darf dieser Spieler das gerade?
function Admin.IsAllowed(source, art)
    local eintrag = Admin.Allowed[source]
    if not eintrag or not eintrag[art] then return false end

    if eintrag[art] < os.time() then
        eintrag[art] = nil
        return false
    end

    return true
end

--- Nimmt eine Kulanz vorzeitig zurueck.
function Admin.Deny(source, art)
    local eintrag = Admin.Allowed[source]
    if eintrag then eintrag[art] = nil end
end

exports('Allow', function(source, art, sekunden)
    return Admin.Allow(source, art, sekunden)
end)

exports('Deny', function(source, art)
    return Admin.Deny(source, art)
end)

exports('IsAllowed', function(source, art)
    return Admin.IsAllowed(source, art)
end)

AddEventHandler('playerDropped', function()
    Admin.Allowed[source] = nil
end)

--- Wer neu lädt, bekommt einen Moment Ruhe: Spawn, Aussehen und die erste
--- Position kommen alle gleichzeitig.
AddEventHandler('moonshine:server:playerLoaded', function(source)
    Admin.Allow(source, 'teleport', 30)
    Admin.Allow(source, 'godmode', 30)
    Admin.Allow(source, 'modell', 30)
end)
