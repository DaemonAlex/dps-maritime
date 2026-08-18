--[[
    dps-maritime - Framework Bridge
    Abstracts QBCore/ESX framework calls for clean, portable code

    Usage:
        Bridge.GetPlayerData()        -- Client: Get player data
        Bridge.GetPlayer(source)      -- Server: Get player object
        Bridge.AddMoney(source, type, amount, reason)
        Bridge.Notify(source, title, message, type)
        Bridge.RegisterCommand(name, help, args, argsRequired, callback, permission)
]]

Bridge = {}

-- Determine framework from config
local Framework = Config.Framework or 'qb'
local FrameworkObject = nil

-----------------------------------------------------------
-- FRAMEWORK INITIALIZATION
-----------------------------------------------------------

local function InitFramework()
    if FrameworkObject then return FrameworkObject end

    if Framework == 'qbx' then
        -- Qbox: this build exposes NO GetCoreObject (both qb-core and qbx_core
        -- variants THROW). All qbx code paths use discrete exports
        -- (exports.qbx_core:GetPlayer / :GetPlayerData / ...), so there is no
        -- core object to cache. Return a truthy sentinel purely so the
        -- `if not Core then return` guards in the generic functions pass.
        FrameworkObject = { qbx = true }
    elseif Framework == 'qb' then
        FrameworkObject = exports['qb-core']:GetCoreObject()
    elseif Framework == 'esx' then
        if GetResourceState('es_extended') == 'started' then
            FrameworkObject = exports['es_extended']:getSharedObject()
        end
    end

    return FrameworkObject
end

-- Initialize on load
CreateThread(function()
    InitFramework()
end)

-----------------------------------------------------------
-- SHARED FUNCTIONS (Client & Server)
-----------------------------------------------------------

function Bridge.GetFramework()
    return Framework
end

function Bridge.GetCore()
    return InitFramework()
end

function Bridge.IsQB()
    return Framework == 'qb'
end

function Bridge.IsQBX()
    return Framework == 'qbx'
end

-- True for any QBCore-family framework (qb or qbx). qbx keeps qb-style player
-- object methods (Player.Functions.AddMoney, Player.PlayerData.*), so most
-- discrete logic is shared between the two.
local function IsQBFamily()
    return Framework == 'qb' or Framework == 'qbx'
end

function Bridge.IsESX()
    return Framework == 'esx'
end

-----------------------------------------------------------
-- NOTIFICATION ABSTRACTION
-----------------------------------------------------------

function Bridge.Notify(source, title, message, notifyType, duration)
    duration = duration or 5000
    notifyType = notifyType or 'info'

    -- Use ox_lib if available (preferred)
    if Config.Notifications == 'ox_lib' then
        if IsDuplicityVersion() then
            -- Server side
            TriggerClientEvent('ox_lib:notify', source, {
                title = title,
                description = message,
                type = notifyType,
                duration = duration,
            })
        else
            -- Client side
            lib.notify({
                title = title,
                description = message,
                type = notifyType,
                duration = duration,
            })
        end
        return
    end

    -- Framework-specific fallback
    if IsDuplicityVersion() then
        -- Server side
        if Framework == 'qb' then
            TriggerClientEvent('QBCore:Notify', source, message, notifyType, duration)
        elseif Framework == 'esx' then
            TriggerClientEvent('esx:showNotification', source, message)
        end
    else
        -- Client side
        if Framework == 'qb' then
            local QBCore = InitFramework()
            if QBCore then
                QBCore.Functions.Notify(message, notifyType, duration)
            end
        elseif Framework == 'esx' then
            local ESX = InitFramework()
            if ESX then
                ESX.ShowNotification(message)
            end
        end
    end
end

-----------------------------------------------------------
-- CLIENT-SIDE FUNCTIONS
-----------------------------------------------------------

