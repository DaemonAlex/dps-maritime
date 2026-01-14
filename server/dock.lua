--[[
    dps-maritime - Jetsam Company
    Dock Work Server Logic
    Uses Bridge for framework abstraction
]]

local Database = exports['dps-maritime']:GetDatabase()

-- Active dock workers
local ActiveDockWorkers = {}

-- Spawned containers (synced)
local SpawnedContainers = {}

-----------------------------------------------------------
-- MANIFEST GENERATION (Multi-Stage Mode)
-----------------------------------------------------------

-- Generate a dock work manifest with multiple containers
local function GenerateDockManifest(level)
    local manifest = {
        id = 'DM-' .. os.time() .. '-' .. math.random(1000, 9999),
        containers = {},
        totalContainers = 0,
        completedContainers = 0,
        createdAt = os.time(),
        timeLimit = Config.DockWork.ManifestMode.TimeLimit,
    }

    -- Determine number of containers based on level
    local minContainers = Config.DockWork.ManifestMode.MinContainers
    local maxContainers = Config.DockWork.ManifestMode.MaxContainers

    -- Higher level = more containers (scaled)
    local levelBonus = math.floor((level - 1) * 0.5)
    local adjustedMax = math.min(maxContainers, minContainers + levelBonus + 2)

    manifest.totalContainers = math.random(minContainers, adjustedMax)

    -- Generate container assignments
    for i = 1, manifest.totalContainers do
        local containerType = Config.GetRandomContainerType(level)
        table.insert(manifest.containers, {
            index = i,
            type = containerType,
            completed = false,
            pickedUp = false,
            deliveredAt = nil,
        })
    end

    return manifest
end

-- Calculate manifest completion bonus/penalty
local function CalculateManifestBonus(manifest)
    local elapsed = os.time() - manifest.createdAt
    local timeLimit = manifest.timeLimit
    local bonusMultiplier = 1.0

    -- Per-container bonus
    local extraContainers = manifest.completedContainers - Config.DockWork.ManifestMode.MinContainers
    if extraContainers > 0 then
        bonusMultiplier = bonusMultiplier + (extraContainers * Config.DockWork.ManifestMode.BonusPerContainer)
    end

    -- Time bonus/penalty
    if elapsed <= (timeLimit * Config.DockWork.ManifestMode.TimeBonusThreshold) then
        -- Completed fast - time bonus!
        bonusMultiplier = bonusMultiplier + Config.DockWork.ManifestMode.TimeBonusPercent
    elseif elapsed > timeLimit then
        -- Late penalty
        local minutesLate = math.floor((elapsed - timeLimit) / 60)
        local latePenalty = minutesLate * Config.DockWork.ManifestMode.LatePenaltyPercent
        latePenalty = math.min(latePenalty, Config.DockWork.ManifestMode.MaxLatePenalty)
        bonusMultiplier = bonusMultiplier - latePenalty
    end

    return math.max(0.5, bonusMultiplier) -- Minimum 50% pay
end

