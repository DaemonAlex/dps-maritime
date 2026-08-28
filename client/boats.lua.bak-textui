--[[
    dps-maritime - Jetsam Company
    Boat Delivery Client
]]

-- Uses Bridge for framework abstraction

-- Job state
local IsBoatWorking = false
local CurrentBoatJob = nil
local SpawnedBoat = nil
local JobBlip = nil
local DestinationBlip = nil

-- Fuel enforcement state
local LastFuelWarning = 0
local FuelStutterActive = false
local FuelMonitorThread = nil

-----------------------------------------------------------
-- BOAT DELIVERY MENU
-----------------------------------------------------------

function OpenBoatDeliveryMenu()
    if IsBoatWorking then
        -- Already working
        lib.registerContext({
            id = 'maritime_boat_working',
            title = 'Boat Delivery - Active',
            menu = 'maritime_main_menu',
            options = {
                {
                    title = 'Current Delivery',
                    description = 'To: ' .. (Config.Ports[CurrentBoatJob.endPort] and Config.Ports[CurrentBoatJob.endPort].name or 'Unknown'),
                    icon = 'ship',
                },
                {
                    title = 'Cargo',
                    description = Config.CargoTypes[CurrentBoatJob.cargoType] and Config.CargoTypes[CurrentBoatJob.cargoType].label or 'Standard',
                    icon = 'box',
                },
                {
                    title = 'Cancel Delivery',
                    description = 'Abandon current delivery (streak reset)',
                    icon = 'circle-xmark',
                    onSelect = function()
                        CancelBoatJob()
                    end,
                },
            },
        })
        lib.showContext('maritime_boat_working')
        return
    end

    -- Show port selection
    local options = {}

    for portId, port in pairs(Config.Ports) do
        local distance = #(GetEntityCoords(PlayerPedId()) - port.coords)

        table.insert(options, {
            title = port.name,
            description = string.format('%.1f km away | %s bonus',
                distance / 1000,
                port.payBonus > 0 and '+' .. math.floor(port.payBonus * 100) .. '%' or 'No'
            ),
            icon = 'anchor',
            onSelect = function()
                SelectBoatAndCargo(portId)
            end,
        })
    end

    lib.registerContext({
        id = 'maritime_boat_menu',
        title = 'Boat Deliveries - Select Start Port',
        menu = 'maritime_main_menu',
        options = options,
    })

    lib.showContext('maritime_boat_menu')
end

-----------------------------------------------------------
-- BOAT AND CARGO SELECTION
-----------------------------------------------------------

-- Store manifest data for job start
local PendingManifestData = nil
local PendingIsTradedManifest = false

function SelectBoatAndCargo(startPortId)
    local level = exports['dps-maritime']:GetPlayerLevel()
    local availableBoats = Maritime.GetAvailableBoats(level)
    local availableCargo = Maritime.GetAvailableCargo(level)

    local boatOptions = {}
    for model, boat in pairs(availableBoats) do
        table.insert(boatOptions, { value = model, label = boat.label .. ' (Tier ' .. boat.tier .. ')' })
    end

    local cargoOptions = {}
    for cargoId, cargo in pairs(availableCargo) do
        local label = cargo.label
        if cargo.illegal then label = label .. ' [ILLEGAL]' end
        if cargo.hazmat then label = label .. ' [HAZMAT]' end
        table.insert(cargoOptions, { value = cargoId, label = label })
    end

    local input = lib.inputDialog('Setup Delivery', {
        { type = 'select', label = 'Select Boat', options = boatOptions, required = true },
        { type = 'select', label = 'Select Cargo', options = cargoOptions, required = true },
    })

    if not input then return end

    local boatModel = input[1]
    local cargoType = input[2]

    -- Validate with server (this also checks/consumes manifest)
    local result = lib.callback.await('dps-maritime:server:requestBoatJob', false, boatModel, cargoType)

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
        return
    end

    -- Store manifest data for job start
    PendingManifestData = result.manifestData
    PendingIsTradedManifest = result.isTradedManifest or false

    -- Select destination
    SelectDestination(startPortId, boatModel, cargoType)
