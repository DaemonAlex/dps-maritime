--[[
    dps-maritime - Jetsam Company
    Sea Life Mechanics

    - Dynamic Anchoring & Mooring
    - Depth Awareness (shallow water damage)
    - Wave Effects (handled by weather script integration)
]]

-- Uses Bridge for framework abstraction

-----------------------------------------------------------
-- CONFIGURATION
-----------------------------------------------------------

local SEA_CONFIG = {
    -- Anchoring
    Anchor = {
        deployTime = 3000,       -- 3 seconds to deploy
        retrieveTime = 2000,     -- 2 seconds to retrieve
        driftWithoutAnchor = 0.5, -- Meters per second drift
        anchorHoldStrength = 0.95, -- 95% drift reduction
        deepWaterMinDepth = 10,  -- Minimum depth for anchoring
        anchorKey = 182,         -- L key
    },

    -- Mooring
    Mooring = {
        mooringRadius = 5.0,     -- Must be within 5m of mooring point
        mooringTime = 4000,      -- 4 seconds to moor
        unmoorTime = 2000,       -- 2 seconds to unmoor
        perfectMoorBonus = 0.05, -- +5% pay for staying moored during unload
    },

    -- Depth Awareness
    Depth = {
        enabled = true,
        checkInterval = 1000,    -- Check every second

        -- Depth thresholds by boat tier
        tierDepths = {
            [1] = 2.0,   -- Tier 1 boats: 2m minimum
            [2] = 4.0,   -- Tier 2 boats: 4m minimum
            [3] = 8.0,   -- Tier 3 boats: 8m minimum (cargo ships need deep water)
        },

        -- Damage settings
        groundingDamagePerSecond = 5, -- HP damage per second when grounded
        scrapeWarningDepth = 2.0,     -- Extra meters before warning
        stuckThreshold = 3,           -- Seconds grounded before "stuck"
    },

    -- UI
    UI = {
        depthMeterX = 0.92,
        depthMeterY = 0.7,
    },
}

-----------------------------------------------------------
-- STATE
-----------------------------------------------------------

local anchorState = {
    deployed = false,
    deploying = false,
    lastPosition = nil,
}

local mooringState = {
    moored = false,
    mooring = false,
    mooringPoint = nil,
}

local depthState = {
    currentDepth = 100,
    isShallow = false,
    groundedTime = 0,
    lastCheck = 0,
}

-----------------------------------------------------------
-- DEPTH CALCULATION
-----------------------------------------------------------

local function GetWaterDepth(coords)
    -- Cast ray down to find water bottom
    local waterZ = coords.z

    -- Get ground Z at water position
    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 100.0, false)

    if foundGround then
        -- Approximate depth (water surface to ground)
        return coords.z - groundZ
    end

    -- If no ground found, assume deep water
    return 100.0
end

local function GetBoatTier(vehicle)
    local model = GetEntityModel(vehicle)

    for boatName, boatData in pairs(Config.Boats) do
        if GetHashKey(boatData.model) == model then
            return boatData.tier or 1
        end
    end

    return 1 -- Default to tier 1
end

local function GetMinimumDepth(tier)
    return SEA_CONFIG.Depth.tierDepths[tier] or SEA_CONFIG.Depth.tierDepths[1]
end

-----------------------------------------------------------
-- ANCHOR SYSTEM
-----------------------------------------------------------

local function DeployAnchor()
    if anchorState.deployed or anchorState.deploying then return end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or vehicle == 0 then return end
    if GetVehicleClass(vehicle) ~= 14 then return end -- Must be a boat

    -- Check depth
    local coords = GetEntityCoords(vehicle)
    local depth = GetWaterDepth(coords)

    if depth < SEA_CONFIG.Anchor.deepWaterMinDepth then
        lib.notify({
            title = 'Cannot Anchor',
            description = 'Water too shallow for anchoring',
            type = 'error',
        })
        return
    end

    anchorState.deploying = true

    -- Progress bar
    if lib.progressBar({
        duration = SEA_CONFIG.Anchor.deployTime,
        label = 'Deploying Anchor...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true },
    }) then
        anchorState.deployed = true
        anchorState.lastPosition = GetEntityCoords(vehicle)

        lib.notify({
            title = 'Anchor Deployed',
            description = 'Vessel secured',
            type = 'success',
        })

        -- Play anchor sound
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end

    anchorState.deploying = false
end

local function RetrieveAnchor()
    if not anchorState.deployed or anchorState.deploying then return end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or vehicle == 0 then return end

    anchorState.deploying = true

    if lib.progressBar({
        duration = SEA_CONFIG.Anchor.retrieveTime,
        label = 'Retrieving Anchor...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true },
    }) then
        anchorState.deployed = false
        anchorState.lastPosition = nil

        lib.notify({
            title = 'Anchor Retrieved',
            description = 'Ready to move',
            type = 'info',
        })
    end

    anchorState.deploying = false
end

local function ToggleAnchor()
    if anchorState.deployed then
        RetrieveAnchor()
    else
        DeployAnchor()
    end
