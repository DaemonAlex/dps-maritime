--[[
    dps-maritime - Jetsam Company
    Fleet Management Client
]]

-- Uses Bridge for framework abstraction

-----------------------------------------------------------
-- FLEET MENU
-----------------------------------------------------------

function OpenFleetMenu()
    local result = lib.callback.await('dps-maritime:server:getFleet', false)

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
        return
    end

    local boats = result.boats or {}

    if #boats == 0 then
        -- No boats owned
        lib.registerContext({
            id = 'maritime_fleet_empty',
            title = 'My Fleet',
            menu = 'maritime_main_menu',
            options = {
                {
                    title = 'No Boats Owned',
                    description = 'Visit the boat shop to purchase vessels',
                    icon = 'ship',
                    disabled = true,
                },
                {
                    title = 'Claim Starter Boat',
                    description = 'Get your free starter vessel',
                    icon = 'gift',
                    onSelect = function()
                        ClaimStarterBoat()
                    end,
                },
            },
        })
        lib.showContext('maritime_fleet_empty')
        return
    end

    local options = {}

    for _, boat in ipairs(boats) do
        local boatConfig = Config.Boats[boat.model]
        local conditionColor = boat.condition > 50 and 'green' or (boat.condition > 25 and 'orange' or 'red')

        table.insert(options, {
            title = boat.name or boatConfig.label,
            description = string.format('%s | Condition: %d%% | Fuel: %d%%',
                boatConfig.label,
                boat.condition,
                math.floor((boat.fuel / boatConfig.fuelCapacity) * 100)
            ),
            icon = 'ship',
            arrow = true,
            onSelect = function()
                OpenBoatManageMenu(boat.id, boat, boatConfig)
            end,
        })
    end

    table.insert(options, {
        title = 'Fleet Capacity',
        description = #boats .. '/' .. Config.Fleet.MaxBoatsPerPlayer .. ' boats',
        icon = 'warehouse',
        disabled = true,
    })

    lib.registerContext({
        id = 'maritime_fleet',
        title = 'My Fleet',
        menu = 'maritime_main_menu',
        options = options,
    })

    lib.showContext('maritime_fleet')
end

-----------------------------------------------------------
-- BOAT MANAGEMENT
-----------------------------------------------------------

function OpenBoatManageMenu(boatId, boat, boatConfig)
    local sellPrice = math.floor(boatConfig.price * Config.Fleet.SellBackPercent * (boat.condition / 100))

    local options = {
        {
            title = 'Boat Details',
            description = boatConfig.label .. ' (Tier ' .. boatConfig.tier .. ')',
            icon = 'info-circle',
            metadata = {
                { label = 'Speed', value = boatConfig.speed },
                { label = 'Cargo Capacity', value = boatConfig.cargoCapacity },
                { label = 'Fuel Capacity', value = boatConfig.fuelCapacity .. 'L' },
                { label = 'Hazmat Rated', value = boatConfig.hazmatRated and 'Yes' or 'No' },
            },
        },
        {
            title = 'Condition: ' .. boat.condition .. '%',
            description = boat.condition < 100 and 'Needs repair' or 'Perfect condition',
            icon = 'heart',
            progress = boat.condition,
        },
        {
            title = 'Fuel: ' .. math.floor((boat.fuel / boatConfig.fuelCapacity) * 100) .. '%',
            description = boat.fuel .. '/' .. boatConfig.fuelCapacity .. ' liters',
            icon = 'gas-pump',
            progress = math.floor((boat.fuel / boatConfig.fuelCapacity) * 100),
        },
    }

    -- Spawn boat option
    table.insert(options, {
        title = 'Spawn Boat',
        description = 'Spawn at nearest port',
        icon = 'water',
        onSelect = function()
            SpawnOwnedBoat(boatId)
        end,
    })

    -- Repair option
    if boat.condition < 100 then
        local damagePercent = 100 - boat.condition
        local repairCost = math.floor(boatConfig.price * Config.Fleet.RepairCostPercent * (damagePercent / 100))

        table.insert(options, {
            title = 'Repair Boat',
            description = 'Cost: ' .. Maritime.FormatMoney(repairCost),
            icon = 'wrench',
            onSelect = function()
                RepairBoat(boatId)
            end,
        })
    end

    -- Rename option
    table.insert(options, {
        title = 'Rename Boat',
        description = 'Current: ' .. (boat.name or boatConfig.label),
        icon = 'pen',
        onSelect = function()
            RenameBoat(boatId)
        end,
    })

    -- Sell option
    table.insert(options, {
        title = 'Sell Boat',
        description = 'Sell for ' .. Maritime.FormatMoney(sellPrice),
        icon = 'dollar-sign',
        onSelect = function()
            SellBoat(boatId, boatConfig.label, sellPrice)
        end,
    })

    -- Insurance claim (if destroyed)
    if boat.condition <= 0 then
        local payout = math.floor(boatConfig.price * Config.Fleet.InsurancePayoutPercent)

        table.insert(options, {
            title = 'Insurance Claim',
            description = 'Claim ' .. Maritime.FormatMoney(payout) .. ' for total loss',
            icon = 'shield',
            onSelect = function()
                InsuranceClaim(boatId)
            end,
        })
    end

    lib.registerContext({
        id = 'maritime_boat_manage_' .. boatId,
        title = boat.name or boatConfig.label,
        menu = 'maritime_fleet',
        options = options,
    })

    lib.showContext('maritime_boat_manage_' .. boatId)
