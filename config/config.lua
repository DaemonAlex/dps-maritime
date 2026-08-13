--[[
    dps-maritime - Jetsam Company
    Main Configuration File
]]

Config = {}

-- Business Identity
Config.BusinessName = 'Jetsam'
Config.BusinessLabel = 'Jetsam Maritime Logistics'
Config.JobName = 'jetsam' -- QB-Core job name (optional, set to nil for civilian job)

-- Framework Settings
Config.Framework = 'qbx' -- 'qbx', 'qb', or 'esx' (this box is pure Qbox)
Config.Target = 'ox_target' -- 'ox_target', 'qb-target', or 'qtarget'
Config.Inventory = 'ox_inventory' -- 'ox_inventory', 'qb-inventory', 'qs-inventory'

-----------------------------------------------------------
-- CARGO CRATE METADATA SYSTEM (qs-inventory)
-- Sealed cargo crates with durability that degrades on damage
-----------------------------------------------------------

Config.CargoCrates = {
    Enabled = true,

    -- Base crate item (must exist in qs-inventory)
    BaseItem = 'sealed_cargo_crate',

    -- Durability settings
    StartingDurability = 100,
    MinSellDurability = 10,       -- Below this = worthless

    -- Damage sources and amounts
    DamageSources = {
        collision = 5,            -- Per collision
        water = 2,                -- Per second in water
        gunfire = 15,             -- Per bullet hit
        explosion = 50,           -- Nearby explosion
        rough_seas = 1,           -- Per 10 seconds in bad weather
    },

    -- Durability affects payout: BasePrice * (Durability / 100)
    PayoutFormula = function(basePrice, durability)
        if durability <= Config.CargoCrates.MinSellDurability then
            return 0 -- Worthless
        end
        return math.floor(basePrice * (durability / 100))
    end,

    -- Visual condition labels
    ConditionLabels = {
        [100] = { label = 'Pristine', color = '~g~' },
        [75]  = { label = 'Good', color = '~g~' },
        [50]  = { label = 'Damaged', color = '~y~' },
        [25]  = { label = 'Heavily Damaged', color = '~o~' },
        [10]  = { label = 'Critical', color = '~r~' },
        [0]   = { label = 'Destroyed', color = '~r~' },
    },
}
Config.Notifications = 'ox_lib' -- 'ox_lib' or 'qbcore'

-- Debug Mode
Config.Debug = false

-----------------------------------------------------------
-- VEHICLE KEYS INTEGRATION (qs-vehiclekeys, etc.)
-- Automatic key handover for company delivery boats
-----------------------------------------------------------

Config.VehicleKeys = {
    Enabled = true,

    -- Supported scripts: 'qs-vehiclekeys', 'qb-vehiclekeys', 'wasabi_carlock'
    -- Auto-detected if left nil
    Script = nil,

    -- Grant keys automatically when job boat spawns
    AutoGrantOnJobStart = true,

    -- Revoke keys when job ends/cancelled
    AutoRevokeOnJobEnd = true,

    -- Minimum level to hand over keys to other players (dock manager RP)
    ManagerKeyLevel = 8,

    -- Company boats (plates starting with these prefixes are Jetsam fleet)
    CompanyPlatePrefixes = {
        'JSM',    -- Jetsam Maritime
        'JTSM',   -- Jetsam
        'PORT',   -- Port Authority
    },

    -- Generate company plate for spawned job boats
    GenerateCompanyPlate = true,
    CompanyPlateFormat = 'JSM%s%d', -- JSM + random letter + random number
}

-----------------------------------------------------------
-- CARGO MANIFEST SYSTEM (Physical Item Trade)
-- Creates organic roleplay between dock workers and captains
-----------------------------------------------------------

Config.Manifest = {
    Enabled = true,

    -- Item name (must exist in qb-core/shared/items.lua)
    ItemName = 'cargo_manifest',

    -- Who can generate manifests
    GeneratorLevelMin = 1,        -- Dock workers start at level 1
    GeneratorLevelMax = 3,        -- Only levels 1-3 generate manifests (dock hands)

    -- Who needs manifests
    RequireForBoatDelivery = true, -- Captains must have manifest to start delivery
    MinLevelToRequire = 4,         -- Level 4+ (boat delivery unlock) needs manifest

    -- Manifest expiration (encourages active trading)
    ExpirationMinutes = 60,        -- Manifests expire after 60 minutes
    ShowExpirationWarning = true,  -- Warn player when manifest is expiring

    -- Bonus for using manifest from another player
    TradeBonus = {
        Enabled = true,
        PayBonus = 0.15,           -- +15% pay when using someone else's manifest
        XPBonus = 0.10,            -- +10% XP when using traded manifest
    },

    -- Manifest metadata stored on item
    -- cargoType, suggestedDestination, createdAt, createdBy, manifestId
    MetadataFields = {
        'cargoType',               -- Type of cargo (for pay calculation)
        'suggestedDestination',    -- Recommended port (optional guidance)
        'containerCount',          -- Number of containers this manifest covers
        'createdAt',               -- Timestamp for expiration
        'createdBy',               -- CitizenID of dock worker
        'manifestId',              -- Unique ID for tracking
    },

    -- Print sound when manifest is generated
    PrintSound = 'PICK_UP_SCRIPTED',
    PrintSoundSet = 'HUD_FRONTEND_CUSTOM_SOUNDSET',

    -- Notification when manifest received
    ManifestReceivedTitle = 'Manifest Printed',
    ManifestReceivedDesc = 'Cargo manifest ready for boat delivery',
}

