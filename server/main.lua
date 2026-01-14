--[[
    dps-maritime - Jetsam Company
    Main Server Script

    Uses Bridge for framework abstraction (QB/ESX)
]]

local Database = exports['dps-maritime']:GetDatabase()

-- Player cache
local PlayerData = {}

-----------------------------------------------------------
-- PLAYER DATA MANAGEMENT
-----------------------------------------------------------

local function GetPlayerIdentifier(source)
    return Bridge.GetIdentifier(source)
end

local function LoadPlayerData(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local data = Database.GetPlayerData(identifier)
    PlayerData[source] = data

    -- Sync to State Bags for real-time access
    if data then
        local player = Player(source)
        player.state:set('maritimeLevel', data.level, true)
        player.state:set('maritimeXP', data.xp, true)
        player.state:set('maritimeTitle', Config.GetLevelData(data.level).title, true)
        player.state:set('maritimeOnDuty', false, true)
    end

    return data
end

-- Update State Bags when data changes
local function SyncPlayerStateBags(source)
    local data = PlayerData[source]
    if not data then return end

    local player = Player(source)
    player.state:set('maritimeLevel', data.level, true)
    player.state:set('maritimeXP', data.xp, true)
    player.state:set('maritimeTitle', Config.GetLevelData(data.level).title, true)
end

local function SavePlayerData(source)
    local data = PlayerData[source]
    if not data then return end

    Database.UpdatePlayerXP(data.identifier, data.xp, data.level)
end

-----------------------------------------------------------
-- XP & LEVELING
-----------------------------------------------------------

local function AddXP(source, amount)
    local data = PlayerData[source]
    if not data then return end

    -- Apply streak bonus
    local streakBonus = math.min(
        data.current_streak * Config.Progression.StreakBonus,
        Config.Progression.MaxStreakBonus
    )
    amount = math.floor(amount * (1 + streakBonus))

    data.xp = data.xp + amount
    local newLevel = Config.GetLevelFromXP(data.xp)

    if newLevel > data.level then
        data.level = newLevel
        local levelData = Config.GetLevelData(newLevel)

        TriggerClientEvent('dps-maritime:client:levelUp', source, {
            level = newLevel,
            title = levelData.title,
            tier = levelData.tier,
        })

        -- Check for new unlocks
        if newLevel == Config.Progression.BoatDeliveryMinLevel then
            Bridge.Notify(source, 'Jetsam Maritime', 'You\'ve unlocked boat deliveries!', 'success')
        end
    end

    SavePlayerData(source)
    SyncPlayerStateBags(source) -- Sync State Bags for real-time client access

    TriggerClientEvent('dps-maritime:client:updateXP', source, {
        xp = data.xp,
        level = data.level,
        xpGained = amount,
    })

    return amount
end

-----------------------------------------------------------
-- PLAYER EVENTS
-----------------------------------------------------------

Bridge.OnPlayerDropped(function(source)
    if PlayerData[source] then
        SavePlayerData(source)
        PlayerData[source] = nil
    end
end)

Bridge.OnPlayerLoaded(function(source)
    LoadPlayerData(source)
end)

-----------------------------------------------------------
-- CALLBACKS
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:getPlayerData', function(source)
    local data = PlayerData[source]
    if not data then
        data = LoadPlayerData(source)
    end
    return data
end)

lib.callback.register('dps-maritime:server:getPlayerLevel', function(source)
    local data = PlayerData[source]
    if not data then
        data = LoadPlayerData(source)
    end
    return data and data.level or 1
end)

lib.callback.register('dps-maritime:server:canDoDockWork', function(source)
    local data = PlayerData[source]
    if not data then
        data = LoadPlayerData(source)
    end
    return data and Config.CanDoDockWork(data.level)
end)

lib.callback.register('dps-maritime:server:canDoBoatDelivery', function(source)
    local data = PlayerData[source]
    if not data then
        data = LoadPlayerData(source)
    end
    return data and Config.CanDoBoatDelivery(data.level)
end)

lib.callback.register('dps-maritime:server:getAvailableCargo', function(source)
    local data = PlayerData[source]
    if not data then
        data = LoadPlayerData(source)
    end
    return Maritime.GetAvailableCargo(data and data.level or 1)
end)

lib.callback.register('dps-maritime:server:getAvailableBoats', function(source)
    local data = PlayerData[source]
    if not data then
        data = LoadPlayerData(source)
    end
    return Maritime.GetAvailableBoats(data and data.level or 1)
end)

-----------------------------------------------------------
-- QS-HOUSING INTEGRATION
-- Check if player owns required properties
-----------------------------------------------------------

-- Check if player owns a dock warehouse (for bulk hauling)
local function PlayerOwnsDockWarehouse(source)
    if not Config.Housing.Enabled then return true end
    if not Config.Housing.Warehouses.Enabled then return true end

    local resourceState = GetResourceState(Config.Housing.Resource)
    if resourceState ~= 'started' then return true end -- Skip check if resource not running

    local warehouses = Config.Housing.Warehouses.DockWarehouses
    if not warehouses or #warehouses == 0 then return true end -- No warehouses configured

    -- Query qs-housing for player's owned properties
    local playerHouses = exports[Config.Housing.Resource]:GetPlayerHouses(source)
    if not playerHouses then return false end

    for _, house in ipairs(playerHouses) do
        for _, warehouseId in ipairs(warehouses) do
            if house == warehouseId or house.id == warehouseId then
                return true
            end
        end
    end

    return false
end

