--[[
    dps-maritime - Jetsam Company
    Server-Side Event Handlers

    Handles rewards and validation for random sea events
]]

-----------------------------------------------------------
-- EVENT XP REWARD
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:awardEventXP', function(xp, eventName)
    local source = source
    local identifier = Bridge.GetIdentifier(source)

    if not identifier then return end

    -- Validate XP amount (anti-cheat)
    if type(xp) ~= 'number' or xp < 0 or xp > 500 then
        print('^1[dps-maritime] Invalid event XP claim from ' .. source .. ': ' .. tostring(xp) .. '^0')
        return
    end

    -- Award XP
    local db = exports['dps-maritime']:GetDatabase()
    if not db then return end

    local playerData = db.GetPlayerData(identifier)
    if not playerData then return end

    local newXP = playerData.xp + xp
    local newLevel = Config.GetLevelFromXP(newXP)

    db.UpdateXP(identifier, newXP)

    -- Check for level up
    if newLevel > playerData.level then
        db.UpdateLevel(identifier, newLevel)

        -- Notify player
        Bridge.Notify(source, {
            title = 'Level Up!',
            description = 'You are now Level ' .. newLevel .. ': ' .. Config.GetLevelData(newLevel).title,
            type = 'success',
            duration = 8000,
        })

        -- Sync state bags
        local player = Player(source)
        player.state:set('maritimeLevel', newLevel, true)
        player.state:set('maritimeXP', newXP, true)
        player.state:set('maritimeTitle', Config.GetLevelData(newLevel).title, true)
    else
        -- Just update XP state
        local player = Player(source)
        player.state:set('maritimeXP', newXP, true)
    end

    -- Trigger XP update event for dashboard
    TriggerClientEvent('dps-maritime:client:updateXP', source, {
        xp = newXP,
        level = newLevel,
    })

    if Config.Debug then
        print('^3[dps-maritime] ' .. source .. ' awarded ' .. xp .. ' XP for event: ' .. (eventName or 'Unknown') .. '^0')
    end
end)

-----------------------------------------------------------
-- EVENT CASH + XP REWARD
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:awardEventReward', function(cash, xp, eventName)
    local source = source
    local identifier = Bridge.GetIdentifier(source)

    if not identifier then return end

    -- Validate amounts (anti-cheat)
    if type(cash) ~= 'number' or cash < 0 or cash > 10000 then
        print('^1[dps-maritime] Invalid event cash claim from ' .. source .. ': ' .. tostring(cash) .. '^0')
        return
    end

    if type(xp) ~= 'number' or xp < 0 or xp > 500 then
        print('^1[dps-maritime] Invalid event XP claim from ' .. source .. ': ' .. tostring(xp) .. '^0')
        return
    end

    -- Award cash
    Bridge.AddMoney(source, 'bank', cash, 'Maritime Event: ' .. (eventName or 'Bonus'))

    -- Award XP
    local db = exports['dps-maritime']:GetDatabase()
    if not db then return end

    local playerData = db.GetPlayerData(identifier)
    if not playerData then return end

    local newXP = playerData.xp + xp
    local newLevel = Config.GetLevelFromXP(newXP)

    db.UpdateXP(identifier, newXP)

    -- Update total earnings
    local newEarnings = (playerData.total_earnings or 0) + cash
    db.UpdateEarnings(identifier, newEarnings)

    -- Check for level up
    if newLevel > playerData.level then
        db.UpdateLevel(identifier, newLevel)

        Bridge.Notify(source, {
            title = 'Level Up!',
            description = 'You are now Level ' .. newLevel .. ': ' .. Config.GetLevelData(newLevel).title,
            type = 'success',
            duration = 8000,
        })
    end

    -- Sync state bags
    local player = Player(source)
    player.state:set('maritimeLevel', newLevel, true)
    player.state:set('maritimeXP', newXP, true)
    player.state:set('maritimeTitle', Config.GetLevelData(newLevel).title, true)

    -- Trigger XP update event for dashboard
    TriggerClientEvent('dps-maritime:client:updateXP', source, {
        xp = newXP,
        level = newLevel,
    })

    if Config.Debug then
        print('^3[dps-maritime] ' .. source .. ' awarded $' .. cash .. ' + ' .. xp .. ' XP for event: ' .. (eventName or 'Unknown') .. '^0')
    end
end)

-----------------------------------------------------------
-- RATE LIMITING FOR EVENT REWARDS
-----------------------------------------------------------

local EventRewardCooldowns = {}
local REWARD_COOLDOWN = 60000 -- 1 minute between event rewards

-- Cleanup old cooldowns
CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes

        local now = GetGameTimer()
        for source, lastTime in pairs(EventRewardCooldowns) do
            if (now - lastTime) > REWARD_COOLDOWN * 2 then
                EventRewardCooldowns[source] = nil
            end
        end
    end
end)

-- Wrap the reward events with rate limiting
local function CheckEventCooldown(source)
    local now = GetGameTimer()
    local lastReward = EventRewardCooldowns[source]

    if lastReward and (now - lastReward) < REWARD_COOLDOWN then
        return false
    end

    EventRewardCooldowns[source] = now
    return true
end

-- Override the events to add rate limiting
AddEventHandler('dps-maritime:server:awardEventXP', function(xp, eventName)
    local source = source
    if not CheckEventCooldown(source) then
        print('^1[dps-maritime] Rate limited event XP claim from ' .. source .. '^0')
    end
end)

AddEventHandler('dps-maritime:server:awardEventReward', function(cash, xp, eventName)
    local source = source
    if not CheckEventCooldown(source) then
        print('^1[dps-maritime] Rate limited event reward claim from ' .. source .. '^0')
    end
end)