-----------------------------------------------------------
-- PROGRESSION SYSTEM
-----------------------------------------------------------

Config.Progression = {
    -- XP Settings
    BaseXPPerDelivery = 100,
    XPPerDistance = 0.5, -- XP per meter traveled

    -- Levels (cumulative XP required)
    -- Each level now has explicit unlocks to prevent "quit zone" feeling
    Levels = {
        [1]  = {
            xp = 0,
            title = 'Dock Hand',
            tier = 1,
            payMultiplier = 1.0,
            unlocks = { 'Standard containers', 'Manual loading (Press E)' },
            -- Level 1: Basic "Press E" loading only
            hasForklift = false,
            hasCompanyRadio = false,
        },
        [2]  = {
            xp = 300,
            title = 'Loader',
            tier = 1,
            payMultiplier = 1.1,
            unlocks = { 'FORKLIFT ACCESS', 'Fragile containers', '+10% pay' },
            -- Level 2: Forklift gameplay unlocked
            hasForklift = true,
            hasCompanyRadio = false,
        },
        [3]  = {
            xp = 800,
            title = 'Senior Loader',
            tier = 1,
            payMultiplier = 1.2,
            unlocks = { 'COMPANY RADIO', 'Refrigerated containers', 'Job Tips', '+20% pay' },
            -- Level 3: Company radio shows high-value container tips
            hasForklift = true,
            hasCompanyRadio = true,
        },
        [4]  = {
            xp = 1500,
            title = 'Deckhand',
            tier = 2,
            payMultiplier = 1.25,
            unlocks = { 'BOAT DELIVERIES', 'Tier 1 boats', 'Standard cargo' },
        },
        [5]  = {
            xp = 2500,
            title = 'Sailor',
            tier = 2,
            payMultiplier = 1.35,
            unlocks = { 'Hazmat containers', 'Tier 2 boats', 'Medium cargo' },
        },
        [6]  = {
            xp = 4000,
            title = 'Boatswain',
            tier = 2,
            payMultiplier = 1.5,
            unlocks = { 'High-value cargo', '+50% pay' },
        },
        [7]  = {
            xp = 6000,
            title = 'Helmsman',
            tier = 3,
            payMultiplier = 1.75,
            unlocks = { 'FLEET OWNERSHIP', 'Cargo ships', 'Hazmat cargo', 'Oversized containers' },
        },
        [8]  = {
            xp = 9000,
            title = 'First Mate',
            tier = 3,
            payMultiplier = 2.0,
            unlocks = { 'Marquis Yacht', 'Contraband cargo' },
        },
        [9]  = {
            xp = 13000,
            title = 'Captain',
            tier = 3,
            payMultiplier = 2.25,
            unlocks = { 'Tug Boat', 'SMUGGLER\'S RADAR', 'Weapons cargo' },
        },
        [10] = {
            xp = 20000,
            title = 'Port Captain',
            tier = 3,
            payMultiplier = 2.5,
            unlocks = { 'Large Cargo Vessel', 'All cargo types', 'Max pay bonus' },
        },
    },

    -- Job Type Unlocks
    DockWorkMinLevel = 1,       -- Minimum level to do dock work
    BoatDeliveryMinLevel = 4,   -- Minimum level to do boat deliveries
    FleetOwnershipMinLevel = 7, -- Minimum level to own boats
    SmugglerRadarMinLevel = 9,  -- Minimum level for smuggler's radar

    -- XP Bonuses
    StreakBonus = 0.05,        -- 5% XP bonus per delivery in streak
    MaxStreakBonus = 0.25,     -- Max 25% streak bonus
    WeatherBonusXP = 0.1,      -- 10% XP bonus for bad weather deliveries
}

-----------------------------------------------------------
-- DOCK WORK SETTINGS (Container Hauling)
-----------------------------------------------------------

Config.DockWork = {
    -- Payment (REBALANCED: $800-1500 base, up to $3750 at max level)
    PaymentMin = 800,
    PaymentMax = 1500,
    PaymentMethod = 'bank', -- 'cash' or 'bank'

    -- Truck Rental (refundable deposit)
    TruckRentalFee = 1500,
    RefundOnReturn = true,

    -- Vehicles
    TruckModel = 'phantom3',
    TrailerModel = 'trflat',
    HandlerModel = 'handler',

    -- Container Props
    ContainerProp = 'prop_contr_03b_ld',
    ContainerPropStacked = 'prop_container_03b',

    -- Interaction Key
    InteractionKey = 51, -- E key

    -- Container Stacking
    MaxStackHeight = 3,
    StackHeightIncrement = 2.75,

    -- Weekly Container Wipe
    ContainerWipe = 'Weekly', -- 'Weekly', 'Restart', or 'Manual'

    -----------------------------------------------------------
    -- MULTI-STAGE MANIFEST MODE
    -- Players must complete a full manifest of containers before shift ends
    -----------------------------------------------------------
    ManifestMode = {
        Enabled = true,
        MinContainers = 3,           -- Minimum containers per manifest
        MaxContainers = 6,           -- Maximum containers per manifest
        BonusPerContainer = 0.05,    -- +5% bonus per container beyond minimum
        TimeLimit = 1800,            -- 30 minutes to complete manifest (seconds)
        TimeBonusThreshold = 0.75,   -- Complete in <75% of time limit = time bonus
        TimeBonusPercent = 0.20,     -- +20% bonus for fast completion
        LatePenaltyPercent = 0.10,   -- -10% per minute late (after time limit)
        MaxLatePenalty = 0.50,       -- Maximum 50% penalty for being late

        -- Zone-based container assignments
        ZoneAssignments = {
            Arrivals = 'loading',    -- Pick up from loading zones
            Storage = 'placement',   -- Deliver to placement zones
        },
    },
}

