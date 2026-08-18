--[[
    dps-maritime - Jetsam Company
    Dock Work Client (Container Hauling)
]]

-- Uses Bridge for framework abstraction

-- Job state
local IsDockWorking = false
local CurrentZone = nil
local CurrentContainerType = nil
local ContainersDelivered = 0

-- Manifest Mode state
local CurrentManifest = nil
local ManifestTimerThread = nil
local PendingPay = 0
local PendingXP = 0

-- Vehicles
local SpawnedTruck = nil
local SpawnedTrailer = nil
local SpawnedHandler = nil

-- Blips
local ActiveBlips = {}

-----------------------------------------------------------
-- DOCK WORK MENU
-----------------------------------------------------------

function OpenDockWorkMenu()
    if IsDockWorking then
        -- Already working, show end job option
        lib.registerContext({
            id = 'maritime_dock_working',
            title = 'Dock Work - Active',
            menu = 'maritime_main_menu',
            options = {
                {
                    title = 'Current Job',
                    description = 'Containers delivered: ' .. ContainersDelivered,
                    icon = 'box',
                },
                {
                    title = 'End Shift',
                    description = 'Return vehicles to end your shift',
                    icon = 'circle-xmark',
                    onSelect = function()
                        EndDockJob(true)
                    end,
                },
                {
                    title = 'Abandon Shift',
                    description = 'Leave without returning vehicles (no refund)',
                    icon = 'ban',
                    onSelect = function()
                        EndDockJob(false)
                    end,
                },
            },
        })
        lib.showContext('maritime_dock_working')
        return
    end

    -- Show available loading zones
    local options = {}

    for i, zone in ipairs(Config.LoadingZones) do
        local distance = #(GetEntityCoords(PlayerPedId()) - zone.pos)

        table.insert(options, {
            title = 'Loading Zone ' .. i,
            description = string.format('%.1f km away', distance / 1000),
            icon = 'warehouse',
            onSelect = function()
                StartDockJob(i)
            end,
        })
    end

    lib.registerContext({
        id = 'maritime_dock_menu',
        title = 'Dock Work',
        menu = 'maritime_main_menu',
        options = options,
    })

    lib.showContext('maritime_dock_menu')
end

-----------------------------------------------------------
-- START DOCK JOB
-----------------------------------------------------------

function StartDockJob(zoneId)
    if IsDockWorking then return end

    local alert = lib.alertDialog({
        header = 'Start Dock Shift',
        content = 'Rental fee: ' .. Maritime.FormatMoney(Config.DockWork.TruckRentalFee) .. '\n\nReturn vehicles at end of shift for full refund.',
        centered = true,
        cancel = true,
    })

    if alert ~= 'confirm' then return end

    TriggerServerEvent('dps-maritime:server:startDockJob', zoneId)
end

RegisterNetEvent('dps-maritime:client:dockJobStarted', function(data)
    IsDockWorking = true
    CurrentZone = data.zoneId
    CurrentContainerType = data.containerType
    ContainersDelivered = 0
    PendingPay = 0
    PendingXP = 0

    -- Handle manifest mode
    if data.manifest then
        CurrentManifest = {
            id = data.manifest.id,
            totalContainers = data.manifest.totalContainers,
            completedContainers = data.manifest.completedContainers or 0,
            timeLimit = data.manifest.timeLimit,
            startTime = data.manifest.startTime,
        }

        -- Start manifest timer display
        StartManifestTimer()
    else
        CurrentManifest = nil
    end

    exports['dps-maritime']:SetOnDuty(true, 'dock')

    -- Spawn vehicles
    SpawnDockVehicles(CurrentZone)

    -- Create blips
    CreateDockBlips()

    local description = 'Dock shift started. Pick up containers and deliver them.'
    if CurrentManifest then
        description = string.format('Manifest started: %d containers | Time limit: %s',
            CurrentManifest.totalContainers,
            FormatTime(CurrentManifest.timeLimit)
        )
    end

    lib.notify({
        title = 'Jetsam Maritime',
        description = description,
        type = 'inform',
        duration = 7000,
    })
end)

-----------------------------------------------------------
-- MANIFEST TIMER & HUD
-----------------------------------------------------------

function FormatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format('%d:%02d', mins, secs)
end