end

function SelectDestination(startPortId, boatModel, cargoType)
    local level = exports['dps-maritime']:GetPlayerLevel()
    local options = {}
    local startPort = Config.Ports[startPortId]

    -- Regular ports
    for portId, port in pairs(Config.Ports) do
        if portId ~= startPortId then
            local distance = Maritime.CalculateDistance(startPort.coords, port.coords)
            local locked = false

            -- Check tier access
            local tierRequired = port.tier or 1
            local levelRequired = (tierRequired - 1) * 3 + 4

            if level < levelRequired then
                locked = true
            end

            table.insert(options, {
                title = port.name,
                description = locked and 'Requires Level ' .. levelRequired or string.format('%.1f km | %s bonus',
                    distance / 1000,
                    port.payBonus > 0 and '+' .. math.floor(port.payBonus * 100) .. '%' or 'No'
                ),
                icon = locked and 'lock' or 'anchor',
                disabled = locked,
                onSelect = function()
                    StartBoatJob(startPortId, portId, boatModel, cargoType, false)
                end,
            })
        end
    end

    -- Deep sea ports (compass navigation)
    if Config.DeepSeaPorts then
        -- Add separator
        table.insert(options, {
            title = '── DISTANT DESTINATIONS ──',
            description = 'Compass navigation only - no GPS!',
            icon = 'compass',
            disabled = true,
        })

        for portId, port in pairs(Config.DeepSeaPorts) do
            local distance = Maritime.CalculateDistance(startPort.coords, port.coords)
            local locked = false
            local lockReason = nil

            -- Check level requirement
            if port.minLevel and level < port.minLevel then
                locked = true
                lockReason = 'Requires Level ' .. port.minLevel
            end

            -- Check cargo type restrictions
            if not locked and port.illegalOnly then
                local cargo = Config.CargoTypes[cargoType]
                if not cargo or not cargo.illegal then
                    locked = true
                    lockReason = 'Contraband cargo only'
                end
            end

            if not locked and port.hazmatOnly then
                local cargo = Config.CargoTypes[cargoType]
                if not cargo or not cargo.hazmat then
                    locked = true
                    lockReason = 'Hazmat cargo only'
                end
            end

            local description
            if locked then
                description = lockReason
            else
                description = string.format('~o~%.1f km~w~ | ~g~+%d%%~w~ bonus | ~r~COMPASS ONLY~w~',
                    distance / 1000,
                    math.floor(port.payBonus * 100)
                )
                if port.fuelRequired then
                    description = description .. string.format('\nMin fuel: %d liters', port.fuelRequired)
                end
            end

            table.insert(options, {
                title = '⚓ ' .. port.name,
                description = description,
                icon = locked and 'lock' or 'ship',
                disabled = locked,
                onSelect = function()
                    -- Check fuel before starting
                    if port.fuelRequired and Config.FuelEnforcement and Config.FuelEnforcement.Enabled then
                        local ped = PlayerPedId()
                        local vehicle = GetVehiclePedIsIn(ped, false)

                        if vehicle and DoesEntityExist(vehicle) then
                            local hasEnough, errorMsg = CheckFuelForDestination(port, vehicle)
                            if not hasEnough then
                                lib.notify({ description = errorMsg, type = 'error', duration = 8000 })
                                return
                            end
                        end
                    end

                    -- Confirm distant journey
                    local confirm = lib.alertDialog({
                        header = 'Distant Sea Journey',
                        content = string.format([[
**Destination:** %s
**Distance:** %.1f km
**Pay Bonus:** +%d%%

⚠️ **WARNING:**
• GPS will be DISABLED
• Use compass bearing to navigate
• Ensure you have enough fuel (%d liters minimum)
• Weather zones may affect your journey

Are you ready to depart?
]], port.name, distance / 1000, math.floor(port.payBonus * 100), port.fuelRequired or 0),
                        centered = true,
                        cancel = true,
                    })

                    if confirm == 'confirm' then
                        StartBoatJob(startPortId, portId, boatModel, cargoType, true)
                    end
                end,
            })
        end
    end

    lib.registerContext({
        id = 'maritime_destination',
        title = 'Select Destination',
        menu = 'maritime_boat_menu',
        options = options,
    })

    lib.showContext('maritime_destination')
