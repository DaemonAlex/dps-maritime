--[[
    dps-maritime - Jetsam Company
    Random Sea Events System

    Dynamic encounters during boat deliveries including:
    - Engine failures
    - Rough seas
    - Coast guard encounters
    - Wildlife sightings
    - Rogue waves
    - Distress signals (rescue opportunities)
    - Storm interference
]]

local isEventActive = false
local currentEvent = nil
local eventThread = nil
local eventBlip = nil

-----------------------------------------------------------
-- EVENT CONFIGURATION
-----------------------------------------------------------

local EventConfig = {
    -- Base check interval (ms) - checks for random events
    CheckInterval = 60000, -- Every 60 seconds (less frequent checks)

    -- Minimum distance from shore before events can trigger
    MinDistanceFromShore = 200.0,

    -- Cooldown between events (ms)
    EventCooldown = 300000, -- 5 minutes between events (rare encounters)

    -- Weather increases event chance
    WeatherMultipliers = {
        CLEAR = 0.5,
        EXTRASUNNY = 0.4,
        CLOUDS = 0.8,
        OVERCAST = 1.0,
        RAIN = 1.5,
        THUNDER = 2.5,
        CLEARING = 0.7,
        NEUTRAL = 1.0,
        SNOW = 1.8,
        BLIZZARD = 3.0,
        SNOWLIGHT = 1.2,
        XMAS = 1.0,
        FOGGY = 1.5,
    },

    -- Level affects event severity
    -- Higher level = more dangerous but rewarding events
    LevelEventTiers = {
        [1] = { maxSeverity = 1, bonusChance = 0 },
        [3] = { maxSeverity = 2, bonusChance = 0.1 },
        [5] = { maxSeverity = 2, bonusChance = 0.15 },
        [7] = { maxSeverity = 3, bonusChance = 0.2 },
        [9] = { maxSeverity = 3, bonusChance = 0.25 },
    },
}

-----------------------------------------------------------
-- EVENT DEFINITIONS
-----------------------------------------------------------

