--[[
    dps-maritime - Jetsam Company
    Fleet Management Server Logic
    Uses Bridge for framework abstraction
]]

local Database = exports['dps-maritime']:GetDatabase()

-----------------------------------------------------------
-- FLEET CALLBACKS
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:getFleet', function(source)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return {} end
    local level = exports['dps-maritime']:GetPlayerMaritimeLevel(source)

    if not Config.CanOwnFleet(level) then
        return { error = 'You need to be level ' .. Config.Progression.FleetOwnershipMinLevel .. ' to own boats' }
    end

    local fleet = Database.GetPlayerFleet(identifier)
    return { boats = fleet or {} }
end)

lib.callback.register('dps-maritime:server:getBoatDetails', function(source, boatId)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local boat = Database.GetBoatById(boatId)

    if not boat or boat.owner ~= identifier then
        return { error = 'Boat not found' }
    end

    local boatConfig = Config.Boats[boat.model]
    return {
        boat = boat,
        config = boatConfig,
    }
end)

-----------------------------------------------------------
-- PURCHASE BOAT
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:purchaseBoat', function(source, boatModel, boatName)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local level = exports['dps-maritime']:GetPlayerMaritimeLevel(source)

    -- Check fleet ownership level
    if not Config.CanOwnFleet(level) then
        return { error = 'You need to be level ' .. Config.Progression.FleetOwnershipMinLevel .. ' to own boats' }
    end

    -- Check boat exists and level requirement
    local boat = Config.Boats[boatModel]
    if not boat then
        return { error = 'Invalid boat model' }
    end

    if level < boat.levelRequired then
        return { error = 'You need to be level ' .. boat.levelRequired .. ' to purchase this boat' }
    end

    -- Check fleet size limit
    local currentFleet = Database.GetPlayerFleet(identifier) or {}
    if #currentFleet >= Config.Fleet.MaxBoatsPerPlayer then
        return { error = 'You have reached the maximum fleet size (' .. Config.Fleet.MaxBoatsPerPlayer .. ' boats)' }
    end

    -- Check funds (H2: Player was an undefined global)
    local Player = Bridge.GetPlayer(source)
    if not Player then return { error = 'Player not found' } end

    local bank = Bridge.GetMoney(source, 'bank')
    if bank < boat.price then
        return { error = 'You need ' .. Maritime.FormatMoney(boat.price) .. ' in your bank account' }
    end

    -- Purchase
    Bridge.RemoveMoney(source, 'bank', boat.price, 'boat-purchase-' .. boatModel)

    local boatId = Database.AddBoatToFleet(identifier, boatModel, boatName or boat.label)

    if boatId then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Jetsam Maritime',
            description = 'Purchased ' .. boat.label .. ' for ' .. Maritime.FormatMoney(boat.price),
            type = 'success',
        })

        return { success = true, boatId = boatId }
    end

    return { error = 'Failed to purchase boat' }
end)

-----------------------------------------------------------
-- SELL BOAT
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:sellBoat', function(source, boatId)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local boat = Database.GetBoatById(boatId)

    if not boat or boat.owner ~= identifier then
        return { error = 'Boat not found' }
    end

    local boatConfig = Config.Boats[boat.model]
    if not boatConfig then
        return { error = 'Invalid boat configuration' }
    end

    -- Calculate sell price
    local basePrice = boatConfig.price * Config.Fleet.SellBackPercent
    local sellPrice = basePrice

    -- Condition affects price
    if Config.Fleet.ConditionAffectsSellPrice then
        sellPrice = math.floor(basePrice * (boat.condition / 100))
    end

    -- Remove boat and pay player (H2: Player was an undefined global)
    local Player = Bridge.GetPlayer(source)
    if not Player then return { error = 'Player not found' } end

    Database.RemoveBoatFromFleet(boatId, identifier)
    Bridge.AddMoney(source, 'bank', sellPrice, 'boat-sale-' .. boat.model)

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Jetsam Maritime',
        description = 'Sold ' .. boatConfig.label .. ' for ' .. Maritime.FormatMoney(sellPrice),
        type = 'success',
    })

    return { success = true, sellPrice = sellPrice }
end)