if not IsDuplicityVersion() then

    -- Get player data
    function Bridge.GetPlayerData()
        if Framework == 'qbx' then
            -- Qbox client: discrete export, qb-style PlayerData shape
            return exports.qbx_core:GetPlayerData()
        end

        local Core = InitFramework()
        if not Core then return nil end

        if Framework == 'qb' then
            return Core.Functions.GetPlayerData()
        elseif Framework == 'esx' then
            return Core.GetPlayerData()
        end

        return nil
    end

    -- Get player identifier (citizenid for QB, identifier for ESX)
    function Bridge.GetIdentifier()
        local playerData = Bridge.GetPlayerData()
        if not playerData then return nil end

        if IsQBFamily() then
            return playerData.citizenid
        elseif Framework == 'esx' then
            return playerData.identifier
        end

        return nil
    end

    -- Get player job
    function Bridge.GetJob()
        local playerData = Bridge.GetPlayerData()
        if not playerData then return nil end

        if IsQBFamily() then
            return playerData.job
        elseif Framework == 'esx' then
            return playerData.job
        end

        return nil
    end

    -- Check if player has job
    function Bridge.HasJob(jobName)
        local job = Bridge.GetJob()
        if not job then return false end

        return job.name == jobName
    end

    -- Get player money (client-side, may not be accurate)
    function Bridge.GetMoney(moneyType)
        local playerData = Bridge.GetPlayerData()
        if not playerData then return 0 end

        moneyType = moneyType or 'cash'

        if IsQBFamily() then
            return playerData.money and playerData.money[moneyType] or 0
        elseif Framework == 'esx' then
            if moneyType == 'cash' then
                return playerData.money or 0
            elseif moneyType == 'bank' then
                for _, account in ipairs(playerData.accounts or {}) do
                    if account.name == 'bank' then
                        return account.money or 0
                    end
                end
            end
        end

        return 0
    end

    -- Check if player is loaded
    function Bridge.IsPlayerLoaded()
        local playerData = Bridge.GetPlayerData()
        if not playerData then return false end

        if IsQBFamily() then
            return playerData.citizenid ~= nil
        elseif Framework == 'esx' then
            return playerData.identifier ~= nil
        end

        return false
    end

    -- Get player name
    function Bridge.GetPlayerName()
        local playerData = Bridge.GetPlayerData()
        if not playerData then return 'Unknown' end

        if IsQBFamily() then
            local charinfo = playerData.charinfo
            if charinfo then
                return (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
            end
        elseif Framework == 'esx' then
            return playerData.name or GetPlayerName(PlayerId())
        end

        return GetPlayerName(PlayerId())
    end

    -- Framework events - Register standardized event listeners
    function Bridge.OnPlayerLoaded(callback)
        if IsQBFamily() then
            -- qbx keeps the QBCore-compat client events
            RegisterNetEvent('QBCore:Client:OnPlayerLoaded', callback)
        elseif Framework == 'esx' then
            RegisterNetEvent('esx:playerLoaded', function(xPlayer)
                callback()
            end)
        end
    end

    function Bridge.OnPlayerUnload(callback)
        if IsQBFamily() then
            RegisterNetEvent('QBCore:Client:OnPlayerUnload', callback)
        elseif Framework == 'esx' then
            RegisterNetEvent('esx:onPlayerLogout', callback)
        end
    end

    function Bridge.OnJobUpdate(callback)
        if IsQBFamily() then
            RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
                callback(job)
            end)
        elseif Framework == 'esx' then
            RegisterNetEvent('esx:setJob', function(job)
                callback(job)
            end)
        end
    end
end

-----------------------------------------------------------
-- SERVER-SIDE FUNCTIONS
-----------------------------------------------------------

