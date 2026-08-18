--[[
    dps-maritime - Jetsam Company
    VIP Leisure Transport - Client Script

    High-paying passenger transport to leisure destinations
    Integrates with RCore leisure resources (golf, casino, etc.)
]]

-- Uses Bridge for framework abstraction

-- State
local ActiveMission = nil
local PassengerPeds = {}
local PickupBlip = nil
local DestinationBlip = nil
local MissionStartTime = nil
local CollisionCount = 0

-----------------------------------------------------------
-- MENU FUNCTIONS
-----------------------------------------------------------

function OpenVIPTransportMenu()
    local PlayerData = exports['dps-maritime']:GetPlayerMaritimeData()
    if not PlayerData then
        lib.notify({ description = 'Failed to load data', type = 'error' })
        return
    end

    local level = PlayerData.level or 1
    if level < Config.VIPTransport.MinLevel then
        lib.notify({
            title = 'VIP Transport',
            description = 'Reach level ' .. Config.VIPTransport.MinLevel .. ' to unlock VIP transport',
            type = 'error',
        })
        return
    end

    -- Check for available destinations
    local destinations = Config.GetAvailableLeisureDestinations()
    if next(destinations) == nil then
        lib.notify({
            title = 'VIP Transport',
            description = 'No leisure destinations available',
            type = 'error',
        })
        return
    end

    local options = {
        {
            title = 'Request VIP Mission',
            description = 'Get a random VIP transport request',
            icon = 'user-tie',
            onSelect = function()
                RequestVIPMission()
            end,
        },
    }

    -- Show available destinations
    for id, dest in pairs(destinations) do
        table.insert(options, {
            title = dest.name,
            description = dest.description,
            icon = 'location-dot',
            metadata = {
                { label = 'Pay Bonus', value = string.format('+%d%%', (dest.payMultiplier - 1) * 100) },
                { label = 'XP Bonus', value = string.format('+%d%%', dest.xpBonus * 100) },
            },
            disabled = true,
        })
    end

    lib.registerContext({
        id = 'maritime_vip_menu',
        title = 'VIP Leisure Transport',
        menu = 'maritime_main_menu',
        options = options,
    })

    lib.showContext('maritime_vip_menu')
end

-----------------------------------------------------------
-- MISSION GENERATION
-----------------------------------------------------------