end

-----------------------------------------------------------
-- START BOAT JOB
-----------------------------------------------------------

function StartBoatJob(startPortId, endPortId, boatModel, cargoType, isDeepSea)
    local startPort = Config.Ports[startPortId]
    local endPort = isDeepSea and Config.DeepSeaPorts[endPortId] or Config.Ports[endPortId]
    local boat = Config.Boats[boatModel]

    if not startPort or not endPort or not boat then return end

    -- Check if player has owned boat or needs to rent
    local level = exports['dps-maritime']:GetPlayerLevel()
    local canOwn = Config.CanOwnFleet(level)

    local useOwnedBoat = false
    local ownedBoatId = nil

    if canOwn then
        -- Check for owned boats
        local fleet = lib.callback.await('dps-maritime:server:getFleet', false)
        if fleet.boats and #fleet.boats > 0 then
            -- Ask if they want to use owned boat
            for _, ownedBoat in ipairs(fleet.boats) do
                if ownedBoat.model == boatModel then
                    local confirm = lib.alertDialog({
                        header = 'Use Owned Boat?',
                        content = 'You own a ' .. boat.label .. '. Use it instead of renting?',
                        centered = true,
                        cancel = true,
                    })

                    if confirm == 'confirm' then
                        useOwnedBoat = true
                        ownedBoatId = ownedBoat.id
                    end
                    break
                end
            end
        end
    end

    if not useOwnedBoat then
        -- Rent boat
        local result = lib.callback.await('dps-maritime:server:rentBoat', false, boatModel)
        if result.error then
            lib.notify({ description = result.error, type = 'error' })
            return
        end
    end

    -- Spawn boat
    SpawnBoat(startPort, boatModel, useOwnedBoat, ownedBoatId)

    -- Set job data
    IsBoatWorking = true
    CurrentBoatJob = {
        startPort = startPortId,
        endPort = endPortId,
        boatModel = boatModel,
        cargoType = cargoType,
        startCoords = startPort.coords,
        startTime = GetGameTimer(),
        ownedBoatId = ownedBoatId,
        -- Plate for key system
        plate = GetSpawnedBoatPlate(),
        -- Manifest data from validation step
        manifestData = PendingManifestData,
        isTradedManifest = PendingIsTradedManifest,
        -- Deep sea destination data
        isDeepSea = isDeepSea or false,
        usesCompass = endPort.navigation == 'compass',
    }

    -- Clear pending manifest data
    PendingManifestData = nil
    PendingIsTradedManifest = false

    exports['dps-maritime']:SetOnDuty(true, 'boat')

    -- Start fuel monitoring
    if Config.FuelEnforcement and Config.FuelEnforcement.Enabled then
        StartFuelMonitor()
    end

    -- Handle navigation based on destination type
    if endPort.navigation == 'compass' then
        -- Use compass navigation for distant destinations
        exports['dps-maritime']:StartCompassNavigation({
            coords = endPort.dockCoords or endPort.coords,
            name = endPort.name,
            hidesMinimap = endPort.hidesMinimap,
        })
    else
        -- Standard GPS blip for regular ports
        CreateDestinationBlip(endPort.coords, endPort.name)
    end

    -- Notify server
    TriggerServerEvent('dps-maritime:server:startBoatJob', CurrentBoatJob)

    local description = 'Delivery started. Destination: ' .. endPort.name
    if isDeepSea then
        description = description .. '\n~o~WARNING: GPS unavailable - use compass!~w~'
    end

    lib.notify({
        title = 'Jetsam Maritime',
        description = description,
        type = 'inform',
        duration = 8000,
    })
end

-----------------------------------------------------------
-- BOAT SPAWNING
-----------------------------------------------------------

-- Track spawned boat plate for key system
local SpawnedBoatPlate = nil

