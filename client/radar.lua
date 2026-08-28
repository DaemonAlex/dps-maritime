--[[
    dps-maritime - Jetsam Company
    Smuggler's Radar System (Level 9+)

    Shows nearby police boats and coast guard vessels for illegal cargo runners
]]

-- Uses Bridge for framework abstraction

-- Local state
local radarEnabled = false
local radarBlips = {}
local emergencyVehicles = {}
local radarUpdateThread = nil

-- Vehicle class IDs
local VEHICLE_CLASS_EMERGENCY = 18  -- Police, Ambulance, Fire
local VEHICLE_CLASS_HELICOPTER = 15
local VEHICLE_CLASS_BOAT = 14

-- Radar configuration
local RADAR_CONFIG = {
    range = 1500.0,              -- Detection range in meters
    updateInterval = 3000,       -- Update every 3 seconds (slower = less precise)
    pingInterval = 5000,         -- Directional ping every 5 seconds

    -- Distance accuracy (adds randomness to readings)
    distanceAccuracy = 0.15,     -- +/- 15% error on distance readings

    -- False positive settings
    falsePositiveChance = 0.20,  -- 20% chance of false positive near civil services
    falsePositiveRange = 300.0,  -- Range to check for hospitals/fire stations

    -- Malfunction settings
    malfunctionChance = 0.05,    -- 5% chance per update to malfunction
    malfunctionDuration = 10000, -- 10 seconds of static

    -- Proximity beep thresholds
    beepThresholds = {
        { distance = 300,  interval = 500,  sound = 'BEEP_RED' },
        { distance = 600,  interval = 1000, sound = 'BEEP_ORANGE' },
        { distance = 1000, interval = 2000, sound = 'BEEP_YELLOW' },
        { distance = 1500, interval = 4000, sound = 'BEEP_GREEN' },
    },
}

-- Civil service locations that cause false positives
local CIVIL_SERVICE_LOCATIONS = {
    -- Hospitals
    vector3(298.0, -584.0, 43.0),    -- Pillbox Hill Medical
    vector3(-449.0, -340.0, 34.0),   -- Mt Zonah Medical
    vector3(1839.0, 3672.0, 34.0),   -- Sandy Shores Medical
    vector3(-247.0, 6331.0, 32.0),   -- Paleto Bay Medical

    -- Fire Stations
    vector3(213.0, -1642.0, 29.0),   -- Davis Fire Station
    vector3(1193.0, -1473.0, 34.0),  -- El Burro Fire Station
    vector3(-634.0, -121.0, 39.0),   -- Rockford Hills Fire
    vector3(-2095.0, 2830.0, 32.0),  -- Route 68 Fire Station

    -- Police Stations (radar picks up parked cruisers)
    vector3(425.0, -980.0, 30.0),    -- Mission Row PD
    vector3(-1108.0, -845.0, 19.0),  -- Vespucci PD
    vector3(1853.0, 3690.0, 34.0),   -- Sandy Shores Sheriff
    vector3(-448.0, 6014.0, 31.0),   -- Paleto Bay Sheriff
}

-----------------------------------------------------------
-- RADAR STATE
-----------------------------------------------------------

local radarMalfunctioning = false
local radarJammed = false
local lastBeepTime = 0
local lastPingTime = 0
local playerHeatLevel = 0

-----------------------------------------------------------
-- JAMMER DETECTION
-----------------------------------------------------------

-- Check if any nearby police have jammers active
local function CheckForJammers()
    if not Config.PoliceJammer or not Config.PoliceJammer.Enabled then
        return false
    end

    local playerCoords = GetEntityCoords(PlayerPedId())

    -- Check all players for jammer status (synced via state bags)
    for _, playerId in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed and targetPed ~= PlayerPedId() then
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(playerCoords - targetCoords)

            if dist <= Config.PoliceJammer.JammerRadius then
                -- Check if this player has jammer active (via state bag)
                local hasJammer = Entity(targetPed).state.policeJammerActive
                if hasJammer then
                    return true
                end
            end
        end
    end

    return false
end