-----------------------------------------------------------
-- BOAT DELIVERY SETTINGS
-----------------------------------------------------------

Config.BoatDelivery = {
    -- Base Payout (REBALANCED: $150 per km is realistic for RP servers)
    BasePayoutPerMeter = 0.15, -- $150 per km
    MinimumPayout = 500, -- Minimum payout for any delivery

    -- Distance Tier Bonuses (longer trips = better pay per km)
    DistanceTiers = {
        { minDistance = 0,     multiplier = 1.0 },   -- 0-5km: base rate
        { minDistance = 5000,  multiplier = 1.25 },  -- 5-10km: +25%
        { minDistance = 10000, multiplier = 1.5 },   -- 10-20km: +50%
        { minDistance = 20000, multiplier = 2.0 },   -- 20km+: +100%
    },

    -- Weather Bonuses (risk = reward)
    WeatherBonuses = {
        clear = 0,
        cloudy = 0.05,
        rain = 0.15,      -- Increased from 0.1
        thunder = 0.35,   -- Increased from 0.25
        fog = 0.20,       -- Increased from 0.15
    },

    -- Damage Penalties (breakage mechanics for fragile cargo)
    DamagePenalties = {
        { threshold = 10, penalty = 0.05 },  -- Minor scratches
        { threshold = 25, penalty = 0.15 },  -- Noticeable damage
        { threshold = 50, penalty = 0.35 },  -- Major damage
        { threshold = 70, penalty = 0.50 },  -- Critical - half pay
    },

    -- Fuel Settings
    FuelEnabled = true,
    FuelPricePerLiter = 3,
    FuelWarningPercent = 20,
    FuelCriticalPercent = 10,
}

-----------------------------------------------------------
-- BULK HAULING (Tug Boat Only)
-- High-reward convoy missions with 5-10 containers
-----------------------------------------------------------

Config.BulkHauling = {
    -- Only vessels with bulkHauling = true can do these
    Enabled = true,

    -- Payment calculation
    -- Base: (containers * distance * baseRate) * bulkPayBonus * levelMultiplier
    BaseRatePerContainer = 500, -- $500 per container base

    -- Time pressure
    TimePerContainer = 60, -- 60 seconds per container (5 containers = 5 min, 10 = 10 min)
    LatePenaltyPercent = 0.05, -- 5% penalty per minute late

    -- Pirate attacks (NPC boats that try to steal cargo)
    Pirates = {
        Enabled = true,
        SpawnDistance = 800.0,
        BoatModels = { 'dinghy', 'speeder', 'seashark' },
        PedModels = { 's_m_y_dealer_01', 'g_m_y_ballasout_01' },
        Weapons = { 'WEAPON_PISTOL', 'WEAPON_MICROSMG' },
        MinPirates = 2,
        MaxPirates = 4,
        RewardForDefending = 2000, -- Bonus for killing/escaping pirates
    },

    -- Coast Guard inspections (for illegal cargo)
    CoastGuard = {
        Enabled = true,
        InspectionTime = 30000, -- 30 seconds to inspect
        BribeAmount = 5000, -- Cost to bribe (if player chooses)
        ConfiscationChance = 0.5, -- 50% chance they confiscate if no bribe
        ArrestChance = 0.2, -- 20% chance of arrest if caught with illegal
    },

    -- Bonus for completing with friends (escort bonus)
    EscortBonus = {
        Enabled = true,
        PerPlayerBonus = 0.1, -- +10% per additional player nearby
        MaxPlayers = 4, -- Max 4 escorts (+40% bonus)
        ProximityRadius = 100.0, -- Must stay within 100m
    },
}

-----------------------------------------------------------
-- FLEET OWNERSHIP
-----------------------------------------------------------

Config.Fleet = {
    MaxBoatsPerPlayer = 5,
    StarterBoat = 'dinghy',
    StarterBoatFree = true,

    -- Sell Back
    SellBackPercent = 0.6, -- 60% of purchase price
    ConditionAffectsSellPrice = true,

    -- Insurance (payout if total loss AND insurance purchased)
    InsuranceEnabled = true,
    InsuranceCostPercent = 0.05, -- 5% of boat value per "term"
    InsurancePayoutPercent = 0.8, -- 80% on total loss

    -- Repair
    RepairCostPercent = 0.1, -- 10% of boat price * damage
}

-----------------------------------------------------------
-- IMPOUND & RECOVERY FEES
-- Money sink for high-level players
-----------------------------------------------------------

Config.Impound = {
    -- Recovery fee for destroyed boats
    DestroyedRecoveryPercent = 0.02, -- 2% of boat value to recover destroyed boat
    DestroyedRecoveryMinimum = 500,  -- Minimum $500 recovery fee

    -- Recovery fee for abandoned boats (left in ocean)
    AbandonedRecoveryPercent = 0.01, -- 1% of boat value
    AbandonedRecoveryMinimum = 250,  -- Minimum $250 recovery fee
    AbandonedTimeout = 900000, -- 15 minutes before boat is "abandoned"

    -- Impound locations
    ImpoundLocations = {
        vector3(1299.45, -3246.78, 5.90), -- Elysian Island dock
        vector3(-847.57, -1368.01, 1.60), -- Vespucci Marina
    },

    -- Impound NPC
    ImpoundNPC = {
        model = 's_m_y_dockwork_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
    },

    -- Boat condition on recovery
    RecoveredHealthPercent = 75, -- Boats come back at 75% health
    RecoveredFuelPercent = 25,   -- Boats come back at 25% fuel

    -- Daily storage fee (if not recovered within 24 hours)
    DailyStorageFee = 100, -- $100 per day
    MaxStorageDays = 7,    -- After 7 days, boat is sold at auction
    AuctionReturnPercent = 0.3, -- Player gets 30% of auction price

    -- Grace period for new players
    GracePeriodLevel = 5, -- Players below level 5 get reduced fees
    GracePeriodDiscount = 0.5, -- 50% discount on fees
}

