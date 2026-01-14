--[[
    dps-maritime - Jetsam Company
    Boat Delivery Server Logic
    Uses Bridge for framework abstraction
]]

local Database = exports['dps-maritime']:GetDatabase()

-- Active boat jobs
local ActiveBoatJobs = {}

-----------------------------------------------------------
-- BOAT JOB MANAGEMENT
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:requestBoatJob', function(source, boatModel, cargoType)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local level = exports['dps-maritime']:GetPlayerMaritimeLevel(source)

    -- Check level requirement
    if not Config.CanDoBoatDelivery(level) then
        return { error = 'You need to be level ' .. Config.Progression.BoatDeliveryMinLevel .. ' for boat deliveries' }
    end

    -- Check boat level requirement
    local boat = Config.Boats[boatModel]
    if not boat then
        return { error = 'Invalid boat model' }
    end

    if level < boat.levelRequired then
        return { error = 'You need to be level ' .. boat.levelRequired .. ' to use this boat' }
    end

    -- Check cargo level requirement
    local cargo = Config.CargoTypes[cargoType]
    if cargo and level < cargo.levelRequired then
        return { error = 'You need to be level ' .. cargo.levelRequired .. ' for this cargo' }
    end

    -- Check hazmat requirement
    if cargo and cargo.requiresHazmatBoat and not boat.hazmatRated then
        return { error = 'This cargo requires a hazmat-rated vessel' }
    end

    -- Check for manifest requirement (Level 4+ needs manifest from dock workers)
    local manifestData = nil
    local isTraded = false

    if Config.Manifest and Config.Manifest.Enabled and Config.Manifest.RequireForBoatDelivery then
        if level >= Config.Manifest.MinLevelToRequire then
            -- Check if player has a cargo manifest
            local manifestItem = exports[Config.Inventory]:GetItemByName(source, Config.Manifest.ItemName)

            if not manifestItem then
                return { error = 'You need a Cargo Manifest from a dock worker to start a delivery' }
            end

            -- Get manifest metadata
            manifestData = manifestItem.info or manifestItem.metadata

            -- Validate manifest
            local valid, errorMsg = exports['dps-maritime']:ValidateManifest(manifestData)
            if not valid then
                return { error = errorMsg or 'Invalid manifest' }
            end

            -- Check if manifest was created by someone else (trade bonus)
            if manifestData.createdBy and manifestData.createdBy ~= identifier then
                isTraded = true
            end

            -- Remove the manifest from inventory (consumed on job start)
            exports[Config.Inventory]:RemoveItem(source, Config.Manifest.ItemName, 1, manifestItem.slot)

            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Manifest Accepted',
                description = 'Cargo manifest verified and logged',
                type = 'success',
            })
        end
    end

    return {
        success = true,
        boat = boat,
        cargo = cargo,
        manifestData = manifestData,
        isTradedManifest = isTraded,
    }
end)

RegisterNetEvent('dps-maritime:server:startBoatJob', function(data)
    local source = source
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end

    ActiveBoatJobs[source] = {
        identifier = identifier,
        boatModel = data.boatModel,
        cargoType = data.cargoType,
        startPort = data.startPort,
        endPort = data.endPort,
        startTime = os.time(),
        startCoords = data.startCoords,
        -- Manifest data for trade bonus
        manifestData = data.manifestData,
        isTradedManifest = data.isTradedManifest or false,
    }

    -- Register with security system for validation on completion
    exports['dps-maritime']:SecurityOnJobStart(source, data.startPort, data.endPort, 'boat')

    local message = 'Delivery job started. Destination: ' .. (Config.Ports[data.endPort] and Config.Ports[data.endPort].shortName or data.endPort)

    -- Notify if using traded manifest
    if data.isTradedManifest and Config.Manifest and Config.Manifest.TradeBonus.Enabled then
        message = message .. ' (+' .. math.floor(Config.Manifest.TradeBonus.PayBonus * 100) .. '% trade bonus!)'
    end

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Jetsam Maritime',
        description = message,
        type = 'inform',
    })