end

-- Anchor drift prevention thread
CreateThread(function()
    while true do
        Wait(100)

        if anchorState.deployed then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle and vehicle ~= 0 and anchorState.lastPosition then
                local currentPos = GetEntityCoords(vehicle)
                local dist = #(currentPos - anchorState.lastPosition)

                -- If drifted too far, pull back
                if dist > 2.0 then
                    local direction = (anchorState.lastPosition - currentPos)
                    direction = direction / #direction

                    -- Apply force back toward anchor point
                    ApplyForceToEntity(vehicle, 1,
                        direction.x * 5.0, direction.y * 5.0, 0,
                        0, 0, 0, 0, true, true, true, false, true)
                end
            end
        end
    end
end)

-----------------------------------------------------------
-- MOORING SYSTEM
-----------------------------------------------------------

-- Mooring points are defined in Config.Ports
local function GetNearestMooringPoint()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for portId, port in pairs(Config.Ports) do
        if port.mooringPoint then
            local dist = #(coords - port.mooringPoint)
            if dist <= SEA_CONFIG.Mooring.mooringRadius then
                return port.mooringPoint, portId
            end
        elseif port.boatSpawn then
            -- Use boat spawn as mooring point if none defined
            local spawnCoords = vector3(port.boatSpawn.x, port.boatSpawn.y, port.boatSpawn.z)
            local dist = #(coords - spawnCoords)
            if dist <= SEA_CONFIG.Mooring.mooringRadius * 2 then
                return spawnCoords, portId
            end
        end
    end

    return nil, nil
end

local function MoorVessel()
    if mooringState.moored or mooringState.mooring then return end

    local mooringPoint, portId = GetNearestMooringPoint()

    if not mooringPoint then
        lib.notify({
            title = 'Cannot Moor',
            description = 'No mooring point nearby',
            type = 'error',
        })
        return
    end

    mooringState.mooring = true

    if lib.progressBar({
        duration = SEA_CONFIG.Mooring.mooringTime,
        label = 'Mooring vessel...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true },
    }) then
        mooringState.moored = true
        mooringState.mooringPoint = mooringPoint

        -- Freeze the vehicle
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle and vehicle ~= 0 then
            FreezeEntityPosition(vehicle, true)
        end

        lib.notify({
            title = 'Vessel Moored',
            description = 'Secured at ' .. (Config.Ports[portId] and Config.Ports[portId].shortName or 'dock'),
            type = 'success',
        })
    end

    mooringState.mooring = false
end

local function UnmoorVessel()
    if not mooringState.moored or mooringState.mooring then return end

    mooringState.mooring = true

    if lib.progressBar({
        duration = SEA_CONFIG.Mooring.unmoorTime,
        label = 'Unmooring vessel...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true },
    }) then
        mooringState.moored = false
        mooringState.mooringPoint = nil

        -- Unfreeze the vehicle
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle and vehicle ~= 0 then
            FreezeEntityPosition(vehicle, false)
        end

        lib.notify({
            title = 'Vessel Unmoored',
            description = 'Ready to depart',
            type = 'info',
        })
    end

    mooringState.mooring = false
end

-----------------------------------------------------------
-- DEPTH AWARENESS SYSTEM
-----------------------------------------------------------

-- Track textUI state to avoid spam
local depthTextUIShown = false
local lastDepthUIUpdate = 0
local DEPTH_UI_UPDATE_INTERVAL = 500 -- Update text UI every 500ms max

local function DrawDepthMeter(depth, minDepth, isShallow)
    -- OPTIMIZATION: Always prefer ox_lib textUI over native drawing
    -- Native drawing uses Scaleform memory every frame

    -- Check if using jg-hud depth meter instead
    if Config.JGHud and Config.JGHud.Enabled and Config.JGHud.UseDepthMeter then
        -- Send depth data to jg-hud
        if GetGameTimer() - lastDepthUIUpdate > DEPTH_UI_UPDATE_INTERVAL then
            TriggerEvent('jg-hud:updateDepth', depth, isShallow)
            lastDepthUIUpdate = GetGameTimer()
        end
        return
    end

    -- Use ox_lib textUI (lightweight, no Scaleform draw calls)
    if GetGameTimer() - lastDepthUIUpdate > DEPTH_UI_UPDATE_INTERVAL then
        lastDepthUIUpdate = GetGameTimer()

        local icon = isShallow and 'triangle-exclamation' or 'water'
        local color = isShallow and 'error' or 'info'

        local text = string.format('**DEPTH:** %.1fm', depth)
        if isShallow then
            text = text .. '  \n**! SHALLOW WATER !**'
        end

        if not depthTextUIShown then
            lib.showTextUI(text, { style = { backgroundColor = '#1b2340', color = '#f4f1ea', borderLeft = '3px solid #ff7a45' }, iconColor = '#ff7a45', position = 'right-center',
                icon = icon,
                style = {
                    borderRadius = 5,
                    backgroundColor = isShallow and '#8B0000CC' or '#14285ACC',
                }
            })
            depthTextUIShown = true
        else
            -- Update existing textUI (lib.showTextUI replaces existing)
            lib.showTextUI(text, { style = { backgroundColor = '#1b2340', color = '#f4f1ea', borderLeft = '3px solid #ff7a45' }, iconColor = '#ff7a45', position = 'right-center',
                icon = icon,
                style = {
                    borderRadius = 5,
                    backgroundColor = isShallow and '#8B0000CC' or '#14285ACC',
                }
            })
        end
    end
