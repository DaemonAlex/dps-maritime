--[[
    dps-maritime - Jetsam Company
    Mini-Games for Specialized Tasks

    - Hazmat Pressure Stabilization (Level 7+)
    - Crane Operation (Dock Work)
    - Forklift Precision (Level 2+)
]]

-- Uses Bridge for framework abstraction

-- Mini-game state
local activeMinigame = nil
local minigameData = {}

-----------------------------------------------------------
-- HAZMAT PRESSURE STABILIZATION
-- Keep the gauge in the green zone while driving
-----------------------------------------------------------

local HAZMAT_CONFIG = {
    -- Gauge settings
    gaugeMin = 0,
    gaugeMax = 100,
    greenZoneMin = 40,
    greenZoneMax = 60,
    warningZoneMin = 25,
    warningZoneMax = 75,

    -- Pressure drift (affected by driving)
    baseDrift = 0.5,           -- Base drift per tick
    speedDriftMultiplier = 0.1, -- Additional drift per mph
    collisionSpike = 25,        -- Pressure spike on collision
    waveDrift = 2.0,            -- Drift from waves (random)

    -- Controls
    increaseKey = 38,  -- E key - increase pressure
    decreaseKey = 44,  -- Q key - decrease pressure
    adjustRate = 3.0,  -- How fast player can adjust

    -- Penalties
    penaltyPerSecondOutOfZone = 0.01, -- 1% pay penalty per second outside green
    explosionThreshold = 5,           -- Seconds at 0 or 100 = explosion
    explosionChance = 0.3,            -- 30% chance of explosion when critical

    -- UI Position
    uiX = 0.85,
    uiY = 0.5,
}

local hazmatState = {
    active = false,
    pressure = 50,
    timeOutOfZone = 0,
    timeCritical = 0,
    totalPenalty = 0,
    lastCollisionTime = 0,
}

-- Check if player had a collision recently
local lastVehicleHealth = 1000

local function CheckForCollision(vehicle)
    local currentHealth = GetEntityHealth(vehicle)
    local collision = currentHealth < lastVehicleHealth - 50
    lastVehicleHealth = currentHealth
    return collision
end

-- Draw the pressure gauge HUD
local function DrawHazmatGauge()
    -- Check if hazmat gauge is enabled
    if Config.UI and not Config.UI.EnableHazmatGauge then
        -- Use ox_lib textui as alternative
        if Config.UI.UseTextUI then
            local pressure = hazmatState.pressure
            local status = pressure >= HAZMAT_CONFIG.greenZoneMin and pressure <= HAZMAT_CONFIG.greenZoneMax
                and '[STABLE]' or '[UNSTABLE]'
            lib.showTextUI('Pressure: ' .. math.floor(pressure) .. '% ' .. status, {
                position = 'right-center',
            })
        end
        return
    end

    local x, y = HAZMAT_CONFIG.uiX, HAZMAT_CONFIG.uiY
    local pressure = hazmatState.pressure

    -- Background bar
    DrawRect(x, y, 0.02, 0.2, 40, 40, 40, 200)

    -- Danger zones (red)
    DrawRect(x, y - 0.075, 0.018, 0.05, 200, 50, 50, 180) -- Top danger
    DrawRect(x, y + 0.075, 0.018, 0.05, 200, 50, 50, 180) -- Bottom danger

    -- Warning zones (yellow)
    DrawRect(x, y - 0.025, 0.018, 0.05, 200, 200, 50, 180) -- Top warning
    DrawRect(x, y + 0.025, 0.018, 0.05, 200, 200, 50, 180) -- Bottom warning

    -- Green zone
    DrawRect(x, y, 0.018, 0.04, 50, 200, 50, 180)

    -- Pressure indicator (white line)
    local indicatorY = y + 0.1 - (pressure / 100 * 0.2)
    DrawRect(x, indicatorY, 0.025, 0.006, 255, 255, 255, 255)

    -- Pressure text
    local color = '~g~'
    if pressure < HAZMAT_CONFIG.warningZoneMin or pressure > HAZMAT_CONFIG.warningZoneMax then
        color = '~r~'
    elseif pressure < HAZMAT_CONFIG.greenZoneMin or pressure > HAZMAT_CONFIG.greenZoneMax then
        color = '~y~'
    end

    SetTextFont(4)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentString(color .. math.floor(pressure) .. ' PSI')
    EndTextCommandDisplayText(x - 0.025, y + 0.12)

    -- Controls hint
    SetTextFont(4)
    SetTextScale(0.25, 0.25)
    SetTextColour(180, 180, 180, 200)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentString('[E] + Pressure  [Q] - Pressure')
    EndTextCommandDisplayText(x - 0.045, y + 0.145)

    -- Warning if out of zone
    if pressure < HAZMAT_CONFIG.greenZoneMin or pressure > HAZMAT_CONFIG.greenZoneMax then
        SetTextFont(4)
        SetTextScale(0.3, 0.3)
        SetTextColour(255, 100, 100, 255)
        SetTextOutline()
        BeginTextCommandDisplayText('STRING')
        if pressure < HAZMAT_CONFIG.warningZoneMin or pressure > HAZMAT_CONFIG.warningZoneMax then
            AddTextComponentString('~r~~h~!!! CRITICAL !!!')
        else
            AddTextComponentString('~y~! PRESSURE WARNING')
        end
        EndTextCommandDisplayText(x - 0.04, y - 0.13)
    end