-----------------------------------------------------------
-- DOCK JOB MANAGEMENT
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:startDockJob', function(zoneId)
    local source = source
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end
    local level = exports['dps-maritime']:GetPlayerMaritimeLevel(source)

    if not Config.CanDoDockWork(level) then
        TriggerClientEvent('ox_lib:notify', source, {
            description = 'You need to be at least level ' .. Config.Progression.DockWorkMinLevel .. ' to do dock work',
            type = 'error',
        })
        return
    end

    -- Charge rental fee
    local cash = Player.PlayerData.money.cash
    local bank = Player.PlayerData.money.bank
    local rentalFee = Config.DockWork.TruckRentalFee

    if cash < rentalFee and bank < rentalFee then
        TriggerClientEvent('ox_lib:notify', source, {
            description = 'You need ' .. Maritime.FormatMoney(rentalFee) .. ' for the truck rental',
            type = 'error',
        })
        return
    end

    local paymentMethod = cash >= rentalFee and 'cash' or 'bank'
    Player.Functions.RemoveMoney(paymentMethod, rentalFee, 'dock-truck-rental')

    -- Generate dock manifest if ManifestMode is enabled
    local manifest = nil
    if Config.DockWork.ManifestMode and Config.DockWork.ManifestMode.Enabled then
        manifest = GenerateDockManifest(level)
    end

    -- Track worker
    ActiveDockWorkers[source] = {
        identifier = identifier,
        zoneId = zoneId,
        startTime = os.time(),
        containersDelivered = 0,
        rentalPaid = rentalFee,
        manifest = manifest,
        accumulatedPay = 0,
        accumulatedXP = 0,
    }

    -- Get first container type
    local containerType
    if manifest then
        containerType = manifest.containers[1].type
    else
        containerType = Config.GetRandomContainerType(level)
    end

    TriggerClientEvent('dps-maritime:client:dockJobStarted', source, {
        zoneId = zoneId,
        containerType = containerType,
        rentalFee = rentalFee,
        manifest = manifest and {
            id = manifest.id,
            totalContainers = manifest.totalContainers,
            completedContainers = 0,
            timeLimit = manifest.timeLimit,
            startTime = manifest.createdAt,
        } or nil,
    })

    local description = 'Dock job started. Rental fee: ' .. Maritime.FormatMoney(rentalFee)
    if manifest then
        description = description .. '\nManifest: ' .. manifest.totalContainers .. ' containers to deliver'
    end

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Jetsam Maritime',
        description = description,
        type = 'inform',
        duration = 7000,
    })
end)

RegisterNetEvent('dps-maritime:server:endDockJob', function(returnVehicles)
    local source = source
    local worker = ActiveDockWorkers[source]
    if not worker then return end

    if not Bridge.GetPlayer(source) then return end

    -- Refund rental if vehicles returned properly
    if returnVehicles and Config.DockWork.RefundOnReturn then
        Bridge.AddMoney(source, 'cash', worker.rentalPaid, 'dock-rental-refund')
        Bridge.Notify(source, 'Refund', 'Rental deposit refunded: ' .. Maritime.FormatMoney(worker.rentalPaid), 'success')
    end

    ActiveDockWorkers[source] = nil

    TriggerClientEvent('dps-maritime:client:dockJobEnded', source)
end)

