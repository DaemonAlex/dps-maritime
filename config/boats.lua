--[[
    dps-maritime - Jetsam Company
    Boat Definitions
]]

Config.Boats = {
    -----------------------------------------------------------
    -- TIER 1: Small Vessels (Level 4+)
    -----------------------------------------------------------
    ['dinghy'] = {
        label = 'Dinghy',
        model = 'dinghy',
        tier = 1,
        levelRequired = 4,
        price = 15000,
        rentalPrice = 500, -- Low-level rental option

        -- Performance
        speed = 60,
        handling = 0.9,
        cargoCapacity = 1,
        fuelCapacity = 50,
        fuelConsumption = 0.4, -- Fuel efficient

        -- Payout multiplier (based on vessel size/capacity)
        payMultiplier = 1.0,

        -- Spawn
        spawnOffset = vector3(0, 0, 0.5),

        -- Features
        hazmatRated = false,
        canTowContainers = false,

        -- SMALL CRAFT BENEFITS
        fuelEfficiencyBonus = 0.3,    -- 30% less fuel usage
        dockAccess = 'all',            -- Can dock anywhere
        remoteDelivery = true,         -- Can deliver to remote locations
        canalAccess = true,            -- Can navigate canals
    },

    ['seashark'] = {
        label = 'Seashark',
        model = 'seashark',
        tier = 1,
        levelRequired = 4,
        price = 12000, -- REDUCED: Budget express option
        rentalPrice = 300,

        speed = 80,
        handling = 0.95,
        cargoCapacity = 1,
        fuelCapacity = 30,
        fuelConsumption = 0.3, -- VERY fuel efficient (half of others)

        payMultiplier = 0.9, -- Less cargo = less pay for normal deliveries

        spawnOffset = vector3(0, 0, 0.3),
        hazmatRated = false,
        canTowContainers = false,

        -- FUEL EFFICIENCY SPECIALIST
        fuelEfficiencyBonus = 0.5, -- Uses 50% less fuel than listed

        -- EXPRESS DELIVERY SPECIALIST
        -- The Seashark can navigate narrow canal routes that larger boats cannot
        expressDelivery = true,       -- Can do express routes
        expressPayBonus = 0.5,        -- +50% pay on express routes
        canalAccess = true,           -- Can navigate LS River canals

        -- DOCK ACCESS: Can deliver anywhere
        dockAccess = 'all',           -- Small craft can dock anywhere
        remoteDelivery = true,        -- Can deliver to remote/hard-to-reach locations
    },

    ['speeder'] = {
        label = 'Speeder',
        model = 'speeder',
        tier = 1,
        levelRequired = 4,
        price = 45000,
        rentalPrice = 1000,

        speed = 75,
        handling = 0.85,
        cargoCapacity = 2,
        fuelCapacity = 80,
        fuelConsumption = 0.8,

        payMultiplier = 1.15, -- Good balance of speed and capacity

        spawnOffset = vector3(0, 0, 0.5),
        hazmatRated = false,
        canTowContainers = false,
    },

    ['suntrap'] = {
        label = 'Suntrap',
        model = 'suntrap',
        tier = 1,
        levelRequired = 4,
        price = 28000,
        rentalPrice = 600,

        speed = 50,
        handling = 0.8,
        cargoCapacity = 2,
        fuelCapacity = 60,
        fuelConsumption = 0.6,

        payMultiplier = 1.1, -- Slow but decent capacity

        spawnOffset = vector3(0, 0, 0.5),
        hazmatRated = false,
        canTowContainers = false,
    },

    -----------------------------------------------------------
    -- TIER 2: Medium Vessels (Level 5-6)
    -----------------------------------------------------------
    ['jetmax'] = {
        label = 'Jetmax',
        model = 'jetmax',
        tier = 2,
        levelRequired = 5,
        price = 225000,
        rentalPrice = 5000,

        speed = 70,
        handling = 0.85,
        cargoCapacity = 3,
        fuelCapacity = 150,
        fuelConsumption = 0.9,

        payMultiplier = 1.35,

        spawnOffset = vector3(0, 0, 0.5),
        hazmatRated = false,
        canTowContainers = false,
    },

    ['tropic'] = {
        label = 'Tropic',
        model = 'tropic',
        tier = 2,
        levelRequired = 5,
        price = 150000,
        rentalPrice = 3500,

        speed = 55,
        handling = 0.8,
        cargoCapacity = 4,
        fuelCapacity = 200,
        fuelConsumption = 0.85,

        payMultiplier = 1.5, -- High capacity workhorse

        spawnOffset = vector3(0, 0, 0.5),
        hazmatRated = false,
        canTowContainers = false,
    },

    ['squalo'] = {
        label = 'Squalo',
        model = 'squalo',
        tier = 2,
        levelRequired = 6,
        price = 285000,
        rentalPrice = 6000,

        speed = 68,
        handling = 0.88,
        cargoCapacity = 3,
        fuelCapacity = 180,
        fuelConsumption = 0.95,

        payMultiplier = 1.4,

        spawnOffset = vector3(0, 0, 0.5),
        hazmatRated = false,
        canTowContainers = false,
    },

    ['toro'] = {
        label = 'Toro',
        model = 'toro',
        tier = 2,
        levelRequired = 6,
        price = 375000,
        rentalPrice = 8000,

        speed = 65,
        handling = 0.82,
        cargoCapacity = 4,
        fuelCapacity = 220,
        fuelConsumption = 1.0,

        payMultiplier = 1.6, -- Premium mid-tier vessel

        spawnOffset = vector3(0, 0, 0.5),
        hazmatRated = false,
        canTowContainers = false,
    },

    -----------------------------------------------------------
    -- TIER 3: Large Vessels (Level 7+)
    -----------------------------------------------------------
    ['costal'] = {
        label = 'Coastal Cargo Ship',
        model = 'costal',
        tier = 3,
        levelRequired = 7,
        price = 450000,
        rentalPrice = 15000,

        speed = 35,
        handling = 0.5,
        cargoCapacity = 8,
        fuelCapacity = 500,
        fuelConsumption = 1.5,

        payMultiplier = 2.0, -- Cargo ships get major bonuses

        spawnOffset = vector3(0, 0, 1.0),
        hazmatRated = true,
        canTowContainers = true,

        -- Cargo ship specific
        containerCapacity = 2,

        -- LARGE VESSEL RESTRICTIONS
        dockAccess = 'major',          -- Can only dock at major ports
        minDepthRequired = 8.0,        -- Needs deep water
        remoteDelivery = false,        -- Cannot deliver to small docks
        fuelEfficiencyBonus = -0.2,    -- 20% MORE fuel usage (less efficient)
    },

    ['marquis'] = {
        label = 'Marquis Yacht',
        model = 'marquis',
        tier = 3,
        levelRequired = 8,
        price = 1500000,
        rentalPrice = 25000,

        speed = 45,
        handling = 0.6,
        cargoCapacity = 6,
        fuelCapacity = 400,
        fuelConsumption = 1.2,

        payMultiplier = 1.8, -- Luxury vessel for high-value cargo

        spawnOffset = vector3(0, 0, 1.0),
        hazmatRated = true,
        canTowContainers = false,
    },

    ['tug'] = {
        label = 'Tug Boat',
        model = 'tug',
        tier = 3,
        levelRequired = 9,
        price = 2250000,
        rentalPrice = 40000,

        speed = 25,
        handling = 0.4,
        cargoCapacity = 10,
        fuelCapacity = 800,
        fuelConsumption = 2.0,

        payMultiplier = 2.5, -- Slow but massive capacity

        spawnOffset = vector3(0, 0, 1.5),
        hazmatRated = true,
        canTowContainers = true,

        containerCapacity = 4,

        -- BULK HAULING SPECIALIST
        -- The Tug is the ONLY vessel that can do bulk container runs
        bulkHauling = true,
        bulkContainerMin = 5,    -- Minimum 5 containers per bulk run
        bulkContainerMax = 10,   -- Maximum 10 containers per bulk run
        bulkPayBonus = 0.75,     -- +75% pay for bulk runs (on top of payMultiplier)
        bulkXPBonus = 1.0,       -- Double XP for bulk runs

        -- Bulk run risks (makes it an "escort mission")
        bulkPirateChance = 0.15, -- 15% chance of NPC pirates attacking
        bulkPoliceChance = 0.10, -- 10% chance of coast guard inspection (if carrying illegal)
    },

    ['costal2'] = {
        label = 'Large Cargo Vessel',
        model = 'costal2',
        tier = 3,
        levelRequired = 10,
        price = 5000000,
        rentalPrice = 75000,

        speed = 30,
        handling = 0.35,
        cargoCapacity = 16,
        fuelCapacity = 1200,
        fuelConsumption = 2.5,

        payMultiplier = 3.5, -- Maximum payout vessel

        spawnOffset = vector3(0, 0, 2.0),
        hazmatRated = true,
        canTowContainers = true,

        containerCapacity = 6,

        -- LARGE VESSEL RESTRICTIONS
        dockAccess = 'major',          -- Can only dock at major ports
        minDepthRequired = 12.0,       -- Needs VERY deep water
        remoteDelivery = false,        -- Cannot deliver to small docks
        fuelEfficiencyBonus = -0.3,    -- 30% MORE fuel usage (large engine)
    },
}