-----------------------------------------------------------
-- VESSEL MAINTENANCE SYSTEM
-- Boats require periodic service at dry dock
-----------------------------------------------------------

Config.Maintenance = {
    Enabled = true,

    -- Service intervals (in game hours or real minutes)
    ServiceInterval = 180,          -- 3 hours of use before service needed
    UseRealTime = false,            -- If true, ServiceInterval is in real minutes

    -- Neglect penalties
    NeglectPenalties = {
        [0] = {                     -- 0-25% overdue
            speedPenalty = 0,
            engineStallChance = 0,
            fuelLeakRate = 0,
        },
        [25] = {                    -- 25-50% overdue
            speedPenalty = 0.05,    -- 5% slower
            engineStallChance = 0.01,
            fuelLeakRate = 0.01,
        },
        [50] = {                    -- 50-75% overdue
            speedPenalty = 0.15,    -- 15% slower
            engineStallChance = 0.03,
            fuelLeakRate = 0.02,
        },
        [75] = {                    -- 75-100% overdue
            speedPenalty = 0.25,    -- 25% slower
            engineStallChance = 0.05,
            fuelLeakRate = 0.03,
        },
        [100] = {                   -- 100%+ overdue (CRITICAL)
            speedPenalty = 0.40,    -- 40% slower
            engineStallChance = 0.10,
            fuelLeakRate = 0.05,
            randomBreakdown = true, -- Can randomly break down
        },
    },

    -- Service costs (percentage of boat value)
    ServiceCostPercent = 0.02,      -- 2% of boat value for basic service
    RepairCostPercent = 0.05,       -- 5% of boat value for repairs
    OverhaulCostPercent = 0.10,     -- 10% for major overhaul (if >100% overdue)

    -- Dry dock locations
    DryDocks = {
        {
            name = 'Elysian Dry Dock',
            coords = vector3(1320.45, -3250.67, 5.90),
            npcModel = 's_m_m_dockwork_01',
        },
        {
            name = 'Vespucci Marine Service',
            coords = vector3(-870.23, -1390.45, 1.60),
            npcModel = 's_m_m_dockwork_01',
        },
    },

    -- Service time (in ms)
    BasicServiceTime = 30000,       -- 30 seconds
    RepairTime = 60000,             -- 60 seconds
    OverhaulTime = 120000,          -- 2 minutes
}

-----------------------------------------------------------
-- RESCUE & TOWING SYSTEM
-- Players can earn money rescuing stranded boaters
-----------------------------------------------------------

Config.Rescue = {
    Enabled = true,
    MinLevel = 5,                   -- Minimum level to do rescue jobs

    -- Rescue job types
    JobTypes = {
        ['stranded_npc'] = {
            label = 'Stranded Boater',
            description = 'Tow NPC boat back to port',
            payBase = 1500,
            payPerKm = 100,
            xp = 150,
            spawnChance = 0.4,
            timeout = 600,          -- 10 minutes to complete
        },
        ['fuel_delivery'] = {
            label = 'Fuel Delivery',
            description = 'Deliver fuel to stranded vessel',
            payBase = 800,
            payPerKm = 50,
            xp = 100,
            spawnChance = 0.3,
            requiresItem = 'jerry_can',
        },
        ['medical_emergency'] = {
            label = 'Medical Emergency',
            description = 'Transport injured boater to shore',
            payBase = 2500,
            payPerKm = 150,
            xp = 250,
            spawnChance = 0.15,
            timeLimit = 300,        -- 5 minutes - urgent!
            bonusForSpeed = 0.25,   -- +25% if completed fast
        },
        ['salvage'] = {
            label = 'Salvage Operation',
            description = 'Recover cargo from sunken vessel',
            payBase = 3000,
            payPerKm = 75,
            xp = 300,
            spawnChance = 0.15,
            levelRequired = 7,
            requiresDiving = true,
        },
    },

    -- Rescue dispatch
    DispatchInterval = 300000,      -- Check for new rescue calls every 5 min
    MaxActiveRescues = 3,           -- Max 3 rescue jobs available at once
    RescueRadius = 5000,            -- Jobs spawn within 5km

    -- Towing mechanics
    Towing = {
        TowRopeLength = 15.0,
        MaxTowSpeed = 20.0,         -- Max 20 mph while towing
        TowAttachTime = 5000,       -- 5 seconds to attach tow rope
        BreakChance = 0.02,         -- 2% chance rope breaks per collision
    },

    -- Rescue vehicles (boats that can do rescues)
    AllowedVehicles = {
        'dinghy', 'speeder', 'jetmax', 'tropic', 'tug',
    },

    -- Blip settings
    Blip = {
        sprite = 459,               -- Lifebuoy
        color = 3,                  -- Blue
        scale = 0.8,
    },
}

