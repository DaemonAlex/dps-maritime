--[[
    dps-maritime - Jetsam Company
    Location Definitions
]]

-----------------------------------------------------------
-- MAIN HUB / NPC LOCATION
-----------------------------------------------------------

Config.MainHub = {
    coords = vector4(1197.22, -3253.58, 7.10, 88.28),
    npcModel = 's_m_m_dockwork_01',
    npcScenario = 'WORLD_HUMAN_CLIPBOARD',
    label = 'Jetsam Maritime',
}

-----------------------------------------------------------
-- DOCK WORK: TRUCK & TRAILER SPAWN
-----------------------------------------------------------

Config.DockVehicleSpawns = {
    Truck = {
        coords = vector4(1189.59, -3245.60, 6.03, 92.15),
    },
    Trailer = {
        coords = vector4(1206.63, -3225.87, 5.86, 87.32),
    },
}

-----------------------------------------------------------
-- DOCK WORK: CONTAINER LOADING ZONES
-- These are where players pick up containers with the handler
-----------------------------------------------------------

Config.LoadingZones = {
    [1] = {
        pos = vector3(9.24, -2422.39, 6.01),
        markerSize = vector3(5.5, 0.5, 16.0),
        markerColor = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
        direction = 125.0,
        trailerHeading = 233.0,
        handlerSpawn = vector3(24.90, -2433.27, 6.00),
        handlerHeading = 235.33,
        containerSpawns = {
            { coords = vector3(95.94, -2480.76, 5.00), heading = 321.33 },
            { coords = vector3(-99.62, -2462.51, 5.02), heading = 149.18 },
            { coords = vector3(-282.79, -2410.55, 5.00), heading = 318.25 },
            { coords = vector3(-84.38, -2389.40, 5.00), heading = 354.19 },
        },
    },
    [2] = {
        pos = vector3(43.04, -2473.66, 6.01),
        markerSize = vector3(5.5, 0.5, 16.0),
        markerColor = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
        direction = -55.0,
        trailerHeading = 53.0,
        handlerSpawn = vector3(-25.22, -2456.87, 6.01),
        handlerHeading = 236.12,
        containerSpawns = {
            { coords = vector3(95.94, -2480.76, 5.00), heading = 321.33 },
            { coords = vector3(-99.62, -2462.51, 5.02), heading = 149.18 },
            { coords = vector3(-282.79, -2410.55, 5.00), heading = 318.25 },
            { coords = vector3(-84.38, -2389.40, 5.00), heading = 354.19 },
        },
    },
    [3] = {
        pos = vector3(-260.52, -2389.75, 6.00),
        markerSize = vector3(5.5, 0.5, 16.0),
        markerColor = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
        direction = 90.0,
        trailerHeading = 269.0,
        handlerSpawn = vector3(-246.35, -2397.70, 6.00),
        handlerHeading = 85.47,
        containerSpawns = {
            { coords = vector3(95.94, -2480.76, 5.00), heading = 321.33 },
            { coords = vector3(-99.62, -2462.51, 5.02), heading = 149.18 },
            { coords = vector3(-282.79, -2410.55, 5.00), heading = 318.25 },
            { coords = vector3(-84.38, -2389.40, 5.00), heading = 354.19 },
        },
    },
    [4] = {
        pos = vector3(-477.63, -2714.20, 6.00),
        markerSize = vector3(5.5, 0.5, 16.0),
        markerColor = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
        direction = 45.0,
        trailerHeading = 315.0,
        handlerSpawn = vector3(-470.41, -2722.77, 6.00),
        handlerHeading = 315.79,
        containerSpawns = {
            { coords = vector3(-472.96, -2748.83, 5.00), heading = 131.45 },
            { coords = vector3(-511.18, -2753.60, 5.00), heading = 73.39 },
            { coords = vector3(-449.01, -2685.06, 5.00), heading = 228.18 },
            { coords = vector3(-395.48, -2724.83, 5.01), heading = 217.39 },
        },
    },
    [5] = {
        pos = vector3(-371.28, -2608.44, 6.00),
        markerSize = vector3(5.5, 0.5, 16.0),
        markerColor = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
        direction = 45.0,
        trailerHeading = 315.0,
        handlerSpawn = vector3(-375.64, -2636.87, 6.00),
        handlerHeading = 134.62,
        containerSpawns = {
            { coords = vector3(-472.96, -2748.83, 5.00), heading = 131.45 },
            { coords = vector3(-511.18, -2753.60, 5.00), heading = 73.39 },
            { coords = vector3(-449.01, -2685.06, 5.00), heading = 228.18 },
            { coords = vector3(-395.48, -2724.83, 5.01), heading = 217.39 },
        },
    },
    [6] = {
        pos = vector3(505.63, -2151.63, 5.92),
        markerSize = vector3(5.5, 0.5, 16.0),
        markerColor = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
        direction = 90.0,
        trailerHeading = 268.0,
        handlerSpawn = vector3(491.71, -2161.86, 5.92),
        handlerHeading = 274.62,
        containerSpawns = {
            { coords = vector3(483.26, -2141.77, 5.01), heading = 26.25 },
            { coords = vector3(484.88, -2154.21, 5.01), heading = 156.99 },
            { coords = vector3(467.81, -2157.36, 5.01), heading = 115.93 },
            { coords = vector3(413.16, -2187.95, 5.01), heading = 36.82 },
        },
    },
    [7] = {
        pos = vector3(511.25, -3022.92, 6.00),
        markerSize = vector3(5.5, 0.5, 16.0),
        markerColor = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
        direction = 90.0,
        trailerHeading = 269.0,
        handlerSpawn = vector3(499.41, -3034.54, 6.08),
        handlerHeading = 356.0,
        containerSpawns = {
            { coords = vector3(534.03, -2935.18, 5.04), heading = 326.58 },
            { coords = vector3(521.86, -2934.77, 5.04), heading = 91.99 },
            { coords = vector3(608.19, -3038.19, 5.07), heading = 121.76 },
        },
    },
}

