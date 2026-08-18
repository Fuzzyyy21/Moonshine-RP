--- Missionsvorlagen. Der Server zieht daraus taeglich bzw. woechentlich
--- eine zufaellige Auswahl je Spieler.
---
---   event  Fortschrittsereignis (siehe server/missions.lua)
---   goal   Zielwert
---   reward Belohnung (siehe server/rewards.lua)

Progress.Missions = {

    -- Taegliche Missionen ----------------------------------------------------
    { id = 'daily_playtime', kind = 'daily', event = 'playtime', goal = 60,
      label = 'Praesenz zeigen', description = 'Sei 60 Minuten online.',
      icon = '⏱', reward = { money = 6000, bpxp = 150 } },

    { id = 'daily_meditate', kind = 'daily', event = 'meditate', goal = 2,
      label = 'Innere Ruhe', description = 'Meditiere zweimal an einem Ritualpunkt.',
      icon = '🧘', reward = { money = 5000, bpxp = 150 } },

    { id = 'daily_ritual', kind = 'daily', event = 'ritual', goal = 1,
      label = 'Alte Riten', description = 'Fuehre ein vollstaendiges Ritual durch.',
      icon = '🕯', reward = { money = 8000, bpxp = 200 } },

    { id = 'daily_boss', kind = 'daily', event = 'boss', goal = 1,
      label = 'Jagdgesellschaft', description = 'Beteilige dich am Kampf gegen einen Weltboss.',
      icon = '☠', reward = { money = 12000, bpxp = 300, cases = { holz = 1 } } },

    { id = 'daily_skill', kind = 'daily', event = 'skillUsed', goal = 15,
      label = 'Kraftprobe', description = 'Setze 15 Klassenfaehigkeiten ein.',
      icon = '✨', reward = { money = 6000, bpxp = 180 } },

    { id = 'daily_craft', kind = 'daily', event = 'craft', goal = 1,
      label = 'Steinbinder', description = 'Binde einen Klassenstein.',
      icon = '◆', reward = { money = 9000, bpxp = 220 } },

    { id = 'daily_revive', kind = 'daily', event = 'revive', goal = 2,
      label = 'Lebensretter', description = 'Belebe zwei Wesen wieder.',
      icon = '💚', reward = { money = 10000, bpxp = 250 } },

    { id = 'daily_shop', kind = 'daily', event = 'buyStone', goal = 5,
      label = 'Guter Kunde', description = 'Kaufe fuenf Grundsteine beim Haendler.',
      icon = '🪙', reward = { money = 4000, bpxp = 120 } },

    { id = 'daily_event', kind = 'daily', event = 'worldEvent', goal = 1,
      label = 'Zeuge', description = 'Sei online, wenn ein Weltereignis beginnt.',
      icon = '🌒', reward = { money = 7000, bpxp = 200 } },

    -- Woechentliche Missionen ------------------------------------------------
    { id = 'weekly_playtime', kind = 'weekly', event = 'playtime', goal = 420,
      label = 'Stammgast', description = 'Sei sieben Stunden online.',
      icon = '⏳', reward = { money = 45000, bpxp = 900, cases = { silber = 1 } } },

    { id = 'weekly_boss', kind = 'weekly', event = 'boss', goal = 5,
      label = 'Bossjaeger', description = 'Erlege fuenf Weltbosse mit.',
      icon = '🗡', reward = { money = 60000, bpxp = 1200, cases = { gold = 1 } } },

    { id = 'weekly_craft', kind = 'weekly', event = 'craft', goal = 5,
      label = 'Meister der Steine', description = 'Binde fuenf Klassensteine.',
      icon = '💎', reward = { money = 55000, bpxp = 1100 } },

    { id = 'weekly_skillup', kind = 'weekly', event = 'skillUpgrade', goal = 3,
      label = 'Aufstieg', description = 'Steigere dreimal eine Klassenfaehigkeit.',
      icon = '📈', reward = { money = 50000, bpxp = 1000, cases = { silber = 1 } } },

    { id = 'weekly_ritual', kind = 'weekly', event = 'ritual', goal = 6,
      label = 'Ritualmeister', description = 'Fuehre sechs Rituale durch.',
      icon = '🔮', reward = { money = 65000, bpxp = 1300 } },

    { id = 'weekly_event', kind = 'weekly', event = 'worldEvent', goal = 4,
      label = 'Sterndeuter', description = 'Erlebe vier Weltereignisse mit.',
      icon = '🌌', reward = { money = 55000, bpxp = 1100, cases = { gold = 1 } } },

    { id = 'weekly_meditate', kind = 'weekly', event = 'meditate', goal = 10,
      label = 'Versenkung', description = 'Meditiere zehnmal.',
      icon = '☯', reward = { money = 40000, bpxp = 800 } },
}

Progress.MissionsById = {}
for _, mission in ipairs(Progress.Missions) do
    Progress.MissionsById[mission.id] = mission
end

function Progress.GetMission(id)
    if type(id) ~= 'string' then return nil end
    return Progress.MissionsById[id]
end

--- Alle Vorlagen einer Art.
function Progress.GetMissionPool(kind)
    local pool = {}

    for _, mission in ipairs(Progress.Missions) do
        if mission.kind == kind then pool[#pool + 1] = mission end
    end

    return pool
end