-- Helper function to calculate recovery fee
function Config.CalculateRecoveryFee(boatModel, isDestroyed, daysInImpound)
    local boat = Config.Boats[boatModel]
    if not boat then return 0 end

    local basePercent = isDestroyed and Config.Impound.DestroyedRecoveryPercent or Config.Impound.AbandonedRecoveryPercent
    local minimum = isDestroyed and Config.Impound.DestroyedRecoveryMinimum or Config.Impound.AbandonedRecoveryMinimum

    local baseFee = math.max(boat.price * basePercent, minimum)

    -- Add daily storage fees
    local storageFee = (daysInImpound or 0) * Config.Impound.DailyStorageFee

    return math.floor(baseFee + storageFee)
end

-----------------------------------------------------------
-- NPC & BLIP SETTINGS
-----------------------------------------------------------

Config.NPC = {
    Model = 's_m_m_dockwork_01',
    Location = vector4(1197.22, -3253.58, 7.10, 88.28), -- Main job NPC
    Scenario = 'WORLD_HUMAN_CLIPBOARD',
}

Config.Blips = {
    Job = {
        sprite = 410,
        color = 3,
        scale = 0.8,
        label = 'Jetsam Maritime',
    },
    LoadingZone = {
        sprite = 479,
        color = 3,
        scale = 0.6,
        label = 'Loading Zone',
    },
    Port = {
        sprite = 410,
        color = 1,
        scale = 0.7,
        label = 'Port',
    },
    BoatSpawn = {
        sprite = 427,
        color = 3,
        scale = 0.6,
        label = 'Boat Spawn',
    },
}

-----------------------------------------------------------
-- HEAT LEVEL SYSTEM (Smuggler Counter-Play)
-- More illegal runs = more police attention
-----------------------------------------------------------

Config.HeatLevel = {
    Enabled = true,

    -- Heat accumulation
    HeatPerIllegalRun = 20,      -- +20 heat per illegal cargo delivered
    HeatDecayPerMinute = 5,      -- -5 heat per minute when not running
    MaxHeat = 100,

    -- Heat thresholds and effects
    Thresholds = {
        [20] = {
            label = 'Warm',
            policeBlipRadius = 500,    -- Police see 500m search area
            radarAccuracy = 1.0,       -- Normal radar
        },
        [40] = {
            label = 'Hot',
            policeBlipRadius = 300,    -- Tighter search area
            radarAccuracy = 0.9,       -- 10% less accurate
            extraPatrols = 1,          -- 1 extra patrol boat spawns
        },
        [60] = {
            label = 'Burning',
            policeBlipRadius = 150,    -- Very tight search
            radarAccuracy = 0.75,      -- 25% less accurate (heat interference)
            extraPatrols = 2,
            helicopterChance = 0.3,    -- 30% chance of heli
        },
        [80] = {
            label = 'Inferno',
            policeBlipRadius = 75,     -- Almost pinpoint
            radarAccuracy = 0.5,       -- Radar half effective
            extraPatrols = 3,
            helicopterChance = 0.6,
            coastGuardAlert = true,    -- Coast guard actively hunting
        },
        [100] = {
            label = 'Most Wanted',
            policeBlipRadius = 50,     -- They know where you are
            radarAccuracy = 0.25,      -- Radar barely works
            extraPatrols = 4,
            helicopterChance = 0.9,
            coastGuardAlert = true,
            roadblocks = true,         -- Water "roadblocks" at ports
        },
    },

    -- Cooldown options
    SafeHouseReduction = 30,    -- -30 heat for hiding in safe house
    BribeReduction = 50,        -- -50 heat for paying bribe (see below)
    BribeCost = 10000,          -- $10,000 to bribe dispatcher
}

-----------------------------------------------------------
-- POLICE JAMMER SYSTEM
-- Allows police to counter smuggler radar
-----------------------------------------------------------

Config.PoliceJammer = {
    Enabled = true,

    -- Jammer effects on smuggler radar
    JammerRadius = 400,           -- 400m jamming radius
    StaticIntensity = 0.8,        -- 80% static when jammed
    DirectionScramble = true,     -- Scrambles direction readings
    FalseContactChance = 0.5,     -- 50% chance of false contacts when jammed

    -- Visual effects on smuggler HUD
    JammedText = '~~~ JAMMED ~~~',
    StaticChars = { '/', '\\', '|', '-', '*', '#' },

    -- Police jammer item (if using inventory system)
    JammerItem = 'police_jammer',
    JammerDuration = 300000,      -- 5 minutes per use
}

-----------------------------------------------------------
-- COMPANY RADIO (Level 3+)
-- Shows "Job Tips" - locations of high-value containers
-----------------------------------------------------------

Config.CompanyRadio = {
    -- How often tips are broadcast
    TipInterval = 60000, -- Every 60 seconds

    -- Tip types with their bonuses
    Tips = {
        ['priority_shipment'] = {
            label = 'Priority Shipment',
            description = 'Rush order - client paying premium',
            payBonus = 0.25, -- +25% pay
            xpBonus = 0.15,
            spawnChance = 0.3, -- 30% chance to spawn
            icon = 'star',
        },
        ['bulk_order'] = {
            label = 'Bulk Order',
            description = 'Multiple containers going same destination',
            payBonus = 0.15,
            xpBonus = 0.2,
            spawnChance = 0.4,
            icon = 'boxes',
        },
        ['vip_cargo'] = {
            label = 'VIP Cargo',
            description = 'High-profile client - handle with care',
            payBonus = 0.4, -- +40% pay
            xpBonus = 0.25,
            spawnChance = 0.15, -- Rare
            icon = 'crown',
            fragile = true, -- Damage penalty applies
        },
        ['overtime_bonus'] = {
            label = 'Overtime Available',
            description = 'Night shift bonus active',
            payBonus = 0.2,
            xpBonus = 0.1,
            spawnChance = 0.5,
            icon = 'clock',
            timeRestricted = true, -- Only 22:00 - 06:00
        },
    },

    -- Blip settings for tips
    Blip = {
        sprite = 478,
        color = 5, -- Yellow
        scale = 0.8,
        flash = true,
    },
}