-----------------------------------------------------------
-- DOCK WORK: CONTAINER UNLOADING ZONES
-- These are where players drop off containers at the port
-----------------------------------------------------------

Config.UnloadingZones = {
    [1] = {
        pos = vector3(1137.80, -2999.57, 5.90),
        markerSize = vector3(5.5, 0.5, 16.0),
        markerColor = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
        direction = 90.0,
        trailerHeading = 268.0,
        handlerSpawn = vector3(1089.86, -3000.69, 5.90),
        handlerHeading = 268.96,
        parkingPos = vector3(1089.86, -3000.69, 5.90),
        parkingSize = vector3(3.5, 3.5, 4.0),
    },
    [2] = {
        pos = vector3(1109.32, -2963.99, 5.90),
        markerSize = vector3(5.5, 0.5, 16.0),
        markerColor = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
        direction = 90.0,
        trailerHeading = 268.0,
        handlerSpawn = vector3(1088.09, -2972.57, 5.90),
        handlerHeading = 0.48,
        parkingPos = vector3(1088.09, -2972.57, 5.90),
        parkingSize = vector3(3.5, 3.5, 4.0),
    },
    [3] = {
        pos = vector3(1105.52, -3015.95, 5.90),
        markerSize = vector3(5.5, 0.5, 16.0),
        markerColor = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
        direction = 90.0,
        trailerHeading = 270.0,
        handlerSpawn = vector3(1087.81, -3022.71, 5.90),
        handlerHeading = 3.18,
        parkingPos = vector3(1087.81, -3022.71, 5.90),
        parkingSize = vector3(3.5, 3.5, 4.0),
    },
}

-----------------------------------------------------------
-- DOCK WORK: CONTAINER PLACEMENT ZONES
-- Final placement for stacking containers
-----------------------------------------------------------

Config.ContainerPlacement = {
    [1] = {
        pos = vector3(1184.94, -2986.98, 5.90),
        size = vector3(5.5, 3.5, 4.0),
        color = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
    },
    [2] = {
        pos = vector3(1183.56, -3032.40, 5.90),
        size = vector3(5.5, 3.5, 4.0),
        color = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
    },
    [3] = {
        pos = vector3(1185.14, -2970.99, 5.90),
        size = vector3(5.5, 3.5, 4.0),
        color = { r = 52, g = 134, b = 235, a = 100 },
        rotation = 90.0,
    },
}