-----------------------------------------------------------
-- DOCK ACCESS TYPES
-----------------------------------------------------------

Config.DockAccessTypes = {
    ['all'] = {
        label = 'All Ports',
        description = 'Can dock at any location',
        ports = 'all',
    },
    ['major'] = {
        label = 'Major Ports Only',
        description = 'Can only dock at deep water ports',
        ports = { 'elysian', 'paleto', 'cayo' }, -- Must match port IDs in locations.lua
    },
}

-----------------------------------------------------------
-- REMOTE DELIVERY LOCATIONS
-- Only accessible by small craft (Seashark, Dinghy)
-----------------------------------------------------------

Config.RemoteDeliveries = {
    ['cayo_ruins'] = {
        name = 'Cayo Perico Ruins',
        coords = vector3(5030.45, -5150.32, 1.0),
        payBonus = 0.35, -- +35% for remote delivery
        requiresRemoteAccess = true,
    },
    ['canal_warehouse'] = {
        name = 'LS River Warehouse',
        coords = vector3(450.23, -1250.67, 0.5),
        payBonus = 0.25,
        requiresRemoteAccess = true,
        requiresCanalAccess = true,
    },
    ['gordo_lighthouse'] = {
        name = 'El Gordo Lighthouse',
        coords = vector3(3424.56, 5167.89, 1.0),
        payBonus = 0.40, -- Remote + lighthouse delivery
        requiresRemoteAccess = true,
    },
    ['humane_beach'] = {
        name = 'Humane Labs Beach',
        coords = vector3(3852.12, 3690.45, 0.5),
        payBonus = 0.30,
        requiresRemoteAccess = true,
    },
}

-----------------------------------------------------------
-- HELPER FUNCTIONS
-----------------------------------------------------------

function Config.GetBoat(model)
    return Config.Boats[model]
end

function Config.GetBoatsForLevel(level)
    local available = {}
    for model, data in pairs(Config.Boats) do
        if level >= data.levelRequired then
            available[model] = data
        end
    end
    return available
end

function Config.GetBoatsByTier(tier)
    local boats = {}
    for model, data in pairs(Config.Boats) do
        if data.tier == tier then
            boats[model] = data
        end
    end
    return boats
end

function Config.CanUseBoat(model, level)
    local boat = Config.Boats[model]
    if not boat then return false end
    return level >= boat.levelRequired
end