end)

RegisterNetEvent('dps-maritime:server:cancelBoatJob', function()
    local source = source

    if ActiveBoatJobs[source] then
        -- Notify security system
        exports['dps-maritime']:SecurityOnJobCancel(source)

        -- Reset streak on cancellation
        TriggerEvent('dps-maritime:server:resetStreak')
        ActiveBoatJobs[source] = nil

        Bridge.Notify(source, 'Job Cancelled', 'Delivery cancelled. Streak reset.', 'error')
    end
end)

RegisterNetEvent('dps-maritime:server:completeBoatJob', function(data)
    local source = source
    local job = ActiveBoatJobs[source]
    if not job then return end

    if not Bridge.GetPlayer(source) then return end

    -- Server-side security validation
    local isValid, validatedDistance, errorMsg = exports['dps-maritime']:SecurityValidateCompletion(
        source,
        data.distance or 0,
        { cargoType = job.cargoType, endPort = job.endPort }
    )

    if not isValid then
        Bridge.Notify(source, 'Delivery Failed', errorMsg or 'Validation failed', 'error')
        return
    end

    local level = exports['dps-maritime']:GetPlayerMaritimeLevel(source)
    local distance = validatedDistance  -- Use server-validated distance
    local weather = data.weather or 'clear'
    local damagePercent = data.damagePercent or 0

    -- Calculate pay and XP using validated distance
    local pay = Maritime.CalculateBoatPay(distance, job.cargoType, level, weather, damagePercent, job.boatModel)
    local xp = Maritime.CalculateBoatXP(distance, job.cargoType, level, weather)

    -- Port bonus
    local endPort = Config.Ports[job.endPort]
    if endPort and endPort.payBonus then
        pay = math.floor(pay * (1 + endPort.payBonus))
    end

    -- Cargo damage penalty for fragile items
    local cargo = Config.CargoTypes[job.cargoType]
    if cargo and cargo.fragile and damagePercent > 0 then
        local damageMultiplier = cargo.damageMultiplier or 1.0
        local penalty = (damagePercent / 100) * damageMultiplier
        pay = math.floor(pay * (1 - penalty))
    end

    -- Apply trade bonus if using manifest from another player
    local tradeBonus = 0
    local tradeXPBonus = 0
    if job.isTradedManifest and Config.Manifest and Config.Manifest.TradeBonus.Enabled then
        tradeBonus = math.floor(pay * Config.Manifest.TradeBonus.PayBonus)
        tradeXPBonus = math.floor(xp * Config.Manifest.TradeBonus.XPBonus)
        pay = pay + tradeBonus
        xp = xp + tradeXPBonus
    end

    -- Pay player
    TriggerEvent('dps-maritime:server:payout', pay, 'boat', {
        job_type = 'boat',
        cargo_type = job.cargoType,
        start_port = job.startPort,
        end_port = job.endPort,
        distance = math.floor(distance),
        xp_earned = xp,
        boat_used = job.boatModel,
        manifest_id = job.manifestData and job.manifestData.manifestId or nil,
        trade_bonus = tradeBonus,
    })

    -- Add XP
    TriggerEvent('dps-maritime:server:addXP', xp)

    -- Clear job
    ActiveBoatJobs[source] = nil

    TriggerClientEvent('dps-maritime:client:boatJobComplete', source, {
        pay = pay,
        xp = xp,
        distance = distance,
        bonus = endPort and endPort.payBonus or 0,
        tradeBonus = tradeBonus,
        tradeXPBonus = tradeXPBonus,
    })
end)

-----------------------------------------------------------
-- ILLEGAL CARGO - POLICE ALERT SYSTEM
-----------------------------------------------------------

-- Track active smugglers for police visibility
local ActiveSmugglers = {}