-----------------------------------------------------------
-- BOAT DELIVERY: PORTS
-----------------------------------------------------------

Config.Ports = {
    ['elysian'] = {
        name = 'Port of Los Santos',
        shortName = 'Elysian',
        coords = vector3(169.43, -3086.71, 5.90),
        boatSpawn = vector4(192.50, -3068.44, -0.5, 270.0),
        tier = 1,
        hasFuel = true,
        payBonus = 0,
    },
    ['vespucci'] = {
        name = 'Vespucci Beach Marina',
        shortName = 'Vespucci',
        coords = vector3(-847.57, -1368.01, 1.60),
        boatSpawn = vector4(-853.89, -1359.42, -0.5, 110.0),
        tier = 1,
        hasFuel = true,
        payBonus = 0,
    },
    ['del_perro'] = {
        name = 'Del Perro Pier',
        shortName = 'Del Perro',
        coords = vector3(-1610.73, -1015.38, 13.02),
        boatSpawn = vector4(-1605.88, -1028.77, -0.5, 220.0),
        tier = 1,
        hasFuel = true,
        payBonus = 0.05,
    },
    ['paleto'] = {
        name = 'Paleto Bay Marina',
        shortName = 'Paleto',
        coords = vector3(-275.87, 6637.55, 7.50),
        boatSpawn = vector4(-283.36, 6638.99, -0.5, 45.0),
        tier = 2,
        hasFuel = true,
        payBonus = 0.1,
    },
    ['catfish'] = {
        name = 'Catfish View',
        shortName = 'Catfish',
        coords = vector3(3834.20, 4465.50, 2.72),
        boatSpawn = vector4(3824.12, 4469.93, -0.5, 280.0),
        tier = 2,
        hasFuel = false,
        payBonus = 0.15,
    },
    ['cayo'] = {
        name = 'Cayo Perico',
        shortName = 'Cayo',
        coords = vector3(4971.37, -5173.39, 2.05),
        boatSpawn = vector4(4985.63, -5170.16, -0.5, 90.0),
        tier = 3,
        hasFuel = true,
        payBonus = 0.25,
        international = true,
    },
}

-----------------------------------------------------------
-- DISTANT SEA DESTINATIONS (Compass Navigation Required)
-- High-risk, high-reward routes with no GPS guidance
-----------------------------------------------------------