-----------------------------------------------------------
-- FORKLIFT SETTINGS (Level 2+)
-----------------------------------------------------------

Config.Forklift = {
    Model = 'forklift', -- Forklift vehicle model
    SpawnDistance = 50.0, -- Max distance from loading zone

    -- Pallet props
    PalletProp = 'prop_boxpile_06a',
    PalletAttachBone = 'forks',

    -- Speed limits while carrying
    MaxSpeedWithLoad = 15.0, -- MPH
    TipOverAngle = 35.0, -- Degrees before cargo falls

    -- XP bonus for using forklift vs Press E
    ForkliftXPBonus = 0.15, -- +15% XP for using forklift

    -- Damage from dropping cargo
    DropDamagePercent = 0.1, -- 10% pay penalty per drop
    MaxDrops = 3, -- After 3 drops, cargo is destroyed
}

-----------------------------------------------------------
-- INTEGRATION SETTINGS
-----------------------------------------------------------

Config.Keys = {
    Enabled = false,
    System = 'qb-vehiclekeys', -- 'qb-vehiclekeys', 'qs-vehiclekeys', 'wasabi_carlock'
}

Config.Fuel = {
    Enabled = true,
    System = 'ox_fuel', -- 'ox_fuel', 'LegacyFuel', 'ps-fuel'
}

-- jg-hud Integration (if installed)
Config.JGHud = {
    Enabled = true, -- Set to true to use jg-hud's boat systems
    UseAnchorSystem = true,    -- Use jg-hud's anchor instead of ours
    UseBoatHUD = true,         -- Use jg-hud's boat-specific HUD
    UseDepthMeter = true,      -- Use jg-hud's depth meter if available
}

-----------------------------------------------------------
-- UI OPTIMIZATION SETTINGS
-- This resource uses ox_lib for all menus/notifications
-- These settings control the lightweight native HUD elements
-----------------------------------------------------------

Config.UI = {
    -- Native HUD elements (lightweight DrawRect calls)
    -- Set to false to disable if using external HUD mods
    EnableHazmatGauge = true,      -- Hazmat pressure stabilization gauge
    EnableForkliftTilt = true,     -- Forklift balance meter
    EnableDepthMeter = true,       -- Depth awareness display
    EnableRadarDisplay = true,     -- Smuggler's radar compass

    -- Performance optimization
    HUDRefreshRate = 0,            -- ms between HUD updates (0 = every frame)

    -- ox_lib text UI (alternative to DrawText)
    UseTextUI = true,              -- Use lib.showTextUI instead of native text

    -- Notification settings
    NotificationPosition = 'top-right',
    NotificationDuration = 5000,

    -- Progress bar settings
    ProgressPosition = 'bottom',   -- 'bottom', 'middle', 'top'
}

-- jg-advancedgarages Bridge (prevents double-dip exploit)
-- Syncs with jg-advancedgarages to prevent spawning boats already out
Config.GarageBridge = {
    Enabled = true,

    -- Resource detection
    GarageResource = 'jg-advancedgarages',

    -- Database sync
    UseDatabase = true,                 -- Query player_vehicles for state
    VehiclesTable = 'player_vehicles',  -- Table name

    -- State values (match jg-advancedgarages)
    StateIn = 1,    -- Vehicle is in garage
    StateOut = 0,   -- Vehicle is spawned

    -- Double-spawn prevention
    PreventDoubleSpawn = true,          -- Don't spawn if already out
    PreventDuplicateFleet = true,       -- Can't own same boat twice

    -- Fee integration
    ChargeRecoveryFees = true,          -- Charge our impound fees through garage
    RecoveryCooldown = 60,              -- Seconds between recovery attempts

    -- When maritime boat is put in garage, update fleet tracking
    SyncWithFleet = true,               -- Keep fleet table in sync

    -- Notification when blocked
    BlockedNotify = {
        title = 'Boat Already Out',
        description = 'This vessel is already spawned. Return it first.',
        type = 'error',
    },
}

Config.Phone = {
    Enabled = true,
    Apps = { 'lb-phone', 'qs-smartphone', 'npwd' },
}

-----------------------------------------------------------
-- QS-HOUSING INTEGRATION
-- Property ownership unlocks advanced job features
-----------------------------------------------------------