local Events = {
    -----------------------------------------------------------
    -- NEGATIVE EVENTS
    -----------------------------------------------------------
    ['engine_failure'] = {
        label = 'Engine Failure',
        description = 'Your engine has stalled!',
        type = 'negative',
        severity = 1,
        baseChance = 0.03, -- Rare: ~3% per check
        duration = { min = 8000, max = 15000 },
        icon = 'wrench',
        cargoMultiplier = {
            hazmat = 0.5,        -- Less likely with hazmat (better maintained)
            illegal = 1.5,      -- More likely with contraband (rushed)
        },
        effects = {
            disableEngine = true,
        },
        onStart = function(data)
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle and DoesEntityExist(vehicle) then
                SetVehicleEngineOn(vehicle, false, true, true)
                SetVehicleUndriveable(vehicle, true)
            end

            lib.notify({
                title = 'Engine Failure!',
                description = 'Your engine has stalled. Attempting restart...',
                type = 'error',
                duration = 5000,
            })

            -- Play engine failure sound
            PlaySoundFrontend(-1, 'WEAPON_PURCHASE', 'HUD_AMMO_SHOP_SOUNDSET', false)
        end,
        onEnd = function(data)
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle and DoesEntityExist(vehicle) then
                SetVehicleUndriveable(vehicle, false)
                SetVehicleEngineOn(vehicle, true, true, false)
            end

            lib.notify({
                title = 'Engine Restored',
                description = 'Engine restarted successfully.',
                type = 'success',
            })
        end,
    },

    ['rough_seas'] = {
        label = 'Rough Seas',
        description = 'High waves affecting boat handling',
        type = 'negative',
        severity = 2,
        baseChance = 0.04, -- Rare: ~4% per check (weather dependent)
        duration = { min = 20000, max = 45000 },
        icon = 'water',
        weatherRequired = { 'RAIN', 'THUNDER', 'OVERCAST', 'FOGGY' },
        effects = {
            shakeCam = true,
            reduceHandling = true,
        },
        onStart = function(data)
            lib.notify({
                title = 'Rough Seas',
                description = 'Hold steady! High waves ahead.',
                type = 'warning',
                duration = 5000,
            })

            -- Start camera shake
            CreateThread(function()
                while currentEvent and currentEvent.id == 'rough_seas' do
                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.3)
                    Wait(2000)
                end
            end)
        end,
        onEnd = function(data)
            StopGameplayCamShaking(true)
            lib.notify({
                title = 'Seas Calming',
                description = 'Waters returning to normal.',
                type = 'inform',
            })
        end,
    },

    ['rogue_wave'] = {
        label = 'Rogue Wave',
        description = 'A massive wave hits your vessel',
        type = 'negative',
        severity = 3,
        baseChance = 0.015, -- Very rare: ~1.5% per check
        duration = { min = 3000, max = 5000 },
        icon = 'wave-square',
        weatherMultiplier = {
            THUNDER = 2.0,
            RAIN = 1.5,
        },
        effects = {
            pushBoat = true,
            damage = 10, -- 10% damage to boat
        },
        onStart = function(data)
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            lib.notify({
                title = 'ROGUE WAVE!',
                description = 'Brace for impact!',
                type = 'error',
                duration = 3000,
            })

            -- Heavy camera shake
            ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 1.0)

            -- Push the boat
            if vehicle and DoesEntityExist(vehicle) then
                local velocity = GetEntityVelocity(vehicle)
                local pushDirection = vector3(
                    math.random(-10, 10),
                    math.random(-10, 10),
                    math.random(3, 8)
                )
                SetEntityVelocity(vehicle, velocity.x + pushDirection.x, velocity.y + pushDirection.y, velocity.z + pushDirection.z)

                -- Apply damage
                local currentHealth = GetEntityHealth(vehicle)
                local maxHealth = GetEntityMaxHealth(vehicle)
                local damage = math.floor(maxHealth * 0.1)
                SetEntityHealth(vehicle, math.max(currentHealth - damage, 100))
            end
        end,
        onEnd = function(data)
            StopGameplayCamShaking(true)
        end,
    },

    ['coast_guard'] = {
        label = 'Coast Guard Patrol',
        description = 'Coast Guard vessel approaching',
        type = 'negative',
        severity = 2,
        baseChance = 0.025, -- Rare: ~2.5% per check (illegal cargo only)
        duration = { min = 30000, max = 60000 },
        icon = 'shield-halved',
        cargoRequired = { illegal = true },
        effects = {
            spawnPatrol = true,
            alertPolice = true,
        },
        onStart = function(data)
            lib.notify({
                title = 'Coast Guard Alert',
                description = 'Coast Guard patrol detected! Evade or prepare for inspection.',
                type = 'warning',
                duration = 8000,
            })

            -- Spawn coast guard boat
            SpawnCoastGuardPatrol(data)
        end,
        onEnd = function(data)
            -- Coast guard leaves if player escaped
            if data.patrolVehicle and DoesEntityExist(data.patrolVehicle) then
                DeleteEntity(data.patrolVehicle)
            end
            if data.patrolPed and DoesEntityExist(data.patrolPed) then
                DeleteEntity(data.patrolPed)
            end
            ClearEventBlip()
        end,
    },

    ['storm_interference'] = {
        label = 'Storm Interference',
        description = 'Electrical storm disrupting navigation',
        type = 'negative',
        severity = 2,
        baseChance = 0.03, -- Rare: ~3% per check (thunder only)
        duration = { min = 15000, max = 30000 },
        icon = 'bolt',
        weatherRequired = { 'THUNDER' },
        effects = {
            disableRadar = true,
            flashScreen = true,
        },
        onStart = function(data)
            lib.notify({
                title = 'Storm Interference',
                description = 'Navigation systems disrupted!',
                type = 'error',
                duration = 5000,
            })

            -- Disable radar/minimap during storm
            SetRadarZoom(0)

            -- Lightning flash effects
            CreateThread(function()
                while currentEvent and currentEvent.id == 'storm_interference' do
                    local flashChance = math.random()
                    if flashChance < 0.2 then
                        -- Screen flash
                        AnimpostfxPlay('RaceTurbo', 200, false)
                        Wait(100)
                        AnimpostfxStop('RaceTurbo')
                    end
                    Wait(math.random(1000, 4000))
                end
            end)
        end,
        onEnd = function(data)
            SetRadarZoom(0)
            AnimpostfxStop('RaceTurbo')
            lib.notify({
                title = 'Systems Online',
                description = 'Navigation restored.',
                type = 'success',
            })
        end,
    },

    -----------------------------------------------------------
    -- POSITIVE EVENTS
    -----------------------------------------------------------
    ['wildlife_sighting'] = {
        label = 'Wildlife Sighting',
        description = 'Dolphins spotted nearby!',
        type = 'positive',
        severity = 1,
        baseChance = 0.05, -- Uncommon: ~5% per check
        duration = { min = 10000, max = 20000 },
        icon = 'fish',
        rewards = {
            xp = 25,
        },
        onStart = function(data)
            lib.notify({
                title = 'Wildlife Sighting!',
                description = 'Dolphins swimming alongside your boat! (+25 XP)',
                type = 'success',
                duration = 8000,
            })

            -- Award bonus XP
            TriggerServerEvent('dps-maritime:server:awardEventXP', 25, 'Wildlife Sighting')
        end,
        onEnd = function(data)
            -- Nothing special
        end,
    },

    ['calm_waters'] = {
        label = 'Calm Waters',
        description = 'Exceptionally smooth sailing',
        type = 'positive',
        severity = 1,
        baseChance = 0.04, -- Uncommon: ~4% per check (good weather only)
        duration = { min = 30000, max = 60000 },
        icon = 'sun',
        weatherRequired = { 'CLEAR', 'EXTRASUNNY' },
        effects = {
            speedBoost = 1.1, -- 10% speed boost
        },
        onStart = function(data)
            lib.notify({
                title = 'Calm Waters',
                description = 'Perfect conditions! Slightly faster travel.',
                type = 'success',
            })
        end,
        onEnd = function(data)
            lib.notify({
                title = 'Conditions Normalizing',
                description = 'Returning to normal speed.',
                type = 'inform',
            })
        end,
    },

    ['distress_signal'] = {
        label = 'Distress Signal',
        description = 'Another vessel needs help!',
        type = 'opportunity',
        severity = 2,
        baseChance = 0.02, -- Rare: ~2% per check
        duration = { min = 120000, max = 180000 }, -- 2-3 minutes to respond
        icon = 'life-ring',
        minLevel = 5,
        rewards = {
            xp = 150,
            cash = { min = 1500, max = 3000 },
        },
        onStart = function(data)
            lib.notify({
                title = 'Distress Signal Detected!',
                description = 'A vessel needs rescue. Will you help?',
                type = 'warning',
                duration = 10000,
            })

            -- Create blip for distress location
            local playerPos = GetEntityCoords(PlayerPedId())
            local distressPos = vector3(
                playerPos.x + math.random(-400, 400),
                playerPos.y + math.random(-400, 400),
                playerPos.z
            )

            -- Store for later
            data.distressPos = distressPos

            CreateEventBlip(distressPos, 'Distress Signal', 459, 1, true)

            -- Optional: Add ox_target zone at distress location
            -- Player can investigate to get reward
        end,
        onEnd = function(data)
            ClearEventBlip()
            -- Event timed out - no penalty
        end,
        onComplete = function(data)
            -- Player reached distress location
            local reward = math.random(data.rewards.cash.min, data.rewards.cash.max)
            TriggerServerEvent('dps-maritime:server:awardEventReward', reward, data.rewards.xp, 'Rescue Mission')

            lib.notify({
                title = 'Rescue Complete!',
                description = string.format('You saved them! +$%d +%d XP', reward, data.rewards.xp),
                type = 'success',
                duration = 8000,
            })
        end,
    },

    ['floating_cargo'] = {
        label = 'Floating Cargo',
        description = 'Abandoned cargo spotted in the water',
        type = 'opportunity',
        severity = 1,
        baseChance = 0.025, -- Rare: ~2.5% per check
        duration = { min = 60000, max = 90000 },
        icon = 'box',
        minLevel = 4,
        rewards = {
            xp = 50,
            cash = { min = 500, max = 1500 },
        },
        onStart = function(data)
            lib.notify({
                title = 'Cargo Spotted!',
                description = 'Floating cargo nearby. Collect it for a bonus!',
                type = 'inform',
                duration = 8000,
            })

            local playerPos = GetEntityCoords(PlayerPedId())
            local cargoPos = vector3(
                playerPos.x + math.random(-200, 200),
                playerPos.y + math.random(-200, 200),
                playerPos.z - 1.0
            )

            data.cargoPos = cargoPos
            CreateEventBlip(cargoPos, 'Floating Cargo', 501, 5, true)
        end,
        onEnd = function(data)
            ClearEventBlip()
        end,
        onComplete = function(data)
            local reward = math.random(data.rewards.cash.min, data.rewards.cash.max)
            TriggerServerEvent('dps-maritime:server:awardEventReward', reward, data.rewards.xp, 'Salvage Bonus')

            lib.notify({
                title = 'Cargo Collected!',
                description = string.format('Salvage bonus: +$%d +%d XP', reward, data.rewards.xp),
                type = 'success',
            })
        end,
    },

    ['tailwind'] = {
        label = 'Favorable Tailwind',
        description = 'Strong tailwind boosting your speed',
        type = 'positive',
        severity = 1,
        baseChance = 0.035, -- Uncommon: ~3.5% per check
        duration = { min = 20000, max = 40000 },
        icon = 'wind',
        effects = {
            speedBoost = 1.15, -- 15% speed boost
        },
        onStart = function(data)
            lib.notify({
                title = 'Tailwind!',
                description = 'Favorable winds speeding you along!',
                type = 'success',
            })
        end,
        onEnd = function(data)
            lib.notify({
                title = 'Wind Dying Down',
                description = 'Speed returning to normal.',
                type = 'inform',
            })
        end,
    },
}

