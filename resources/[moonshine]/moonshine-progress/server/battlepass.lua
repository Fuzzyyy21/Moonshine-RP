--- Battle Pass: Stufenbelohnungen und Premium-Freischaltung.

--- Baut die Anzeige des Battle Pass.
function Progress.BuildBattlePassPayload(profile)
    local config = ProgressConfig.BattlePass
    local level, into, needed = Progress.GetBattlePassLevel(profile.bpXp)

    local tiers = {}

    for tierLevel = 1, config.maxLevel do
        local free, premium = Progress.GetTierReward(tierLevel)

        tiers[#tiers + 1] = {
            level        = tierLevel,
            unlocked     = level >= tierLevel,
            free         = Progress.DescribeReward(free),
            premium      = Progress.DescribeReward(premium),
            freeClaimed  = profile:IsTierClaimed(tierLevel, 'free'),
            premiumClaimed = profile:IsTierClaimed(tierLevel, 'premium'),
            highlight    = Progress.BattlePassTiers[tierLevel] ~= nil,
        }
    end

    return {
        season      = config.season,
        seasonLabel = config.seasonLabel,
        level       = level,
        maxLevel    = config.maxLevel,
        xp          = into,
        xpNeeded    = needed,
        totalXp     = profile.bpXp,
        premium     = profile.premium,
        premiumPrice = config.premiumPrice,
        tiers       = tiers,
    }
end

--- Holt die Belohnung einer Stufe ab.
function Progress.ClaimTier(source, level, track)
    local profile = Progress.GetProfile(source)
    if not profile then return false end

    local player = profile:Player()
    if not player then return false end

    level = math.floor(tonumber(level) or 0)
    if level < 1 or level > ProgressConfig.BattlePass.maxLevel then return false end
    if track ~= 'free' and track ~= 'premium' then return false end

    local current = Progress.GetBattlePassLevel(profile.bpXp)
    if current < level then
        player:Notify('Diese Stufe hast du noch nicht erreicht.', 'error')
        return false
    end

    if track == 'premium' and not profile.premium then
        player:Notify('Dafuer brauchst du den Premium-Pass.', 'error')
        return false
    end

    if not profile:MarkTierClaimed(level, track) then
        player:Notify('Diese Belohnung hast du bereits abgeholt.', 'error')
        return false
    end

    local free, premium = Progress.GetTierReward(level)
    local reward = track == 'premium' and premium or free

    local _, text = Progress.GiveReward(source, reward, 'battlepass')
    player:Notify(('Stufe %d: %s'):format(level, text), 'success', 8000)

    profile:Save()
    profile:Sync()

    return true
end

--- Holt alles ab, was verfuegbar ist.
function Progress.ClaimAllTiers(source)
    local profile = Progress.GetProfile(source)
    if not profile then return false end

    local player = profile:Player()
    if not player then return false end

    local current = Progress.GetBattlePassLevel(profile.bpXp)
    local claimed = 0

    for level = 1, current do
        local free, premium = Progress.GetTierReward(level)

        if not profile:IsTierClaimed(level, 'free') then
            profile:MarkTierClaimed(level, 'free')
            Progress.GiveReward(source, free, 'battlepass')
            claimed = claimed + 1
        end

        if profile.premium and not profile:IsTierClaimed(level, 'premium') then
            profile:MarkTierClaimed(level, 'premium')
            Progress.GiveReward(source, premium, 'battlepass')
            claimed = claimed + 1
        end
    end

    if claimed == 0 then
        player:Notify('Es liegt nichts zum Abholen bereit.', 'info')
        return false
    end

    player:Notify(('%d Belohnungen abgeholt.'):format(claimed), 'success', 8000)

    profile:Save()
    profile:Sync()

    return true
end

--- Kauft den Premium-Pass der laufenden Saison.
function Progress.BuyPremium(source)
    local profile = Progress.GetProfile(source)
    if not profile then return false end

    local player = profile:Player()
    if not player then return false end

    if profile.premium then
        player:Notify('Du hast den Premium-Pass bereits.', 'error')
        return false
    end

    local config = ProgressConfig.BattlePass
    if not player:RemoveMoney(config.premiumPrice, config.premiumAccount, 'battlepass-premium') then
        player:Notify(('Dir fehlen %s.'):format(MS.Utils.FormatMoney(
            config.premiumPrice - player:GetMoney(config.premiumAccount))), 'error')
        return false
    end

    profile.premium = true
    profile.dirty   = true

    player:Notify('Premium-Pass freigeschaltet. Alle bisherigen Stufen sind abholbar.', 'success', 10000)

    profile:Save()
    profile:Sync()

    TriggerEvent('progress:server:premiumBought', source)
    return true
end

--- Battle-Pass-XP von aussen vergeben.
function Progress.AddBattlePassXp(source, amount)
    local profile = Progress.GetProfile(source)
    if not profile then return 0 end

    local gained = profile:AddBattlePassXp(amount)
    if gained > 0 then profile:Sync() end

    return gained
end

RegisterNetEvent('progress:server:claimTier', function(level, track)
    local source = source
    if not MS.RateLimit(source, 'progress:server:claimTier', 25, 10) then return end
    Progress.ClaimTier(source, level, track)
end)

RegisterNetEvent('progress:server:claimAllTiers', function()
    Progress.ClaimAllTiers(source)
end)

RegisterNetEvent('progress:server:buyPremium', function()
    Progress.BuyPremium(source)
end)
