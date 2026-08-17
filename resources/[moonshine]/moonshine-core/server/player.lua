--- Serverseitige Spielerobjekte.
--- Methoden liegen in MS.PlayerMethods, damit andere Dateien (inventory.lua,
--- status.lua, ...) das Objekt erweitern koennen.

MS.Players       = {}   -- [source] = Player
MS.PlayerMethods = {}

local Player = MS.PlayerMethods
Player.__index = Player

--- Erstellt ein Spielerobjekt aus Account- und Charakterdaten.
---@param source number
---@param user table Datensatz aus ms_users
---@param character table Datensatz aus ms_characters
function MS.CreatePlayer(source, user, character)
    local accounts = MS.Utils.DecodeJson(character.accounts, {})
    for account, definition in pairs(Config.Accounts) do
        accounts[account] = tonumber(accounts[account]) or definition.default
    end

    local metadata = MS.Utils.DecodeJson(character.metadata, {})
    metadata.hunger = tonumber(metadata.hunger) or 100.0
    metadata.thirst = tonumber(metadata.thirst) or 100.0

    local self = setmetatable({
        source     = source,
        license    = character.license,
        accountName = user.name,
        adminLevel = user.admin_level or 0,

        charId     = character.id,
        slot       = character.slot,
        firstname  = character.firstname,
        lastname   = character.lastname,
        fullname   = ('%s %s'):format(character.firstname, character.lastname),
        dob        = character.dob,
        gender     = character.gender,

        job        = MS.BuildJob(character.job, character.job_grade),
        accounts   = accounts,
        inventory  = MS.Utils.DecodeJson(character.inventory, {}),
        metadata   = metadata,
        appearance = MS.Utils.DecodeJson(character.appearance, {}),
        position   = MS.Utils.DecodeJson(character.position, {
            x = Config.DefaultSpawn.x, y = Config.DefaultSpawn.y,
            z = Config.DefaultSpawn.z, heading = Config.DefaultSpawn.w,
        }),

        loadedAt   = os.time(),
        lastPaycheck = os.time(),
    }, Player)

    MS.Players[source] = self
    return self
end

-- Zugriff -------------------------------------------------------------------

---@return table|nil
function MS.GetPlayer(source)
    return MS.Players[tonumber(source)]
end

---@return table|nil
function MS.GetPlayerByCharId(charId)
    for _, player in pairs(MS.Players) do
        if player.charId == charId then return player end
    end
end

---@return table|nil
function MS.GetPlayerByLicense(license)
    for _, player in pairs(MS.Players) do
        if player.license == license then return player end
    end
end

--- Alle geladenen Spieler, optional nach Job gefiltert.
function MS.GetPlayers(jobName)
    local result = {}
    for _, player in pairs(MS.Players) do
        if not jobName or player.job.name == jobName then
            result[#result + 1] = player
        end
    end
    return result
end

-- Basis ---------------------------------------------------------------------

--- Client-taugliche Kopie der Spielerdaten (ohne Funktionen).
function Player:GetData()
    return {
        source    = self.source,
        charId    = self.charId,
        firstname = self.firstname,
        lastname  = self.lastname,
        fullname  = self.fullname,
        dob       = self.dob,
        gender    = self.gender,
        job       = self.job,
        accounts  = self.accounts,
        inventory = self.inventory,
        metadata  = self.metadata,
        adminLevel = self.adminLevel,
        maxWeight = Config.Inventory.maxWeight,
        maxSlots  = Config.Inventory.maxSlots,
    }
end

--- Schickt die aktuellen Daten an den Client.
function Player:Sync()
    TriggerClientEvent('moonshine:client:syncData', self.source, self:GetData())
end

function Player:Notify(message, type, duration)
    TriggerClientEvent('moonshine:client:notify', self.source, message, type or 'info', duration or 5000)
end

function Player:TriggerEvent(eventName, ...)
    TriggerClientEvent(eventName, self.source, ...)
end

function Player:HasPermission(level)
    return self.adminLevel >= (level or 1)
end

function Player:Kick(reason)
    DropPlayer(self.source, reason or 'Du wurdest vom Server entfernt.')
end

--- Aktualisiert die zuletzt bekannte Position (wird beim Speichern verwendet).
function Player:SetPosition(x, y, z, heading)
    self.position = { x = x, y = y, z = z, heading = heading or 0.0 }
end

--- Speichert den Charakter in der Datenbank.
function Player:Save()
    if not self.charId then return false end

    MS.DB.SaveCharacter(self.charId, {
        job        = self.job.name,
        jobGrade   = self.job.grade,
        accounts   = self.accounts,
        inventory  = self.inventory,
        position   = self.position,
        appearance = self.appearance,
        metadata   = self.metadata,
    })
    return true
end

-- Job -----------------------------------------------------------------------

--- Setzt Job und Rang. Gibt false zurueck wenn der Job nicht existiert.
function Player:SetJob(name, grade)
    if not MS.GetJob(name) then
        MS.Utils.Print('warn', 'Unbekannter Job "%s" fuer %s', tostring(name), self.fullname)
        return false
    end

    local previous = self.job
    self.job = MS.BuildJob(name, grade)

    self:Sync()
    self:TriggerEvent('moonshine:client:jobChanged', self.job, previous)
    TriggerEvent('moonshine:server:jobChanged', self.source, self.job, previous)
    MS.Logger.Log('admin', ('%s ist jetzt %s (%s)'):format(self.fullname, self.job.label, self.job.gradeLabel), self.license)
    return true
end

-- Geld ----------------------------------------------------------------------

---@return number
function Player:GetMoney(account)
    return self.accounts[account or 'cash'] or 0
end

function Player:CanAfford(amount, account)
    return self:GetMoney(account or 'cash') >= amount
end

--- Interne Kontobuchung.
local function applyMoney(self, account, delta, reason)
    account = account or 'cash'
    if not Config.Accounts[account] then
        MS.Utils.Print('warn', 'Unbekanntes Konto "%s"', tostring(account))
        return false
    end

    self.accounts[account] = math.max(0, (self.accounts[account] or 0) + delta)
    self:Sync()
    self:TriggerEvent('moonshine:client:moneyChanged', account, self.accounts[account], delta)
    TriggerEvent('moonshine:server:moneyChanged', self.source, account, self.accounts[account], delta, reason)

    MS.Logger.Transaction(self.charId, account, delta, self.accounts[account], reason)
    return true
end

function Player:AddMoney(amount, account, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    return applyMoney(self, account, amount, reason or 'add')
end

function Player:RemoveMoney(amount, account, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    if not self:CanAfford(amount, account) then return false end
    return applyMoney(self, account, -amount, reason or 'remove')
end

function Player:SetMoney(amount, account, reason)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    account = account or 'cash'
    local delta = amount - self:GetMoney(account)
    return applyMoney(self, account, delta, reason or 'set')
end

-- Metadaten -----------------------------------------------------------------

function Player:GetMetadata(key)
    if key == nil then return self.metadata end
    return self.metadata[key]
end

function Player:SetMetadata(key, value)
    self.metadata[key] = value
    self:Sync()
    self:TriggerEvent('moonshine:client:metadataChanged', key, value)
end