-----------------------------------------------------------
-- HELPER FUNCTIONS
-----------------------------------------------------------

local function GetCurrentWeather()
    local weatherHash = GetPrevWeatherTypeHashName()
    local weatherNames = {
        [GetHashKey('CLEAR')] = 'CLEAR',
        [GetHashKey('EXTRASUNNY')] = 'EXTRASUNNY',
        [GetHashKey('CLOUDS')] = 'CLOUDS',
        [GetHashKey('OVERCAST')] = 'OVERCAST',
        [GetHashKey('RAIN')] = 'RAIN',
        [GetHashKey('THUNDER')] = 'THUNDER',
        [GetHashKey('CLEARING')] = 'CLEARING',
        [GetHashKey('NEUTRAL')] = 'NEUTRAL',
        [GetHashKey('SNOW')] = 'SNOW',
        [GetHashKey('BLIZZARD')] = 'BLIZZARD',
        [GetHashKey('SNOWLIGHT')] = 'SNOWLIGHT',
        [GetHashKey('XMAS')] = 'XMAS',
        [GetHashKey('FOGGY')] = 'FOGGY',
    }
    return weatherNames[weatherHash] or 'CLEAR'
end

local function GetDistanceFromShore(coords)
    -- Simple check using water depth
    local _, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    local waterHeight = GetWaterHeight(coords.x, coords.y, coords.z)

    -- If we're over deep water (no ground nearby), we're far from shore
    if groundZ == 0.0 or (waterHeight - groundZ) > 10.0 then
        return 500.0 -- Far from shore
    end

    return math.abs(waterHeight - groundZ) * 10