-- Generate a company plate for job boats
local function GenerateCompanyPlate()
    if not Config.VehicleKeys or not Config.VehicleKeys.GenerateCompanyPlate then
        return nil
    end

    local letters = 'ABCDEFGHJKLMNPRSTUVWXYZ'
    local randomLetter = letters:sub(math.random(#letters), math.random(#letters))
    local randomNum = math.random(1000, 9999)

    -- Format: JSM A 1234
    local plate = string.format(Config.VehicleKeys.CompanyPlateFormat or 'JSM%s%d', randomLetter, randomNum)

    -- Ensure 8 chars max
    return plate:sub(1, 8)
end

function SpawnBoat(port, boatModel, isOwned, ownedBoatId)
    local spawnPos = port.boatSpawn
    local boat = Config.Boats[boatModel]

    lib.requestModel(boatModel, 5000)

    SpawnedBoat = CreateVehicle(
        joaat(boatModel),
        spawnPos.x, spawnPos.y, spawnPos.z + (boat.spawnOffset.z or 0.5),
        spawnPos.w,
        true, false
    )

    SetEntityAsMissionEntity(SpawnedBoat, true, true)
    SetVehicleOnGroundProperly(SpawnedBoat)
    SetVehicleEngineOn(SpawnedBoat, true, true, false)
    SetModelAsNoLongerNeeded(joaat(boatModel))

    -- Set fuel if owned
    if isOwned and ownedBoatId then
        local boatDetails = lib.callback.await('dps-maritime:server:getBoatDetails', false, ownedBoatId)
        if boatDetails and boatDetails.boat then
            -- Set fuel with your fuel system
            if Config.Fuel.Enabled then
                exports[Config.Fuel.System]:SetFuel(SpawnedBoat, boatDetails.boat.fuel)
            end
            -- Owned boats keep their plate
            SpawnedBoatPlate = GetVehicleNumberPlateText(SpawnedBoat)
        end
    else
        -- Company boat - generate Jetsam plate
        SpawnedBoatPlate = GenerateCompanyPlate()
        if SpawnedBoatPlate then
            SetVehicleNumberPlateText(SpawnedBoat, SpawnedBoatPlate)
        else
            SpawnedBoatPlate = GetVehicleNumberPlateText(SpawnedBoat)
        end

        -- Full fuel for company boats
        if Config.Fuel.Enabled then
            exports[Config.Fuel.System]:SetFuel(SpawnedBoat, boat.fuelCapacity)
        end
    end

    -- Set waypoint
    SetNewWaypoint(spawnPos.x, spawnPos.y)
end

-- Get the current spawned boat plate
function GetSpawnedBoatPlate()
    return SpawnedBoatPlate
end

exports('GetSpawnedBoatPlate', GetSpawnedBoatPlate)

-- Export current boat job data for events system
exports('GetCurrentBoatJob', function()
    if IsBoatWorking and CurrentBoatJob then
        return CurrentBoatJob
    end
    return nil
end)

-----------------------------------------------------------
-- DESTINATION BLIP
-----------------------------------------------------------

function CreateDestinationBlip(coords, name)
    ClearDestinationBlip()

    DestinationBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(DestinationBlip, 427)
    SetBlipDisplay(DestinationBlip, 4)
    SetBlipScale(DestinationBlip, 1.0)
    SetBlipColour(DestinationBlip, 5)
    SetBlipRoute(DestinationBlip, true)
    SetBlipRouteColour(DestinationBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextEntry('boat_dest', 'Destination: ' .. name)
    EndTextCommandSetBlipName(DestinationBlip)
end

function ClearDestinationBlip()
    if DestinationBlip and DoesBlipExist(DestinationBlip) then
        RemoveBlip(DestinationBlip)
        DestinationBlip = nil
    end
end

-----------------------------------------------------------
-- COMPLETE DELIVERY
-----------------------------------------------------------

CreateThread(function()
    while true do
        Wait(1000)

        if IsBoatWorking and CurrentBoatJob then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local endPort = Config.Ports[CurrentBoatJob.endPort]

            if endPort then
                local distance = #(playerCoords - endPort.coords)

                if distance < 50.0 then
                    -- Near destination, check if in boat
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

                    if vehicle and vehicle == SpawnedBoat then
                        -- Show delivery prompt
                        lib.showTextUI('[E] Complete Delivery', {
                            position = 'right-center',
                        })

                        if IsControlJustPressed(0, 38) then -- E key
                            CompleteBoatDelivery()
                        end
                    else
                        lib.hideTextUI()
                    end
                else
                    lib.hideTextUI()
                end
            end
        end
    end
end)

function CompleteBoatDelivery()
    if not IsBoatWorking or not CurrentBoatJob then return end

    lib.hideTextUI()

    local startPort = Config.Ports[CurrentBoatJob.startPort]
    local endPort = Config.Ports[CurrentBoatJob.endPort]
    local distance = Maritime.CalculateDistance(startPort.coords, endPort.coords)

    -- Get boat damage
    local damagePercent = 0
    if SpawnedBoat and DoesEntityExist(SpawnedBoat) then
        local health = GetEntityHealth(SpawnedBoat)
        local maxHealth = GetEntityMaxHealth(SpawnedBoat)
        damagePercent = math.floor((1 - (health / maxHealth)) * 100)
    end

    -- Get weather
    local weather = lib.callback.await('dps-maritime:server:getWeather', false)

    -- Complete on server
    TriggerServerEvent('dps-maritime:server:completeBoatJob', {
        distance = distance,
        weather = weather,
        damagePercent = damagePercent,
    })

    -- Store owned boat
    if CurrentBoatJob.ownedBoatId and SpawnedBoat then
        local fuel = 100
        if Config.Fuel.Enabled then
            fuel = exports[Config.Fuel.System]:GetFuel(SpawnedBoat)
        end
        local condition = 100 - damagePercent

        TriggerServerEvent('dps-maritime:server:storeBoat', CurrentBoatJob.ownedBoatId, fuel, condition)
    end

    -- Cleanup
    CleanupBoatJob()
end

RegisterNetEvent('dps-maritime:client:boatJobComplete', function(data)
    local description = string.format('%s | +%d XP | %.1f km',
        Maritime.FormatMoney(data.pay),
        data.xp,
        data.distance / 1000
    )

    -- Show trade bonus if applicable
    if data.tradeBonus and data.tradeBonus > 0 then
        description = description .. string.format('\nTrade Bonus: +%s | +%d XP',
            Maritime.FormatMoney(data.tradeBonus),
            data.tradeXPBonus or 0
        )
    end

    lib.notify({
        title = 'Delivery Complete',
        description = description,
        type = 'success',
        duration = 8000,
    })
end)

-----------------------------------------------------------
-- CANCEL JOB
-----------------------------------------------------------

function CancelBoatJob()
    if not IsBoatWorking then return end

    local confirm = lib.alertDialog({
        header = 'Cancel Delivery?',
        content = 'You will lose your delivery streak and any rental fee paid.',
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then return end

    TriggerServerEvent('dps-maritime:server:cancelBoatJob')
    CleanupBoatJob()
end

-----------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------

function CleanupBoatJob()
    IsBoatWorking = false
    CurrentBoatJob = nil

    exports['dps-maritime']:SetOnDuty(false, nil)

    -- Stop fuel monitoring
    StopFuelMonitor()

    -- Stop compass navigation if active
    if exports['dps-maritime']:IsCompassNavigating() then
        exports['dps-maritime']:StopCompassNavigation()
    end

    ClearDestinationBlip()

    if SpawnedBoat and DoesEntityExist(SpawnedBoat) then
        DeleteVehicle(SpawnedBoat)
        SpawnedBoat = nil
    end

    lib.hideTextUI()
end

-----------------------------------------------------------
-- PORT TARGETS
-----------------------------------------------------------

CreateThread(function()
    Wait(1000)

    for portId, port in pairs(Config.Ports) do
        -- Fuel station at port
        if port.hasFuel then
            exports.ox_target:addSphereZone({
                coords = port.coords,
                radius = 10.0,
                options = {
                    {
                        name = 'boat_fuel_' .. portId,
                        icon = 'fa-solid fa-gas-pump',
                        label = 'Refuel Boat',
                        canInteract = function()
                            local ped = PlayerPedId()
                            local vehicle = GetVehiclePedIsIn(ped, false)
                            return vehicle and vehicle ~= 0 and IsThisModelABoat(GetEntityModel(vehicle))
                        end,
                        onSelect = function()
                            RefuelBoat()
                        end,
                    },
                },
            })
        end

        -- Create port blip
        local blip = AddBlipForCoord(port.coords.x, port.coords.y, port.coords.z)
        SetBlipSprite(blip, Config.Blips.Port.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Blips.Port.scale)
        SetBlipColour(blip, Config.Blips.Port.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextEntry('port_' .. portId, port.shortName)
        EndTextCommandSetBlipName(blip)
    end
end)

-----------------------------------------------------------
-- REFUELING
-----------------------------------------------------------

function RefuelBoat()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or not IsThisModelABoat(GetEntityModel(vehicle)) then
        lib.notify({ description = 'You need to be in a boat', type = 'error' })
        return
    end

    local currentFuel = 100
    if Config.Fuel.Enabled then
        currentFuel = exports[Config.Fuel.System]:GetFuel(vehicle)
    end

    local neededFuel = 100 - currentFuel
    if neededFuel <= 0 then
        lib.notify({ description = 'Tank is already full', type = 'inform' })
        return
    end

    local cost = math.ceil(neededFuel * Config.BoatDelivery.FuelPricePerLiter)

    local confirm = lib.alertDialog({
        header = 'Refuel Boat',
        content = string.format('Refuel %.0f liters for %s?', neededFuel, Maritime.FormatMoney(cost)),
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then return end

    local result = lib.callback.await('dps-maritime:server:refuelBoat', false, NetworkGetNetworkIdFromEntity(vehicle), neededFuel)

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
        return
    end

    -- Refuel animation
    lib.progressBar({
        duration = 5000,
        label = 'Refueling...',
        useWhileDead = false,
        canCancel = false,
        disable = { move = true, car = true, combat = true },
    })

    if Config.Fuel.Enabled then
        exports[Config.Fuel.System]:SetFuel(vehicle, 100)
    end

    lib.notify({
        description = 'Boat refueled for ' .. Maritime.FormatMoney(result.cost),
        type = 'success',
    })
end

-----------------------------------------------------------
-- ILLEGAL CARGO CHECKS
-----------------------------------------------------------

CreateThread(function()
    while true do
        Wait(30000) -- Check every 30 seconds

        if IsBoatWorking and CurrentBoatJob then
            local cargo = Config.CargoTypes[CurrentBoatJob.cargoType]
            if cargo and cargo.illegal then
                local playerCoords = GetEntityCoords(PlayerPedId())
                TriggerServerEvent('dps-maritime:server:illegalCargoAlert', playerCoords)
            end
        end
    end
end)

-----------------------------------------------------------
-- POLICE BLIP SYSTEM (for law enforcement visibility)
-----------------------------------------------------------

local PoliceBlips = {}

RegisterNetEvent('dps-maritime:client:createPoliceBlip', function(data)
    -- Only show to police/sheriff/coastguard
    local PlayerData = Bridge.GetPlayerData()
    local job = PlayerData.job and PlayerData.job.name

    if job ~= 'police' and job ~= 'sheriff' and job ~= 'coastguard' then
        return
    end

    -- Remove old blip if exists
    if PoliceBlips[data.smugglerId] then
        RemoveBlip(PoliceBlips[data.smugglerId])
    end

    -- Create new blip
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, 427)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.2)
    SetBlipColour(blip, 1) -- Red
    SetBlipFlashes(blip, true)
    SetBlipAsShortRange(blip, false) -- Show on map even when far
    BeginTextCommandSetBlipName('STRING')
    AddTextEntry('smuggler_' .. data.smugglerId, 'Suspected Smuggler')
    EndTextCommandSetBlipName(blip)

    PoliceBlips[data.smugglerId] = blip

    -- Auto-remove after 5 minutes
    SetTimeout(300000, function()
        if PoliceBlips[data.smugglerId] then
            RemoveBlip(PoliceBlips[data.smugglerId])
            PoliceBlips[data.smugglerId] = nil
        end
    end)
end)

RegisterNetEvent('dps-maritime:client:removePoliceBlip', function(smugglerId)
    if PoliceBlips[smugglerId] then
        RemoveBlip(PoliceBlips[smugglerId])
        PoliceBlips[smugglerId] = nil
    end
end)

-----------------------------------------------------------
-- FUEL ENFORCEMENT SYSTEM
-----------------------------------------------------------

local function GetBoatFuel(vehicle)
    if not Config.Fuel.Enabled then return 100 end
    if not vehicle or not DoesEntityExist(vehicle) then return 100 end

    return exports[Config.Fuel.System]:GetFuel(vehicle)
end

local function TriggerEngineStutter(vehicle)
    if FuelStutterActive then return end
    if not vehicle or not DoesEntityExist(vehicle) then return end

    FuelStutterActive = true

    -- Random stutter duration
    local duration = math.random(
        Config.FuelEnforcement.StutterDuration.min,
        Config.FuelEnforcement.StutterDuration.max
    )

    -- Kill engine
    SetVehicleEngineOn(vehicle, false, true, true)

    lib.notify({
        title = 'Low Fuel',
        description = 'Engine stutter - fuel critical!',
        type = 'error',
    })

    -- Restart after duration
    SetTimeout(duration, function()
        if vehicle and DoesEntityExist(vehicle) then
            SetVehicleEngineOn(vehicle, true, true, false)
        end
        FuelStutterActive = false
    end)
end

function StartFuelMonitor()  -- global: called earlier in this file
    if FuelMonitorThread then return end

    FuelMonitorThread = CreateThread(function()
        local lastStutterCheck = 0

        while IsBoatWorking do
            Wait(1000) -- Check every second

            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle and vehicle == SpawnedBoat and DoesEntityExist(vehicle) then
                local fuel = GetBoatFuel(vehicle)
                local currentTime = GetGameTimer()

                -- Stranded check (0% fuel)
                if fuel <= Config.FuelEnforcement.DeadAtPercent then
                    -- Engine won't start
                    SetVehicleEngineOn(vehicle, false, true, true)

                    if currentTime - LastFuelWarning > 10000 then
                        LastFuelWarning = currentTime
                        lib.notify({
                            title = 'OUT OF FUEL',
                            description = 'You are stranded! Call for rescue or abandon ship.',
                            type = 'error',
                            duration = 10000,
                        })
                    end

                    -- Show rescue option
                    lib.showTextUI('[G] Call Rescue (' .. Maritime.FormatMoney(Config.FuelEnforcement.RescueCost) .. ')', {
                        position = 'right-center',
                        icon = 'ship',
                    })

                    if IsControlJustPressed(0, 47) then -- G key
                        CallRescue()
                    end

                -- Engine stutter check (below stutter threshold)
                elseif fuel <= Config.FuelEnforcement.StutterStartPercent then
                    -- Random stutter chance
                    if currentTime - lastStutterCheck > 1000 then
                        lastStutterCheck = currentTime

                        if math.random() < Config.FuelEnforcement.StutterChancePerSecond then
                            TriggerEngineStutter(vehicle)
                        end
                    end

                    if currentTime - LastFuelWarning > 15000 then
                        LastFuelWarning = currentTime
                        lib.notify({
                            title = 'CRITICAL FUEL',
                            description = 'Engine failing! Find fuel immediately!',
                            type = 'error',
                        })
                    end

                -- Critical warning
                elseif fuel <= Config.FuelEnforcement.CriticalAtPercent then
                    if currentTime - LastFuelWarning > 30000 then
                        LastFuelWarning = currentTime
                        lib.notify({
                            title = 'Fuel Critical',
                            description = string.format('Only %.0f%% fuel remaining! Return to port NOW!', fuel),
                            type = 'error',
                        })
                    end

                -- Low fuel warning
                elseif fuel <= Config.FuelEnforcement.WarnAtPercent then
                    if currentTime - LastFuelWarning > 60000 then
                        LastFuelWarning = currentTime
                        lib.notify({
                            title = 'Low Fuel',
                            description = string.format('%.0f%% fuel remaining. Consider refueling.', fuel),
                            type = 'warning',
                        })
                    end
                end
            end
        end

        FuelMonitorThread = nil
    end)
end

function StopFuelMonitor()  -- global: called earlier in this file
    FuelMonitorThread = nil
    FuelStutterActive = false
    LastFuelWarning = 0
end

function CallRescue()
    local confirm = lib.alertDialog({
        header = 'Call Maritime Rescue?',
        content = string.format(
            'Cost: %s\nWait time: %d minutes\n\nA rescue vessel will tow you to the nearest port.',
            Maritime.FormatMoney(Config.FuelEnforcement.RescueCost),
            math.floor(Config.FuelEnforcement.RescueWaitTime / 60)
        ),
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then return end

    local result = lib.callback.await('dps-maritime:server:callRescue', false)

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
        return
    end

    lib.notify({
        title = 'Rescue Dispatched',
        description = 'Help is on the way. Stay with your vessel.',
        type = 'inform',
        duration = 10000,
    })

    -- Simulate rescue arrival
    lib.progressBar({
        duration = Config.FuelEnforcement.RescueWaitTime * 1000,
        label = 'Waiting for rescue...',
        useWhileDead = false,
        canCancel = false,
        disable = { move = false, car = true, combat = true },
    })

    -- Teleport to nearest port
    local nearestPort = nil
    local nearestDist = 999999

    local playerPos = GetEntityCoords(PlayerPedId())
    for portId, port in pairs(Config.Ports) do
        local dist = #(playerPos - port.coords)
        if dist < nearestDist then
            nearestDist = dist
            nearestPort = port
        end
    end

    if nearestPort then
        -- Cancel current job
        TriggerServerEvent('dps-maritime:server:cancelBoatJob')

        -- Clean up and teleport
        CleanupBoatJob()

        SetEntityCoords(PlayerPedId(), nearestPort.coords.x, nearestPort.coords.y, nearestPort.coords.z + 1)

        lib.notify({
            title = 'Rescue Complete',
            description = 'You have been brought to ' .. nearestPort.name,
            type = 'success',
        })
    end
end

-- Check if boat has enough fuel for distant destination
function CheckFuelForDestination(destination, vehicle)
    if not Config.FuelEnforcement or not Config.FuelEnforcement.Enabled then
        return true, nil
    end

    if not Config.FuelEnforcement.RequireMinFuelForDistant then
        return true, nil
    end

    local fuelRequired = destination.fuelRequired
    if not fuelRequired then return true, nil end

    local currentFuel = GetBoatFuel(vehicle)

    -- Get boat's fuel capacity
    local boatModel = GetEntityModel(vehicle)
    local boatData = nil
    for model, data in pairs(Config.Boats) do
        if joaat(model) == boatModel then
            boatData = data
            break
        end
    end

    if not boatData then return true, nil end

    -- Calculate fuel percentage required
    local percentRequired = (fuelRequired / boatData.fuelCapacity) * 100

    if currentFuel < percentRequired then
        return false, string.format(
            'Insufficient fuel! You need at least %d liters (%.0f%%) for this journey. Current: %.0f%%',
            fuelRequired,
            percentRequired,
            currentFuel
        )
    end

    return true, nil
end

-----------------------------------------------------------
-- CLEANUP ON RESOURCE STOP
-----------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    ClearDestinationBlip()
    StopFuelMonitor()
    lib.hideTextUI()

    if SpawnedBoat and DoesEntityExist(SpawnedBoat) then
        DeleteVehicle(SpawnedBoat)
    end

    -- Clean up police blips
    for id, blip in pairs(PoliceBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
end)