Config.DeepSeaPorts = {
    ['lighthouse_island'] = {
        name = 'Lighthouse Island',
        shortName = 'Lighthouse',
        description = 'Remote island with lighthouse and dock - perfect for discrete deliveries',
        -- Coordinates need to be confirmed from the Island YMAP
        -- Default placement: Far southwest of Los Santos
        coords = vector3(-3200.0, -4500.0, 2.0),
        dockCoords = vector3(-3195.0, -4485.0, 1.0),
        boatSpawn = vector4(-3190.0, -4480.0, -0.5, 45.0),
        tier = 3,
        hasFuel = false,                   -- No fuel station - plan your trip!
        payBonus = 0.40,                   -- +40% pay
        minLevel = 6,                      -- Level 6+ required
        fuelRequired = 350,                -- Minimum fuel to attempt (liters)
        distanceFromLS = 10000,            -- ~10km from Los Santos
        navigation = 'compass',            -- Disables GPS, shows bearing only
        hidesMinimap = true,               -- Full immersion - no minimap
        mapResource = 'Island', -- Resource name for the island map (in [defaultmaps])
    },
    ['oil_platform'] = {
        name = 'Offshore Oil Platform',
        shortName = 'Oil Rig',
        description = 'Industrial oil platform - hazardous cargo welcome',
        coords = vector3(-3500.0, -2200.0, 5.0),
        dockCoords = vector3(-3490.0, -2195.0, 1.0),
        boatSpawn = vector4(-3485.0, -2190.0, -0.5, 90.0),
        tier = 3,
        hasFuel = true,                    -- Oil platform has fuel!
        payBonus = 0.35,                   -- +35% pay
        minLevel = 5,                      -- Level 5+ required
        fuelRequired = 280,                -- Minimum fuel
        distanceFromLS = 7000,             -- ~7km from Los Santos
        navigation = 'compass',
        hidesMinimap = true,
        hazmatOnly = true,                 -- Only accepts hazmat cargo
    },
    ['smugglers_cove'] = {
        name = 'Smuggler\'s Cove',
        shortName = 'Smugglers',
        description = 'Hidden cove for contraband - no questions asked',
        coords = vector3(5500.0, -6200.0, 1.5),
        dockCoords = vector3(5510.0, -6195.0, 1.0),
        boatSpawn = vector4(5515.0, -6190.0, -0.5, 270.0),
        tier = 3,
        hasFuel = false,
        payBonus = 0.50,                   -- +50% pay for illegal cargo
        minLevel = 9,                      -- Level 9+ (Captain rank) required
        fuelRequired = 450,                -- Long distance
        distanceFromLS = 14000,            -- ~14km
        navigation = 'compass',
        hidesMinimap = true,
        illegalOnly = true,                -- Only accepts contraband
        policeHeat = 15,                   -- Adds heat when delivering here
    },
    ['northern_outpost'] = {
        name = 'Northern Outpost',
        shortName = 'N. Outpost',
        description = 'Remote northern island - frontier territory',
        coords = vector3(3200.0, 8800.0, 2.5),
        dockCoords = vector3(3210.0, 8790.0, 1.0),
        boatSpawn = vector4(3215.0, 8785.0, -0.5, 180.0),
        tier = 3,
        hasFuel = false,
        payBonus = 0.45,                   -- +45% pay
        minLevel = 7,                      -- Level 7+ required
        fuelRequired = 400,
        distanceFromLS = 12500,            -- ~12.5km
        navigation = 'compass',
        hidesMinimap = true,
        -- Random weather events more common here
        weatherZone = 'storm_alley',
    },
    ['cayo_main_dock'] = {
        name = 'Cayo Main Dock',
        shortName = 'Cayo Deep',
        description = 'Primary Cayo Perico dock - high security, high pay',
        coords = vector3(4910.0, -5100.0, 2.5),
        dockCoords = vector3(4905.0, -5095.0, 1.0),
        boatSpawn = vector4(4900.0, -5090.0, -0.5, 315.0),
        tier = 3,
        hasFuel = true,
        payBonus = 2.50,                   -- 3.5x total (base 1.0 + 2.5 bonus)
        minLevel = 8,                      -- Level 8+ (Senior Captain)
        fuelRequired = 400,
        distanceFromLS = 11000,            -- ~11km
        navigation = 'compass',
        hidesMinimap = true,
        international = true,
        -- High risk = high reward
        riskLevel = 'high',
    },
    ['far_northwest_outpost'] = {
        name = 'Northwest Frontier',
        shortName = 'NW Frontier',
        description = 'Extreme northwest waters far beyond Paleto Bay - harsh conditions, extreme pay',
        -- Far northwest deep ocean, well beyond Paleto Bay
        coords = vector3(-4500.0, 9500.0, 1.0),
        dockCoords = vector3(-4495.0, 9495.0, 0.5),
        boatSpawn = vector4(-4490.0, 9490.0, -0.5, 135.0),
        tier = 3,
        hasFuel = false,                   -- No fuel - prepare well!
        payBonus = 4.00,                   -- 5.0x total (base 1.0 + 4.0 bonus)
        minLevel = 10,                     -- Level 10 (Fleet Admiral) required
        fuelRequired = 650,                -- Extreme distance
        distanceFromLS = 20000,            -- ~20km - longest route
        navigation = 'compass',
        hidesMinimap = true,
        -- Extreme storm zone
        weatherZone = 'arctic_storm',
        riskLevel = 'extreme',
    },
    ['paleto_offshore'] = {
        name = 'Paleto Offshore Platform',
        shortName = 'Paleto Off',
        description = 'Offshore drilling platform north of Paleto - easy run',
        coords = vector3(-3000.0, 7000.0, 0.0),
        dockCoords = vector3(-2995.0, 6995.0, 1.0),
        boatSpawn = vector4(-2990.0, 6990.0, -0.5, 225.0),
        tier = 2,                          -- Lower tier - entry level deep sea
        hasFuel = true,                    -- Has fuel station
        payBonus = 0.20,                   -- 1.2x total (base 1.0 + 0.2 bonus)
        minLevel = 4,                      -- Level 4+ (Deckhand)
        fuelRequired = 200,                -- Moderate fuel need
        distanceFromLS = 6500,             -- ~6.5km
        navigation = 'compass',
        hidesMinimap = false,              -- Minimap visible - easier route
        riskLevel = 'low',
    },
}