end

local function GetPlayerLevelTier(level)
    local tier = EventConfig.LevelEventTiers[1]
    for lvl, data in pairs(EventConfig.LevelEventTiers) do
        if level >= lvl then
            tier = data
        end
    end
    return tier
end

local function IsCargoIllegal()
    local ok, jobData = pcall(function()
        return exports['dps-maritime']:GetCurrentBoatJob()
    end)
    if not ok then jobData = nil end
    if not jobData then return false end

    local cargoType = jobData.cargoType
    local cargo = Config.CargoTypes[cargoType]
    return cargo and cargo.illegal
end

local function IsCargoHazmat()
    local jobData = exports['dps-maritime']:GetCurrentBoatJob and exports['dps-maritime']:GetCurrentBoatJob()
    if not jobData then return false end

    local cargoType = jobData.cargoType
    local cargo = Config.CargoTypes[cargoType]
    return cargo and cargo.hazmat
end

function CreateEventBlip(coords, label, sprite, color, flash)
    ClearEventBlip()

    eventBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(eventBlip, sprite or 1)
    SetBlipDisplay(eventBlip, 4)
    SetBlipScale(eventBlip, 0.9)
    SetBlipColour(eventBlip, color or 1)
    SetBlipAsShortRange(eventBlip, false)

    if flash then
        SetBlipFlashes(eventBlip, true)
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextEntry('event_blip', label or 'Event')
    EndTextCommandSetBlipName(eventBlip)
