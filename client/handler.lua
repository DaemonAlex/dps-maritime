--[[
    dps-maritime - Jetsam Company
    Handler Vehicle Mechanics
]]

-- Handler state
local AttachedContainer = nil
local AttachedContainerData = nil
local HandlerVehicle = nil

-----------------------------------------------------------
-- CONTAINER ATTACHMENT
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:client:pickupContainer', function(zoneId)
    local zone = Config.LoadingZones[zoneId]
    if not zone then return end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or vehicle == 0 then
        lib.notify({ description = 'You need to be in the handler vehicle', type = 'error' })
        return
    end

    local model = GetEntityModel(vehicle)
    if model ~= joaat(Config.DockWork.HandlerModel) then
        lib.notify({ description = 'You need to be in the handler vehicle', type = 'error' })
        return
    end

    if AttachedContainer then
        lib.notify({ description = 'You already have a container attached', type = 'error' })
        return
    end

    HandlerVehicle = vehicle

    -- Get random container spawn from zone
    local containerSpawns = zone.containerSpawns
    local spawn = containerSpawns[math.random(#containerSpawns)]

    -- Create container prop
    lib.requestModel(Config.DockWork.ContainerProp, 5000)

    AttachedContainer = CreateObject(
        joaat(Config.DockWork.ContainerProp),
        spawn.coords.x, spawn.coords.y, spawn.coords.z,
        true, false, false
    )

    SetEntityHeading(AttachedContainer, spawn.heading)

    -- Attach to handler
    local boneIndex = GetEntityBoneIndexByName(vehicle, Config.Handler.AttachBone)
    local offset = Config.Handler.AttachOffset
    local rotation = Config.Handler.AttachRotation

    AttachEntityToEntity(
        AttachedContainer,
        vehicle,
        boneIndex,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        true, true, false, false, 2, true
    )

    SetModelAsNoLongerNeeded(joaat(Config.DockWork.ContainerProp))

    -- Store container data
    AttachedContainerData = {
        zoneId = zoneId,
        containerType = Config.GetRandomContainerType(exports['dps-maritime']:GetPlayerLevel()),
        pickupTime = GetGameTimer(),
    }

    lib.notify({
        title = 'Container Picked Up',
        description = 'Deliver to an unloading zone',
        type = 'success',
    })

    -- Set waypoint to nearest unloading zone
    local playerCoords = GetEntityCoords(ped)
    local nearestZone = nil
    local nearestDist = math.huge

    for i, uzone in ipairs(Config.UnloadingZones) do
        local dist = #(playerCoords - uzone.pos)
        if dist < nearestDist then
            nearestDist = dist
            nearestZone = uzone
        end
    end

    if nearestZone then
        SetNewWaypoint(nearestZone.pos.x, nearestZone.pos.y)
    end
end)

-----------------------------------------------------------
-- CONTAINER UNLOADING (to trailer)
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:client:unloadContainer', function(zoneId)
    local zone = Config.UnloadingZones[zoneId]
    if not zone then return end

    if not AttachedContainer or not DoesEntityExist(AttachedContainer) then
        lib.notify({ description = 'No container attached', type = 'error' })
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or GetEntityModel(vehicle) ~= joaat(Config.DockWork.HandlerModel) then
        lib.notify({ description = 'You need to be in the handler vehicle', type = 'error' })
        return
    end

    -- Check if near a trailer
    local trailer = GetNearbyTrailer(zone.pos, 10.0)
    if not trailer then
        lib.notify({ description = 'No trailer nearby to unload onto', type = 'error' })
        return
    end

    -- Detach from handler
    DetachEntity(AttachedContainer, true, true)

    -- Attach to trailer
    local trailerBone = GetEntityBoneIndexByName(trailer, Config.Handler.TrailerBone)
    local trailerOffset = Config.Handler.TrailerOffset

    AttachEntityToEntity(
        AttachedContainer,
        trailer,
        trailerBone,
        trailerOffset.x, trailerOffset.y, trailerOffset.z,
        0.0, 0.0, 90.0,
        true, true, false, false, 2, true
    )

    lib.notify({
        title = 'Container Loaded',
        description = 'Deliver to the container storage area',
        type = 'success',
    })

    -- Update waypoint to placement zone
    local placementZone = Config.ContainerPlacement[1]
    if placementZone then
        SetNewWaypoint(placementZone.pos.x, placementZone.pos.y)
    end
end)

-----------------------------------------------------------
-- CONTAINER PLACEMENT (stacking)
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:client:placeContainer', function(zoneId)
    local zone = Config.ContainerPlacement[zoneId]
    if not zone then return end

    if not AttachedContainer or not DoesEntityExist(AttachedContainer) then
        lib.notify({ description = 'No container to place', type = 'error' })
        return
    end

    -- Get existing containers from server
    local existingContainers = lib.callback.await('dps-maritime:server:getContainers', false)

    -- Convert to array for position finding
    local containerArray = {}
    for _, container in pairs(existingContainers or {}) do
        table.insert(containerArray, container)
    end

    -- Find next stack position
    local nextPos = Config.FindNextStackPosition(containerArray)

    if not nextPos then
        lib.notify({ description = 'Container storage is full', type = 'error' })
        return
    end

    -- Detach and delete temporary prop
    DetachEntity(AttachedContainer, true, true)
    DeleteEntity(AttachedContainer)

    -- Create permanent stacked container
    lib.requestModel(Config.DockWork.ContainerPropStacked, 5000)

    local stackedContainer = CreateObject(
        joaat(Config.DockWork.ContainerPropStacked),
        nextPos.x, nextPos.y, nextPos.z,
        true, false, false
    )

    SetEntityHeading(stackedContainer, nextPos.heading)
    FreezeEntityPosition(stackedContainer, true)
    SetModelAsNoLongerNeeded(joaat(Config.DockWork.ContainerPropStacked))

    -- Notify server
    TriggerServerEvent('dps-maritime:server:placeContainer', {
        x = nextPos.x,
        y = nextPos.y,
        z = nextPos.z,
        heading = nextPos.heading,
    })

    -- Complete delivery
    TriggerServerEvent('dps-maritime:server:containerDelivered', AttachedContainerData.containerType)

    -- Clear state
    AttachedContainer = nil
    AttachedContainerData = nil

    -- Set waypoint back to loading zone
    local loadingZone = Config.LoadingZones[1]
    if loadingZone then
        SetNewWaypoint(loadingZone.pos.x, loadingZone.pos.y)
    end