-----------------------------------------------------------
-- WEATHER ZONES (Localized Storm/Fog Effects)
-- Crossing these zones adds risk but bonus pay
-----------------------------------------------------------

Config.WeatherZones = {
    ['storm_alley'] = {
        name = 'Storm Alley',
        coords = vector3(1500.0, -4500.0, 0.0),
        radius = 2500,                     -- 2.5km radius
        weatherType = 'thunder',
        effects = {
            visibilityMult = 0.35,         -- 35% visibility
            waveDamage = 3,                -- HP/sec in rough seas
            driftForce = 0.35,             -- Lateral drift
            engineStallChance = 0.02,      -- 2% stall chance per second
        },
        payBonus = 0.35,                   -- +35% for crossing
        description = 'Severe thunderstorms - proceed with caution',
    },
    ['fog_bank'] = {
        name = 'The Fog Bank',
        coords = vector3(-2800.0, -3000.0, 0.0),
        radius = 2000,                     -- 2km radius
        weatherType = 'fog',
        effects = {
            visibilityMult = 0.15,         -- 15% visibility
            radarDisabled = true,          -- Smuggler radar doesn't work
            compassFlicker = true,         -- Compass readings unstable
        },
        payBonus = 0.25,                   -- +25% for crossing
        description = 'Dense fog - navigation instruments unreliable',
    },
    ['rough_waters'] = {
        name = 'Rough Waters',
        coords = vector3(4000.0, -3500.0, 0.0),
        radius = 3000,                     -- 3km radius - large zone
        weatherType = 'rain',
        effects = {
            visibilityMult = 0.60,         -- 60% visibility
            waveDamage = 2,
            driftForce = 0.25,
            fuelConsumptionMult = 1.25,    -- +25% fuel usage
        },
        payBonus = 0.20,                   -- +20% for crossing
        description = 'Choppy waters and rain - increased fuel consumption',
    },
    ['arctic_storm'] = {
        name = 'Arctic Storm Zone',
        coords = vector3(-4500.0, 9500.0, 0.0),  -- Far northwest deep ocean
        radius = 5000,                     -- 5km radius - huge storm zone
        weatherType = 'blizzard',
        effects = {
            visibilityMult = 0.10,         -- 10% visibility - near blind
            waveDamage = 5,                -- Heavy damage
            driftForce = 0.50,             -- Strong lateral drift
            engineStallChance = 0.05,      -- 5% stall chance per second
            fuelConsumptionMult = 1.50,    -- +50% fuel usage
            freezeDamage = 2,              -- Cold damage to player
        },
        payBonus = 0.75,                   -- +75% for crossing
        description = 'EXTREME: Arctic blizzard - visibility near zero, heavy seas',
    },
}

-----------------------------------------------------------
-- FUEL ENFORCEMENT (Point of No Return)
-- Strict fuel requirements for distant runs
-----------------------------------------------------------