end

function StartHazmatMinigame(cargoData)
    if hazmatState.active then return end

    hazmatState = {
        active = true,
        pressure = 50,
        timeOutOfZone = 0,
        timeCritical = 0,
        totalPenalty = 0,
        lastCollisionTime = 0,
    }

    lib.notify({
        title = 'Hazmat Cargo Loaded',
        description = 'Keep pressure stable! [E] increase [Q] decrease',
        type = 'warning',
        duration = 5000,
    })

    -- Main hazmat loop
    CreateThread(function()
        while hazmatState.active do
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

            if vehicle and vehicle ~= 0 then
                -- Calculate drift based on speed
                local speed = GetEntitySpeed(vehicle) * 2.236936 -- Convert to mph
                local drift = HAZMAT_CONFIG.baseDrift + (speed * HAZMAT_CONFIG.speedDriftMultiplier)

                -- Random wave effect
                if math.random() < 0.1 then
                    drift = drift + (math.random() - 0.5) * HAZMAT_CONFIG.waveDrift * 2
                end

                -- Collision spike
                if CheckForCollision(vehicle) then
                    local spike = HAZMAT_CONFIG.collisionSpike * (0.5 + math.random() * 0.5)
                    if math.random() > 0.5 then
                        hazmatState.pressure = hazmatState.pressure + spike
                    else
                        hazmatState.pressure = hazmatState.pressure - spike
                    end
                    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
                end

                -- Apply random drift direction
                if math.random() > 0.5 then
                    hazmatState.pressure = hazmatState.pressure + drift * 0.1
                else
                    hazmatState.pressure = hazmatState.pressure - drift * 0.1
                end

                -- Player controls
                if IsControlPressed(0, HAZMAT_CONFIG.increaseKey) then -- E
                    hazmatState.pressure = hazmatState.pressure + HAZMAT_CONFIG.adjustRate * 0.1
                end
                if IsControlPressed(0, HAZMAT_CONFIG.decreaseKey) then -- Q
                    hazmatState.pressure = hazmatState.pressure - HAZMAT_CONFIG.adjustRate * 0.1
                end

                -- Clamp pressure
                hazmatState.pressure = math.max(0, math.min(100, hazmatState.pressure))

                -- Check zone status
                local inGreen = hazmatState.pressure >= HAZMAT_CONFIG.greenZoneMin and
                               hazmatState.pressure <= HAZMAT_CONFIG.greenZoneMax
                local inWarning = hazmatState.pressure >= HAZMAT_CONFIG.warningZoneMin and
                                 hazmatState.pressure <= HAZMAT_CONFIG.warningZoneMax
                local critical = hazmatState.pressure <= 5 or hazmatState.pressure >= 95

                if not inGreen then
                    hazmatState.timeOutOfZone = hazmatState.timeOutOfZone + 0.1
                    hazmatState.totalPenalty = hazmatState.totalPenalty +
                        (HAZMAT_CONFIG.penaltyPerSecondOutOfZone * 0.1)
                end

                if critical then
                    hazmatState.timeCritical = hazmatState.timeCritical + 0.1

                    -- Explosion check
                    if hazmatState.timeCritical >= HAZMAT_CONFIG.explosionThreshold then
                        if math.random() < HAZMAT_CONFIG.explosionChance then
                            -- BOOM
                            local coords = GetEntityCoords(vehicle)
                            AddExplosion(coords.x, coords.y, coords.z, 2, 5.0, true, false, 1.0)
                            hazmatState.active = false
                            hazmatState.totalPenalty = 1.0 -- 100% penalty

                            lib.notify({
                                title = 'HAZMAT EXPLOSION',
                                description = 'Pressure failure caused explosion!',
                                type = 'error',
                                duration = 5000,
                            })

                            TriggerServerEvent('dps-maritime:server:hazmatExplosion')
                            return
                        end
                    end
                else
                    hazmatState.timeCritical = 0
                end

                -- Draw gauge
                DrawHazmatGauge()
            end

            Wait(100) -- 10 ticks per second
        end
    end)