-----------------------------------------------------------
-- CONTAINER DELIVERY
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:containerDelivered', function(containerType)
    local source = source
    local worker = ActiveDockWorkers[source]
    if not worker then return end

    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end
    local level = exports['dps-maritime']:GetPlayerMaritimeLevel(source)

    -- Calculate base pay and XP
    local pay = Maritime.CalculateDockPay(containerType, level)
    local xp = Maritime.CalculateDockXP(containerType)

    -- Update worker stats
    worker.containersDelivered = worker.containersDelivered + 1

    -- Check if using ManifestMode
    local manifest = worker.manifest
    local manifestComplete = false
    local nextContainerType = nil
    local manifestProgress = nil

    if manifest and Config.DockWork.ManifestMode and Config.DockWork.ManifestMode.Enabled then
        -- Update manifest progress
        manifest.completedContainers = manifest.completedContainers + 1

        -- Mark current container as complete
        for _, container in ipairs(manifest.containers) do
            if not container.completed then
                container.completed = true
                container.deliveredAt = os.time()
                break
            end
        end

        -- Accumulate pay and XP (paid out at manifest completion)
        worker.accumulatedPay = worker.accumulatedPay + pay
        worker.accumulatedXP = worker.accumulatedXP + xp

        -- Check if manifest is complete
        if manifest.completedContainers >= manifest.totalContainers then
            manifestComplete = true

            -- Calculate bonus multiplier
            local bonusMultiplier = CalculateManifestBonus(manifest)

            -- Apply bonus to accumulated pay
            local finalPay = math.floor(worker.accumulatedPay * bonusMultiplier)
            local finalXP = math.floor(worker.accumulatedXP * bonusMultiplier)

            -- Pay player the full amount
            TriggerEvent('dps-maritime:server:payout', finalPay, 'dock', {
                job_type = 'dock',
                cargo_type = 'manifest_' .. manifest.id,
                start_port = 'loading_zone',
                end_port = 'storage',
                distance = 0,
                xp_earned = finalXP,
                boat_used = nil,
            })

            -- Add XP
            TriggerEvent('dps-maritime:server:addXP', finalXP)

            -- Calculate time info for notification
            local elapsed = os.time() - manifest.createdAt
            local timeLimit = manifest.timeLimit

            TriggerClientEvent('dps-maritime:client:manifestComplete', source, {
                manifestId = manifest.id,
                totalContainers = manifest.totalContainers,
                basePay = worker.accumulatedPay,
                finalPay = finalPay,
                bonusMultiplier = bonusMultiplier,
                baseXP = worker.accumulatedXP,
                finalXP = finalXP,
                elapsed = elapsed,
                timeLimit = timeLimit,
                wasOnTime = elapsed <= timeLimit,
                wasFast = elapsed <= (timeLimit * Config.DockWork.ManifestMode.TimeBonusThreshold),
            })
        else
            -- Get next container type from manifest
            for _, container in ipairs(manifest.containers) do
                if not container.completed then
                    nextContainerType = container.type
                    break
                end
            end

            manifestProgress = {
                current = manifest.completedContainers,
                total = manifest.totalContainers,
                timeRemaining = manifest.timeLimit - (os.time() - manifest.createdAt),
            }

            -- Notify progress (no payout until manifest complete)
            TriggerClientEvent('dps-maritime:client:containerComplete', source, {
                pay = 0, -- No immediate pay in manifest mode
                xp = 0,
                nextContainerType = nextContainerType,
                totalDelivered = worker.containersDelivered,
                manifestGenerated = false,
                manifestProgress = manifestProgress,
                pendingPay = worker.accumulatedPay,
                pendingXP = worker.accumulatedXP,
            })
        end
    else
        -- Legacy mode: immediate pay per container
        TriggerEvent('dps-maritime:server:payout', pay, 'dock', {
            job_type = 'dock',
            cargo_type = containerType,
            start_port = 'loading_zone',
            end_port = 'storage',
            distance = 0,
            xp_earned = xp,
            boat_used = nil,
        })

        -- Add XP
        TriggerEvent('dps-maritime:server:addXP', xp)

        -- Generate cargo manifest if system is enabled and player is eligible
        local manifestGenerated = false
        if Config.Manifest and Config.Manifest.Enabled then
            if level >= Config.Manifest.GeneratorLevelMin and level <= Config.Manifest.GeneratorLevelMax then
                -- Generate manifest with metadata
                local manifestData = GenerateCargoManifest(identifier, containerType, worker.containersDelivered)

                if manifestData then
                    -- Add manifest item to player inventory
                    local success = exports[Config.Inventory]:AddItem(source, Config.Manifest.ItemName, 1, false, manifestData)

                    if success then
                        manifestGenerated = true
                        TriggerClientEvent('ox_lib:notify', source, {
                            title = Config.Manifest.ManifestReceivedTitle,
                            description = Config.Manifest.ManifestReceivedDesc,
                            type = 'success',
                            duration = 5000,
                        })

                        -- Play print sound
                        TriggerClientEvent('dps-maritime:client:playManifestSound', source)

                        Maritime.Debug('Generated manifest for ' .. identifier .. ' - Type: ' .. containerType)
                    end
                end
            end
        end

        -- Get next container type
        nextContainerType = Config.GetRandomContainerType(level)

        TriggerClientEvent('dps-maritime:client:containerComplete', source, {
            pay = pay,
            xp = xp,
            nextContainerType = nextContainerType,
            totalDelivered = worker.containersDelivered,
            manifestGenerated = manifestGenerated,
        })
    end
end)

-----------------------------------------------------------
-- CARGO MANIFEST GENERATION
-----------------------------------------------------------