RegisterNetEvent('dps-maritime:server:illegalCargoAlert', function(coords)
    local source = source
    local job = ActiveBoatJobs[source]
    if not job then return end

    local cargo = Config.CargoTypes[job.cargoType]
    if not cargo or not cargo.illegal then return end

    local policeChance = cargo.policeChance or 0.15

    if math.random() < policeChance then
        if not Bridge.GetPlayer(source) then return end

        -- Track this smuggler
        ActiveSmugglers[source] = {
            coords = coords,
            cargoType = job.cargoType,
            startTime = os.time(),
        }

        -- Get player name for dispatch
        local playerName = Bridge.GetPlayerName(source)

        -- Alert police via multiple dispatch systems
        local alertData = {
            coords = coords,
            title = 'Maritime Smuggling',
            message = 'Suspicious vessel spotted carrying contraband near the coast',
            code = '10-31', -- Smuggling code
            icon = 'fas fa-ship',
            blip = {
                sprite = 427,
                colour = 1,
                scale = 1.0,
                text = 'Suspected Smuggler',
            },
        }

        -- ps-dispatch integration
        TriggerEvent('ps-dispatch:server:notify', {
            dispatchcodename = 'maritimesmuggling',
            dispatchCode = '10-31',
            firstStreet = 'Ocean',
            gender = false,
            model = nil,
            plate = nil,
            priority = 2,
            firstColor = nil,
            automaticGunfire = false,
            origin = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
            },
            dispatchMessage = 'Suspected maritime smuggling activity',
            job = { 'police', 'sheriff', 'coastguard' },
        })

        -- cd_dispatch integration
        TriggerEvent('cd_dispatch:AddNotification', {
            job_table = { 'police', 'sheriff' },
            coords = coords,
            title = '10-31 - Maritime Smuggling',
            message = 'Suspicious vessel spotted with potential contraband',
            flash = 1,
            unique_id = tostring(source),
            blip = {
                sprite = 427,
                scale = 1.2,
                colour = 1,
                flashes = true,
                text = 'Maritime Smuggling',
                time = 300,
                radius = 0,
            },
        })

        -- qs-dispatch integration
        TriggerEvent('qs-dispatch:server:CreateDispatchCall', {
            job = 'police',
            callLocation = coords,
            callCode = { code = '10-31', snippet = 'Maritime Smuggling' },
            message = 'Suspicious vessel spotted carrying contraband',
            flashes = true,
            image = nil,
            blip = {
                sprite = 427,
                scale = 1.0,
                colour = 1,
                flashes = true,
                text = 'Maritime Smuggling',
                time = (5 * 60 * 1000),
            },
        })

        -- Create visible blip for all police on duty
        TriggerClientEvent('dps-maritime:client:createPoliceBlip', -1, {
            coords = coords,
            smugglerId = source,
        })

        -- Notify the smuggler
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Warning',
            description = 'Your cargo has been spotted! Coast Guard may be responding.',
            type = 'error',
            duration = 8000,
        })

        -- Log for admin review
        Maritime.Debug('Smuggler alert triggered for player ' .. source .. ' at ' .. coords.x .. ', ' .. coords.y)
    end
end)

-- Clear smuggler tracking when job ends
RegisterNetEvent('dps-maritime:server:clearSmuggler', function()
    local source = source
    ActiveSmugglers[source] = nil
    TriggerClientEvent('dps-maritime:client:removePoliceBlip', -1, source)
end)

-- Callback for police to get active smugglers
lib.callback.register('dps-maritime:server:getActiveSmugglers', function(source)
    if not Bridge.GetPlayer(source) then return {} end

    local job = Bridge.GetJob(source)
    if not job then return {} end
    if job.name ~= 'police' and job.name ~= 'sheriff' and job.name ~= 'coastguard' then
        return {}
    end

    return ActiveSmugglers
end)

