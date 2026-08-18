--[[
    dps-maritime - Jetsam Company
    Shared Utility Functions
]]

Maritime = Maritime or {}

-----------------------------------------------------------
-- DISTANCE CALCULATION
-----------------------------------------------------------

function Maritime.CalculateDistance(pos1, pos2)
    if not pos1 or not pos2 then return 0 end
    local x1, y1, z1 = pos1.x or pos1[1], pos1.y or pos1[2], pos1.z or pos1[3]
    local x2, y2, z2 = pos2.x or pos2[1], pos2.y or pos2[2], pos2.z or pos2[3]
    return #(vector3(x1, y1, z1) - vector3(x2, y2, z2))
end

-----------------------------------------------------------
-- PAY CALCULATION
-----------------------------------------------------------

function Maritime.CalculateBoatPay(distance, cargoType, level, weather, damagePercent, boatModel)
    local basePay = distance * Config.BoatDelivery.BasePayoutPerMeter

    -- Distance tier multiplier
    local distanceMultiplier = 1.0
    for _, tier in ipairs(Config.BoatDelivery.DistanceTiers) do
        if distance >= tier.minDistance then
            distanceMultiplier = tier.multiplier
        end
    end
    basePay = basePay * distanceMultiplier

    -- Cargo type multiplier
    local cargo = Config.CargoTypes[cargoType]
    if cargo then
        basePay = basePay * cargo.payMultiplier
    end

    -- Vessel multiplier (larger boats = bigger payouts but higher overhead)
    if boatModel then
        local boat = Config.Boats[boatModel]
        if boat and boat.payMultiplier then
            basePay = basePay * boat.payMultiplier
        end
    end

    -- Level multiplier
    local levelData = Config.GetLevelData(level)
    basePay = basePay * levelData.payMultiplier

    -- Weather bonus
    local weatherBonus = Config.BoatDelivery.WeatherBonuses[weather] or 0
    basePay = basePay * (1 + weatherBonus)

    -- Damage penalty (breakage for fragile cargo)
    if damagePercent and damagePercent > 0 then
        for _, penalty in ipairs(Config.BoatDelivery.DamagePenalties) do
            if damagePercent >= penalty.threshold then
                basePay = basePay * (1 - penalty.penalty)
            end
        end
    end

    -- Ensure minimum payout
    local minPayout = Config.BoatDelivery.MinimumPayout or 500
    if basePay < minPayout then
        basePay = minPayout
    end

    return math.floor(basePay)
end

function Maritime.CalculateDockPay(containerType, level)
    local container = Config.ContainerCargoTypes[containerType]
    if not container then
        container = Config.ContainerCargoTypes['standard_container']
    end

    local basePay = math.random(container.payMin, container.payMax)
    local levelData = Config.GetLevelData(level)

    return math.floor(basePay * levelData.payMultiplier)
end

-----------------------------------------------------------
-- XP CALCULATION
-----------------------------------------------------------

function Maritime.CalculateBoatXP(distance, cargoType, level, weather)
    local baseXP = Config.Progression.BaseXPPerDelivery
    baseXP = baseXP + (distance * Config.Progression.XPPerDistance)

    -- Cargo XP multiplier
    local cargo = Config.CargoTypes[cargoType]
    if cargo then
        baseXP = baseXP * cargo.xpMultiplier
    end

    -- Weather bonus
    if weather == 'rain' or weather == 'thunder' or weather == 'fog' then
        baseXP = baseXP * (1 + Config.Progression.WeatherBonusXP)
    end

    return math.floor(baseXP)
end

function Maritime.CalculateDockXP(containerType)
    local container = Config.ContainerCargoTypes[containerType]
    if not container then
        container = Config.ContainerCargoTypes['standard_container']
    end
    return container.xp or 75
end

-----------------------------------------------------------
-- LEVEL UTILITIES
-----------------------------------------------------------

function Maritime.GetXPToNextLevel(currentXP, currentLevel)
    local nextLevel = currentLevel + 1
    if nextLevel > 10 then return 0 end

    local nextLevelData = Config.Progression.Levels[nextLevel]
    if not nextLevelData then return 0 end

    return nextLevelData.xp - currentXP
end

function Maritime.GetLevelProgress(currentXP, currentLevel)
    local currentLevelData = Config.Progression.Levels[currentLevel]
    local nextLevel = currentLevel + 1
    local nextLevelData = Config.Progression.Levels[nextLevel]

    if not nextLevelData then return 100 end

    local currentLevelXP = currentLevelData.xp
    local nextLevelXP = nextLevelData.xp
    local xpIntoLevel = currentXP - currentLevelXP
    local xpNeeded = nextLevelXP - currentLevelXP

    return math.floor((xpIntoLevel / xpNeeded) * 100)