-- Check if player owns an island safehouse (for contraband)
local function PlayerOwnsIslandSafehouse(source)
    if not Config.Housing.Enabled then return true end
    if not Config.Housing.IslandSafehouses.Enabled then return true end

    local resourceState = GetResourceState(Config.Housing.Resource)
    if resourceState ~= 'started' then return true end

    local safehouses = Config.Housing.IslandSafehouses.Properties
    if not safehouses or #safehouses == 0 then return true end

    local playerHouses = exports[Config.Housing.Resource]:GetPlayerHouses(source)
    if not playerHouses then return false end

    for _, house in ipairs(playerHouses) do
        for _, safehouseId in ipairs(safehouses) do
            if house == safehouseId or house.id == safehouseId then
                return true
            end
        end
    end

    return false
end

-- Callback to check property access
lib.callback.register('dps-maritime:server:canAccessBulkHauling', function(source)
    if not Config.Housing.Warehouses.RequiredForBulkHaul then return true end
    return PlayerOwnsDockWarehouse(source)
end)

lib.callback.register('dps-maritime:server:canAccessContraband', function(source)
    if not Config.Housing.IslandSafehouses.RequiredForContraband then return true end
    return PlayerOwnsIslandSafehouse(source)
end)

-----------------------------------------------------------
-- PAYMENT
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:payout', function(amount, jobType, details)
    local source = source
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return end

    -- Add money via Bridge
    local paymentMethod = Config.DockWork.PaymentMethod
    Bridge.AddMoney(source, paymentMethod, amount, 'maritime-delivery')

    -- Update stats
    Database.IncrementDelivery(identifier, jobType, amount)

    -- Log delivery
    if details then
        details.identifier = identifier
        details.payout = amount
        Database.LogDelivery(details)
    end

    -- Update streak
    local data = PlayerData[source]
    if data then
        data.current_streak = (data.current_streak or 0) + 1
        Database.UpdateStreak(identifier, data.current_streak)
    end

    Bridge.Notify(source, 'Jetsam Maritime', 'Payment received: ' .. Maritime.FormatMoney(amount), 'success')
end)

RegisterNetEvent('dps-maritime:server:addXP', function(amount)
    local source = source
    AddXP(source, amount)
end)

-----------------------------------------------------------
-- STREAK RESET
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:resetStreak', function()
    local source = source
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return end

    local data = PlayerData[source]
    if data then
        data.current_streak = 0
        Database.UpdateStreak(identifier, 0)
    end
end)

-----------------------------------------------------------
-- ADMIN COMMANDS
-----------------------------------------------------------

Bridge.RegisterCommand('setmaritimelevel', 'Set maritime level (Admin)', {
    { name = 'id', help = 'Player ID' },
    { name = 'level', help = 'Level (1-10)' },
}, true, function(source, args)
    local targetId = tonumber(args[1])
    local level = tonumber(args[2])

    if not targetId or not level then return end
    if level < 1 or level > 10 then
        Bridge.Notify(source, 'Error', 'Level must be between 1 and 10', 'error')
        return
    end

    local targetData = PlayerData[targetId]
    if not targetData then
        Bridge.Notify(source, 'Error', 'Player not found', 'error')
        return
    end

    local levelData = Config.GetLevelData(level)
    targetData.level = level
    targetData.xp = levelData.xp

    Database.UpdatePlayerXP(targetData.identifier, targetData.xp, level)

    TriggerClientEvent('dps-maritime:client:updateXP', targetId, {
        xp = targetData.xp,
        level = level,
    })

    Bridge.Notify(source, 'Success', 'Set player maritime level to ' .. level, 'success')
end, 'admin')

Bridge.RegisterCommand('maritimestats', 'View maritime stats', {}, false, function(source)
    local data = PlayerData[source]
    if not data then
        data = LoadPlayerData(source)
    end

    if not data then return end

    local levelData = Config.GetLevelData(data.level)

    Bridge.Notify(source, 'Maritime Stats', string.format(
        'Level %d (%s)\nXP: %d\nBoat Deliveries: %d\nDock Deliveries: %d\nTotal Earnings: %s',
        data.level,
        levelData.title,
        data.xp,
        data.boat_deliveries or 0,
        data.dock_deliveries or 0,
        Maritime.FormatMoney(data.total_earnings or 0)
    ), 'inform', 10000)
end)

-----------------------------------------------------------
-- INVENTORY CALLBACK (for Bridge.Inventory.HasItem on client)
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:hasItem', function(source, item, count)
    return Bridge.Inventory.HasItem(source, item, count or 1)
end)

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('GetPlayerMaritimeData', function(source)
    return PlayerData[source]
end)

exports('GetPlayerMaritimeLevel', function(source)
    local data = PlayerData[source]
    return data and data.level or 1
end)

exports('AddMaritimeXP', function(source, amount)
    return AddXP(source, amount)
end)

-- Set player duty status (syncs via State Bags)
exports('SetMaritimeOnDuty', function(source, onDuty, jobType)
    local player = Player(source)
    player.state:set('maritimeOnDuty', onDuty, true)
    player.state:set('maritimeJobType', jobType or nil, true)
end)

-----------------------------------------------------------
-- STATE BAGS
-- Client can access via LocalPlayer.state.maritimeLevel, etc.
-- Other clients can see via Player(serverId).state.maritimeLevel
--
-- Available state bags:
--   maritimeLevel  - Player's current maritime level (1-10)
--   maritimeXP     - Current XP
--   maritimeTitle  - Title for current level
--   maritimeOnDuty - Whether player is on a maritime job
--   maritimeJobType - Type of job ('dock' or 'boat')
-----------------------------------------------------------