function StartManifestTimer()
    if ManifestTimerThread then return end

    ManifestTimerThread = CreateThread(function()
        while IsDockWorking and CurrentManifest do
            Wait(1000)

            -- Calculate remaining time
            local elapsed = GetCloudTimeAsInt() - CurrentManifest.startTime
            local remaining = CurrentManifest.timeLimit - elapsed

            -- Update TextUI with manifest progress
            local progress = string.format('Container %d/%d',
                CurrentManifest.completedContainers + 1,
                CurrentManifest.totalContainers
            )

            local timeColor = '~w~'
            if remaining <= 0 then
                timeColor = '~r~'
                remaining = math.abs(remaining)
                progress = progress .. string.format(' | %sOVERTIME: +%s', timeColor, FormatTime(remaining))
            elseif remaining <= 120 then -- Less than 2 minutes
                timeColor = '~o~'
                progress = progress .. string.format(' | %sTime: %s', timeColor, FormatTime(remaining))
            else
                progress = progress .. string.format(' | Time: %s', FormatTime(remaining))
            end

            -- Show pending pay
            if PendingPay > 0 then
                progress = progress .. string.format('\nPending: ~g~%s~w~ | ~b~+%d XP', Maritime.FormatMoney(PendingPay), PendingXP)
            end

            lib.showTextUI(progress, {
                position = 'top-center',
                icon = 'box',
            })
        end

        lib.hideTextUI()
        ManifestTimerThread = nil
    end)
end

function StopManifestTimer()
    if ManifestTimerThread then
        lib.hideTextUI()
    end
    CurrentManifest = nil
end

-----------------------------------------------------------
-- VEHICLE SPAWNING
-----------------------------------------------------------

function SpawnDockVehicles(zoneId)
    local zone = Config.LoadingZones[zoneId]
    if not zone then return end

    local truckCoords = Config.DockVehicleSpawns.Truck.coords
    local trailerCoords = Config.DockVehicleSpawns.Trailer.coords

    -- Spawn truck
    lib.requestModel(Config.DockWork.TruckModel, 5000)
    SpawnedTruck = CreateVehicle(
        joaat(Config.DockWork.TruckModel),
        truckCoords.x, truckCoords.y, truckCoords.z, truckCoords.w,
        true, false
    )
    SetEntityAsMissionEntity(SpawnedTruck, true, true)
    SetVehicleOnGroundProperly(SpawnedTruck)
    SetVehicleEngineOn(SpawnedTruck, true, true, false)
    SetModelAsNoLongerNeeded(joaat(Config.DockWork.TruckModel))

    -- Spawn trailer
    lib.requestModel(Config.DockWork.TrailerModel, 5000)
    SpawnedTrailer = CreateVehicle(
        joaat(Config.DockWork.TrailerModel),
        trailerCoords.x, trailerCoords.y, trailerCoords.z, trailerCoords.w,
        true, false
    )
    SetEntityAsMissionEntity(SpawnedTrailer, true, true)
    SetVehicleOnGroundProperly(SpawnedTrailer)
    SetModelAsNoLongerNeeded(joaat(Config.DockWork.TrailerModel))

    -- Set GPS to truck
    SetNewWaypoint(truckCoords.x, truckCoords.y)

    lib.notify({
        description = 'Your truck is ready. Trailer is nearby.',
        type = 'inform',
    })
end

function SpawnHandler(zoneId)
    local zone = Config.LoadingZones[zoneId]
    if not zone then return end

    local handlerCoords = zone.handlerSpawn
    local handlerHeading = zone.handlerHeading

    lib.requestModel(Config.DockWork.HandlerModel, 5000)
    SpawnedHandler = CreateVehicle(
        joaat(Config.DockWork.HandlerModel),
        handlerCoords.x, handlerCoords.y, handlerCoords.z, handlerHeading,
        true, false
    )
    SetEntityAsMissionEntity(SpawnedHandler, true, true)
    SetVehicleOnGroundProperly(SpawnedHandler)
    SetVehicleEngineOn(SpawnedHandler, true, true, false)
    SetModelAsNoLongerNeeded(joaat(Config.DockWork.HandlerModel))

    return SpawnedHandler
end

-----------------------------------------------------------
-- BLIPS
-----------------------------------------------------------