-----------------------------------------------------------
-- FUEL MANAGEMENT
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:refuelBoat', function(source, boatNetId, amount)
    if not Bridge.GetPlayer(source) then return false end

    local cost = amount * Config.BoatDelivery.FuelPricePerLiter

    local cash = Bridge.GetMoney(source, 'cash')
    if cash < cost then
        return { error = 'Not enough cash. Need ' .. Maritime.FormatMoney(cost) }
    end

    Bridge.RemoveMoney(source, 'cash', cost, 'boat-fuel')

    return { success = true, cost = cost }
end)

-----------------------------------------------------------
-- BOAT RENTAL (for players without fleet)
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:rentBoat', function(source, boatModel)
    if not Bridge.GetPlayer(source) then return nil end

    local level = exports['dps-maritime']:GetPlayerMaritimeLevel(source)
    local boat = Config.Boats[boatModel]

    if not boat then
        return { error = 'Invalid boat' }
    end

    if level < boat.levelRequired then
        return { error = 'You need to be level ' .. boat.levelRequired }
    end

    -- Rental cost is 10% of purchase price
    local rentalCost = math.floor(boat.price * 0.1)
    local cash = Bridge.GetMoney(source, 'cash')
    local bank = Bridge.GetMoney(source, 'bank')

    if cash < rentalCost and bank < rentalCost then
        return { error = 'You need ' .. Maritime.FormatMoney(rentalCost) .. ' to rent this boat' }
    end

    local paymentMethod = cash >= rentalCost and 'cash' or 'bank'
    Bridge.RemoveMoney(source, paymentMethod, rentalCost, 'boat-rental')

    return { success = true, model = boatModel, rentalCost = rentalCost }
end)

-----------------------------------------------------------
-- WEATHER SYNC
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:getWeather', function(source)
    -- Integrate with your weather system
    -- For now, return a basic weather state
    local weathers = { 'clear', 'cloudy', 'rain', 'thunder', 'fog' }
    local weights = { 40, 30, 15, 10, 5 }

    local total = 0
    for _, w in ipairs(weights) do total = total + w end

    local rand = math.random(total)
    local cumulative = 0

    for i, w in ipairs(weights) do
        cumulative = cumulative + w
        if rand <= cumulative then
            return weathers[i]
        end
    end

    return 'clear'
end)

-----------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------

AddEventHandler('playerDropped', function()
    local source = source
    if ActiveBoatJobs[source] then
        ActiveBoatJobs[source] = nil
    end
    if ActiveVIPMissions and ActiveVIPMissions[source] then
        ActiveVIPMissions[source] = nil
    end
end)

-----------------------------------------------------------
-- VIP LEISURE TRANSPORT
-- High-paying passenger transport to leisure destinations
-----------------------------------------------------------

local ActiveVIPMissions = {}

lib.callback.register('dps-maritime:server:requestVIPMission', function(source, data)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end
    local level = exports['dps-maritime']:GetPlayerMaritimeLevel(source)

    -- Check VIP transport level
    if level < Config.VIPTransport.MinLevel then
        return { error = 'You need to be level ' .. Config.VIPTransport.MinLevel .. ' for VIP transport' }
    end

    -- Check if already has active mission
    if ActiveVIPMissions[source] then
        return { error = 'You already have an active VIP mission' }
    end

    -- Validate destination
    local destination = Config.VIPTransport.Destinations[data.destinationId]
    if not destination then
        return { error = 'Invalid destination' }
    end

    -- Check if destination resource is running
    if GetResourceState(destination.resource) ~= 'started' then
        return { error = destination.name .. ' is currently closed' }
    end

    -- Validate mission type
    local missionType = Config.VIPTransport.MissionTypes[data.missionTypeId]
    if not missionType then
        return { error = 'Invalid mission type' }
    end

    -- Check level requirement for specific mission types
    if missionType.levelRequired and level < missionType.levelRequired then
        return { error = 'You need to be level ' .. missionType.levelRequired .. ' for this mission type' }
    end

    -- Create mission
    local missionId = source .. '_' .. os.time()

    ActiveVIPMissions[source] = {
        id = missionId,
        destinationId = data.destinationId,
        missionTypeId = data.missionTypeId,
        startTime = os.time(),
        destination = destination,
        missionType = missionType,
    }

    return {
        success = true,
        missionId = missionId,
        destinationId = data.destinationId,
        missionTypeId = data.missionTypeId,
        destination = destination,
        missionType = missionType,
    }
end)

