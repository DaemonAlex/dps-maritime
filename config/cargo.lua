--[[
    dps-maritime - Jetsam Company
    Cargo Type Definitions
]]

-----------------------------------------------------------
-- BOAT CARGO TYPES
-----------------------------------------------------------

Config.CargoTypes = {
    -----------------------------------------------------------
    -- STANDARD CARGO (Level 4+)
    -----------------------------------------------------------
    ['standard'] = {
        label = 'General Cargo',
        description = 'Mixed goods and supplies',
        levelRequired = 4,
        payMultiplier = 1.0,
        xpMultiplier = 1.0,
        weight = 1.0,
        fragile = false,
        perishable = false,
        illegal = false,
    },

    ['electronics'] = {
        label = 'Electronics',
        description = 'Sensitive electronic equipment',
        levelRequired = 4,
        payMultiplier = 1.5,
        xpMultiplier = 1.3,
        weight = 0.8,
        fragile = true,
        perishable = false,
        illegal = false,
        damageMultiplier = 1.5,
    },

    ['seafood'] = {
        label = 'Fresh Seafood',
        description = 'Time-sensitive catch of the day',
        levelRequired = 4,
        payMultiplier = 1.4,
        xpMultiplier = 1.2,
        weight = 1.2,
        fragile = false,
        perishable = true,
        perishTime = 0.7, -- 70% of normal time
        illegal = false,
    },

    ['supplies'] = {
        label = 'Restaurant Supplies',
        description = 'Food and beverage supplies',
        levelRequired = 4,
        payMultiplier = 1.2,
        xpMultiplier = 1.1,
        weight = 1.5,
        fragile = false,
        perishable = true,
        perishTime = 0.8,
        illegal = false,
    },

    -----------------------------------------------------------
    -- MEDIUM VALUE CARGO (Level 5+)
    -----------------------------------------------------------
    ['vehicle_parts'] = {
        label = 'Vehicle Parts',
        description = 'Auto parts and components',
        levelRequired = 5,
        payMultiplier = 1.6,
        xpMultiplier = 1.4,
        weight = 2.5,
        fragile = false,
        perishable = false,
        illegal = false,
        heavyLoad = true,
    },

    ['clothing'] = {
        label = 'Boutique Clothing',
        description = 'Designer fashion items',
        levelRequired = 5,
        payMultiplier = 1.8,
        xpMultiplier = 1.3,
        weight = 0.5,
        fragile = true,
        perishable = false,
        illegal = false,
    },

    ['alcohol'] = {
        label = 'Premium Alcohol',
        description = 'Fine wines and spirits',
        levelRequired = 5,
        payMultiplier = 1.7,
        xpMultiplier = 1.4,
        weight = 1.8,
        fragile = true,
        perishable = false,
        illegal = false,
    },

    -----------------------------------------------------------
    -- HIGH VALUE CARGO (Level 6+)
    -----------------------------------------------------------
    ['medical'] = {
        label = 'Medical Supplies',
        description = 'Pharmaceuticals and equipment',
        levelRequired = 6,
        payMultiplier = 2.0,
        xpMultiplier = 1.8,
        weight = 0.6,
        fragile = true,
        perishable = true,
        perishTime = 0.6,
        illegal = false,
    },

    ['luxury'] = {
        label = 'Luxury Goods',
        description = 'High-end items and jewelry',
        levelRequired = 6,
        payMultiplier = 2.5,
        xpMultiplier = 1.5,
        weight = 0.4,
        fragile = true,
        perishable = false,
        illegal = false,
        damageMultiplier = 2.0,
    },

    ['yacht_provisions'] = {
        label = 'Yacht Provisions',
        description = 'Luxury yacht supplies',
        levelRequired = 6,
        payMultiplier = 2.2,
        xpMultiplier = 1.6,
        weight = 1.0,
        fragile = true,
        perishable = true,
        perishTime = 0.75,
        illegal = false,
    },

    -----------------------------------------------------------
    -- HAZMAT CARGO (Level 7+, requires hazmat-rated boat)
    -----------------------------------------------------------
    ['hazmat'] = {
        label = 'Hazardous Materials',
        description = 'Dangerous goods requiring special handling',
        levelRequired = 7,
        payMultiplier = 3.5,
        xpMultiplier = 2.0,
        weight = 2.0,
        fragile = true,
        perishable = false,
        illegal = false,
        hazmat = true,
        explosionRisk = 0.15,
        requiresHazmatBoat = true,
    },

    ['chemicals'] = {
        label = 'Industrial Chemicals',
        description = 'Chemical compounds for manufacturing',
        levelRequired = 7,
        payMultiplier = 3.0,
        xpMultiplier = 1.8,
        weight = 2.5,
        fragile = false,
        perishable = false,
        illegal = false,
        hazmat = true,
        requiresHazmatBoat = true,
    },

    -----------------------------------------------------------
    -- CONTRABAND CARGO (Level 8+, illegal)
    -----------------------------------------------------------
    ['contraband'] = {
        label = 'Unmarked Crates',
        description = 'Contents unknown, no questions asked',
        levelRequired = 8,
        payMultiplier = 4.0,
        xpMultiplier = 2.5,
        weight = 1.5,
        fragile = false,
        perishable = false,
        illegal = true,
        policeChance = 0.15,
    },

    ['weapons'] = {
        label = 'Arms Shipment',
        description = 'Military-grade equipment',
        levelRequired = 9,
        payMultiplier = 5.0,
        xpMultiplier = 3.0,
        weight = 3.0,
        fragile = false,
        perishable = false,
        illegal = true,
        policeChance = 0.25,
        heavyLoad = true,
    },

    ['drugs'] = {
        label = 'Pharmaceutical Samples',
        description = 'Unlicensed medical products',
        levelRequired = 9,
        payMultiplier = 5.5,
        xpMultiplier = 3.5,
        weight = 0.5,
        fragile = true,
        perishable = false,
        illegal = true,
        policeChance = 0.30,
    },

    -----------------------------------------------------------
    -- PREMIUM CARGO (Level 10)
    -----------------------------------------------------------
    ['supercar_parts'] = {
        label = 'Exotic Car Parts',
        description = 'Rare supercar components',
        levelRequired = 10,
        payMultiplier = 6.0,
        xpMultiplier = 4.0,
        weight = 1.5,
        fragile = true,
        perishable = false,
        illegal = false,
        damageMultiplier = 3.0,
    },
}