end

function ClearEventBlip()
    if eventBlip and DoesBlipExist(eventBlip) then
        RemoveBlip(eventBlip)
        eventBlip = nil
    end
end

-----------------------------------------------------------
-- COAST GUARD PATROL SPAWNING
-----------------------------------------------------------

function SpawnCoastGuardPatrol(eventData)
    local playerPos = GetEntityCoords(PlayerPedId())

    -- Spawn position offset from player
    local angle = math.rad(math.random(0, 360))
    local distance = math.random(150, 250)
    local spawnPos = vector3(
        playerPos.x + math.cos(angle) * distance,
        playerPos.y + math.sin(angle) * distance,
        playerPos.z
    )

    -- Request models
    local boatModel = 'predator'
    local pedModel = 's_m_y_uscg_01'

    lib.requestModel(boatModel, 5000)
    lib.requestModel(pedModel, 5000)

    -- Spawn boat
    local boat = CreateVehicle(
        joaat(boatModel),
        spawnPos.x, spawnPos.y, spawnPos.z + 1.0,
        GetHeadingFromVector_2d(playerPos.x - spawnPos.x, playerPos.y - spawnPos.y),
        true, false
    )

    SetEntityAsMissionEntity(boat, true, true)
    SetVehicleEngineOn(boat, true, true, false)
    SetModelAsNoLongerNeeded(joaat(boatModel))

    -- Spawn pilot
    local pilot = CreatePedInsideVehicle(
        boat, 4, joaat(pedModel), -1, true, false
    )

    SetEntityAsMissionEntity(pilot, true, true)
    SetPedRelationshipGroupHash(pilot, GetHashKey('COP'))
    GiveWeaponToPed(pilot, GetHashKey('WEAPON_PISTOL'), 100, false, true)
    SetModelAsNoLongerNeeded(joaat(pedModel))

    -- Task: Chase player
    TaskVehicleChase(pilot, PlayerPedId())
    SetPedKeepTask(pilot, true)

    -- Store references
    eventData.patrolVehicle = boat
    eventData.patrolPed = pilot

    -- Create blip for patrol
    CreateEventBlip(spawnPos, 'Coast Guard', 455, 3, true)
end