end

-----------------------------------------------------------
-- CARGO UTILITIES
-----------------------------------------------------------

function Maritime.GetAvailableCargo(level)
    local available = {}
    for id, cargo in pairs(Config.CargoTypes) do
        if level >= cargo.levelRequired then
            available[id] = cargo
        end
    end
    return available
end

function Maritime.GetRandomCargo(level, excludeIllegal)
    local available = {}
    for id, cargo in pairs(Config.CargoTypes) do
        if level >= cargo.levelRequired then
            if not excludeIllegal or not cargo.illegal then
                table.insert(available, id)
            end
        end
    end
    if #available == 0 then return 'standard' end
    return available[math.random(#available)]
end

-----------------------------------------------------------
-- BOAT UTILITIES
-----------------------------------------------------------

function Maritime.GetAvailableBoats(level)
    local available = {}
    for model, boat in pairs(Config.Boats) do
        if level >= boat.levelRequired then
            available[model] = boat
        end
    end
    return available
end

function Maritime.CanUseBoat(model, level)
    local boat = Config.Boats[model]
    if not boat then return false end
    return level >= boat.levelRequired
end

-----------------------------------------------------------
-- PORT UTILITIES
-----------------------------------------------------------

function Maritime.GetNearestPort(coords)
    local nearest = nil
    local nearestDist = math.huge

    for id, port in pairs(Config.Ports) do
        local dist = Maritime.CalculateDistance(coords, port.coords)
        if dist < nearestDist then
            nearestDist = dist
            nearest = id
        end
    end

    return nearest, nearestDist
end

function Maritime.GetRandomDeliveryPort(excludePort, level)
    local available = {}
    for id, port in pairs(Config.Ports) do
        if id ~= excludePort then
            local tierRequired = port.tier or 1
            local levelRequired = (tierRequired - 1) * 3 + 4
            if level >= levelRequired then
                table.insert(available, id)
            end
        end
    end
    if #available == 0 then return nil end
    return available[math.random(#available)]
end

-----------------------------------------------------------
-- TIME FORMATTING
-----------------------------------------------------------

function Maritime.FormatTime(seconds)
    if seconds < 60 then
        return string.format('%ds', seconds)
    elseif seconds < 3600 then
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format('%dm %ds', mins, secs)
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        return string.format('%dh %dm', hours, mins)
    end
end

function Maritime.FormatMoney(amount)
    return '$' .. string.format('%0.0f', amount):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
end

-----------------------------------------------------------
-- CARGO CRATE UTILITIES (qs-inventory metadata)
-----------------------------------------------------------

-- Condition labels based on durability
Maritime.CrateConditions = {
    { min = 90, label = 'Pristine', color = 'green' },
    { min = 70, label = 'Good', color = 'blue' },
    { min = 50, label = 'Fair', color = 'yellow' },
    { min = 25, label = 'Damaged', color = 'orange' },
    { min = 10, label = 'Critical', color = 'red' },
    { min = 0, label = 'Destroyed', color = 'gray' },
}

---@param durability number The current durability (0-100)
---@return string label The condition label
---@return string color The condition color
function Maritime.GetCrateCondition(durability)
    for _, condition in ipairs(Maritime.CrateConditions) do
        if durability >= condition.min then
            return condition.label, condition.color
        end
    end
    return 'Destroyed', 'gray'
end

---@param basePrice number The base price of the cargo
---@param durability number The current durability (0-100)
---@return number payout The calculated payout based on durability
function Maritime.CalculateCratePayout(basePrice, durability)
    if not Config.CargoCrates or not Config.CargoCrates.Enabled then
        return basePrice
    end

    -- Use config formula if available
    if Config.CargoCrates.PayoutFormula then
        return Config.CargoCrates.PayoutFormula(basePrice, durability)
    end

    -- Default formula: linear scaling
    local minDurability = Config.CargoCrates.MinSellDurability or 10
    if durability <= minDurability then
        return 0
    end

    return math.floor(basePrice * (durability / 100))
end

---@param cargoType string The type of cargo
---@param basePrice number The base price for this cargo
---@param quantity number|nil Optional quantity (default 1)
---@return table metadata The metadata table for qs-inventory
function Maritime.CreateCrateMetadata(cargoType, basePrice, quantity)
    local cargo = Config.CargoTypes[cargoType]
    local startingDurability = Config.CargoCrates and Config.CargoCrates.StartingDurability or 100

    return {
        durability = startingDurability,
        cargoType = cargoType,
        cargoLabel = cargo and cargo.label or 'Standard Cargo',
        basePrice = basePrice,
        quantity = quantity or 1,
        sealedAt = os.time(),
        origin = 'jetsam_maritime',
        -- Visual description for inventory tooltip
        description = string.format('%s - %s\nCondition: %s\nBase Value: %s',
            cargo and cargo.label or 'Standard Cargo',
            Maritime.GetCrateCondition(startingDurability),
            Maritime.FormatMoney(basePrice)
        ),
    }
end

---@param currentDurability number Current durability
---@param damageSource string The source of damage (collision, water, gunfire, explosion, rough_seas)
---@return number newDurability The new durability after damage
---@return number damageTaken The amount of damage taken
function Maritime.CalculateCrateDamage(currentDurability, damageSource)
    if not Config.CargoCrates or not Config.CargoCrates.Enabled then
        return currentDurability, 0
    end

    local damageSources = Config.CargoCrates.DamageSources or {
        collision = 5,
        water = 2,
        gunfire = 15,
        explosion = 50,
        rough_seas = 1,
    }

    local damage = damageSources[damageSource] or 5
    local newDurability = math.max(0, currentDurability - damage)

    return newDurability, damage
end

---@param metadata table The cargo crate metadata
---@param damageSource string The source of damage
---@return table updatedMetadata The updated metadata with new durability
function Maritime.DamageCrateMetadata(metadata, damageSource)
    if not metadata or not metadata.durability then
        return metadata
    end

    local newDurability, damageTaken = Maritime.CalculateCrateDamage(metadata.durability, damageSource)
    metadata.durability = newDurability

    -- Update description
    local condition, _ = Maritime.GetCrateCondition(newDurability)
    metadata.description = string.format('%s - %s\nCondition: %s (%d%%)\nBase Value: %s',
        metadata.cargoLabel or 'Standard Cargo',
        condition,
        newDurability,
        Maritime.FormatMoney(metadata.basePrice or 0)
    )

    return metadata, damageTaken
end

---@param metadata table The cargo crate metadata
---@return number payout The final payout for this crate
function Maritime.GetCrateFinalPayout(metadata)
    if not metadata then return 0 end

    local basePrice = metadata.basePrice or 0
    local durability = metadata.durability or 100

    return Maritime.CalculateCratePayout(basePrice, durability)
end

-----------------------------------------------------------
-- TABLE UTILITIES
-----------------------------------------------------------

---Count the number of entries in a table (works with non-sequential keys)
---@param tbl table The table to count
---@return number count The number of entries
function Maritime.TableLength(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-----------------------------------------------------------
-- STATE BAG ACCESSORS (Client-side only)
-- Provides easy access to synced player maritime data
-----------------------------------------------------------

if not IsDuplicityVersion() then
    -- Get local player's maritime level from State Bags
    function Maritime.GetMyLevel()
        return LocalPlayer.state.maritimeLevel or 1
    end

    -- Get local player's maritime XP from State Bags
    function Maritime.GetMyXP()
        return LocalPlayer.state.maritimeXP or 0
    end

    -- Get local player's maritime title from State Bags
    function Maritime.GetMyTitle()
        return LocalPlayer.state.maritimeTitle or 'Deckhand'
    end

    -- Check if local player is on maritime duty
    function Maritime.AmIOnDuty()
        return LocalPlayer.state.maritimeOnDuty or false
    end

    -- Get local player's current job type ('dock' or 'boat')
    function Maritime.GetMyJobType()
        return LocalPlayer.state.maritimeJobType
    end

    -- Get another player's maritime level from State Bags
    ---@param serverId number The server ID of the player
    function Maritime.GetPlayerLevel(serverId)
        local player = Player(serverId)
        return player and player.state.maritimeLevel or 1
    end

    -- Check if another player is on maritime duty
    ---@param serverId number The server ID of the player
    function Maritime.IsPlayerOnDuty(serverId)
        local player = Player(serverId)
        return player and player.state.maritimeOnDuty or false
    end

    -- Watch for state changes (useful for UI updates)
    ---@param handler function Callback function(key, newValue, oldValue)
    function Maritime.OnStateChange(handler)
        AddStateBagChangeHandler('maritime', nil, function(bagName, key, value, _reserved, replicated)
            if string.match(bagName, 'player:') then
                local serverId = tonumber(string.match(bagName, 'player:(%d+)'))
                if serverId == GetPlayerServerId(PlayerId()) then
                    handler(key:gsub('maritime', ''), value)
                end
            end
        end)
    end
end

-----------------------------------------------------------
-- DEBUG
-----------------------------------------------------------

function Maritime.Debug(...)
    if Config.Debug then
        print('[dps-maritime]', ...)
    end
end
