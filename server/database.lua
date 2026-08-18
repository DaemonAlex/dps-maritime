--[[
    dps-maritime - Jetsam Company
    Database Operations
]]

local Database = {}

-----------------------------------------------------------
-- PLAYER DATA
-----------------------------------------------------------

function Database.GetPlayerData(identifier)
    local result = MySQL.single.await([[
        SELECT * FROM maritime_players WHERE identifier = ?
    ]], { identifier })

    if not result then
        -- Create new player record
        MySQL.insert.await([[
            INSERT INTO maritime_players (identifier, xp, level, boat_deliveries, dock_deliveries, total_earnings)
            VALUES (?, 0, 1, 0, 0, 0)
        ]], { identifier })

        return {
            identifier = identifier,
            xp = 0,
            level = 1,
            boat_deliveries = 0,
            dock_deliveries = 0,
            total_earnings = 0,
            current_streak = 0,
        }
    end

    return result
end

function Database.UpdatePlayerXP(identifier, xp, level)
    MySQL.update.await([[
        UPDATE maritime_players SET xp = ?, level = ? WHERE identifier = ?
    ]], { xp, level, identifier })
end

function Database.IncrementDelivery(identifier, jobType, earnings)
    if jobType == 'boat' then
        MySQL.update.await([[
            UPDATE maritime_players
            SET boat_deliveries = boat_deliveries + 1,
                total_earnings = total_earnings + ?
            WHERE identifier = ?
        ]], { earnings, identifier })
    else
        MySQL.update.await([[
            UPDATE maritime_players
            SET dock_deliveries = dock_deliveries + 1,
                total_earnings = total_earnings + ?
            WHERE identifier = ?
        ]], { earnings, identifier })
    end
end

function Database.UpdateStreak(identifier, streak)
    MySQL.update.await([[
        UPDATE maritime_players SET current_streak = ? WHERE identifier = ?
    ]], { streak, identifier })
end

-- Add to total_earnings without touching delivery counts (used for event bonuses)
function Database.AddEarnings(identifier, amount)
    if not amount or amount <= 0 then return end
    MySQL.update.await([[
        UPDATE maritime_players SET total_earnings = total_earnings + ? WHERE identifier = ?
    ]], { amount, identifier })
end

-----------------------------------------------------------
-- DELIVERY HISTORY
-----------------------------------------------------------