if IsDuplicityVersion() then

    -- Get player object
    function Bridge.GetPlayer(source)
        if Framework == 'qbx' then
            -- Qbox: discrete export. Player object keeps qb-style methods:
            -- Player.Functions.AddMoney/RemoveMoney, Player.PlayerData.*
            return exports.qbx_core:GetPlayer(source)
        end

        local Core = InitFramework()
        if not Core then return nil end

        if Framework == 'qb' then
            return Core.Functions.GetPlayer(source)
        elseif Framework == 'esx' then
            return Core.GetPlayerFromId(source)
        end

        return nil
    end

    -- Get player identifier
    function Bridge.GetIdentifier(source)
        local player = Bridge.GetPlayer(source)
        if not player then return nil end

        if IsQBFamily() then
            return player.PlayerData.citizenid
        elseif Framework == 'esx' then
            return player.identifier
        end

        return nil
    end

    -- Get player job
    function Bridge.GetJob(source)
        local player = Bridge.GetPlayer(source)
        if not player then return nil end

        if IsQBFamily() then
            return player.PlayerData.job
        elseif Framework == 'esx' then
            return player.job
        end

        return nil
    end

    -- Check if player has job
    function Bridge.HasJob(source, jobName)
        local job = Bridge.GetJob(source)
        if not job then return false end
        return job.name == jobName
    end

    -- Get player money
    function Bridge.GetMoney(source, moneyType)
        local player = Bridge.GetPlayer(source)
        if not player then return 0 end

        moneyType = moneyType or 'cash'

        if IsQBFamily() then
            return player.PlayerData.money and player.PlayerData.money[moneyType] or 0
        elseif Framework == 'esx' then
            if moneyType == 'cash' then
                return player.getMoney()
            elseif moneyType == 'bank' then
                return player.getAccount('bank').money
            end
        end

        return 0
    end

    -- Add money to player
    function Bridge.AddMoney(source, moneyType, amount, reason)
        local player = Bridge.GetPlayer(source)
        if not player then return false end

        moneyType = moneyType or 'cash'
        reason = reason or 'dps-maritime'

        if IsQBFamily() then
            return player.Functions.AddMoney(moneyType, amount, reason)
        elseif Framework == 'esx' then
            if moneyType == 'cash' then
                player.addMoney(amount)
            elseif moneyType == 'bank' then
                player.addAccountMoney('bank', amount)
            end
            return true
        end

        return false
    end

    -- Remove money from player
    function Bridge.RemoveMoney(source, moneyType, amount, reason)
        local player = Bridge.GetPlayer(source)
        if not player then return false end

        moneyType = moneyType or 'cash'
        reason = reason or 'dps-maritime'

        if IsQBFamily() then
            return player.Functions.RemoveMoney(moneyType, amount, reason)
        elseif Framework == 'esx' then
            if moneyType == 'cash' then
                player.removeMoney(amount)
            elseif moneyType == 'bank' then
                player.removeAccountMoney('bank', amount)
            end
            return true
        end

        return false
    end

    -- Get player name
    function Bridge.GetPlayerName(source)
        local player = Bridge.GetPlayer(source)
        if not player then return GetPlayerName(source) end

        if IsQBFamily() then
            local charinfo = player.PlayerData.charinfo
            if charinfo then
                return (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
            end
        elseif Framework == 'esx' then
            return player.getName()
        end

        return GetPlayerName(source)
    end

    -- Register command with permission check
    function Bridge.RegisterCommand(name, helpText, args, argsRequired, callback, permission)
        if Framework == 'qbx' then
            -- Qbox has no GetCoreObject/Commands.Add. Use native RegisterCommand
            -- (callback receives a POSITIONAL args array, matching the args[1]/
            -- args[2] contract the qb Commands.Add callbacks rely on) with a
            -- manual ace permission gate for admin/god commands.
            RegisterCommand(name, function(source, cmdArgs)
                if permission == 'admin' or permission == 'god' then
                    local allowed = IsPlayerAceAllowed(source, 'group.admin')
                        or IsPlayerAceAllowed(source, 'command')
                    if not allowed then
                        Bridge.Notify(source, 'No Permission', 'You do not have permission to use this command', 'error')
                        return
                    end
                end
                callback(source, cmdArgs)
            end, false)
        elseif Framework == 'qb' then
            local Core = InitFramework()
            if Core then
                Core.Commands.Add(name, helpText, args, argsRequired, callback, permission)
            end
        elseif Framework == 'esx' then
            -- ESX uses RegisterCommand with permission checks
            RegisterCommand(name, function(source, rawArgs)
                -- Check permission
                if permission then
                    local xPlayer = Bridge.GetPlayer(source)
                    if not xPlayer then return end

                    local group = xPlayer.getGroup()
                    if permission == 'admin' and group ~= 'admin' and group ~= 'superadmin' then
                        return
                    end
                    if permission == 'god' and group ~= 'superadmin' then
                        return
                    end
                end

                callback(source, rawArgs)
            end, false)
        end
    end

    -- Check if player has permission
    function Bridge.HasPermission(source, permission)
        if Framework == 'qbx' then
            -- Qbox: ace-based permissions (no GetCoreObject). Admin groups are
            -- granted group.admin / group.god principals by qbx.
            if permission == 'admin' then
                return IsPlayerAceAllowed(source, 'group.admin')
                    or IsPlayerAceAllowed(source, 'group.god')
                    or IsPlayerAceAllowed(source, 'command')
            elseif permission == 'god' then
                return IsPlayerAceAllowed(source, 'group.god')
                    or IsPlayerAceAllowed(source, 'command')
            end
            return IsPlayerAceAllowed(source, 'command')
        elseif Framework == 'qb' then
            local Core = InitFramework()
            if Core and Core.Functions.HasPermission then
                return Core.Functions.HasPermission(source, permission)
            end
            -- Fallback: check player object
            local player = Bridge.GetPlayer(source)
            if player then
                local group = player.PlayerData.group or 'user'
                if permission == 'admin' then
                    return group == 'admin' or group == 'god' or group == 'superadmin'
                elseif permission == 'god' then
                    return group == 'god' or group == 'superadmin'
                end
            end
        elseif Framework == 'esx' then
            local player = Bridge.GetPlayer(source)
            if player then
                local group = player.getGroup()
                if permission == 'admin' then
                    return group == 'admin' or group == 'superadmin'
                elseif permission == 'god' then
                    return group == 'superadmin'
                end
            end
        end
        return false
    end

    -- Framework events - Server side
    function Bridge.OnPlayerLoaded(callback)
        if Framework == 'qbx' then
            -- qbx fires QBCore:Server:OnPlayerLoaded with the Player object;
            -- derive the source from it (the magic `source` global is not
            -- reliably set for locally-fired events).
            AddEventHandler('QBCore:Server:OnPlayerLoaded', function(player)
                local src = (player and player.PlayerData and player.PlayerData.source) or source
                callback(src)
            end)
        elseif Framework == 'qb' then
            AddEventHandler('QBCore:Server:OnPlayerLoaded', function()
                callback(source)
            end)
        elseif Framework == 'esx' then
            RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
                callback(playerId)
            end)
        end
    end

    function Bridge.OnPlayerDropped(callback)
        AddEventHandler('playerDropped', function(reason)
            callback(source, reason)
        end)
    end
