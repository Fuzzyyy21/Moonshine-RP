--- Outfits je Charakter.

Appearance.DB = {}
Appearance.DB.Ready = false

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `ms_outfits` (
    `id`           INT         NOT NULL AUTO_INCREMENT,
    `character_id` INT         NOT NULL,
    `label`        VARCHAR(32) NOT NULL,
    `data`         LONGTEXT    NOT NULL,
    `created_at`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `character_id` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

MySQL.ready(function()
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) end)

    if not ok then
        print(('^1[Aussehen]^7 Schema konnte nicht angelegt werden: %s'):format(tostring(err)))
        return
    end

    Appearance.DB.Ready = true
    print('^2[Aussehen]^7 Datenbank bereit.')
end)

function Appearance.DB.LoadOutfits(characterId)
    return MySQL.query.await(
        'SELECT id, label, data FROM ms_outfits WHERE character_id = ? ORDER BY id ASC',
        { characterId }) or {}
end

function Appearance.DB.CountOutfits(characterId)
    local row = MySQL.single.await(
        'SELECT COUNT(*) AS total FROM ms_outfits WHERE character_id = ?', { characterId })

    return row and tonumber(row.total) or 0
end

function Appearance.DB.SaveOutfit(characterId, label, data)
    return MySQL.insert.await([[
        INSERT INTO ms_outfits (character_id, label, data) VALUES (?, ?, ?)
    ]], { characterId, label, json.encode(data) })
end

function Appearance.DB.GetOutfit(outfitId, characterId)
    return MySQL.single.await(
        'SELECT id, label, data FROM ms_outfits WHERE id = ? AND character_id = ?',
        { outfitId, characterId })
end

function Appearance.DB.DeleteOutfit(outfitId, characterId)
    return MySQL.update.await(
        'DELETE FROM ms_outfits WHERE id = ? AND character_id = ?',
        { outfitId, characterId })
end