-- Get jammed display text with static
local function GetJammedStaticText()
    local chars = Config.PoliceJammer.StaticChars
    local result = ''
    for i = 1, 15 do
        result = result .. chars[math.random(#chars)]
    end
    return result
end

-- Scramble direction when jammed
local function ScrambleDirection(realDirection)
    if not Config.PoliceJammer.DirectionScramble then
        return realDirection
    end

    local directions = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }
    return directions[math.random(#directions)]
end

-----------------------------------------------------------
-- HEAT LEVEL FUNCTIONS
-----------------------------------------------------------

local function GetHeatThreshold(heat)
    if not Config.HeatLevel or not Config.HeatLevel.Enabled then
        return nil
    end

    local currentThreshold = nil
    for threshold, data in pairs(Config.HeatLevel.Thresholds) do
        if heat >= threshold then
            if not currentThreshold or threshold > currentThreshold then
                currentThreshold = threshold
            end
        end
    end

    if currentThreshold then
        return Config.HeatLevel.Thresholds[currentThreshold]
    end
    return nil
end

local function GetRadarAccuracyFromHeat()
    local threshold = GetHeatThreshold(playerHeatLevel)
    if threshold and threshold.radarAccuracy then
        return threshold.radarAccuracy
    end
    return 1.0
end

-- Sync heat level from server
RegisterNetEvent('dps-maritime:client:updateHeatLevel', function(heat)
    playerHeatLevel = heat
end)

-----------------------------------------------------------
-- HELPER FUNCTIONS
-----------------------------------------------------------

-- Get compass direction from angle
local function GetCompassDirection(angle)
    -- Normalize angle to 0-360
    angle = angle % 360
    if angle < 0 then angle = angle + 360 end

    if angle >= 337.5 or angle < 22.5 then return 'N'
    elseif angle >= 22.5 and angle < 67.5 then return 'NE'
    elseif angle >= 67.5 and angle < 112.5 then return 'E'
    elseif angle >= 112.5 and angle < 157.5 then return 'SE'
    elseif angle >= 157.5 and angle < 202.5 then return 'S'
    elseif angle >= 202.5 and angle < 247.5 then return 'SW'
    elseif angle >= 247.5 and angle < 292.5 then return 'W'
    else return 'NW' end
end

-- Get direction from player to target
local function GetDirectionTo(targetCoords)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local playerHeading = GetEntityHeading(PlayerPedId())

    -- Calculate angle to target
    local dx = targetCoords.x - playerCoords.x
    local dy = targetCoords.y - playerCoords.y
    local angleToTarget = math.deg(math.atan2(dy, dx))

    -- Convert to compass bearing (0 = North)
    local bearing = (90 - angleToTarget) % 360

    return GetCompassDirection(bearing), bearing
end

-- Add inaccuracy to distance readings
local function GetFuzzyDistance(actualDistance)
    local error = actualDistance * RADAR_CONFIG.distanceAccuracy
    local fuzzy = actualDistance + (math.random() * error * 2 - error)
    -- Round to nearest 50m for realism
    return math.floor(fuzzy / 50) * 50
end

-- Get rough distance description
local function GetDistanceDescription(distance)
    if distance < 200 then return 'VERY CLOSE', '~r~'
    elseif distance < 500 then return 'CLOSE', '~o~'
    elseif distance < 1000 then return 'NEARBY', '~y~'
    else return 'DISTANT', '~w~' end
end

-- Check if near civil services (causes false positives)
local function IsNearCivilServices()
    local playerCoords = GetEntityCoords(PlayerPedId())

    for _, location in ipairs(CIVIL_SERVICE_LOCATIONS) do
        if #(playerCoords - location) < RADAR_CONFIG.falsePositiveRange then
            return true
        end
    end
    return false
end

-- Generate false positive contact
local function GenerateFalsePositive()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local randomAngle = math.random() * 360
    local randomDist = math.random(400, 1200)

    local fakeX = playerCoords.x + math.cos(math.rad(randomAngle)) * randomDist
    local fakeY = playerCoords.y + math.sin(math.rad(randomAngle)) * randomDist

    return {
        coords = vector3(fakeX, fakeY, playerCoords.z),
        distance = randomDist,
        vehicleType = math.random() > 0.5 and 'cars' or 'boats',
        isFalsePositive = true,
        occupied = false,
        sirensOn = false,
    }
end

-- Play proximity beep based on distance
local function PlayProximityBeep(distance)
    local now = GetGameTimer()

    for _, threshold in ipairs(RADAR_CONFIG.beepThresholds) do
        if distance <= threshold.distance then
            if now - lastBeepTime >= threshold.interval then
                -- Play beep sound
                PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
                lastBeepTime = now
            end
            return
        end
    end
end

local function GetVehicleType(vehicle)
    local vehClass = GetVehicleClass(vehicle)

    if vehClass == VEHICLE_CLASS_HELICOPTER then
        return 'helicopters'
    elseif vehClass == VEHICLE_CLASS_BOAT then
        return 'boats'
    else
        return 'cars'
    end
end

local function IsEmergencyVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false, nil end

    local vehClass = GetVehicleClass(vehicle)

    -- Emergency class (18) = police, ambulance, fire trucks
    if vehClass == VEHICLE_CLASS_EMERGENCY then
        return true, 'cars'
    end

    -- Also check helicopters with sirens (police helis)
    if vehClass == VEHICLE_CLASS_HELICOPTER then
        if IsVehicleSirenOn(vehicle) or GetVehicleClass(vehicle) == VEHICLE_CLASS_EMERGENCY then
            return true, 'helicopters'
        end
        -- Check if it has emergency lights capability
        if DoesVehicleHaveSiren(vehicle) then
            return true, 'helicopters'
        end
    end

    -- Check boats with sirens (coast guard)
    if vehClass == VEHICLE_CLASS_BOAT then
        if DoesVehicleHaveSiren(vehicle) then
            return true, 'boats'
        end
    end

    return false, nil
end

local function GetNearbyEmergencyVehicles(range)
    local emergencyVehicles = {}
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Get all vehicles in range
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(vehicles) do
        local isEmergency, vehicleType = IsEmergencyVehicle(vehicle)
        if isEmergency then
            local vehCoords = GetEntityCoords(vehicle)
            local distance = #(playerCoords - vehCoords)

            if distance <= range then
                -- Check if occupied by player
                local driver = GetPedInVehicleSeat(vehicle, -1)
                local isOccupied = driver ~= 0 and IsPedAPlayer(driver)

                -- Check if sirens are active
                local sirensOn = IsVehicleSirenOn(vehicle)

                table.insert(emergencyVehicles, {
                    entity = vehicle,
                    coords = vehCoords,
                    distance = distance,
                    occupied = isOccupied,
                    sirensOn = sirensOn,
                    heading = GetEntityHeading(vehicle),
                    vehicleType = vehicleType,
                })
            end
        end
    end

    -- Sort by distance (closest first)
    table.sort(emergencyVehicles, function(a, b) return a.distance < b.distance end)

    return emergencyVehicles
end

-- Count vehicles by type
local function CountByType(vehicles)
    local counts = { boats = 0, cars = 0, helicopters = 0 }
    for _, v in ipairs(vehicles) do
        if counts[v.vehicleType] then
            counts[v.vehicleType] = counts[v.vehicleType] + 1
        end
    end
    return counts
end

local function ClearRadarBlips()
    for _, blip in ipairs(radarBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    radarBlips = {}
end

-- NO BLIPS - Directional radar only shows pings on HUD
local function UpdateRadarBlips()
    -- Clear any old blips (we don't use them anymore)
    ClearRadarBlips()

    -- Check for police jammers
    radarJammed = CheckForJammers()

    -- Check for malfunction (more likely if high heat)
    local malfunctionChance = RADAR_CONFIG.malfunctionChance
    local heatThreshold = GetHeatThreshold(playerHeatLevel)
    if heatThreshold then
        -- Higher heat = more interference
        malfunctionChance = malfunctionChance + (1 - (heatThreshold.radarAccuracy or 1)) * 0.1
    end

    if math.random() < malfunctionChance then
        radarMalfunctioning = true
        PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

        SetTimeout(RADAR_CONFIG.malfunctionDuration, function()
            radarMalfunctioning = false
            PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end)
    end

    -- If jammed, add extra false positives
    if radarJammed and Config.PoliceJammer then
        if math.random() < Config.PoliceJammer.FalseContactChance then
            table.insert(emergencyVehicles, GenerateFalsePositive())
        end
    end

    -- Add false positives if near civil services
    if IsNearCivilServices() and math.random() < RADAR_CONFIG.falsePositiveChance then
        table.insert(emergencyVehicles, GenerateFalsePositive())
    end

    -- Re-sort by distance
    table.sort(emergencyVehicles, function(a, b) return a.distance < b.distance end)

    -- Play proximity beep for closest contact (muffled if jammed)
    if #emergencyVehicles > 0 and not radarMalfunctioning then
        if not radarJammed then
            PlayProximityBeep(emergencyVehicles[1].distance)
        elseif math.random() > Config.PoliceJammer.StaticIntensity then
            -- Occasionally beep through static
            PlayProximityBeep(emergencyVehicles[1].distance)
        end
    end
end

-- OPTIMIZED: Use ox_lib textUI instead of native drawing
-- Native drawing uses heavy Scaleform memory every frame
local radarTextUIShown = false
local lastRadarUIUpdate = 0
local RADAR_UI_UPDATE_INTERVAL = 250 -- Update every 250ms

local function BuildRadarText()
    local lines = {}

    -- Heat indicator
    local heatThreshold = GetHeatThreshold(playerHeatLevel)
    local heatLabel = ''
    if heatThreshold then
        heatLabel = ' [' .. heatThreshold.label .. ']'
    end

    table.insert(lines, '**[SMUGGLER RADAR]**' .. heatLabel)

    -- Check for jamming
    if radarJammed then
        table.insert(lines, '/// JAMMED ///')
        table.insert(lines, '! SIGNAL JAMMED - COP NEARBY')
        return table.concat(lines, '  \n'), 'tower-broadcast', '#800080CC'
    end

    -- Check for malfunction
    if radarMalfunctioning then
        table.insert(lines, '/// SIGNAL LOST ///')
        return table.concat(lines, '  \n'), 'circle-exclamation', '#8B0000CC'
    end

    if #emergencyVehicles == 0 then
        table.insert(lines, '✓ NO CONTACTS')
        return table.concat(lines, '  \n'), 'shield-check', '#228B22CC'
    else
        -- Show up to 3 contacts
        local maxShow = math.min(#emergencyVehicles, 3)

        for i = 1, maxShow do
            local contact = emergencyVehicles[i]
            local direction, _ = GetDirectionTo(contact.coords)
            local distDesc, _ = GetDistanceDescription(contact.distance)

            -- Type icon
            local typeIcon = contact.vehicleType == 'helicopters' and '🚁' or
                            (contact.vehicleType == 'boats' and '🚤' or '🚔')

            -- Build contact string
            local status = contact.sirensOn and 'SIRENS!' or (contact.occupied and 'ACTIVE' or 'idle')
            local contactStr = string.format('%s %s %s (%s)', typeIcon, direction, distDesc, status)

            if contact.isFalsePositive then
                contactStr = contactStr .. ' ?'
            end

            table.insert(lines, contactStr)
        end

        -- More contacts indicator
        if #emergencyVehicles > 3 then
            table.insert(lines, string.format('+ %d more...', #emergencyVehicles - 3))
        end

        -- Interference warning
        if IsNearCivilServices() then
            table.insert(lines, '⚠ INTERFERENCE DETECTED')
        end

        -- Color based on threat level
        local bgColor = '#14285ACC' -- Default blue
        if emergencyVehicles[1] and emergencyVehicles[1].distance < 200 then
            bgColor = '#8B0000CC' -- Red for close
        elseif emergencyVehicles[1] and emergencyVehicles[1].distance < 500 then
            bgColor = '#8B4000CC' -- Orange for medium
        end

        return table.concat(lines, '  \n'), 'satellite-dish', bgColor
    end
end

local function UpdateRadarHUD()
    -- Throttle updates to reduce overhead
    if GetGameTimer() - lastRadarUIUpdate < RADAR_UI_UPDATE_INTERVAL then
        return
    end
    lastRadarUIUpdate = GetGameTimer()

    local text, icon, bgColor = BuildRadarText()

    lib.showTextUI(text, { style = { backgroundColor = '#1b2340', color = '#f4f1ea', borderLeft = '3px solid #ff7a45' }, iconColor = '#ff7a45', position = 'top-left',
        icon = icon,
        style = {
            borderRadius = 5,
            backgroundColor = bgColor,
        }
    })
    radarTextUIShown = true
end

local function HideRadarHUD()
    if radarTextUIShown then
        lib.hideTextUI()
        radarTextUIShown = false
    end
end

-- Legacy function name for compatibility
local function DrawRadarHUD()
    UpdateRadarHUD()
end

-----------------------------------------------------------
-- RADAR CONTROL
-----------------------------------------------------------

local function StartRadar()
    if radarEnabled then return end

    radarEnabled = true

    -- Update thread (data gathering)
    radarUpdateThread = CreateThread(function()
        while radarEnabled do
            emergencyVehicles = GetNearbyEmergencyVehicles(RADAR_CONFIG.range)
            UpdateRadarBlips()
            Wait(RADAR_CONFIG.updateInterval)
        end
    end)

    -- OPTIMIZED: HUD update thread - no longer uses Wait(0)
    -- ox_lib textUI is throttled internally, we just need to trigger updates
    CreateThread(function()
        while radarEnabled do
            UpdateRadarHUD()
            Wait(250) -- Update UI every 250ms instead of every frame
        end
    end)

    -- Play activation sound
    PlaySoundFrontend(-1, 'PICK_UP_COLLECTION', 'HUD_FRONTEND_CUSTOM_SOUNDSET', true)

    lib.notify({
        title = 'Smuggler\'s Radar',
        description = 'Radar activated - scanning for coast guard',
        type = 'success',
        duration = 3000,
    })
end

local function StopRadar()
    if not radarEnabled then return end

    radarEnabled = false
    ClearRadarBlips()
    emergencyVehicles = {}

    -- IMPORTANT: Hide the textUI when stopping radar
    HideRadarHUD()

    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

    lib.notify({
        title = 'Smuggler\'s Radar',
        description = 'Radar deactivated',
        type = 'inform',
        duration = 2000,
    })
end

local function ToggleRadar()
    if radarEnabled then
        StopRadar()
    else
        StartRadar()
    end
end

-----------------------------------------------------------
-- PUBLIC FUNCTIONS
-----------------------------------------------------------

function IsRadarEnabled()
    return radarEnabled
end

function GetEmergencyVehicleCount()
    return #emergencyVehicles
end

function GetClosestEmergencyVehicle()
    if #emergencyVehicles > 0 then
        return emergencyVehicles[1]
    end
    return nil
end

function GetEmergencyVehicleCounts()
    return CountByType(emergencyVehicles)
end

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('IsRadarEnabled', IsRadarEnabled)
exports('ToggleRadar', ToggleRadar)
exports('GetEmergencyVehicleCount', GetEmergencyVehicleCount)
exports('GetClosestEmergencyVehicle', GetClosestEmergencyVehicle)
exports('GetEmergencyVehicleCounts', GetEmergencyVehicleCounts)

-----------------------------------------------------------
-- EVENTS
-----------------------------------------------------------

-- Toggle radar via event (for keybind or menu)
RegisterNetEvent('dps-maritime:client:toggleRadar', function()
    -- Check player level
    local playerData = Bridge.GetPlayerData()
    if not playerData or not playerData.metadata then return end

    local xp = playerData.metadata.maritime_xp or 0
    local level = Config.GetLevelFromXP(xp)

    if level < Config.Progression.SmugglerRadarMinLevel then
        lib.notify({
            title = 'Smuggler\'s Radar',
            description = string.format('Requires Level %d (Captain)', Config.Progression.SmugglerRadarMinLevel),
            type = 'error',
            duration = 3000,
        })
        return
    end

    ToggleRadar()
end)

-- Auto-enable radar when carrying illegal cargo (if Level 9+)
RegisterNetEvent('dps-maritime:client:cargoPickedUp', function(cargoType)
    local cargo = Config.GetCargoType(cargoType)
    if not cargo or not cargo.illegal then return end

    local playerData = Bridge.GetPlayerData()
    if not playerData or not playerData.metadata then return end

    local xp = playerData.metadata.maritime_xp or 0
    local level = Config.GetLevelFromXP(xp)

    if level >= Config.Progression.SmugglerRadarMinLevel then
        if not radarEnabled then
            lib.notify({
                title = 'Smuggler\'s Radar',
                description = 'Auto-activating radar for contraband run',
                type = 'warning',
                duration = 3000,
            })
            Wait(1000)
            StartRadar()
        end
    end
end)

-- Disable radar when job ends
RegisterNetEvent('dps-maritime:client:jobComplete', function()
    if radarEnabled then
        StopRadar()
    end
end)

RegisterNetEvent('dps-maritime:client:jobCancelled', function()
    if radarEnabled then
        StopRadar()
    end
end)

-----------------------------------------------------------
-- KEYBIND
-----------------------------------------------------------

-- Register keybind for radar toggle
RegisterCommand('+smuggler_radar', function()
    TriggerEvent('dps-maritime:client:toggleRadar')
end, false)

RegisterKeyMapping('+smuggler_radar', 'Toggle Smuggler\'s Radar', 'keyboard', 'GRAVE') -- Tilde key

-----------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        ClearRadarBlips()
    end
end)