-- NOTE (M5): the original standalone `spawnOwnedBoat` callback that lived here
-- was DEAD CODE - it was overridden by the garage-aware registration of the
-- same event name further down ("SPAWN CALLBACK WITH GARAGE SYNC"). It has been
-- removed so only the garage-aware version (which enforces double-spawn
-- prevention) is active.

-----------------------------------------------------------
-- STORE BOAT
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:storeBoat', function(boatId, fuel, condition)
    local source = source
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end

    local boat = Database.GetBoatById(boatId)

    if not boat or boat.owner ~= identifier then return end

    Database.UpdateBoatCondition(boatId, condition, fuel)

    Bridge.Notify(source, 'Success', 'Boat stored successfully', 'success')
end)

-----------------------------------------------------------
-- REPAIR BOAT
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:repairBoat', function(source, boatId)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local boat = Database.GetBoatById(boatId)

    if not boat or boat.owner ~= identifier then
        return { error = 'Boat not found' }
    end

    local boatConfig = Config.Boats[boat.model]
    if not boatConfig then
        return { error = 'Invalid boat configuration' }
    end

    -- Calculate repair cost
    local damagePercent = 100 - boat.condition
    local repairCost = math.floor(boatConfig.price * Config.Fleet.RepairCostPercent * (damagePercent / 100))

    if repairCost <= 0 then
        return { error = 'Boat doesn\'t need repairs' }
    end

    -- H2: Player was an undefined global
    local Player = Bridge.GetPlayer(source)
    if not Player then return { error = 'Player not found' } end

    local bank = Bridge.GetMoney(source, 'bank')
    if bank < repairCost then
        return { error = 'You need ' .. Maritime.FormatMoney(repairCost) .. ' to repair this boat' }
    end

    Bridge.RemoveMoney(source, 'bank', repairCost, 'boat-repair')
    Database.UpdateBoatCondition(boatId, 100, boat.fuel)

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Jetsam Maritime',
        description = 'Boat repaired for ' .. Maritime.FormatMoney(repairCost),
        type = 'success',
    })

    return { success = true, repairCost = repairCost }
end)

-----------------------------------------------------------
-- INSURANCE CLAIM
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:insuranceClaim', function(source, boatId)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local boat = Database.GetBoatById(boatId)

    if not boat or boat.owner ~= identifier then
        return { error = 'Boat not found' }
    end

    local boatConfig = Config.Boats[boat.model]
    if not boatConfig then
        return { error = 'Invalid boat configuration' }
    end

    -- Insurance payout
    local payout = math.floor(boatConfig.price * Config.Fleet.InsurancePayoutPercent)

    -- Remove boat and pay insurance (H2: Player was an undefined global)
    local Player = Bridge.GetPlayer(source)
    if not Player then return { error = 'Player not found' } end

    Database.RemoveBoatFromFleet(boatId, identifier)
    Bridge.AddMoney(source, 'bank', payout, 'boat-insurance')

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Jetsam Maritime',
        description = 'Insurance claim processed. Received ' .. Maritime.FormatMoney(payout),
        type = 'success',
    })

    return { success = true, payout = payout }
end)

-----------------------------------------------------------
-- STARTER BOAT
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:claimStarterBoat', function(source)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local level = exports['dps-maritime']:GetPlayerMaritimeLevel(source)

    if not Config.CanOwnFleet(level) then
        return { error = 'You need to be level ' .. Config.Progression.FleetOwnershipMinLevel .. ' to own boats' }
    end

    -- Check if already has boats
    local currentFleet = Database.GetPlayerFleet(identifier) or {}
    if #currentFleet > 0 then
        return { error = 'You already own boats' }
    end

    if not Config.Fleet.StarterBoatFree then
        return { error = 'Starter boat is not available' }
    end

    local starterModel = Config.Fleet.StarterBoat
    local boat = Config.Boats[starterModel]

    if not boat then
        return { error = 'Starter boat configuration error' }
    end

    local boatId = Database.AddBoatToFleet(identifier, starterModel, 'My First Boat')

    if boatId then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Jetsam Maritime',
            description = 'You received your starter boat: ' .. boat.label,
            type = 'success',
        })

        return { success = true, boatId = boatId, model = starterModel }
    end

    return { error = 'Failed to claim starter boat' }
end)