-----------------------------------------------------------
-- CONTAINER CARGO TYPES (For dock work)
-----------------------------------------------------------

Config.ContainerCargoTypes = {
    -----------------------------------------------------------
    -- LEVEL 1: Basic Containers
    -----------------------------------------------------------
    ['standard_container'] = {
        label = 'Standard Container',
        description = 'General goods container',
        payMin = 800,
        payMax = 1200,
        xp = 75,
        levelRequired = 1,
    },

    -----------------------------------------------------------
    -- LEVEL 2: Fragile Containers (new mechanic: watch your driving!)
    -----------------------------------------------------------
    ['fragile_container'] = {
        label = 'Fragile Container',
        description = 'Handle with care - electronics and glassware',
        payMin = 1100,
        payMax = 1700,
        xp = 100,
        levelRequired = 2,
        fragile = true,           -- NEW: Payout reduced based on damage
        damageMultiplier = 1.5,   -- 1.5x damage penalty
    },

    -----------------------------------------------------------
    -- LEVEL 3: Perishable/Refrigerated (new mechanic: time limit!)
    -----------------------------------------------------------
    ['refrigerated'] = {
        label = 'Refrigerated Container',
        description = 'Temperature-controlled goods - deliver quickly!',
        payMin = 1200,
        payMax = 1800,
        xp = 120,
        levelRequired = 3,
        perishable = true,        -- NEW: Time limit on delivery
        perishTime = 300,         -- 5 minutes to deliver
        perishPenalty = 0.5,      -- Lose 50% pay if expired
    },

    -----------------------------------------------------------
    -- LEVEL 5: Hazmat (requires careful handling)
    -----------------------------------------------------------
    ['hazmat_container'] = {
        label = 'Hazmat Container',
        description = 'Dangerous materials - no collisions!',
        payMin = 1600,
        payMax = 2400,
        xp = 150,
        levelRequired = 5,
        hazmat = true,
        damageMultiplier = 2.0,   -- Heavy penalty for damage
        explosionRisk = 0.05,     -- 5% explosion chance on heavy collision
    },

    -----------------------------------------------------------
    -- LEVEL 7: Oversized (requires skill to maneuver)
    -----------------------------------------------------------
    ['oversized'] = {
        label = 'Oversized Container',
        description = 'Extra-large cargo - tight spaces are risky',
        payMin = 2000,
        payMax = 3200,
        xp = 200,
        levelRequired = 7,
        oversized = true,         -- Harder to maneuver
        speedPenalty = 0.8,       -- 20% slower with this load
    },
}

-----------------------------------------------------------
-- HELPER FUNCTIONS
-----------------------------------------------------------

function Config.GetCargoType(cargoId)
    return Config.CargoTypes[cargoId]
end

function Config.GetCargoForLevel(level)
    local available = {}
    for id, cargo in pairs(Config.CargoTypes) do
        if level >= cargo.levelRequired then
            available[id] = cargo
        end
    end
    return available
end

function Config.CanUseCargo(cargoId, level)
    local cargo = Config.CargoTypes[cargoId]
    if not cargo then return false end
    return level >= cargo.levelRequired
end

function Config.GetRandomContainerType(level)
    local available = {}
    for id, cargo in pairs(Config.ContainerCargoTypes) do
        local req = cargo.levelRequired or 1
        if level >= req then
            table.insert(available, id)
        end
    end
    if #available == 0 then
        return 'standard_container'
    end
    return available[math.random(#available)]
end