Config.Housing = {
    Enabled = true,
    Resource = 'qs-housing',            -- Housing resource name

    -- Warehouse ownership enables cargo consolidation
    Warehouses = {
        Enabled = true,
        RequiredForBulkHaul = true,     -- Must own warehouse for bulk hauling

        -- Warehouse properties near the docks (property IDs from qs-housing)
        -- Players who own these can consolidate small shipments into bulk
        DockWarehouses = {
            -- Add your qs-housing property IDs here
            -- Example: 'warehouse_elysian_1', 'warehouse_elysian_2'
        },

        -- Cargo consolidation bonuses
        ConsolidationBonus = 0.25,      -- +25% pay for consolidated shipments
        MaxConsolidatedCrates = 10,     -- Max crates per consolidated shipment
        ConsolidationTime = 30,         -- Seconds to consolidate cargo
    },

    -- Island safehouse for contraband access
    IslandSafehouses = {
        Enabled = true,
        RequiredForContraband = true,   -- Must own island property for illegal jobs

        -- Safehouse property IDs (from qs-housing)
        -- Players who own these get access to contraband delivery points
        Properties = {
            -- Add your qs-housing island property IDs here
            -- Example: 'safehouse_cayo_1', 'safehouse_island_dock'
        },

        -- Contraband bonuses for property owners
        ContrabandPayBonus = 0.35,      -- +35% for contraband deliveries
        HeatReduction = 0.20,           -- -20% heat accumulation
    },
}

-----------------------------------------------------------
-- DOCK STAGING REQUIREMENTS
-- Short hauls before accessing boat captain jobs
-----------------------------------------------------------

Config.DockStaging = {
    Enabled = true,

    -- Require dock work before boat deliveries
    RequireDockXP = true,
    MinDockDeliveries = 15,             -- Must complete 15 dock container runs
    MinDockXP = 500,                    -- OR have 500+ dock XP

    -- Short haul staging before each boat run
    StagingRequired = true,
    StagingContainers = { min = 3, max = 5 },  -- 3-5 containers to "prepare shipment"
    StagingTimeLimit = 600,             -- 10 minutes to complete staging
    StagingPayPercent = 0.20,           -- Staging pays 20% of the total boat run

    -- Staging unlocks
    StagingUnlocksBoatRun = true,       -- Must complete staging to start boat delivery
    StagingValidFor = 1800,             -- Staging valid for 30 minutes

    -- Forklift bonus during staging
    ForkliftStagingBonus = 0.15,        -- +15% bonus for using forklift during staging

    -- Skip staging (high level players can skip)
    SkipLevel = 8,                      -- Level 8+ can skip staging
    SkipCost = 2500,                    -- OR pay $2500 to have NPC do staging
}

-----------------------------------------------------------
-- DOCK XP TRACKING (Separate from overall XP)
-- Ensures players learn the logistics side before captaining
-----------------------------------------------------------

Config.DockXPRequirement = {
    Enabled = true,

    -- Dock-specific XP (earned only from dock container work)
    DockXPPerContainer = 25,            -- 25 dock XP per container moved
    DockXPForkliftBonus = 10,           -- +10 dock XP for using forklift

    -- Requirements to unlock boat captain
    MinDockXPForBoats = 300,            -- Need 300 dock XP to unlock boat deliveries
    MinDockXPForDeepSea = 800,          -- Need 800 dock XP for deep sea routes

    -- Database column (added to maritime_employees)
    -- dock_xp INT DEFAULT 0
}

-----------------------------------------------------------
-- VIP LEISURE TRANSPORT (RCore Integration)
-- High-paying passenger transport to leisure destinations
-----------------------------------------------------------