-----------------------------------------------------------
-- EVENT SELECTION
-----------------------------------------------------------

local function SelectRandomEvent()
    local level = exports['dps-maritime']:GetPlayerLevel() or 1
    local levelTier = GetPlayerLevelTier(level)
    local weather = GetCurrentWeather()
    local weatherMult = EventConfig.WeatherMultipliers[weather] or 1.0

    local isIllegal = IsCargoIllegal()
    local isHazmat = IsCargoHazmat()

    local eligibleEvents = {}

    for eventId, event in pairs(Events) do
        local eligible = true
        local chance = event.baseChance * weatherMult

        -- Check severity
        if event.severity > levelTier.maxSeverity then
            eligible = false
        end

        -- Check minimum level
        if event.minLevel and level < event.minLevel then
            eligible = false
        end

        -- Check weather requirements
        if event.weatherRequired then
            local weatherMatch = false
            for _, w in ipairs(event.weatherRequired) do
                if w == weather then
                    weatherMatch = true
                    break
                end
            end
            if not weatherMatch then
                eligible = false
            end
        end

        -- Check cargo requirements
        if event.cargoRequired then
            if event.cargoRequired.illegal and not isIllegal then
                eligible = false
            end
            if event.cargoRequired.hazmat and not isHazmat then
                eligible = false
            end
        end

        -- Apply cargo multipliers
        if event.cargoMultiplier then
            if isIllegal and event.cargoMultiplier.illegal then
                chance = chance * event.cargoMultiplier.illegal
            end
            if isHazmat and event.cargoMultiplier.hazmat then
                chance = chance * event.cargoMultiplier.hazmat
            end
        end

        -- Apply weather-specific multipliers
        if event.weatherMultiplier and event.weatherMultiplier[weather] then
            chance = chance * event.weatherMultiplier[weather]
        end

        -- Bonus chance for higher levels
        if event.type == 'positive' or event.type == 'opportunity' then
            chance = chance * (1 + levelTier.bonusChance)
        end

        if eligible then
            table.insert(eligibleEvents, { id = eventId, event = event, chance = chance })
        end
    end

    -- Roll for each eligible event
    local selectedEvent = nil
    for _, entry in ipairs(eligibleEvents) do
        if math.random() < entry.chance then
            selectedEvent = entry
            break
        end
    end

    return selectedEvent
end

-----------------------------------------------------------
-- EVENT EXECUTION
-----------------------------------------------------------

local function StartEvent(eventEntry)
    if isEventActive then return end

    local eventId = eventEntry.id
    local event = eventEntry.event

    isEventActive = true
    currentEvent = {
        id = eventId,
        event = event,
        startTime = GetGameTimer(),
        data = {},
    }

    -- Calculate duration
    local duration = math.random(event.duration.min, event.duration.max)
    currentEvent.endTime = currentEvent.startTime + duration

    -- Copy rewards reference
    if event.rewards then
        currentEvent.data.rewards = event.rewards
    end

    -- Call onStart
    if event.onStart then
        event.onStart(currentEvent.data)
    end

    -- Start event thread
    eventThread = CreateThread(function()
        local eventData = currentEvent

        -- Wait for duration
        Wait(duration)

        -- Event ended naturally
        if currentEvent and currentEvent.id == eventId then
            EndEvent(false)
        end
    end)

    -- For opportunity events, monitor if player reaches location
    if event.type == 'opportunity' and (currentEvent.data.distressPos or currentEvent.data.cargoPos) then
        CreateThread(function()
            local targetPos = currentEvent.data.distressPos or currentEvent.data.cargoPos

            while currentEvent and currentEvent.id == eventId do
                Wait(1000)

                local playerPos = GetEntityCoords(PlayerPedId())
                local dist = #(playerPos - targetPos)

                if dist < 30.0 then
                    -- Player reached the location
                    if event.onComplete then
                        event.onComplete(currentEvent.data)
                    end
                    EndEvent(true)
                    break
                end
            end
        end)
    end