function CreateDockBlips()
    ClearDockBlips()

    -- Loading zone blips
    for i, zone in ipairs(Config.LoadingZones) do
        local blip = AddBlipForCoord(zone.pos.x, zone.pos.y, zone.pos.z)
        SetBlipSprite(blip, Config.Blips.LoadingZone.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Blips.LoadingZone.scale)
        SetBlipColour(blip, Config.Blips.LoadingZone.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextEntry('loading_zone_' .. i, 'Loading Zone ' .. i)
        EndTextCommandSetBlipName(blip)
        table.insert(ActiveBlips, blip)
    end

    -- Unloading zone blips
    for i, zone in ipairs(Config.UnloadingZones) do
        local blip = AddBlipForCoord(zone.pos.x, zone.pos.y, zone.pos.z)
        SetBlipSprite(blip, 478)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.6)
        SetBlipColour(blip, 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextEntry('unloading_zone_' .. i, 'Unloading Zone ' .. i)
        EndTextCommandSetBlipName(blip)
        table.insert(ActiveBlips, blip)
    end
end

function ClearDockBlips()
    for _, blip in ipairs(ActiveBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    ActiveBlips = {}
end

-----------------------------------------------------------
-- END DOCK JOB
-----------------------------------------------------------

function EndDockJob(returnVehicles)
    if not IsDockWorking then return end

    -- Clean up manifest timer
    StopManifestTimer()

    -- Clean up vehicles
    if SpawnedTruck and DoesEntityExist(SpawnedTruck) then
        DeleteVehicle(SpawnedTruck)
        SpawnedTruck = nil
    end

    if SpawnedTrailer and DoesEntityExist(SpawnedTrailer) then
        DeleteVehicle(SpawnedTrailer)
        SpawnedTrailer = nil
    end

    if SpawnedHandler and DoesEntityExist(SpawnedHandler) then
        DeleteVehicle(SpawnedHandler)
        SpawnedHandler = nil
    end

    ClearDockBlips()

    IsDockWorking = false
    CurrentZone = nil
    CurrentContainerType = nil
    CurrentManifest = nil
    PendingPay = 0
    PendingXP = 0

    exports['dps-maritime']:SetOnDuty(false, nil)

    TriggerServerEvent('dps-maritime:server:endDockJob', returnVehicles)
end

RegisterNetEvent('dps-maritime:client:dockJobEnded', function()
    lib.notify({
        title = 'Jetsam Maritime',
        description = 'Dock shift ended. Total containers: ' .. ContainersDelivered,
        type = 'inform',
    })
    ContainersDelivered = 0
end)

-----------------------------------------------------------
-- CONTAINER DELIVERY COMPLETE
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:client:containerComplete', function(data)
    ContainersDelivered = data.totalDelivered
    CurrentContainerType = data.nextContainerType

    -- Update manifest progress if in manifest mode
    if data.manifestProgress then
        if CurrentManifest then
            CurrentManifest.completedContainers = data.manifestProgress.current
        end
        PendingPay = data.pendingPay or 0
        PendingXP = data.pendingXP or 0

        lib.notify({
            title = 'Container Delivered',
            description = string.format('Progress: %d/%d | Pending: %s',
                data.manifestProgress.current,
                data.manifestProgress.total,
                Maritime.FormatMoney(PendingPay)
            ),
            type = 'success',
        })
    else
        -- Legacy mode - immediate pay
        lib.notify({
            title = 'Container Delivered',
            description = Maritime.FormatMoney(data.pay) .. ' | +' .. data.xp .. ' XP',
            type = 'success',
        })
    end
end)

-----------------------------------------------------------
-- MANIFEST COMPLETE
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:client:manifestComplete', function(data)
    -- Stop the timer
    StopManifestTimer()

    -- Build completion message
    local bonusText = ''
    if data.bonusMultiplier > 1.0 then
        bonusText = string.format(' (+%d%% bonus)', math.floor((data.bonusMultiplier - 1) * 100))
    elseif data.bonusMultiplier < 1.0 then
        bonusText = string.format(' (-%d%% penalty)', math.floor((1 - data.bonusMultiplier) * 100))
    end

    local timeText = ''
    if data.wasFast then
        timeText = '~g~FAST DELIVERY!~w~'
    elseif data.wasOnTime then
        timeText = '~g~On Time~w~'
    else
        timeText = '~r~Late Delivery~w~'
    end

    -- Show completion alert
    lib.alertDialog({
        header = 'Manifest Complete!',
        content = string.format([[
**Manifest ID:** %s
**Containers:** %d delivered
**Time:** %s (%s)

---

**Base Pay:** %s
**Final Pay:** %s%s

**Base XP:** %d
**Final XP:** %d

---

%s
]],
            data.manifestId,
            data.totalContainers,
            FormatTime(data.elapsed),
            timeText,
            Maritime.FormatMoney(data.basePay),
            Maritime.FormatMoney(data.finalPay),
            bonusText,
            data.baseXP,
            data.finalXP,
            data.wasFast and 'Great work! Time bonus applied!' or (data.wasOnTime and 'Manifest completed on time.' or 'Try to complete faster next time.')
        ),
        centered = true,
    })

    -- Reset pending values
    PendingPay = 0
    PendingXP = 0
    ContainersDelivered = 0
end)

