-- SetFogDensity is not a FiveM native; emulate with a timecycle modifier
local fogTcActive = false
local function SetFogDensity(intensity)
    if intensity and intensity > 0.01 then
        SetTimecycleModifier('prologue_ending_fog')
        SetTimecycleModifierStrength(math.min(intensity, 1.0))
        fogTcActive = true
    elseif fogTcActive then
        ClearTimecycleModifier()
        fogTcActive = false
    end
end

--[[
    dps-maritime - Jetsam Company
    Weather Zones System
    Localized weather effects that add risk/reward to maritime journeys
]]

-- Uses Bridge for framework abstraction

-- State
local ActiveWeatherZone = nil
local WeatherZoneThread = nil
local ZoneEntered = false
local ZonePayBonus = 0
local OriginalWeather = nil

-----------------------------------------------------------
-- WEATHER ZONE DETECTION
-----------------------------------------------------------

local function GetCurrentWeatherZone(playerPos)
    if not Config.WeatherZones then return nil end

    for zoneId, zone in pairs(Config.WeatherZones) do
        local distance = #(vector3(playerPos.x, playerPos.y, 0) - vector3(zone.coords.x, zone.coords.y, 0))
        if distance <= zone.radius then
            return zoneId, zone
        end
    end

    return nil, nil
end

-----------------------------------------------------------
-- WEATHER EFFECTS
-----------------------------------------------------------

local function ApplyWeatherZoneEffects(zone)
    if not zone or not zone.effects then return end

    local effects = zone.effects
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    -- Apply drift force (simulated wave push)
    if effects.driftForce and effects.driftForce > 0 and vehicle ~= 0 then
        local heading = GetEntityHeading(vehicle)
        local driftAngle = heading + 90 -- Perpendicular to heading
        local driftX = math.sin(math.rad(driftAngle)) * effects.driftForce
        local driftY = math.cos(math.rad(driftAngle)) * effects.driftForce

        ApplyForceToEntity(vehicle, 1, driftX, driftY, 0.0, 0.0, 0.0, 0.0, false, true, true, true, false, true)
    end

    -- Apply wave damage
    if effects.waveDamage and effects.waveDamage > 0 and vehicle ~= 0 then
        -- Only apply damage every second
        local health = GetEntityHealth(vehicle)
        local newHealth = health - effects.waveDamage
        if newHealth > 0 then
            SetEntityHealth(vehicle, newHealth)
        end
    end

    -- Engine stall chance
    if effects.engineStallChance and effects.engineStallChance > 0 and vehicle ~= 0 then
        if math.random() < effects.engineStallChance then
            SetVehicleEngineOn(vehicle, false, true, true)
            lib.notify({
                title = 'Engine Stall',
                description = 'Rough seas caused engine failure! Restart required.',
                type = 'error',
            })
        end
    end
end

local function ApplyVisibilityEffect(zone)
    if not zone or not zone.effects then return end

    local effects = zone.effects

    -- Apply visibility reduction (fog/rain effect)
    if effects.visibilityMult and effects.visibilityMult < 1.0 then
        -- Use game's timecycle modifiers for visibility
        local intensity = 1.0 - effects.visibilityMult

        if zone.weatherType == 'fog' then
            SetFogDensity(intensity)
        elseif zone.weatherType == 'thunder' or zone.weatherType == 'rain' then
            -- Rain already handled by weather, just adjust fog
            SetFogDensity(intensity * 0.5)
        end
    end
end

-----------------------------------------------------------
-- WEATHER ZONE THREAD
-----------------------------------------------------------

local function StartWeatherZoneMonitor()
    if WeatherZoneThread then return end

    WeatherZoneThread = CreateThread(function()
        local lastDamageTime = 0

        while true do
            Wait(500) -- Check every 500ms

            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)
            local currentTime = GetGameTimer()

            local zoneId, zone = GetCurrentWeatherZone(playerPos)

            if zone and not ZoneEntered then
                -- Entered a new weather zone
                ZoneEntered = true
                ActiveWeatherZone = zone
                ZonePayBonus = zone.payBonus or 0

                -- Store original weather
                OriginalWeather = GetPrevWeatherTypeHashName()

                -- Set zone weather
                if zone.weatherType then
                    SetWeatherTypePersist(zone.weatherType)
                    SetWeatherTypeNow(zone.weatherType)
                    SetWeatherTypeNowPersist(zone.weatherType)
                end

                lib.notify({
                    title = 'Weather Warning',
                    description = zone.description or ('Entering ' .. zone.name),
                    type = 'warning',
                    duration = 7000,
                })

                -- Show pay bonus
                if zone.payBonus and zone.payBonus > 0 then
                    lib.notify({
                        title = 'Risk Bonus',
                        description = string.format('+%d%% pay for crossing this zone', math.floor(zone.payBonus * 100)),
                        type = 'inform',
                    })
                end

                Maritime.Debug('Entered weather zone: ' .. zone.name)

            elseif not zone and ZoneEntered then
                -- Exited weather zone
                ZoneEntered = false

                lib.notify({
                    title = 'Weather Clear',
                    description = 'You have exited the hazardous zone',
                    type = 'success',
                })

                -- Restore original weather
                if OriginalWeather then
                    ClearWeatherTypePersist()
                    SetWeatherTypeNow(OriginalWeather)
                end

                -- Track zone crossing bonus
                if ZonePayBonus > 0 then
                    TriggerServerEvent('dps-maritime:server:zoneBonus', ZonePayBonus)
                end

                ActiveWeatherZone = nil
                ZonePayBonus = 0

                Maritime.Debug('Exited weather zone')
            end

            -- Apply effects while in zone
            if ZoneEntered and ActiveWeatherZone then
                -- Apply visibility effects every frame in a separate fast loop
                ApplyVisibilityEffect(ActiveWeatherZone)

                -- Apply damage/drift effects every second
                if currentTime - lastDamageTime >= 1000 then
                    lastDamageTime = currentTime
                    ApplyWeatherZoneEffects(ActiveWeatherZone)
                end
            end
        end
    end)

    -- Fast loop for visibility effects when in zone
    CreateThread(function()
        while true do
            if ZoneEntered and ActiveWeatherZone then
                Wait(0)
                -- Re-read after the frame yield: the zone-exit loop can nil
                -- ActiveWeatherZone during that exact frame (was a crash)
                local zone = ActiveWeatherZone
                if zone and zone.weatherType then
                    SetWeatherTypePersist(zone.weatherType)
                end
            else
                Wait(500)
            end
        end
    end)
end

-----------------------------------------------------------
-- INITIALIZATION
-----------------------------------------------------------

CreateThread(function()
    Wait(2000) -- Wait for config to load

    if Config.WeatherZones and next(Config.WeatherZones) then
        StartWeatherZoneMonitor()
        Maritime.Debug('Weather zone system initialized with ' .. Maritime.TableLength(Config.WeatherZones) .. ' zones')
    else
        Maritime.Debug('No weather zones configured')
    end
end)

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('IsInWeatherZone', function()
    return ZoneEntered
end)

exports('GetCurrentWeatherZoneBonus', function()
    return ZonePayBonus
end)

exports('GetActiveWeatherZone', function()
    return ActiveWeatherZone
end)

-----------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Restore weather
    if OriginalWeather then
        ClearWeatherTypePersist()
        SetWeatherTypeNow(OriginalWeather)
    end
end)