end

-----------------------------------------------------------
-- INVENTORY BRIDGE
-----------------------------------------------------------

Bridge.Inventory = {}

function Bridge.Inventory.GetScript()
    return Config.Inventory or 'qs-inventory'
end

if IsDuplicityVersion() then
    -- Server-side inventory functions

    function Bridge.Inventory.AddItem(source, item, count, metadata)
        local inventory = Bridge.Inventory.GetScript()
        count = count or 1

        if inventory == 'ox_inventory' then
            return exports.ox_inventory:AddItem(source, item, count, metadata)
        elseif inventory == 'qb-inventory' then
            return exports['qb-inventory']:AddItem(source, item, count, false, metadata, 'dps-maritime')
        elseif inventory == 'qs-inventory' then
            return exports['qs-inventory']:AddItem(source, item, count, false, metadata, 'dps-maritime')
        end

        return false
    end

    function Bridge.Inventory.RemoveItem(source, item, count, metadata, slot)
        local inventory = Bridge.Inventory.GetScript()
        count = count or 1

        if inventory == 'ox_inventory' then
            -- ox signature: RemoveItem(inv, item, count, metadata, slot)
            return exports.ox_inventory:RemoveItem(source, item, count, metadata, slot)
        elseif inventory == 'qb-inventory' then
            return exports['qb-inventory']:RemoveItem(source, item, count, slot, 'dps-maritime')
        elseif inventory == 'qs-inventory' then
            return exports['qs-inventory']:RemoveItem(source, item, count, slot, 'dps-maritime')
        end

        return false
    end

    -- Return an array of slot entries { slot, count, metadata } for an item.
    -- Needed when metadata (e.g. cargo manifest fields) and the exact slot matter.
    function Bridge.Inventory.GetItemSlots(source, item)
        local inventory = Bridge.Inventory.GetScript()

        if inventory == 'ox_inventory' then
            return exports.ox_inventory:Search(source, 'slots', item) or {}
        elseif inventory == 'qb-inventory' then
            local data = exports['qb-inventory']:GetItemByName(source, item)
            return data and { { slot = data.slot, count = data.amount, metadata = data.info } } or {}
        elseif inventory == 'qs-inventory' then
            local data = exports['qs-inventory']:GetItemByName(source, item)
            return data and { { slot = data.slot, count = data.amount, metadata = data.info } } or {}
        end

        return {}
    end

    function Bridge.Inventory.HasItem(source, item, count)
        local inventory = Bridge.Inventory.GetScript()
        count = count or 1

        if inventory == 'ox_inventory' then
            local itemData = exports.ox_inventory:GetItem(source, item, false)
            return itemData and itemData.count >= count
        elseif inventory == 'qb-inventory' then
            local itemData = exports['qb-inventory']:GetItemByName(source, item)
            return itemData and itemData.amount >= count
        elseif inventory == 'qs-inventory' then
            local itemData = exports['qs-inventory']:GetItemByName(source, item)
            return itemData and itemData.amount >= count
        end

        return false
    end

    function Bridge.Inventory.GetItem(source, item)
        local inventory = Bridge.Inventory.GetScript()

        if inventory == 'ox_inventory' then
            return exports.ox_inventory:GetItem(source, item, false)
        elseif inventory == 'qb-inventory' then
            return exports['qb-inventory']:GetItemByName(source, item)
        elseif inventory == 'qs-inventory' then
            return exports['qs-inventory']:GetItemByName(source, item)
        end

        return nil
    end