end

local function HideDepthMeter()
    if depthTextUIShown then
        lib.hideTextUI()
        depthTextUIShown = false
    end
end

-- Depth monitoring thread
-- OPTIMIZED: No longer uses Wait(0) - uses throttled updates instead
CreateThread(function()
    local wasInBoat = false

    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        -- Only check for boats
        if vehicle and vehicle ~= 0 and GetVehicleClass(vehicle) == 14 then
            wasInBoat = true
            local coords = GetEntityCoords(vehicle)
            local tier = GetBoatTier(vehicle)
            local minDepth = GetMinimumDepth(tier)

            -- Only do depth calculation at config interval (default 1000ms)
            if GetGameTimer() - depthState.lastCheck > SEA_CONFIG.Depth.checkInterval then
                depthState.currentDepth = GetWaterDepth(coords)
                depthState.lastCheck = GetGameTimer()

                -- Check if shallow
                local wasShallow = depthState.isShallow
                depthState.isShallow = depthState.currentDepth < minDepth

                if depthState.isShallow then
                    depthState.groundedTime = depthState.groundedTime + (SEA_CONFIG.Depth.checkInterval / 1000)

                    -- Apply damage
                    local damage = SEA_CONFIG.Depth.groundingDamagePerSecond
                    SetVehicleEngineHealth(vehicle, GetVehicleEngineHealth(vehicle) - damage)
                    SetVehicleBodyHealth(vehicle, GetVehicleBodyHealth(vehicle) - damage)

                    -- Warning on first shallow
                    if not wasShallow then
                        lib.notify({
                            title = 'Shallow Water!',
                            description = string.format('Minimum depth: %.1fm - Taking hull damage!', minDepth),
                            type = 'error',
                        })
                        PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
                    end

                    -- Stuck warning
                    if depthState.groundedTime >= SEA_CONFIG.Depth.stuckThreshold then
                        lib.notify({
                            title = 'GROUNDED',
                            description = 'Vessel is stuck! Reverse or call for tow.',
                            type = 'error',
                        })
                    end
                else
                    depthState.groundedTime = 0
                end
            end

            -- Show depth meter for Tier 3 boats or when approaching shallow
            if tier >= 3 or depthState.currentDepth < minDepth + SEA_CONFIG.Depth.scrapeWarningDepth then
                DrawDepthMeter(depthState.currentDepth, minDepth, depthState.isShallow)
            else
                -- Hide if not needed
                HideDepthMeter()
            end

            -- OPTIMIZED: Wait 200ms instead of 0 - textUI updates are throttled anyway
            Wait(200)
        else
            -- Not in boat - cleanup and wait longer
            if wasInBoat then
                HideDepthMeter()
                wasInBoat = false
            end
            depthState.isShallow = false
            depthState.groundedTime = 0
            Wait(1000) -- Check less frequently when not in boat
        end
    end
end)

-----------------------------------------------------------
-- KEY BINDINGS
-----------------------------------------------------------

-- Anchor toggle
RegisterCommand('+toggle_anchor', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle and vehicle ~= 0 and GetVehicleClass(vehicle) == 14 then
        ToggleAnchor()
    end
end, false)

RegisterKeyMapping('+toggle_anchor', 'Toggle Boat Anchor', 'keyboard', 'L')

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('IsAnchored', function() return anchorState.deployed end)
exports('IsMoored', function() return mooringState.moored end)
exports('GetCurrentDepth', function() return depthState.currentDepth end)
exports('IsInShallowWater', function() return depthState.isShallow end)
exports('DeployAnchor', DeployAnchor)
exports('RetrieveAnchor', RetrieveAnchor)
exports('MoorVessel', MoorVessel)
exports('UnmoorVessel', UnmoorVessel)

-----------------------------------------------------------
-- EVENTS
-----------------------------------------------------------

-- Force unmoor when leaving delivery zone
RegisterNetEvent('dps-maritime:client:deliveryComplete', function()
    if mooringState.moored then
        -- Auto-unmoor after delivery
        mooringState.moored = false
        mooringState.mooringPoint = nil

        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle and vehicle ~= 0 then
            FreezeEntityPosition(vehicle, false)
        end
    end
end)

-- Check mooring requirement for delivery
RegisterNetEvent('dps-maritime:client:checkMooringForDelivery', function(requiresMooring)
    if requiresMooring and not mooringState.moored then
        lib.notify({
            title = 'Mooring Required',
            description = 'Moor your vessel before unloading cargo',
            type = 'warning',
        })
    end
end)