Config.VIPTransport = {
    Enabled = true,
    MinLevel = 6,               -- Level 6+ to unlock VIP transport
    MinBoatTier = 2,            -- Requires Tier 2+ boats (luxury vessels)

    -- Base pay settings
    BasePayPerPassenger = 500,
    BasePayPerKm = 75,
    TipChance = 0.30,           -- 30% chance of getting a tip
    TipRange = { min = 100, max = 500 },

    -- VIP satisfaction affects tips and ratings
    SatisfactionFactors = {
        smoothRide = 0.3,       -- No collisions = +30% tip chance
        onTime = 0.25,          -- Arrive on time = +25% tip chance
        luxuryVessel = 0.2,     -- Tier 3 boat = +20% tip chance
        cleanVessel = 0.15,     -- High condition = +15% tip chance
        scenicRoute = 0.1,      -- Longer but scenic = +10% tip chance
    },

    -- Penalty for bad service
    BadServicePenalty = 0.5,    -- 50% pay reduction for crashes/late arrival

    -- Passenger NPC models
    PassengerModels = {
        standard = {
            'a_m_y_business_01', 'a_f_y_business_01', 'a_m_y_business_02', 'a_f_y_business_02',
        },
        vip = {
            'a_m_y_hipster_01', 'a_f_y_hipster_01', 'cs_bankman', 'cs_beverly',
        },
        celebrity = {
            'cs_lazlow', 'cs_nervousron', 'cs_chrisformage',
        },
    },

    -- Pickup locations (marinas, yacht clubs)
    PickupLocations = {
        {
            name = 'Del Perro Marina',
            coords = vector3(-857.54, -1378.67, 1.60),
            heading = 180.0,
            tier = 'standard',
        },
        {
            name = 'Vespucci Yacht Club',
            coords = vector3(-1593.45, -863.23, 2.10),
            heading = 225.0,
            tier = 'vip',
        },
        {
            name = 'Casino Docks',
            coords = vector3(1280.45, 283.67, 1.50),
            heading = 90.0,
            tier = 'celebrity',
        },
        {
            name = 'Elysian Island Private Pier',
            coords = vector3(1299.45, -3246.78, 5.90),
            heading = 270.0,
            tier = 'standard',
        },
        {
            name = 'Paleto Bay Harbor',
            coords = vector3(-264.23, 6646.89, 2.10),
            heading = 45.0,
            tier = 'standard',
        },
    },

    -- Leisure destinations (RCore integration)
    -- Only destinations with running resources will be available
    Destinations = {
        ['golf'] = {
            name = 'Los Santos Golf Club',
            resource = 'rcore_golf',
            coords = vector3(-1336.45, 59.23, 54.40),   -- Golf club entrance
            boatDock = vector3(-1857.23, -1232.45, 1.0), -- Nearby marina
            payMultiplier = 1.5,                         -- +50% for golf VIPs
            xpBonus = 0.25,
            tier = 'vip',
            description = 'Transport wealthy clients to the golf course',
        },
        ['casino'] = {
            name = 'Diamond Casino & Resort',
            resource = 'rcore_casino',
            coords = vector3(922.23, 50.67, 81.20),
            boatDock = vector3(1280.45, 283.67, 1.50),
            payMultiplier = 2.0,                         -- +100% for casino high-rollers
            xpBonus = 0.35,
            tier = 'celebrity',
            description = 'VIP casino guests - handle with discretion',
        },
        ['lunapark'] = {
            name = 'Luna Park',
            resource = 'rcore_lunapark',
            coords = vector3(-1650.23, -1102.45, 13.0),
            boatDock = vector3(-1593.45, -863.23, 2.10),
            payMultiplier = 1.2,
            xpBonus = 0.15,
            tier = 'standard',
            description = 'Family fun at the amusement park',
        },
        ['bowling'] = {
            name = 'Memory Lanes Bowling',
            resource = 'rcore_bowling',
            coords = vector3(748.67, -778.23, 26.30),
            boatDock = vector3(-857.54, -1378.67, 1.60),
            payMultiplier = 1.1,
            xpBonus = 0.1,
            tier = 'standard',
            description = 'Casual bowling night transport',
        },
        ['camping'] = {
            name = 'Mount Chiliad Campground',
            resource = 'rcore_camping',
            coords = vector3(425.67, 5613.23, 766.0),
            boatDock = vector3(-264.23, 6646.89, 2.10),  -- Paleto Bay
            payMultiplier = 1.8,                         -- Long distance
            xpBonus = 0.40,
            tier = 'standard',
            description = 'Nature enthusiasts heading to the mountains',
        },
        ['tennis'] = {
            name = 'Rockford Hills Tennis Club',
            resource = 'rcore_tennis',
            coords = vector3(-1274.45, 346.23, 37.40),
            boatDock = vector3(-1857.23, -1232.45, 1.0),
            payMultiplier = 1.3,
            xpBonus = 0.15,
            tier = 'vip',
            description = 'Tennis club members need transport',
        },
        ['arcade'] = {
            name = 'Videogeddon Arcade',
            resource = 'rcore_arcade',
            coords = vector3(92.23, -1292.45, 29.30),
            boatDock = vector3(-857.54, -1378.67, 1.60),
            payMultiplier = 1.0,
            xpBonus = 0.1,
            tier = 'standard',
            description = 'Gamers heading to the arcade',
        },
    },

    -- Mission types
    MissionTypes = {
        ['single_vip'] = {
            label = 'VIP Transport',
            description = 'Transport a single VIP to their destination',
            passengers = 1,
            payMultiplier = 1.0,
            timeLimit = 600,    -- 10 minutes
        },
        ['couple'] = {
            label = 'Couples Transport',
            description = 'Transport a couple to their leisure destination',
            passengers = 2,
            payMultiplier = 1.5,
            timeLimit = 600,
        },
        ['group'] = {
            label = 'Group Excursion',
            description = 'Transport a group of friends',
            passengers = 4,
            payMultiplier = 2.5,
            timeLimit = 900,    -- 15 minutes
            requiresBoatCapacity = 4,
        },
        ['celebrity'] = {
            label = 'Celebrity Escort',
            description = 'Discretely transport a celebrity',
            passengers = 1,
            payMultiplier = 3.0,
            timeLimit = 480,    -- 8 minutes (urgent)
            levelRequired = 8,
            bonusTip = 1000,
            discretionRequired = true, -- Avoid police attention
        },
    },

    -- Blip settings
    Blip = {
        pickup = { sprite = 280, color = 5, scale = 0.9 },      -- Yellow taxi-like
        destination = { sprite = 408, color = 2, scale = 0.8 }, -- Green leisure
    },
}

-- Helper function to check if destination resource is running
function Config.IsLeisureDestinationAvailable(destinationId)
    local dest = Config.VIPTransport.Destinations[destinationId]
    if not dest then return false end
    return GetResourceState(dest.resource) == 'started'
end

-- Get available destinations based on running resources
function Config.GetAvailableLeisureDestinations()
    local available = {}
    for id, dest in pairs(Config.VIPTransport.Destinations) do
        if Config.IsLeisureDestinationAvailable(id) then
            available[id] = dest
        end
    end
    return available
end

-----------------------------------------------------------
-- HELPER FUNCTIONS
-----------------------------------------------------------

function Config.GetLevelFromXP(xp)
    local level = 1
    for lvl, data in pairs(Config.Progression.Levels) do
        if xp >= data.xp then
            level = lvl
        end
    end
    return level
end

function Config.GetLevelData(level)
    return Config.Progression.Levels[level] or Config.Progression.Levels[1]
end

function Config.CanDoDockWork(level)
    return level >= Config.Progression.DockWorkMinLevel
end

function Config.CanDoBoatDelivery(level)
    return level >= Config.Progression.BoatDeliveryMinLevel
end

function Config.CanOwnFleet(level)
    return level >= Config.Progression.FleetOwnershipMinLevel
end

function Config.CalculateDockPay(baseAmount, level)
    local levelData = Config.GetLevelData(level)
    return math.floor(baseAmount * levelData.payMultiplier)
end