-----------------------------------------------------------
-- RENAME BOAT
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:renameBoat', function(source, boatId, newName)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local boat = Database.GetBoatById(boatId)

    if not boat or boat.owner ~= identifier then
        return { error = 'Boat not found' }
    end

    if not newName or newName == '' or #newName > 30 then
        return { error = 'Invalid boat name' }
    end

    MySQL.update.await([[
        UPDATE maritime_fleet SET name = ? WHERE id = ?
    ]], { newName, boatId })

    return { success = true }
end)

-----------------------------------------------------------
-- JG-ADVANCEDGARAGES BRIDGE
-- Prevents double-spawning by syncing with garage system
-- Uses exports to properly "lock" boats during deliveries
-----------------------------------------------------------

local GarageBridge = {}

-- Track active boat spawns for cleanup
local ActiveBoatSpawns = {} -- [source] = { boatId, plate }

-- Detect which garage script is running
function GarageBridge.DetectGarageScript()
    local scripts = {
        'jg-advancedgarages',
        'qs-advancedgarages',
        'qb-garages',
        'cd_garage',
    }

    for _, script in ipairs(scripts) do
        if GetResourceState(script) == 'started' then
            return script
        end
    end

    return nil
end

-- Check if garage bridge is enabled
function GarageBridge.IsEnabled()
    if not Config.GarageBridge or not Config.GarageBridge.Enabled then
        return false
    end
    return GarageBridge.DetectGarageScript() ~= nil
end

-- Get vehicle state from garage system
---@param plate string The vehicle plate
---@return string state 'stored', 'out', 'impound', or 'unknown'
function GarageBridge.GetVehicleState(plate)
    local script = GarageBridge.DetectGarageScript()
    if not script then return 'unknown' end

    if script == 'jg-advancedgarages' then
        local state = exports['jg-advancedgarages']:getVehicleState(plate)
        if state == 1 then return 'stored'
        elseif state == 0 then return 'out'
        elseif state == 2 then return 'impound'
        end
        return 'unknown'

    elseif script == 'qs-advancedgarages' then
        local status = exports['qs-advancedgarages']:GetVehicleStatus(plate)
        if status == 1 then return 'stored'
        elseif status == 0 then return 'out'
        elseif status == 2 then return 'impound'
        end
        return 'unknown'

    elseif script == 'qb-garages' then
        local result = MySQL.scalar.await(
            'SELECT state FROM player_vehicles WHERE plate = ?',
            { plate }
        )
        if result == 1 then return 'stored'
        elseif result == 0 then return 'out'
        elseif result == 2 then return 'impound'
        end
        return 'unknown'
    end

    return 'unknown'
end