function Database.LogDelivery(data)
    MySQL.insert.await([[
        INSERT INTO maritime_history
        (identifier, job_type, cargo_type, start_port, end_port, distance, payout, xp_earned, boat_used)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.identifier,
        data.job_type,
        data.cargo_type,
        data.start_port,
        data.end_port,
        data.distance,
        data.payout,
        data.xp_earned,
        data.boat_used
    })
end

function Database.GetPlayerHistory(identifier, limit)
    limit = limit or 10
    return MySQL.query.await([[
        SELECT * FROM maritime_history
        WHERE identifier = ?
        ORDER BY completed_at DESC
        LIMIT ?
    ]], { identifier, limit })
end

-----------------------------------------------------------
-- FLEET MANAGEMENT
-----------------------------------------------------------

function Database.GetPlayerFleet(identifier)
    return MySQL.query.await([[
        SELECT * FROM maritime_fleet WHERE owner = ?
    ]], { identifier })
end

-- Generate a unique boat plate
function Database.GenerateBoatPlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local nums = '0123456789'
    local plate

    repeat
        -- Format: JET + 2 letters + 3 numbers (e.g., JETAB123)
        plate = 'JET'
        for i = 1, 2 do
            local idx = math.random(1, #chars)
            plate = plate .. chars:sub(idx, idx)
        end
        for i = 1, 3 do
            local idx = math.random(1, #nums)
            plate = plate .. nums:sub(idx, idx)
        end

        -- Check if plate exists
        local exists = MySQL.scalar.await([[
            SELECT 1 FROM maritime_fleet WHERE plate = ?
        ]], { plate })
    until not exists

    return plate
end

function Database.AddBoatToFleet(identifier, boatModel, boatName)
    local boat = Config.Boats[boatModel]
    if not boat then return nil end

    -- Generate unique plate for garage system integration
    local plate = Database.GenerateBoatPlate()

    local id = MySQL.insert.await([[
        INSERT INTO maritime_fleet (owner, model, name, plate, fuel, `condition`, is_spawned, is_impounded)
        VALUES (?, ?, ?, ?, ?, 100, 0, 0)
    ]], { identifier, boatModel, boatName, plate, boat.fuelCapacity })

    return id
end

function Database.RemoveBoatFromFleet(boatId, identifier)
    MySQL.update.await([[
        DELETE FROM maritime_fleet WHERE id = ? AND owner = ?
    ]], { boatId, identifier })
end

function Database.UpdateBoatCondition(boatId, condition, fuel)
    MySQL.update.await([[
        UPDATE maritime_fleet SET `condition` = ?, fuel = ? WHERE id = ?
    ]], { condition, fuel, boatId })
end

function Database.GetBoatById(boatId)
    return MySQL.single.await([[
        SELECT * FROM maritime_fleet WHERE id = ?
    ]], { boatId })
end

function Database.GetBoatByPlate(plate)
    return MySQL.single.await([[
        SELECT * FROM maritime_fleet WHERE plate = ?
    ]], { plate })
end

-----------------------------------------------------------
-- SPAWN STATE TRACKING (for jg-advancedgarages bridge)
-----------------------------------------------------------

function Database.UpdateBoatSpawnState(boatId, isSpawned)
    MySQL.update.await([[
        UPDATE maritime_fleet SET is_spawned = ? WHERE id = ?
    ]], { isSpawned and 1 or 0, boatId })
end

function Database.GetSpawnedBoats(identifier)
    return MySQL.query.await([[
        SELECT * FROM maritime_fleet WHERE owner = ? AND is_spawned = 1
    ]], { identifier })
end

-----------------------------------------------------------
-- IMPOUND TRACKING
-----------------------------------------------------------

function Database.ImpoundBoat(boatId)
    MySQL.update.await([[
        UPDATE maritime_fleet
        SET is_impounded = 1, is_spawned = 0, impound_time = NOW()
        WHERE id = ?
    ]], { boatId })
end

function Database.RecoverFromImpound(boatId, newCondition, newFuel)
    MySQL.update.await([[
        UPDATE maritime_fleet
        SET is_impounded = 0, impound_time = NULL, `condition` = ?, fuel = ?
        WHERE id = ?
    ]], { newCondition, newFuel, boatId })
end

function Database.GetImpoundedBoats(identifier)
    return MySQL.query.await([[
        SELECT
            mf.*,
            TIMESTAMPDIFF(DAY, impound_time, NOW()) as days_impounded
        FROM maritime_fleet mf
        WHERE owner = ? AND is_impounded = 1
    ]], { identifier })
end

function Database.GetImpoundDays(boatId)
    local result = MySQL.single.await([[
        SELECT TIMESTAMPDIFF(DAY, impound_time, NOW()) as days
        FROM maritime_fleet WHERE id = ?
    ]], { boatId })
    return result and result.days or 0
end

-----------------------------------------------------------
-- MAINTENANCE TRACKING
-----------------------------------------------------------

function Database.UpdateServiceHours(boatId, hours)
    MySQL.update.await([[
        UPDATE maritime_fleet SET service_hours = service_hours + ? WHERE id = ?
    ]], { hours, boatId })
end

function Database.RecordService(boatId)
    MySQL.update.await([[
        UPDATE maritime_fleet SET service_hours = 0, last_service = NOW() WHERE id = ?
    ]], { boatId })
end

function Database.GetServiceDue(identifier)
    -- Returns boats that are past their service interval
    local serviceInterval = Config.Maintenance and Config.Maintenance.ServiceInterval or 180
    return MySQL.query.await([[
        SELECT * FROM maritime_fleet
        WHERE owner = ? AND service_hours >= ?
    ]], { identifier, serviceInterval })
end

-----------------------------------------------------------
-- CONTAINER TRACKING
-----------------------------------------------------------

function Database.GetAllContainers()
    return MySQL.query.await([[
        SELECT * FROM maritime_containers
    ]])
end

function Database.SaveContainer(x, y, z, heading, placedBy)
    return MySQL.insert.await([[
        INSERT INTO maritime_containers (x, y, z, heading, placed_by)
        VALUES (?, ?, ?, ?, ?)
    ]], { x, y, z, heading, placedBy })
end

function Database.DeleteContainer(id)
    MySQL.update.await([[
        DELETE FROM maritime_containers WHERE id = ?
    ]], { id })
end

function Database.ClearAllContainers()
    MySQL.update.await([[
        DELETE FROM maritime_containers
    ]])
end

function Database.GetContainerCount()
    local result = MySQL.single.await([[
        SELECT COUNT(*) as count FROM maritime_containers
    ]])
    return result and result.count or 0
end

-----------------------------------------------------------
-- LEADERBOARD
-----------------------------------------------------------

function Database.GetLeaderboard(limit)
    limit = limit or 10
    return MySQL.query.await([[
        SELECT identifier, level, xp, boat_deliveries, dock_deliveries, total_earnings
        FROM maritime_players
        ORDER BY xp DESC
        LIMIT ?
    ]], { limit })
end

-----------------------------------------------------------
-- EXPORT
-----------------------------------------------------------

exports('GetDatabase', function()
    return Database
end)

return Database
