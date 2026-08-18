--[[
    dps-maritime - Jetsam Company
    Compass Navigation System
    For distant sea destinations where GPS is disabled
]]

-- Uses Bridge for framework abstraction

-- Navigation state
local IsNavigating = false
local CurrentDestination = nil
local NavigationThread = nil
local MinimapHidden = false
local OriginalRadarState = true

-----------------------------------------------------------
-- COMPASS DIRECTIONS
-----------------------------------------------------------

local CompassDirections = {
    { min = 337.5, max = 360, dir = 'N', full = 'North' },
    { min = 0, max = 22.5, dir = 'N', full = 'North' },
    { min = 22.5, max = 67.5, dir = 'NE', full = 'Northeast' },
    { min = 67.5, max = 112.5, dir = 'E', full = 'East' },
    { min = 112.5, max = 157.5, dir = 'SE', full = 'Southeast' },
    { min = 157.5, max = 202.5, dir = 'S', full = 'South' },
    { min = 202.5, max = 247.5, dir = 'SW', full = 'Southwest' },
    { min = 247.5, max = 292.5, dir = 'W', full = 'West' },
    { min = 292.5, max = 337.5, dir = 'NW', full = 'Northwest' },
}

local function GetCompassDirection(heading)
    for _, dir in ipairs(CompassDirections) do
        if heading >= dir.min and heading < dir.max then
            return dir.dir, dir.full
        end
    end
    return 'N', 'North'
end

-----------------------------------------------------------
-- BEARING CALCULATION
-----------------------------------------------------------

local function CalculateBearing(from, to)
    local dx = to.x - from.x
    local dy = to.y - from.y
    local radians = math.atan(dx, dy)
    local degrees = math.deg(radians)
    if degrees < 0 then
        degrees = degrees + 360
    end
    return degrees
end

local function CalculateDistance(from, to)
    local dx = to.x - from.x
    local dy = to.y - from.y
    return math.sqrt(dx * dx + dy * dy)
end

-----------------------------------------------------------
-- MINIMAP CONTROL
-----------------------------------------------------------

local function HideMinimap()
    if MinimapHidden then return end
    OriginalRadarState = not IsRadarHidden()
    DisplayRadar(false)
    MinimapHidden = true
    Maritime.Debug('Minimap hidden for compass navigation')
end

local function ShowMinimap()
    if not MinimapHidden then return end
    DisplayRadar(OriginalRadarState)
    MinimapHidden = false
    Maritime.Debug('Minimap restored')
end

-----------------------------------------------------------
-- COMPASS HUD DRAWING
-----------------------------------------------------------

local function DrawCompassHUD(bearing, distance, direction, destName)
    -- Background box
    local boxX, boxY = 0.5, 0.08
    local boxW, boxH = 0.16, 0.08

    DrawRect(boxX, boxY, boxW, boxH, 0, 0, 0, 180)
    DrawRect(boxX, boxY - 0.04, boxW, 0.003, 255, 200, 0, 255) -- Gold accent

    -- Bearing display
    local bearingText = string.format('BEARING: %d°', math.floor(bearing))
    SetTextFont(4)
    SetTextScale(0.45, 0.45)
    SetTextColour(255, 200, 0, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(bearingText)
    EndTextCommandDisplayText(boxX, boxY - 0.035)

    -- Distance display
    local distanceText
    if distance >= 1000 then
        distanceText = string.format('%.1f km', distance / 1000)
    else
        distanceText = string.format('%d m', math.floor(distance))
    end

    SetTextFont(4)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName('DISTANCE: ' .. distanceText)
    EndTextCommandDisplayText(boxX, boxY - 0.005)

    -- Direction arrow and text
    local arrowText = '← ' .. direction
    local playerHeading = GetEntityHeading(PlayerPedId())
    local relativeBearing = bearing - playerHeading
    if relativeBearing < 0 then relativeBearing = relativeBearing + 360 end

    if relativeBearing > 315 or relativeBearing <= 45 then
        arrowText = '↑ ' .. direction  -- Ahead
    elseif relativeBearing > 45 and relativeBearing <= 135 then
        arrowText = '→ ' .. direction  -- Right
    elseif relativeBearing > 135 and relativeBearing <= 225 then
        arrowText = '↓ ' .. direction  -- Behind
    else
        arrowText = '← ' .. direction  -- Left
    end

    SetTextFont(4)
    SetTextScale(0.4, 0.4)
    SetTextColour(100, 200, 255, 255)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(arrowText)
    EndTextCommandDisplayText(boxX, boxY + 0.025)

    -- Destination name
    SetTextFont(4)
    SetTextScale(0.3, 0.3)
    SetTextColour(180, 180, 180, 255)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(destName or 'Unknown')
    EndTextCommandDisplayText(boxX, boxY + 0.05)
end

-----------------------------------------------------------
-- NAVIGATION START/STOP
-----------------------------------------------------------

function StartCompassNavigation(destData)
    if IsNavigating then
        StopCompassNavigation()
    end

    CurrentDestination = {
        coords = destData.coords or destData.dockCoords,
        name = destData.name or destData.shortName or 'Destination',
        hidesMinimap = destData.hidesMinimap or false,
    }

    IsNavigating = true

    -- Hide minimap if required
    if CurrentDestination.hidesMinimap then
        HideMinimap()
    end

    -- Start navigation thread
    NavigationThread = CreateThread(function()
        while IsNavigating and CurrentDestination do
            Wait(0)

            local playerPos = GetEntityCoords(PlayerPedId())
            local destPos = CurrentDestination.coords

            local bearing = CalculateBearing(playerPos, destPos)
            local distance = CalculateDistance(playerPos, destPos)
            local dir, fullDir = GetCompassDirection(bearing)

            DrawCompassHUD(bearing, distance, dir, CurrentDestination.name)

            -- Check if arrived (within 50m)
            if distance < 50.0 then
                lib.notify({
                    title = 'Navigation',
                    description = 'You have arrived at ' .. CurrentDestination.name,
                    type = 'success',
                })
                StopCompassNavigation()
                break
            end
        end
    end)

    lib.notify({
        title = 'Compass Navigation',
        description = 'GPS disabled. Follow compass bearing to ' .. CurrentDestination.name,
        type = 'inform',
        duration = 7000,
    })

    Maritime.Debug('Started compass navigation to: ' .. CurrentDestination.name)
end

function StopCompassNavigation()
    IsNavigating = false
    CurrentDestination = nil

    -- Restore minimap
    ShowMinimap()

    Maritime.Debug('Compass navigation stopped')
end

-- Check if currently navigating
function IsCompassNavigating()
    return IsNavigating
end

-- Get current navigation destination
function GetNavigationDestination()
    return CurrentDestination
end

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('StartCompassNavigation', StartCompassNavigation)
exports('StopCompassNavigation', StopCompassNavigation)
exports('IsCompassNavigating', IsCompassNavigating)
exports('GetNavigationDestination', GetNavigationDestination)

-----------------------------------------------------------
-- EVENTS
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:client:startNavigation', function(destData)
    StartCompassNavigation(destData)
end)

RegisterNetEvent('dps-maritime:client:stopNavigation', function()
    StopCompassNavigation()
end)

-----------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    StopCompassNavigation()
end)