-- Mark vehicle as OUT in garage system (prevents spawning elsewhere)
---@param plate string The vehicle plate
---@return boolean success
function GarageBridge.SetVehicleOut(plate)
    if not plate then return false end

    local script = GarageBridge.DetectGarageScript()
    if not script then return true end -- No garage script = always allow

    Maritime.Debug('GarageBridge: Setting vehicle OUT - ' .. plate)

    if script == 'jg-advancedgarages' then
        exports['jg-advancedgarages']:setVehicleState(plate, 0, nil)
        return true

    elseif script == 'qs-advancedgarages' then
        exports['qs-advancedgarages']:SetVehicleStatus(plate, 0)
        return true

    elseif script == 'qb-garages' then
        MySQL.update.await('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { plate })
        return true

    elseif script == 'cd_garage' then
        exports['cd_garage']:SetVehicleState(plate, 'out')
        return true
    end

    return false
end

-- Mark vehicle as STORED in garage system (allows spawning from garage)
---@param plate string The vehicle plate
---@param garageId string|nil Optional garage ID
---@return boolean success
function GarageBridge.SetVehicleStored(plate, garageId)
    if not plate then return false end

    local script = GarageBridge.DetectGarageScript()
    if not script then return true end

    garageId = garageId or 'boathouse'

    Maritime.Debug('GarageBridge: Setting vehicle STORED - ' .. plate)

    if script == 'jg-advancedgarages' then
        exports['jg-advancedgarages']:setVehicleState(plate, 1, garageId)
        return true

    elseif script == 'qs-advancedgarages' then
        exports['qs-advancedgarages']:SetVehicleStatus(plate, 1)
        return true

    elseif script == 'qb-garages' then
        MySQL.update.await('UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?', { garageId, plate })
        return true

    elseif script == 'cd_garage' then
        exports['cd_garage']:SetVehicleState(plate, 'stored')
        return true
    end

    return false
end

-- Check if vehicle is already out (spawned elsewhere)
---@param plate string The vehicle plate
---@return boolean isOut
function GarageBridge.IsVehicleOut(plate)
    return GarageBridge.GetVehicleState(plate) == 'out'
end

-- Get vehicle plate from maritime fleet by boat ID
---@param boatId number The maritime fleet boat ID
---@return string|nil plate The vehicle plate or nil
function GarageBridge.GetBoatPlate(boatId)
    local plate = MySQL.scalar.await([[
        SELECT plate FROM maritime_fleet WHERE id = ?
    ]], { boatId })
    return plate
end

-- Check if boat can be spawned (not already out)
---@param source number Player server ID
---@param boatId number Maritime fleet boat ID
---@return boolean canSpawn Whether the boat can be spawned
---@return string|nil error Error message if cannot spawn
function GarageBridge.CanSpawnBoat(source, boatId)
    if not GarageBridge.IsEnabled() then return true, nil end
    if not Config.GarageBridge.PreventDoubleSpawn then return true, nil end

    local plate = GarageBridge.GetBoatPlate(boatId)
    if not plate then
        -- No plate means maritime-only boat, not in garage system
        return true, nil
    end

    if GarageBridge.IsVehicleOut(plate) then
        return false, 'This boat is already spawned elsewhere'
    end

    return true, nil
end

-- Register boat spawn for cleanup tracking
---@param source number Player server ID
---@param boatId number The boat ID
---@param plate string The vehicle plate
function GarageBridge.RegisterSpawn(source, boatId, plate)
    ActiveBoatSpawns[source] = {
        boatId = boatId,
        plate = plate,
        spawnTime = os.time(),
    }

    -- Exclude from dps-vehiclepersistence to prevent tracking conflicts
    if plate and GetResourceState('dps-vehiclepersistence') == 'started' then
        exports['dps-vehiclepersistence']:ExcludeFromPersistence(plate, 'dps-maritime', 'maritime job boat')
    end

    Maritime.Debug('GarageBridge: Registered spawn for player ' .. source .. ' - Plate: ' .. (plate or 'N/A'))
end

-- Unregister boat spawn
---@param source number Player server ID
function GarageBridge.UnregisterSpawn(source)
    if ActiveBoatSpawns[source] then
        local spawn = ActiveBoatSpawns[source]

        -- Remove exclusion from dps-vehiclepersistence
        if spawn.plate and GetResourceState('dps-vehiclepersistence') == 'started' then
            exports['dps-vehiclepersistence']:RemoveExclusion(spawn.plate)
        end

        Maritime.Debug('GarageBridge: Unregistered spawn for player ' .. source)
        ActiveBoatSpawns[source] = nil
    end
end

-- Get active spawn for player
---@param source number Player server ID
---@return table|nil spawnData
function GarageBridge.GetActiveSpawn(source)
    return ActiveBoatSpawns[source]
end

-----------------------------------------------------------
-- SPAWN CALLBACK WITH GARAGE SYNC
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:spawnOwnedBoat', function(source, boatId, spawnCoords)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local boat = Database.GetBoatById(boatId)

    if not boat or boat.owner ~= identifier then
        return { error = 'Boat not found' }
    end

    if boat.condition <= 0 then
        return { error = 'This boat is too damaged and needs repair' }
    end

    -- Check garage bridge BEFORE spawning
    local canSpawn, blockReason = GarageBridge.CanSpawnBoat(source, boatId)
    if not canSpawn then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Boat Unavailable',
            description = blockReason or 'This boat is already out',
            type = 'error',
        })
        return { error = blockReason }
    end

    -- Get plate for garage sync
    local plate = GarageBridge.GetBoatPlate(boatId)

    -- CRITICAL: Mark vehicle as OUT in garage system before spawning
    if plate and GarageBridge.IsEnabled() then
        GarageBridge.SetVehicleOut(plate)
    end

    -- Track this spawn for cleanup
    GarageBridge.RegisterSpawn(source, boatId, plate)

    local boatConfig = Config.Boats[boat.model]

    return {
        success = true,
        model = boat.model,
        fuel = boat.fuel,
        condition = boat.condition,
        boatId = boatId,
        plate = plate,
        config = boatConfig,
    }