end

function StopHazmatMinigame()
    if not hazmatState.active then return 0 end

    hazmatState.active = false

    -- Return penalty percentage (0-1)
    return math.min(hazmatState.totalPenalty, 0.75) -- Cap at 75% penalty
end

function GetHazmatPenalty()
    return hazmatState.totalPenalty
end

-----------------------------------------------------------
-- CRANE OPERATION MINI-GAME
-- Precision movement to load/unload containers
-----------------------------------------------------------

local CRANE_CONFIG = {
    -- Movement settings
    moveSpeed = 0.5,
    lowerSpeed = 0.3,
    swayAmount = 0.02,  -- Container sway

    -- Target zone
    targetRadius = 1.5,  -- Must be within 1.5m of target
    perfectRadius = 0.5, -- Perfect placement bonus

    -- Time limits
    maxTime = 60,        -- 60 seconds max

    -- Bonuses
    perfectBonus = 0.15, -- +15% for perfect placement
    speedBonus = 0.10,   -- +10% for under 30 seconds
}

local craneState = {
    active = false,
    containerPos = vector3(0, 0, 0),
    targetPos = vector3(0, 0, 0),
    startTime = 0,
    swayOffset = 0,
}

function StartCraneMinigame(startPos, targetPos)
    if craneState.active then return end

    craneState = {
        active = true,
        containerPos = startPos,
        targetPos = targetPos,
        startTime = GetGameTimer(),
        swayOffset = 0,
    }

    lib.notify({
        title = 'Crane Operation',
        description = 'Use WASD to position, SPACE to lower',
        type = 'info',
        duration = 4000,
    })

    -- Crane control loop
    CreateThread(function()
        while craneState.active do
            -- Calculate sway
            craneState.swayOffset = math.sin(GetGameTimer() / 500) * CRANE_CONFIG.swayAmount

            -- Player controls
            local moveX, moveY = 0, 0

            if IsControlPressed(0, 32) then moveY = CRANE_CONFIG.moveSpeed end  -- W
            if IsControlPressed(0, 33) then moveY = -CRANE_CONFIG.moveSpeed end -- S
            if IsControlPressed(0, 34) then moveX = -CRANE_CONFIG.moveSpeed end -- A
            if IsControlPressed(0, 35) then moveX = CRANE_CONFIG.moveSpeed end  -- D

            craneState.containerPos = craneState.containerPos + vector3(moveX, moveY, 0)

            -- Lower container
            if IsControlPressed(0, 22) then -- SPACE
                craneState.containerPos = craneState.containerPos - vector3(0, 0, CRANE_CONFIG.lowerSpeed)
            end

            -- Draw target zone
            DrawMarker(1, craneState.targetPos.x, craneState.targetPos.y, craneState.targetPos.z - 0.5,
                0, 0, 0, 0, 0, 0,
                CRANE_CONFIG.targetRadius * 2, CRANE_CONFIG.targetRadius * 2, 0.5,
                50, 200, 50, 100, false, false, 2, false, nil, nil, false)

            -- Draw container position (with sway)
            local displayPos = craneState.containerPos + vector3(craneState.swayOffset, 0, 0)
            DrawMarker(1, displayPos.x, displayPos.y, displayPos.z,
                0, 0, 0, 0, 0, 0,
                1.0, 1.0, 2.0,
                200, 150, 50, 150, false, false, 2, false, nil, nil, false)

            -- Check if placed
            local dist = #(vector2(craneState.containerPos.x, craneState.containerPos.y) -
                          vector2(craneState.targetPos.x, craneState.targetPos.y))

            if craneState.containerPos.z <= craneState.targetPos.z + 0.5 then
                if dist <= CRANE_CONFIG.targetRadius then
                    -- Success!
                    local timeTaken = (GetGameTimer() - craneState.startTime) / 1000
                    local bonus = 0

                    if dist <= CRANE_CONFIG.perfectRadius then
                        bonus = bonus + CRANE_CONFIG.perfectBonus
                        lib.notify({
                            title = 'Perfect Placement!',
                            description = string.format('+%d%% bonus', CRANE_CONFIG.perfectBonus * 100),
                            type = 'success',
                        })
                    end

                    if timeTaken < 30 then
                        bonus = bonus + CRANE_CONFIG.speedBonus
                    end

                    craneState.active = false
                    TriggerEvent('dps-maritime:client:craneComplete', bonus)
                    return
                else
                    -- Missed - damage cargo
                    craneState.containerPos = craneState.containerPos + vector3(0, 0, 2) -- Raise back up
                    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
                    lib.notify({
                        title = 'Missed Target',
                        description = 'Reposition and try again',
                        type = 'error',
                    })
                end
            end

            -- Timeout check
            if (GetGameTimer() - craneState.startTime) / 1000 > CRANE_CONFIG.maxTime then
                craneState.active = false
                lib.notify({
                    title = 'Time Expired',
                    description = 'Crane operation failed',
                    type = 'error',
                })
                TriggerEvent('dps-maritime:client:craneFailed')
                return
            end

            Wait(0)
        end
    end)