function RequestVIPMission()
    if ActiveMission then
        lib.notify({
            title = 'VIP Transport',
            description = 'You already have an active mission',
            type = 'error',
        })
        return
    end

    -- Get available destinations
    local destinations = Config.GetAvailableLeisureDestinations()
    local destList = {}
    for id, dest in pairs(destinations) do
        table.insert(destList, { id = id, data = dest })
    end

    if #destList == 0 then
        lib.notify({
            title = 'VIP Transport',
            description = 'No destinations available',
            type = 'error',
        })
        return
    end

    -- Pick random destination
    local chosen = destList[math.random(#destList)]

    -- Pick random mission type
    local missionTypes = {}
    for typeId, typeData in pairs(Config.VIPTransport.MissionTypes) do
        local PlayerData = exports['dps-maritime']:GetPlayerMaritimeData()
        local level = PlayerData and PlayerData.level or 1

        if not typeData.levelRequired or level >= typeData.levelRequired then
            table.insert(missionTypes, { id = typeId, data = typeData })
        end
    end

    local missionType = missionTypes[math.random(#missionTypes)]

    -- Pick random pickup location
    local pickups = Config.VIPTransport.PickupLocations
    local pickup = pickups[math.random(#pickups)]

    -- Request mission from server
    local mission = lib.callback.await('dps-maritime:server:requestVIPMission', false, {
        destinationId = chosen.id,
        missionTypeId = missionType.id,
        pickupIndex = _,
    })

    if mission.error then
        lib.notify({ description = mission.error, type = 'error' })
        return
    end

    -- Start mission
    StartVIPMission(mission)
end

-----------------------------------------------------------
-- MISSION EXECUTION
-----------------------------------------------------------

function StartVIPMission(mission)
    ActiveMission = mission
    MissionStartTime = GetGameTimer()
    CollisionCount = 0

    local pickup = Config.VIPTransport.PickupLocations[math.random(#Config.VIPTransport.PickupLocations)]
    ActiveMission.pickup = pickup

    -- Create pickup blip
    PickupBlip = AddBlipForCoord(pickup.coords.x, pickup.coords.y, pickup.coords.z)
    SetBlipSprite(PickupBlip, Config.VIPTransport.Blip.pickup.sprite)
    SetBlipColour(PickupBlip, Config.VIPTransport.Blip.pickup.color)
    SetBlipScale(PickupBlip, Config.VIPTransport.Blip.pickup.scale)
    SetBlipRoute(PickupBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextEntry('vip_pickup', 'VIP Pickup')
    EndTextCommandSetBlipName(PickupBlip)

    lib.notify({
        title = 'VIP Transport',
        description = 'Head to ' .. pickup.name .. ' to pick up your passenger(s)',
        type = 'info',
        duration = 8000,
    })

    -- Start pickup zone
    CreatePickupZone(pickup)
end

function CreatePickupZone(pickup)
    local zone = lib.zones.sphere({
        coords = pickup.coords,
        radius = 15.0,
        debug = Config.Debug,
        onEnter = function()
            lib.notify({
                title = 'VIP Transport',
                description = 'Press [E] to board passengers',
                type = 'info',
            })
        end,
    })

    ActiveMission.pickupZone = zone

    -- Wait for player to pick up passengers
    CreateThread(function()
        while ActiveMission and not ActiveMission.passengersLoaded do
            Wait(100)

            if ActiveMission.pickupZone then
                local playerCoords = GetEntityCoords(PlayerPedId())
                local dist = #(playerCoords - pickup.coords)

                if dist < 15.0 then
                    -- Check if in boat
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                    if vehicle and vehicle ~= 0 and IsThisModelABoat(GetEntityModel(vehicle)) then
                        if IsControlJustPressed(0, 51) then -- E key
                            BoardPassengers(vehicle)
                        end
                    end
                end
            end
        end
    end)
end

function BoardPassengers(vehicle)
    if not ActiveMission then return end

    local missionType = Config.VIPTransport.MissionTypes[ActiveMission.missionTypeId]
    local destination = Config.VIPTransport.Destinations[ActiveMission.destinationId]
    local numPassengers = missionType.passengers or 1

    -- Spawn passenger NPCs
    local tierModels = Config.VIPTransport.PassengerModels[destination.tier] or Config.VIPTransport.PassengerModels.standard
    local pickup = ActiveMission.pickup

    lib.progressBar({
        duration = 3000,
        label = 'Boarding passengers...',
        useWhileDead = false,
        canCancel = false,
        disable = { move = true, car = true },
    })

    for i = 1, numPassengers do
        local model = tierModels[math.random(#tierModels)]
        lib.requestModel(model, 5000)

        local ped = CreatePed(4, GetHashKey(model), pickup.coords.x, pickup.coords.y, pickup.coords.z, pickup.heading, true, false)

        -- Put in vehicle
        local seatIndex = i -- Seats 1, 2, 3, 4 (passenger seats)
        TaskWarpPedIntoVehicle(ped, vehicle, seatIndex)

        table.insert(PassengerPeds, ped)
        SetModelAsNoLongerNeeded(GetHashKey(model))
    end

    ActiveMission.passengersLoaded = true

    -- Remove pickup zone and blip
    if ActiveMission.pickupZone then
        ActiveMission.pickupZone:remove()
        ActiveMission.pickupZone = nil
    end

    if PickupBlip then
        SetBlipRoute(PickupBlip, false)
        RemoveBlip(PickupBlip)
        PickupBlip = nil
    end

    -- Create destination blip
    DestinationBlip = AddBlipForCoord(destination.boatDock.x, destination.boatDock.y, destination.boatDock.z)
    SetBlipSprite(DestinationBlip, Config.VIPTransport.Blip.destination.sprite)
    SetBlipColour(DestinationBlip, Config.VIPTransport.Blip.destination.color)
    SetBlipScale(DestinationBlip, Config.VIPTransport.Blip.destination.scale)
    SetBlipRoute(DestinationBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextEntry('vip_dest', destination.name)
    EndTextCommandSetBlipName(DestinationBlip)

    lib.notify({
        title = 'VIP Transport',
        description = 'Passengers boarded! Take them to ' .. destination.name,
        type = 'success',
        duration = 5000,
    })

    -- Start destination zone
    CreateDestinationZone(destination)

    -- Track collisions
    TrackCollisions()
end

function CreateDestinationZone(destination)
    local zone = lib.zones.sphere({
        coords = destination.boatDock,
        radius = 20.0,
        debug = Config.Debug,
        onEnter = function()
            lib.notify({
                title = 'VIP Transport',
                description = 'Press [E] to drop off passengers',
                type = 'info',
            })
        end,
    })

    ActiveMission.destinationZone = zone

    -- Wait for player to drop off
    CreateThread(function()
        while ActiveMission and ActiveMission.passengersLoaded do
            Wait(100)

            if ActiveMission.destinationZone then
                local playerCoords = GetEntityCoords(PlayerPedId())
                local dist = #(playerCoords - destination.boatDock)

                if dist < 20.0 then
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                    if vehicle and vehicle ~= 0 then
                        if IsControlJustPressed(0, 51) then -- E key
                            CompleteMission()
                        end
                    end
                end
            end
        end
    end)
end

function TrackCollisions()
    CreateThread(function()
        local lastHealth = 1000

        while ActiveMission and ActiveMission.passengersLoaded do
            Wait(500)

            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle and vehicle ~= 0 then
                local health = GetEntityHealth(vehicle)
                if health < lastHealth - 50 then -- Significant damage
                    CollisionCount = CollisionCount + 1

                    if CollisionCount == 1 then
                        lib.notify({
                            title = 'VIP Transport',
                            description = 'Careful! The passengers are uncomfortable',
                            type = 'warning',
                        })
                    elseif CollisionCount == 3 then
                        lib.notify({
                            title = 'VIP Transport',
                            description = 'Too many collisions! Tip reduced',
                            type = 'error',
                        })
                    end
                end
                lastHealth = health
            end
        end
    end)
end

-----------------------------------------------------------
-- MISSION COMPLETION
-----------------------------------------------------------

function CompleteMission()
    if not ActiveMission then return end

    lib.progressBar({
        duration = 2000,
        label = 'Passengers disembarking...',
        useWhileDead = false,
        canCancel = false,
        disable = { move = true, car = true },
    })

    -- Calculate time
    local elapsedTime = (GetGameTimer() - MissionStartTime) / 1000
    local missionType = Config.VIPTransport.MissionTypes[ActiveMission.missionTypeId]
    local onTime = elapsedTime <= missionType.timeLimit

    -- Remove passengers
    for _, ped in ipairs(PassengerPeds) do
        if DoesEntityExist(ped) then
            TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
            SetTimeout(3000, function()
                if DoesEntityExist(ped) then
                    DeleteEntity(ped)
                end
            end)
        end
    end
    PassengerPeds = {}

    -- Calculate satisfaction
    local satisfaction = 0
    if CollisionCount == 0 then
        satisfaction = satisfaction + Config.VIPTransport.SatisfactionFactors.smoothRide
    end
    if onTime then
        satisfaction = satisfaction + Config.VIPTransport.SatisfactionFactors.onTime
    end

    -- Request payout from server
    local result = lib.callback.await('dps-maritime:server:completeVIPMission', false, {
        missionTypeId = ActiveMission.missionTypeId,
        destinationId = ActiveMission.destinationId,
        elapsedTime = elapsedTime,
        collisions = CollisionCount,
        satisfaction = satisfaction,
    })

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
    else
        local tipMsg = ''
        if result.tip and result.tip > 0 then
            tipMsg = ' + ' .. Maritime.FormatMoney(result.tip) .. ' tip!'
        end

        lib.notify({
            title = 'VIP Transport Complete!',
            description = 'Earned ' .. Maritime.FormatMoney(result.payout) .. tipMsg,
            type = 'success',
            duration = 8000,
        })
    end

    -- Cleanup
    CleanupMission()
end

function CleanupMission()
    if PickupBlip then
        RemoveBlip(PickupBlip)
        PickupBlip = nil
    end

    if DestinationBlip then
        RemoveBlip(DestinationBlip)
        DestinationBlip = nil
    end

    if ActiveMission then
        if ActiveMission.pickupZone then
            ActiveMission.pickupZone:remove()
        end
        if ActiveMission.destinationZone then
            ActiveMission.destinationZone:remove()
        end
    end

    for _, ped in ipairs(PassengerPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    PassengerPeds = {}

    ActiveMission = nil
    MissionStartTime = nil
    CollisionCount = 0
end

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('OpenVIPTransportMenu', OpenVIPTransportMenu)
exports('HasActiveVIPMission', function()
    return ActiveMission ~= nil
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CleanupMission()
    end
end)