end)

-----------------------------------------------------------
-- HELPER FUNCTIONS
-----------------------------------------------------------

function GetNearbyTrailer(coords, radius)
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local model = GetEntityModel(vehicle)
            if model == joaat(Config.DockWork.TrailerModel) then
                local vehicleCoords = GetEntityCoords(vehicle)
                if #(coords - vehicleCoords) < radius then
                    return vehicle
                end
            end
        end
    end

    return nil
end

function HasContainerAttached()
    return AttachedContainer ~= nil and DoesEntityExist(AttachedContainer)
end

exports('HasContainerAttached', HasContainerAttached)

function GetAttachedContainerData()
    return AttachedContainerData
end

exports('GetAttachedContainerData', GetAttachedContainerData)

-----------------------------------------------------------
-- DISTANCE-BASED CONTAINER SYNC
-- Only spawns containers when player is nearby to prevent
-- hitting prop limits and causing desync issues
-----------------------------------------------------------

local ContainerData = {}      -- Server data cache
local SpawnedContainers = {}  -- Actually spawned props
local SPAWN_DISTANCE = 150.0  -- Distance to spawn containers
local DESPAWN_DISTANCE = 200.0 -- Distance to despawn containers
local ContainerStorageCenter = vector3(1135.0, -2985.0, 5.9) -- Center of storage area

-- Update container data from server
RegisterNetEvent('dps-maritime:client:syncContainer', function(containerData)
    ContainerData[containerData.id] = containerData
end)

RegisterNetEvent('dps-maritime:client:removeContainer', function(containerId)
    ContainerData[containerId] = nil

    if SpawnedContainers[containerId] then
        if DoesEntityExist(SpawnedContainers[containerId]) then
            DeleteEntity(SpawnedContainers[containerId])
        end
        SpawnedContainers[containerId] = nil
    end
end)

RegisterNetEvent('dps-maritime:client:clearContainers', function()
    ContainerData = {}

    for id, container in pairs(SpawnedContainers) do
        if DoesEntityExist(container) then
            DeleteEntity(container)
        end
    end
    SpawnedContainers = {}
end)

-- Spawn a container prop
local function SpawnContainerProp(id, data)
    if SpawnedContainers[id] then return end

    lib.requestModel(Config.DockWork.ContainerPropStacked, 5000)

    local container = CreateObject(
        joaat(Config.DockWork.ContainerPropStacked),
        data.x, data.y, data.z,
        false, false, false
    )

    SetEntityHeading(container, data.heading)
    FreezeEntityPosition(container, true)
    SetEntityAsMissionEntity(container, true, true)
    SetModelAsNoLongerNeeded(joaat(Config.DockWork.ContainerPropStacked))

    SpawnedContainers[id] = container
end

-- Despawn a container prop
local function DespawnContainerProp(id)
    if not SpawnedContainers[id] then return end

    if DoesEntityExist(SpawnedContainers[id]) then
        DeleteEntity(SpawnedContainers[id])
    end
    SpawnedContainers[id] = nil
end

-- Distance-based container management thread
CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local distanceToStorage = #(playerCoords - ContainerStorageCenter)

        -- Only process if player is somewhat near the storage area
        if distanceToStorage < DESPAWN_DISTANCE + 50.0 then
            for id, data in pairs(ContainerData) do
                local containerCoords = vector3(data.x, data.y, data.z)
                local distance = #(playerCoords - containerCoords)

                if distance <= SPAWN_DISTANCE then
                    -- Spawn if not already spawned
                    if not SpawnedContainers[id] then
                        SpawnContainerProp(id, data)
                    end
                elseif distance > DESPAWN_DISTANCE then
                    -- Despawn if too far
                    if SpawnedContainers[id] then
                        DespawnContainerProp(id)
                    end
                end
            end

            Wait(500) -- Check more frequently when near
        else
            -- Player is far from storage, despawn all containers
            for id, _ in pairs(SpawnedContainers) do
                DespawnContainerProp(id)
            end

            Wait(2000) -- Check less frequently when far
        end
    end
end)

-- Load existing containers on resource start
CreateThread(function()
    Wait(2000)

    local containers = lib.callback.await('dps-maritime:server:getContainers', false)

    if containers then
        for id, containerData in pairs(containers) do
            ContainerData[id] = containerData
        end
        Maritime.Debug('Cached ' .. #containers .. ' container positions from server')
    end
end)

-----------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if AttachedContainer and DoesEntityExist(AttachedContainer) then
        DeleteEntity(AttachedContainer)
    end

    for id, container in pairs(SpawnedContainers) do
        if DoesEntityExist(container) then
            DeleteEntity(container)
        end
    end
end)
