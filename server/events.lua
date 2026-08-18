--[[
    dps-maritime - Jetsam Company
    Server-Side Event Handlers

    Handles rewards and validation for random sea events.

    SECURITY MODEL (fixes the old money/XP printer):
    - These events ARE legitimately client-initiated (the client detects a world
      event and requests its reward), so the net events stay reachable BUT:
        (a) the reward is RECOMPUTED SERVER-SIDE from the event identity - the
            client-supplied cash/xp values are ignored entirely.
        (b) a REAL per-player, per-event cooldown aborts (returns) BEFORE any
            grant if the player is on cooldown for that event.
        (c) unknown / spoofed event names grant nothing.
    - The old dead second "rate limit" AddEventHandler (which could only print,
      never abort the grant) has been removed.
]]

local Database = exports['dps-maritime']:GetDatabase()

-----------------------------------------------------------
-- SERVER-AUTHORITATIVE REWARD TABLE
-- Keyed by the event name the client sends (see client/events.lua). Cash is
-- rolled server-side within these bounds; XP is fixed. The client never gets to
-- choose the amount.
-----------------------------------------------------------

local EventRewards = {
    -- awardEventXP (XP only)
    ['Wildlife Sighting'] = { xp = 25,  cashMin = 0,    cashMax = 0 },
    -- awardEventReward (cash + XP)
    ['Rescue Mission']    = { xp = 150, cashMin = 1500, cashMax = 3000 }, -- distress_signal
    ['Salvage Bonus']     = { xp = 50,  cashMin = 500,  cashMax = 1500 }, -- floating_cargo
}

-- Per-player, per-event cooldown (ms). Prevents farming a single event.
local REWARD_COOLDOWN = 60000 -- 1 minute per event per player

-- [identifier] = { [eventName] = lastGrantGameTimer }
local EventCooldowns = {}

-----------------------------------------------------------
-- REWARD GRANT (single authoritative path)
-----------------------------------------------------------

local function GrantEventReward(source, eventName)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end

    -- Validate event identity - never grant for an unknown/spoofed name
    local reward = EventRewards[eventName]
    if not reward then
        if Config.Debug then
            print('^1[dps-maritime] Unknown event reward claim from ' .. source .. ': ' .. tostring(eventName) .. '^0')
        end
        return
    end

    -- Real per-player, per-event cooldown. ABORT BEFORE granting anything.
    local now = GetGameTimer()
    EventCooldowns[identifier] = EventCooldowns[identifier] or {}
    local last = EventCooldowns[identifier][eventName]
    if last and (now - last) < REWARD_COOLDOWN then
        if Config.Debug then
            print('^3[dps-maritime] Event reward on cooldown for ' .. source .. ' (' .. eventName .. ')^0')
        end
        return
    end
    EventCooldowns[identifier][eventName] = now

    -- Recompute reward SERVER-SIDE (ignore any client-supplied amounts)
    local cash = 0
    if reward.cashMax and reward.cashMax > 0 then
        cash = math.random(reward.cashMin, reward.cashMax)
    end
    local xp = reward.xp or 0

    -- Grant cash via the Bridge (server-authoritative)
    if cash > 0 then
        Bridge.AddMoney(source, 'bank', cash, 'Maritime Event: ' .. eventName)
        Database.AddEarnings(identifier, cash)
    end

    -- Grant XP through the canonical internal XP path (handles level-up,
    -- persistence, state bags and the client updateXP event). This replaces the
    -- old calls to the nonexistent db.UpdateXP/db.UpdateLevel/db.UpdateEarnings.
    if xp > 0 then
        exports['dps-maritime']:AddMaritimeXP(source, xp)
    end

    -- Notify (correct Bridge.Notify signature: source, title, message, type, duration)
    local msg
    if cash > 0 then
        msg = string.format('%s: +%s +%d XP', eventName, Maritime.FormatMoney(cash), xp)
    else
        msg = string.format('%s: +%d XP', eventName, xp)
    end
    Bridge.Notify(source, 'Maritime Event', msg, 'success', 6000)

    if Config.Debug then
        print('^3[dps-maritime] ' .. source .. ' event reward "' .. eventName .. '": $' .. cash .. ' + ' .. xp .. ' XP^0')
    end
end

-----------------------------------------------------------
-- NET EVENTS (client-initiated, server-validated)
-- Client-supplied amounts are intentionally ignored - only the event name is
-- used, and the reward is recomputed above.
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:awardEventXP', function(_clientXp, eventName)
    GrantEventReward(source, eventName)
end)

RegisterNetEvent('dps-maritime:server:awardEventReward', function(_clientCash, _clientXp, eventName)
    GrantEventReward(source, eventName)
end)

-----------------------------------------------------------
-- COOLDOWN CLEANUP
-----------------------------------------------------------

CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes

        local now = GetGameTimer()
        for identifier, events in pairs(EventCooldowns) do
            local anyActive = false
            for eventName, lastTime in pairs(events) do
                if (now - lastTime) > REWARD_COOLDOWN * 2 then
                    events[eventName] = nil
                else
                    anyActive = true
                end
            end
            if not anyActive then
                EventCooldowns[identifier] = nil
            end
        end
    end
end)