lib.callback.register('dps-maritime:server:completeVIPMission', function(source, data)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end

    local mission = ActiveVIPMissions[source]
    if not mission then
        return { error = 'No active VIP mission' }
    end
    local level = exports['dps-maritime']:GetPlayerMaritimeLevel(source)
    local levelData = Config.GetLevelData(level)

    local destination = Config.VIPTransport.Destinations[mission.destinationId]
    local missionType = Config.VIPTransport.MissionTypes[mission.missionTypeId]

    if not destination or not missionType then
        ActiveVIPMissions[source] = nil
        return { error = 'Mission data corrupted' }
    end

    -- Calculate base pay
    local passengers = missionType.passengers or 1
    local basePay = Config.VIPTransport.BasePayPerPassenger * passengers

    -- Apply multipliers
    basePay = basePay * (destination.payMultiplier or 1.0)
    basePay = basePay * (missionType.payMultiplier or 1.0)
    basePay = basePay * levelData.payMultiplier

    -- Check if on time
    local onTime = data.elapsedTime <= missionType.timeLimit
    if not onTime then
        basePay = basePay * (1 - Config.VIPTransport.BadServicePenalty)
    end

    -- Collision penalty
    if data.collisions and data.collisions > 2 then
        basePay = basePay * 0.8 -- 20% penalty for rough ride
    end

    local pay = math.floor(basePay)

    -- Calculate tip
    local tip = 0
    local tipChance = Config.VIPTransport.TipChance + (data.satisfaction or 0)

    if math.random() < tipChance then
        local minTip = Config.VIPTransport.TipRange.min
        local maxTip = Config.VIPTransport.TipRange.max
        tip = math.random(minTip, maxTip)

        -- Celebrity bonus tip
        if missionType.bonusTip then
            tip = tip + missionType.bonusTip
        end
    end

    -- Calculate XP
    local xp = Config.Progression.BaseXPPerDelivery
    xp = xp * (1 + (destination.xpBonus or 0))
    xp = math.floor(xp)

    -- Pay player
    Player.Functions.AddMoney('bank', pay + tip, 'vip-transport')

    -- Log delivery
    Database.LogDelivery({
        identifier = identifier,
        job_type = 'boat',
        cargo_type = 'vip_transport',
        start_port = 'pickup',
        end_port = destination.name,
        distance = 0,
        payout = pay + tip,
        xp_earned = xp,
        boat_used = 'vip_vessel',
    })

    -- Add XP
    TriggerEvent('dps-maritime:server:addXP', xp)

    -- Clear mission
    ActiveVIPMissions[source] = nil

    return {
        success = true,
        payout = pay,
        tip = tip,
        xp = xp,
        onTime = onTime,
    }
end)

-- Cancel VIP mission
RegisterNetEvent('dps-maritime:server:cancelVIPMission', function()
    local source = source
    if ActiveVIPMissions[source] then
        ActiveVIPMissions[source] = nil
        TriggerClientEvent('ox_lib:notify', source, {
            description = 'VIP mission cancelled',
            type = 'warning',
        })
    end
end)

-- Get active VIP missions for admin
lib.callback.register('dps-maritime:server:getActiveVIPMissions', function(source)
    if not Bridge.GetPlayer(source) then return {} end

    -- Admin check
    if not Bridge.HasPermission(source, 'admin') then
        return {}
    end

    return ActiveVIPMissions
end)