end

function EndEvent(completed)
    if not currentEvent then return end

    local event = currentEvent.event

    -- Call onEnd
    if event.onEnd and not completed then
        event.onEnd(currentEvent.data)
    end

    -- Cleanup
    ClearEventBlip()
    StopGameplayCamShaking(true)
    AnimpostfxStop('RaceTurbo')

    -- Clean up patrol if exists
    if currentEvent.data.patrolVehicle and DoesEntityExist(currentEvent.data.patrolVehicle) then
        DeleteEntity(currentEvent.data.patrolVehicle)
    end
    if currentEvent.data.patrolPed and DoesEntityExist(currentEvent.data.patrolPed) then
        DeleteEntity(currentEvent.data.patrolPed)
    end

    isEventActive = false
    currentEvent = nil
    eventThread = nil
end

-----------------------------------------------------------
-- MAIN EVENT LOOP
-----------------------------------------------------------

local lastEventTime = 0

CreateThread(function()
    while true do
        Wait(EventConfig.CheckInterval)

        -- Check if player is on a boat delivery
        local onDuty = Maritime and Maritime.AmIOnDuty and Maritime.AmIOnDuty()
        local jobType = Maritime and Maritime.GetMyJobType and Maritime.GetMyJobType()

        if onDuty and jobType == 'boat' then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            -- Must be in a boat
            if vehicle and DoesEntityExist(vehicle) and IsThisModelABoat(GetEntityModel(vehicle)) then
                local coords = GetEntityCoords(ped)
                local distFromShore = GetDistanceFromShore(coords)

                -- Only trigger events when far enough from shore
                if distFromShore >= EventConfig.MinDistanceFromShore then
                    local currentTime = GetGameTimer()

                    -- Check cooldown
                    if not isEventActive and (currentTime - lastEventTime) >= EventConfig.EventCooldown then
                        local selectedEvent = SelectRandomEvent()

                        if selectedEvent then
                            lastEventTime = currentTime
                            StartEvent(selectedEvent)
                        end
                    end
                end
            end
        else
            -- Not on duty, end any active event
            if isEventActive then
                EndEvent(false)
            end
        end
    end
end)

-----------------------------------------------------------
-- SPEED BOOST EFFECT HANDLER
-----------------------------------------------------------

CreateThread(function()
    while true do
        Wait(100)

        if currentEvent and currentEvent.event.effects and currentEvent.event.effects.speedBoost then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle and DoesEntityExist(vehicle) then
                local speedBoost = currentEvent.event.effects.speedBoost
                local currentSpeed = GetEntitySpeed(vehicle)
                local heading = GetEntityHeading(vehicle)

                -- Apply slight forward boost
                if currentSpeed > 1.0 then
                    local boostAmount = (speedBoost - 1.0) * 0.5
                    ApplyForceToEntity(
                        vehicle, 1,
                        0.0, boostAmount, 0.0,
                        0.0, 0.0, 0.0,
                        0, true, true, true, false, true
                    )
                end
            end
        end
    end
end)

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('IsEventActive', function()
    return isEventActive
end)

exports('GetCurrentEvent', function()
    if currentEvent then
        return {
            id = currentEvent.id,
            label = currentEvent.event.label,
            type = currentEvent.event.type,
            startTime = currentEvent.startTime,
            endTime = currentEvent.endTime,
        }
    end
    return nil
end)

exports('ForceEvent', function(eventId)
    if Events[eventId] and not isEventActive then
        StartEvent({ id = eventId, event = Events[eventId], chance = 1.0 })
        return true
    end
    return false
end)

exports('EndCurrentEvent', function()
    if isEventActive then
        EndEvent(false)
        return true
    end
    return false
end)

-----------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if isEventActive then
        EndEvent(false)
    end

    ClearEventBlip()
    StopGameplayCamShaking(true)
    AnimpostfxStop('RaceTurbo')
end)