Config.FuelEnforcement = {
    Enabled = true,

    -- Warning thresholds
    WarnAtPercent = 30,                    -- "Low fuel" warning
    CriticalAtPercent = 15,                -- "RETURN NOW" warning
    StrandedAtPercent = 5,                 -- Engine stuttering begins

    -- Stranded mechanics
    StutterStartPercent = 5,               -- Below 5%: random power loss
    StutterChancePerSecond = 0.15,         -- 15% chance per second
    StutterDuration = { min = 500, max = 2000 }, -- ms of power loss

    -- Dead in water
    DeadAtPercent = 0,                     -- 0% = engine won't start
    CanDriftWithCurrent = true,            -- Player drifts slowly when dead

    -- Pre-departure checks for distant destinations
    RequireMinFuelForDistant = true,       -- Must have fuelRequired to depart
    BlockDepartureIfLow = true,            -- Can't start job without fuel

    -- Rescue system
    RescueCost = 5000,                     -- $5000 to call rescue
    RescueWaitTime = 180,                  -- 3 minutes for rescue to arrive
    AbandonPenalty = 0.20,                 -- Lose 20% XP towards next level if abandoning
}

-----------------------------------------------------------
-- BOAT DELIVERY: FUEL STATIONS
-----------------------------------------------------------

Config.FuelStations = {
    { coords = vector3(169.43, -3086.71, 5.90), label = 'Elysian Fuel Dock' },
    { coords = vector3(-847.57, -1368.01, 1.60), label = 'Vespucci Fuel' },
    { coords = vector3(-275.87, 6637.55, 7.50), label = 'Paleto Marina Fuel' },
    { coords = vector3(4971.37, -5173.39, 2.05), label = 'Cayo Perico Fuel' },
}

-----------------------------------------------------------
-- BOAT DELIVERY: BUSINESS DELIVERIES
-- For future logistics company expansion
-----------------------------------------------------------

Config.BusinessDeliveries = {
    ['vanilla_unicorn'] = {
        name = 'Vanilla Unicorn',
        coords = vector3(127.98, -1293.61, 29.27),
        nearestPort = 'elysian',
        acceptedCargo = { 'supplies', 'alcohol', 'luxury' },
        payBonus = 0.1,
    },
    ['tequila'] = {
        name = 'Tequi-la-la',
        coords = vector3(-557.76, 286.83, 82.18),
        nearestPort = 'vespucci',
        acceptedCargo = { 'alcohol', 'supplies' },
        payBonus = 0.1,
    },
    ['bahama'] = {
        name = 'Bahama Mamas West',
        coords = vector3(-1387.08, -586.44, 30.32),
        nearestPort = 'del_perro',
        acceptedCargo = { 'alcohol', 'supplies', 'seafood' },
        payBonus = 0.15,
    },
}

-----------------------------------------------------------
-- EXPRESS DELIVERY ROUTES (Seashark/Jet Ski Only)
-- These use narrow LS River canals that only small watercraft can navigate
-----------------------------------------------------------