end

-----------------------------------------------------------
-- FLEET ACTIONS
-----------------------------------------------------------

function ClaimStarterBoat()
    local result = lib.callback.await('dps-maritime:server:claimStarterBoat', false)

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
        return
    end

    OpenFleetMenu()
end

function SpawnOwnedBoat(boatId)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestPort, nearestDist = Maritime.GetNearestPort(playerCoords)

    if nearestDist > 100.0 then
        lib.notify({ description = 'You need to be at a port to spawn your boat', type = 'error' })
        return
    end

    local port = Config.Ports[nearestPort]
    if not port then return end

    local result = lib.callback.await('dps-maritime:server:spawnOwnedBoat', false, boatId, port.boatSpawn)

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
        return
    end

    -- Spawn the boat
    local spawnPos = port.boatSpawn
    local boatConfig = result.config

    lib.requestModel(result.model, 5000)

    local boat = CreateVehicle(
        joaat(result.model),
        spawnPos.x, spawnPos.y, spawnPos.z + (boatConfig.spawnOffset.z or 0.5),
        spawnPos.w,
        true, false
    )

    SetEntityAsMissionEntity(boat, true, true)
    SetVehicleOnGroundProperly(boat)
    SetVehicleEngineOn(boat, true, true, false)
    SetModelAsNoLongerNeeded(joaat(result.model))

    -- Set fuel
    if Config.Fuel.Enabled then
        exports[Config.Fuel.System]:SetFuel(boat, result.fuel)
    end

    -- Set condition as body health
    local health = math.floor((result.condition / 100) * 1000)
    SetEntityHealth(boat, health)

    lib.notify({
        description = 'Boat spawned at ' .. port.shortName,
        type = 'success',
    })
end

function RepairBoat(boatId)
    local confirm = lib.alertDialog({
        header = 'Repair Boat?',
        content = 'This will fully repair your boat.',
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then return end

    local result = lib.callback.await('dps-maritime:server:repairBoat', false, boatId)

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
        return
    end

    OpenFleetMenu()
end

function RenameBoat(boatId)
    local input = lib.inputDialog('Rename Boat', {
        { type = 'input', label = 'New Name', placeholder = 'Enter boat name', max = 30 },
    })

    if not input or not input[1] then return end

    local result = lib.callback.await('dps-maritime:server:renameBoat', false, boatId, input[1])

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
        return
    end

    lib.notify({ description = 'Boat renamed successfully', type = 'success' })
    OpenFleetMenu()
end

function SellBoat(boatId, boatName, sellPrice)
    local confirm = lib.alertDialog({
        header = 'Sell ' .. boatName .. '?',
        content = 'You will receive ' .. Maritime.FormatMoney(sellPrice),
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then return end

    local result = lib.callback.await('dps-maritime:server:sellBoat', false, boatId)

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
        return
    end

    OpenFleetMenu()
end

function InsuranceClaim(boatId)
    local confirm = lib.alertDialog({
        header = 'File Insurance Claim?',
        content = 'This will permanently remove the boat from your fleet.',
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then return end

    local result = lib.callback.await('dps-maritime:server:insuranceClaim', false, boatId)

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
        return
    end

    OpenFleetMenu()
end