else
    -- Client-side inventory functions

    function Bridge.Inventory.HasItem(item, count)
        local inventory = Bridge.Inventory.GetScript()
        count = count or 1

        if inventory == 'ox_inventory' then
            local itemCount = exports.ox_inventory:Search('count', item)
            return itemCount >= count
        elseif inventory == 'qb-inventory' or inventory == 'qs-inventory' then
            -- QB/QS inventory requires server callback
            return lib.callback.await('dps-maritime:server:hasItem', false, item, count)
        end

        return false
    end
end

-----------------------------------------------------------
-- TARGET SYSTEM BRIDGE
-----------------------------------------------------------

Bridge.Target = {}

function Bridge.Target.GetScript()
    return Config.Target or 'ox_target'
end

if not IsDuplicityVersion() then

    function Bridge.Target.AddLocalEntity(entity, options)
        local target = Bridge.Target.GetScript()

        if target == 'ox_target' then
            exports.ox_target:addLocalEntity(entity, options)
        elseif target == 'qb-target' then
            exports['qb-target']:AddTargetEntity(entity, {
                options = options,
                distance = 2.5,
            })
        elseif target == 'qtarget' then
            exports.qtarget:AddTargetEntity(entity, {
                options = options,
                distance = 2.5,
            })
        end
    end

    function Bridge.Target.RemoveLocalEntity(entity, optionNames)
        local target = Bridge.Target.GetScript()

        if target == 'ox_target' then
            exports.ox_target:removeLocalEntity(entity, optionNames)
        elseif target == 'qb-target' then
            exports['qb-target']:RemoveTargetEntity(entity, optionNames)
        elseif target == 'qtarget' then
            exports.qtarget:RemoveTargetEntity(entity, optionNames)
        end
    end

    function Bridge.Target.AddSphereZone(params)
        local target = Bridge.Target.GetScript()

        if target == 'ox_target' then
            return exports.ox_target:addSphereZone(params)
        elseif target == 'qb-target' then
            exports['qb-target']:AddCircleZone(params.name or 'maritime_zone', params.coords, params.radius or 2.0, {
                name = params.name,
                debugPoly = false,
            }, {
                options = params.options,
                distance = params.radius or 2.0,
            })
            return params.name
        end

        return nil
    end

    function Bridge.Target.RemoveZone(zoneId)
        local target = Bridge.Target.GetScript()

        if target == 'ox_target' then
            exports.ox_target:removeZone(zoneId)
        elseif target == 'qb-target' then
            exports['qb-target']:RemoveZone(zoneId)
        end
    end
end

Maritime.Debug('Bridge loaded for framework: ' .. Framework)