Config.ExpressRoutes = {
    -- These routes give the Seashark a unique purpose
    -- Higher pay but requires BOTH speed AND careful driving
    -- Vessel health determines bonus - damaged hull = no express bonus!

    ['canal_run'] = {
        name = 'LS River Express',
        description = 'Navigate the LS River canal system',
        allowedVehicles = { 'seashark', 'dinghy' }, -- Only small craft
        startPoint = vector4(-227.58, -2398.25, 0.0, 320.0), -- Canal entrance near port
        waypoints = {
            vector3(-139.45, -1878.32, 0.0),   -- Under bridge
            vector3(108.67, -1586.23, 0.0),    -- Canal bend
            vector3(317.89, -1284.56, 0.0),    -- Strawberry area
        },
        endPoint = vector4(523.45, -1012.34, 0.0, 45.0), -- Mirror Park lake exit
        timeLimit = 180, -- 3 minutes
        payMultiplier = 2.5, -- 2.5x normal pay
        xpMultiplier = 2.0,

        -- VESSEL HEALTH REQUIREMENTS
        minHealthForBonus = 90.0,  -- Must have 90%+ health for full bonus
        healthPenaltyScale = 2.0,  -- Each 1% damage = 2% pay penalty
        noPayBelowHealth = 50.0,   -- Below 50% health = NO express bonus at all
    },

    ['vespucci_sprint'] = {
        name = 'Vespucci Beach Sprint',
        description = 'Speed delivery along the coast',
        allowedVehicles = { 'seashark' }, -- Jet ski only
        startPoint = vector4(-847.57, -1368.01, 0.0, 110.0), -- Vespucci Marina
        waypoints = {
            vector3(-1136.78, -1556.42, 0.0),  -- Del Perro pier approach
            vector3(-1450.23, -1203.67, 0.0),  -- Past pier
        },
        endPoint = vector4(-1610.73, -1028.77, 0.0, 220.0), -- Del Perro Pier
        timeLimit = 120, -- 2 minutes
        payMultiplier = 2.0,
        xpMultiplier = 1.8,

        -- VESSEL HEALTH REQUIREMENTS
        minHealthForBonus = 85.0,
        healthPenaltyScale = 2.5,  -- Higher penalty - it's a sprint!
        noPayBelowHealth = 60.0,
    },

    ['murrieta_run'] = {
        name = 'Murrieta Heights Rush',
        description = 'Industrial waterway speed run',
        allowedVehicles = { 'seashark', 'dinghy' },
        startPoint = vector4(169.43, -3086.71, 0.0, 270.0), -- Elysian port
        waypoints = {
            vector3(-101.23, -2512.45, 0.0),   -- Industrial area
            vector3(-324.67, -2245.89, 0.0),   -- Warehouse district
        },
        endPoint = vector4(-527.34, -2178.56, 0.0, 180.0), -- Murrieta dock
        timeLimit = 150, -- 2.5 minutes
        payMultiplier = 2.2,
        xpMultiplier = 1.9,

        -- VESSEL HEALTH REQUIREMENTS
        minHealthForBonus = 85.0,
        healthPenaltyScale = 2.0,
        noPayBelowHealth = 55.0,
    },
}

-- Express delivery health calculation helper
function Config.CalculateExpressBonus(route, vesselHealth)
    -- vesselHealth is 0-100 (percentage)
    local routeData = Config.ExpressRoutes[route]
    if not routeData then return 0, 'Invalid route' end

    -- Below minimum = no bonus at all
    if vesselHealth < routeData.noPayBelowHealth then
        return 0, 'Hull too damaged - express bonus forfeited'
    end

    -- Calculate penalty based on damage
    local damage = 100 - vesselHealth
    local penaltyPercent = 0

    if vesselHealth < routeData.minHealthForBonus then
        -- Each 1% damage below threshold = healthPenaltyScale% pay penalty
        local damageOverThreshold = routeData.minHealthForBonus - vesselHealth
        penaltyPercent = damageOverThreshold * routeData.healthPenaltyScale
    end

    -- Cap penalty at 100%
    penaltyPercent = math.min(penaltyPercent, 100)

    -- Return multiplier (1.0 = full bonus, 0.5 = half bonus, etc.)
    local bonusMultiplier = (100 - penaltyPercent) / 100

    local message = nil
    if bonusMultiplier >= 1.0 then
        message = 'Perfect delivery - full express bonus!'
    elseif bonusMultiplier >= 0.75 then
        message = 'Minor hull damage - slight bonus reduction'
    elseif bonusMultiplier >= 0.5 then
        message = 'Significant hull damage - bonus reduced'
    else
        message = 'Heavy hull damage - minimal bonus'
    end

    return bonusMultiplier, message
end

-- Express delivery cargo types (small, high-value items)
Config.ExpressCargo = {
    ['documents'] = {
        label = 'Urgent Documents',
        description = 'Time-sensitive legal papers',
        payBase = 800,
        xp = 100,
    },
    ['samples'] = {
        label = 'Medical Samples',
        description = 'Lab specimens requiring fast delivery',
        payBase = 1200,
        xp = 150,
        fragile = true,
    },
    ['parts'] = {
        label = 'Emergency Parts',
        description = 'Critical repair components',
        payBase = 1000,
        xp = 120,
    },
    ['cash'] = {
        label = 'Cash Transfer',
        description = 'Unmarked bills - no questions asked',
        payBase = 2000,
        xp = 200,
        illegal = true,
        policeChance = 0.2,
        levelRequired = 8,
    },
}
