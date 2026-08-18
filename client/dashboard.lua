--[[
    dps-maritime - Jetsam Company
    NUI Dashboard Client Handler

    Opens a visual stats dashboard replacing the /maritimestats command
]]

local isDashboardOpen = false

-----------------------------------------------------------
-- OPEN DASHBOARD
-----------------------------------------------------------

local function OpenDashboard()
    if isDashboardOpen then return end

    -- Get player data via callback
    local playerData = lib.callback.await('dps-maritime:server:getPlayerData', false)

    if not playerData then
        lib.notify({
            title = 'Maritime',
            description = 'Failed to load maritime data',
            type = 'error',
        })
        return
    end

    -- Get level data for XP calculations
    local levelData = {}
    for lvl = 1, 10 do
        local data = Config.GetLevelData(lvl)
        levelData[lvl] = {
            xp = data.xp,
            payMultiplier = data.payMultiplier,
            title = data.title,
        }
    end

    isDashboardOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'openDashboard',
        playerData = {
            level = playerData.level or 1,
            xp = playerData.xp or 0,
            title = Config.GetLevelData(playerData.level or 1).title,
            boat_deliveries = playerData.boat_deliveries or 0,
            dock_deliveries = playerData.dock_deliveries or 0,
            total_earnings = playerData.total_earnings or 0,
            current_streak = playerData.current_streak or 0,
            levelData = levelData,
        }
    })
end

-----------------------------------------------------------
-- CLOSE DASHBOARD
-----------------------------------------------------------

local function CloseDashboard()
    if not isDashboardOpen then return end

    isDashboardOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'closeDashboard'
    })
end

-- NUI callback when user closes dashboard
RegisterNUICallback('closeDashboard', function(_, cb)
    CloseDashboard()
    cb('ok')
end)

-----------------------------------------------------------
-- COMMANDS
-----------------------------------------------------------

-- Replace text-based /maritimestats with visual dashboard
RegisterCommand('maritimestats', function()
    OpenDashboard()
end, false)

-- Alternative commands
RegisterCommand('maritimedash', function()
    OpenDashboard()
end, false)

RegisterCommand('mstats', function()
    OpenDashboard()
end, false)

-----------------------------------------------------------
-- KEYBIND (Optional)
-----------------------------------------------------------

-- Register a keybind to open dashboard (default: unbound)
RegisterKeyMapping('maritimestats', 'Open Maritime Dashboard', 'keyboard', '')

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('OpenDashboard', OpenDashboard)
exports('CloseDashboard', CloseDashboard)
exports('IsDashboardOpen', function()
    return isDashboardOpen
end)

-----------------------------------------------------------
-- UPDATE DASHBOARD (if open)
-----------------------------------------------------------

-- Listen for XP updates to refresh dashboard if open
RegisterNetEvent('dps-maritime:client:updateXP', function(data)
    if isDashboardOpen then
        -- Refresh the dashboard with new data
        local playerData = lib.callback.await('dps-maritime:server:getPlayerData', false)
        if playerData then
            local levelData = {}
            for lvl = 1, 10 do
                local lvlData = Config.GetLevelData(lvl)
                levelData[lvl] = {
                    xp = lvlData.xp,
                    payMultiplier = lvlData.payMultiplier,
                    title = lvlData.title,
                }
            end

            SendNUIMessage({
                action = 'updateData',
                playerData = {
                    level = playerData.level or 1,
                    xp = playerData.xp or 0,
                    title = Config.GetLevelData(playerData.level or 1).title,
                    boat_deliveries = playerData.boat_deliveries or 0,
                    dock_deliveries = playerData.dock_deliveries or 0,
                    total_earnings = playerData.total_earnings or 0,
                    current_streak = playerData.current_streak or 0,
                    levelData = levelData,
                }
            })
        end
    end
end)
