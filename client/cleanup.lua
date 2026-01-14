--[[
    dps-maritime - Jetsam Company
    Port Cleanup - Removes default GTA props to prevent Z-fighting
]]

-- Props to remove from the port area (Elysian Island / Terminal)
local PropsToRemove = {
    -- Containers
    'prop_container_01a',
    'prop_container_01b',
    'prop_container_01c',
    'prop_container_01d',
    'prop_container_01e',
    'prop_container_01f',
    'prop_container_01g',
    'prop_container_01h',
    'prop_container_02a',
    'prop_container_03a',
    'prop_container_03b',
    'prop_container_03mb',
    'prop_container_04a',
    'prop_container_04mb',
    'prop_container_05mb',
    'prop_container_ld',
    'prop_container_ld2',
    'prop_contr_03b_ld',

    -- Cranes and port equipment
    'prop_dock_crane_02',
    'prop_dock_crane_02_cab',
    'prop_dock_crane_01',

    -- Misc port props that may interfere
    'prop_container_hole',
}

-- Areas to clean (center coords + radius)
local CleanupZones = {
    -- Terminal Island main area
    { coords = vector3(1135.0, -3000.0, 5.9), radius = 200.0 },
    -- Elysian Island container yard
    { coords = vector3(175.0, -3100.0, 6.0), radius = 250.0 },
    -- Port of LS docks
    { coords = vector3(-200.0, -2800.0, 6.0), radius = 200.0 },
    -- Jetsam HQ area
    { coords = vector3(1197.0, -3250.0, 7.0), radius = 100.0 },
    -- Boat spawn areas
    { coords = vector3(1299.0, -3246.0, 0.0), radius = 100.0 },
    { coords = vector3(-792.0, -1510.0, 0.0), radius = 80.0 },
    -- La Puerta docks
    { coords = vector3(-850.0, -1400.0, 6.0), radius = 150.0 },
}

-- Specific objects to delete by coordinates (for stubborn props)
-- These are known collision points with the custom port map
local SpecificPropsToDelete = {
    -- Terminal container stacks that z-fight with custom map
    { model = 'prop_container_03b', coords = vector3(1148.5, -3024.5, 5.9), radius = 5.0 },
    { model = 'prop_container_03b', coords = vector3(1148.5, -2988.5, 5.9), radius = 5.0 },
    { model = 'prop_container_03a', coords = vector3(1120.0, -3000.0, 5.9), radius = 5.0 },

    -- Dock equipment
    { model = 'prop_dock_crane_02', coords = vector3(1100.0, -3050.0, 5.9), radius = 50.0 },
}

-- Hash the prop names for faster lookup
local PropHashes = {}
for _, propName in ipairs(PropsToRemove) do
    PropHashes[joaat(propName)] = true
end

-----------------------------------------------------------
-- CLEANUP FUNCTIONS
-----------------------------------------------------------

local function CleanupArea(center, radius)
    local objects = GetGamePool('CObject')
    local cleaned = 0

    for _, object in ipairs(objects) do
        if DoesEntityExist(object) then
            local objCoords = GetEntityCoords(object)
            local distance = #(center - objCoords)

            if distance <= radius then
                local model = GetEntityModel(object)

                if PropHashes[model] then
                    SetEntityAsMissionEntity(object, true, true)
                    DeleteEntity(object)
                    cleaned = cleaned + 1
                end
            end
        end
    end

    return cleaned
end

local function CleanupSpecificProps()
    local cleaned = 0

    for _, prop in ipairs(SpecificPropsToDelete) do
        local modelHash = joaat(prop.model)
        local objects = GetGamePool('CObject')

        for _, object in ipairs(objects) do
            if DoesEntityExist(object) and GetEntityModel(object) == modelHash then
                local objCoords = GetEntityCoords(object)
                local distance = #(prop.coords - objCoords)

                if distance <= prop.radius then
                    SetEntityAsMissionEntity(object, true, true)
                    DeleteEntity(object)
                    cleaned = cleaned + 1
                end
            end
        end
    end

    return cleaned
end

local function CleanupAllZones()
    local totalCleaned = 0

    -- Clean by zone
    for _, zone in ipairs(CleanupZones) do
        totalCleaned = totalCleaned + CleanupArea(zone.coords, zone.radius)
    end

    -- Clean specific problem props
    totalCleaned = totalCleaned + CleanupSpecificProps()

    if Config.Debug and totalCleaned > 0 then
        Maritime.Debug('Cleaned ' .. totalCleaned .. ' default props from port areas')
    end

    return totalCleaned
end

-----------------------------------------------------------
-- CONTINUOUS CLEANUP THREAD
-- GTA may respawn props, so we periodically clean
-----------------------------------------------------------

CreateThread(function()
    -- Initial cleanup after resource starts
    Wait(2000)
    CleanupAllZones()

    -- Periodic cleanup every 30 seconds
    while true do
        Wait(30000)

        local playerCoords = GetEntityCoords(PlayerPedId())

        -- Only run cleanup if player is near any cleanup zone
        for _, zone in ipairs(CleanupZones) do
            if #(playerCoords - zone.coords) < zone.radius + 100.0 then
                CleanupAllZones()
                break
            end
        end
    end
end)

-----------------------------------------------------------
-- IPL MANAGEMENT
-- Remove/request specific interior locations
-----------------------------------------------------------

-- Terminal / Elysian Island IPLs to remove
local IPLsToRemove = {
    -- Terminal port area containers and equipment
    'shr_int',
    'shutter_closed',
    'shr_intshutter_open',

    -- Cargo ship related
    'cs1_02_cf_offmission',
    'cs1_02_cf_onmission1',
    'cs1_02_cf_onmission2',
    'cs1_02_cf_onmission3',
    'cs1_02_cf_onmission4',

    -- Container yard variants
    'ch1_02_closed',

    -- Port of LS container arrangements
    'prop_jetty_01',
    'prop_jetty_mod1',
}

-- IPLs we may need to request (our custom map or base requirements)
local IPLsToRequest = {
    -- Base game IPLs that should remain
}

CreateThread(function()
    Wait(500)

    -- Remove conflicting IPLs
    for _, ipl in ipairs(IPLsToRemove) do
        if IsIplActive(ipl) then
            RemoveIpl(ipl)
            if Config.Debug then
                Maritime.Debug('Removed IPL: ' .. ipl)
            end
        end
    end

    -- Request needed IPLs
    for _, ipl in ipairs(IPLsToRequest) do
        if not IsIplActive(ipl) then
            RequestIpl(ipl)
            if Config.Debug then
                Maritime.Debug('Requested IPL: ' .. ipl)
            end
        end
    end
end)

-----------------------------------------------------------
-- ENTITY SET MANAGEMENT
-- For controlling spawned entity groups
-----------------------------------------------------------

-- Disable specific entity sets in the port area if they cause issues
CreateThread(function()
    Wait(1500)

    -- Example: Disable default container entitysets
    -- SetEntitySetState(interiorId, 'default_containers', false)
end)

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('CleanupPort', CleanupAllZones)
exports('CleanupArea', CleanupArea)