end)

-----------------------------------------------------------
-- STORE BOAT WITH GARAGE SYNC
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:storeBoatWithGarage', function(boatId, fuel, condition)
    local source = source
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end

    local boat = Database.GetBoatById(boatId)

    if not boat or boat.owner ~= identifier then return end

    -- Update maritime database
    Database.UpdateBoatCondition(boatId, condition, fuel)

    -- CRITICAL: Mark vehicle as STORED in garage system
    local plate = GarageBridge.GetBoatPlate(boatId)
    if plate and GarageBridge.IsEnabled() then
        GarageBridge.SetVehicleStored(plate)
    end

    -- Unregister spawn tracking
    GarageBridge.UnregisterSpawn(source)

    Bridge.Notify(source, 'Success', 'Boat stored successfully', 'success')
end)

-----------------------------------------------------------
-- CLEANUP ON PLAYER DISCONNECT
-- Ensures boats are marked as stored if player disconnects mid-job
-----------------------------------------------------------

AddEventHandler('playerDropped', function(reason)
    local source = source

    local spawn = GarageBridge.GetActiveSpawn(source)
    if spawn and spawn.plate then
        Maritime.Debug('GarageBridge: Player ' .. source .. ' disconnected with active boat spawn')

        -- Mark boat as stored (player will need to retrieve from garage)
        if GarageBridge.IsEnabled() then
            GarageBridge.SetVehicleStored(spawn.plate)
        end
    end

    -- Always cleanup tracking
    GarageBridge.UnregisterSpawn(source)
end)

-----------------------------------------------------------
-- MANUAL SYNC EVENT (for job completion, cancellation, etc.)
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:syncBoatToGarage', function(boatId, markAsStored)
    local source = source
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end

    local boat = Database.GetBoatById(boatId)

    if not boat or boat.owner ~= identifier then return end

    local plate = GarageBridge.GetBoatPlate(boatId)
    if plate and GarageBridge.IsEnabled() then
        if markAsStored then
            GarageBridge.SetVehicleStored(plate)
        else
            GarageBridge.SetVehicleOut(plate)
        end
    end

    if markAsStored then
        GarageBridge.UnregisterSpawn(source)
    end
end)

-----------------------------------------------------------
-- RECOVERY FEE INTEGRATION
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:recoverBoatFromGarage', function(source, boatId)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local boat = Database.GetBoatById(boatId)

    if not boat or boat.owner ~= identifier then
        return { error = 'Boat not found' }
    end

    if not Config.GarageBridge.ChargeRecoveryFees then
        return { success = true, fee = 0 }
    end

    local boatConfig = Config.Boats[boat.model]
    if not boatConfig then
        return { error = 'Invalid boat configuration' }
    end

    -- Calculate recovery fee using impound settings
    local fee = Config.CalculateRecoveryFee and Config.CalculateRecoveryFee(boat.model, false, 0) or 500

    -- H2: Player was an undefined global
    local Player = Bridge.GetPlayer(source)
    if not Player then return { error = 'Player not found' } end

    local bank = Bridge.GetMoney(source, 'bank')
    if bank < fee then
        return { error = 'You need ' .. Maritime.FormatMoney(fee) .. ' to recover this boat' }
    end

    Bridge.RemoveMoney(source, 'bank', fee, 'boat-recovery')

    -- Restore boat with reduced condition
    local newCondition = Config.Impound and Config.Impound.RecoveredHealthPercent or 50
    local newFuel = Config.Impound and Config.Impound.RecoveredFuelPercent or 30

    Database.UpdateBoatCondition(boatId, newCondition, newFuel)

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Jetsam Maritime',
        description = 'Boat recovered for ' .. Maritime.FormatMoney(fee),
        type = 'success',
    })

    return {
        success = true,
        fee = fee,
        condition = newCondition,
        fuel = newFuel,
    }
end)

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('IsVehicleOut', GarageBridge.IsVehicleOut)
exports('SetVehicleOut', GarageBridge.SetVehicleOut)
exports('SetVehicleStored', GarageBridge.SetVehicleStored)
exports('CanSpawnBoat', GarageBridge.CanSpawnBoat)
exports('GetVehicleState', GarageBridge.GetVehicleState)
exports('GetActiveSpawn', GarageBridge.GetActiveSpawn)