-----------------------------------------------------------
-- LOADING ZONE TARGETS
-----------------------------------------------------------

CreateThread(function()
    for i, zone in ipairs(Config.LoadingZones) do
        -- Create loading zone marker/target
        exports.ox_target:addSphereZone({
            coords = zone.pos,
            radius = 3.0,
            options = {
                {
                    name = 'dock_loading_' .. i,
                    icon = 'fa-solid fa-box',
                    label = 'Pickup Container',
                    canInteract = function()
                        return IsDockWorking and IsHandlerNearby()
                    end,
                    onSelect = function()
                        TriggerEvent('dps-maritime:client:pickupContainer', i)
                    end,
                },
                {
                    name = 'dock_handler_' .. i,
                    icon = 'fa-solid fa-truck-loading',
                    label = 'Get Handler Vehicle',
                    canInteract = function()
                        return IsDockWorking and not SpawnedHandler
                    end,
                    onSelect = function()
                        SpawnHandler(i)
                        lib.notify({ description = 'Handler spawned', type = 'success' })
                    end,
                },
            },
        })
    end

    -- Unloading zones
    for i, zone in ipairs(Config.UnloadingZones) do
        exports.ox_target:addSphereZone({
            coords = zone.pos,
            radius = 3.0,
            options = {
                {
                    name = 'dock_unloading_' .. i,
                    icon = 'fa-solid fa-box-open',
                    label = 'Unload Container',
                    canInteract = function()
                        return IsDockWorking and HasContainerAttached()
                    end,
                    onSelect = function()
                        TriggerEvent('dps-maritime:client:unloadContainer', i)
                    end,
                },
            },
        })
    end

    -- Container placement zones
    for i, zone in ipairs(Config.ContainerPlacement) do
        exports.ox_target:addSphereZone({
            coords = zone.pos,
            radius = 3.0,
            options = {
                {
                    name = 'dock_placement_' .. i,
                    icon = 'fa-solid fa-cubes',
                    label = 'Place Container',
                    canInteract = function()
                        return IsDockWorking and HasContainerAttached()
                    end,
                    onSelect = function()
                        TriggerEvent('dps-maritime:client:placeContainer', i)
                    end,
                },
            },
        })
    end
end)

-----------------------------------------------------------
-- HELPER FUNCTIONS
-----------------------------------------------------------

function IsHandlerNearby()
    if not SpawnedHandler or not DoesEntityExist(SpawnedHandler) then
        return false
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local handlerCoords = GetEntityCoords(SpawnedHandler)

    return #(playerCoords - handlerCoords) < 10.0
end

function HasContainerAttached()
    -- Check handler.lua for attached container state
    return exports['dps-maritime']:HasContainerAttached()
end

-----------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    ClearDockBlips()

    if SpawnedTruck and DoesEntityExist(SpawnedTruck) then
        DeleteVehicle(SpawnedTruck)
    end
    if SpawnedTrailer and DoesEntityExist(SpawnedTrailer) then
        DeleteVehicle(SpawnedTrailer)
    end
    if SpawnedHandler and DoesEntityExist(SpawnedHandler) then
        DeleteVehicle(SpawnedHandler)
    end
end)