end

-----------------------------------------------------------
-- FORKLIFT PRECISION (Level 2+)
-- Balance load while moving
-----------------------------------------------------------

local FORKLIFT_CONFIG = {
    -- Tilt settings
    maxTilt = 35,           -- Degrees before cargo falls
    tiltRecoveryRate = 5,   -- Degrees per second recovery
    tiltFromSpeed = 0.5,    -- Tilt added per mph
    tiltFromTurn = 2.0,     -- Tilt added per degree of turn

    -- Load stability
    stabilizeKey = 21,      -- LEFT SHIFT to stabilize
    stabilizeCost = 0.02,   -- 2% stamina per second
}

local forkliftState = {
    active = false,
    tilt = 0,
    hasLoad = false,
    dropCount = 0,
}

function StartForkliftMinigame()
    if forkliftState.active then return end

    forkliftState = {
        active = true,
        tilt = 0,
        hasLoad = true,
        dropCount = 0,
    }

    CreateThread(function()
        while forkliftState.active and forkliftState.hasLoad do
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle and vehicle ~= 0 then
                local speed = GetEntitySpeed(vehicle) * 2.236936
                local rotation = GetEntityRotation(vehicle)

                -- Calculate tilt from movement
                local turnRate = math.abs(GetEntityRotationVelocity(vehicle).z) * 50
                local tiltChange = (speed * FORKLIFT_CONFIG.tiltFromSpeed * 0.1) +
                                  (turnRate * FORKLIFT_CONFIG.tiltFromTurn * 0.1)

                -- Random direction
                if math.random() > 0.5 then
                    forkliftState.tilt = forkliftState.tilt + tiltChange
                else
                    forkliftState.tilt = forkliftState.tilt - tiltChange
                end

                -- Player can stabilize
                if IsControlPressed(0, FORKLIFT_CONFIG.stabilizeKey) then
                    forkliftState.tilt = forkliftState.tilt * 0.9 -- Reduce tilt
                end

                -- Natural recovery
                if forkliftState.tilt > 0 then
                    forkliftState.tilt = forkliftState.tilt - FORKLIFT_CONFIG.tiltRecoveryRate * 0.1
                elseif forkliftState.tilt < 0 then
                    forkliftState.tilt = forkliftState.tilt + FORKLIFT_CONFIG.tiltRecoveryRate * 0.1
                end

                -- Check for drop
                if math.abs(forkliftState.tilt) >= FORKLIFT_CONFIG.maxTilt then
                    forkliftState.dropCount = forkliftState.dropCount + 1
                    forkliftState.tilt = 0

                    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)

                    if forkliftState.dropCount >= Config.Forklift.MaxDrops then
                        forkliftState.hasLoad = false
                        lib.notify({
                            title = 'Cargo Destroyed',
                            description = 'Too many drops - cargo is ruined',
                            type = 'error',
                        })
                        TriggerEvent('dps-maritime:client:cargoDestroyed')
                    else
                        lib.notify({
                            title = 'Cargo Dropped!',
                            description = string.format('Drops: %d/%d - Pick it back up',
                                forkliftState.dropCount, Config.Forklift.MaxDrops),
                            type = 'warning',
                        })
                    end
                end

                -- Draw tilt indicator
                local tiltPercent = math.abs(forkliftState.tilt) / FORKLIFT_CONFIG.maxTilt

                -- Check if tilt meter is enabled
                if not Config.UI or Config.UI.EnableForkliftTilt then
                    local color = { r = 50, g = 200, b = 50 }

                    if tiltPercent > 0.7 then
                        color = { r = 200, g = 50, b = 50 }
                    elseif tiltPercent > 0.4 then
                        color = { r = 200, g = 200, b = 50 }
                    end

                    -- Simple tilt bar
                    DrawRect(0.5, 0.9, 0.15, 0.02, 40, 40, 40, 150)
                    local indicatorX = 0.5 + (forkliftState.tilt / FORKLIFT_CONFIG.maxTilt * 0.07)
                    DrawRect(indicatorX, 0.9, 0.01, 0.025, color.r, color.g, color.b, 255)

                    -- Center marker
                    DrawRect(0.5, 0.9, 0.005, 0.03, 255, 255, 255, 200)
                elseif Config.UI and Config.UI.UseTextUI then
                    -- ox_lib text alternative
                    local status = tiltPercent < 0.4 and 'STABLE' or (tiltPercent < 0.7 and 'WARNING' or 'DANGER')
                    lib.showTextUI('Tilt: ' .. status, { position = 'bottom-center' })
                end
            end

            Wait(100)
        end

        forkliftState.active = false
    end)
end

function StopForkliftMinigame()
    forkliftState.active = false
    return forkliftState.dropCount
end

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('StartHazmatMinigame', StartHazmatMinigame)
exports('StopHazmatMinigame', StopHazmatMinigame)
exports('GetHazmatPenalty', GetHazmatPenalty)
exports('StartCraneMinigame', StartCraneMinigame)
exports('StartForkliftMinigame', StartForkliftMinigame)
exports('StopForkliftMinigame', StopForkliftMinigame)