function GenerateCargoManifest(creatorId, cargoType, containerCount)
    -- Generate unique manifest ID
    local manifestId = 'JMC-' .. os.time() .. '-' .. math.random(1000, 9999)

    -- Pick a random suggested destination (helps guide captains)
    local suggestedDestination = nil
    local portKeys = {}
    for portId, _ in pairs(Config.Ports) do
        table.insert(portKeys, portId)
    end
    if #portKeys > 0 then
        suggestedDestination = portKeys[math.random(#portKeys)]
    end

    -- Build manifest metadata
    local manifestData = {
        manifestId = manifestId,
        cargoType = cargoType,
        suggestedDestination = suggestedDestination,
        containerCount = containerCount,
        createdAt = os.time(),
        createdBy = creatorId,
        label = 'Cargo Manifest #' .. manifestId,
        description = string.format('Cargo: %s | Containers: %d | Dest: %s',
            cargoType or 'Standard',
            containerCount or 1,
            suggestedDestination or 'Any'
        ),
    }

    return manifestData
end

-- Validate manifest (check expiration, etc.)
function ValidateManifest(manifestData)
    if not manifestData then return false, 'No manifest data' end
    if not manifestData.manifestId then return false, 'Invalid manifest' end

    -- Check expiration
    if Config.Manifest.ExpirationMinutes > 0 then
        local expirationTime = manifestData.createdAt + (Config.Manifest.ExpirationMinutes * 60)
        if os.time() > expirationTime then
            return false, 'Manifest has expired'
        end
    end

    return true, nil
end

exports('ValidateManifest', ValidateManifest)
exports('GenerateCargoManifest', GenerateCargoManifest)

-----------------------------------------------------------
-- CONTAINER PLACEMENT (Stacking)
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:server:placeContainer', function(position)
    local source = source
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end

    -- Save to database
    local containerId = Database.SaveContainer(
        position.x,
        position.y,
        position.z,
        position.heading,
        identifier
    )

    if containerId then
        SpawnedContainers[containerId] = {
            id = containerId,
            x = position.x,
            y = position.y,
            z = position.z,
            heading = position.heading,
            placedBy = identifier,
        }

        -- Sync to all clients
        TriggerClientEvent('dps-maritime:client:syncContainer', -1, SpawnedContainers[containerId])
    end
end)

RegisterNetEvent('dps-maritime:server:removeContainer', function(containerId)
    local source = source

    if SpawnedContainers[containerId] then
        Database.DeleteContainer(containerId)
        SpawnedContainers[containerId] = nil

        -- Sync removal to all clients
        TriggerClientEvent('dps-maritime:client:removeContainer', -1, containerId)
    end
end)

-----------------------------------------------------------
-- CONTAINER SYNC
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:getContainers', function(source)
    return SpawnedContainers
end)

-- Load containers on resource start
CreateThread(function()
    Wait(1000) -- Wait for database to be ready

    local containers = Database.GetAllContainers()
    if containers then
        for _, container in ipairs(containers) do
            SpawnedContainers[container.id] = {
                id = container.id,
                x = container.x,
                y = container.y,
                z = container.z,
                heading = container.heading,
                placedBy = container.placed_by,
            }
        end
        Maritime.Debug('Loaded ' .. #containers .. ' containers from database')
    end
end)

-----------------------------------------------------------
-- WEEKLY CONTAINER WIPE
-----------------------------------------------------------

if Config.DockWork.ContainerWipe == 'Restart' then
    AddEventHandler('onResourceStart', function(resource)
        if resource == GetCurrentResourceName() then
            Database.ClearAllContainers()
            SpawnedContainers = {}
            Maritime.Debug('Containers cleared on restart')
        end
    end)
end

-- Manual wipe command
Bridge.RegisterCommand('clearcontainers', 'Clear all placed containers (Admin)', {}, false, function(source)
    Database.ClearAllContainers()
    SpawnedContainers = {}

    TriggerClientEvent('dps-maritime:client:clearContainers', -1)

    Bridge.Notify(source, 'Success', 'All containers have been cleared', 'success')
end, 'admin')

-----------------------------------------------------------
-- VEHICLE SPAWNING
-----------------------------------------------------------

lib.callback.register('dps-maritime:server:spawnDockVehicle', function(source, vehicleType, coords)
    if not Bridge.GetPlayer(source) then return nil end

    local model
    if vehicleType == 'truck' then
        model = Config.DockWork.TruckModel
    elseif vehicleType == 'trailer' then
        model = Config.DockWork.TrailerModel
    elseif vehicleType == 'handler' then
        model = Config.DockWork.HandlerModel
    else
        return nil
    end

    return model
end)

-----------------------------------------------------------
-- CLEANUP ON DISCONNECT
-----------------------------------------------------------

AddEventHandler('playerDropped', function()
    local source = source
    if ActiveDockWorkers[source] then
        ActiveDockWorkers[source] = nil
    end
end)
