--[[
    dps-maritime - Jetsam Company
    Server-Side Security & Validation

    Prevents exploitation by validating client claims on the server:
    - Distance validation (don't trust client-reported distance)
    - Position validation (verify player is at destination)
    - Rate limiting (prevent spam exploits)
    - Suspicious activity detection
]]

local Security = {}

-----------------------------------------------------------
-- CONFIGURATION
-----------------------------------------------------------

local VALIDATION_CONFIG = {
    -- Distance validation
    MaxDistanceDeviation = 0.25,      -- Allow 25% deviation from server calculation
    MinDeliveryDistance = 100,        -- Minimum valid distance (meters)
    MaxDeliveryDistance = 15000,      -- Maximum valid distance (meters)

    -- Position validation
    DestinationRadius = 150.0,        -- Must be within 150m of destination
    StartPositionRadius = 200.0,      -- Must start within 200m of start port

    -- Rate limiting
    MinTimeBetweenJobs = 30,          -- Minimum 30 seconds between job completions
    MaxJobsPerHour = 30,              -- Maximum jobs per hour per player

    -- Suspicious activity thresholds
    SpeedThreshold = 200.0,           -- Flag if average speed > 200 m/s (impossible for boats)
    MinJobDuration = 15,              -- Minimum job duration in seconds

    -- Logging
    LogSuspiciousActivity = true,
    BanOnConfirmedExploit = false,    -- Set true to auto-ban confirmed exploiters
}

-----------------------------------------------------------
-- PLAYER TRACKING
-----------------------------------------------------------

-- Track job start data for validation
local JobStartData = {}  -- [source] = { startCoords, startTime, startPort, endPort }

-- Track completion times for rate limiting
local CompletionHistory = {} -- [identifier] = { timestamps }

-- Suspicious activity log
local SuspiciousPlayers = {} -- [identifier] = { count, lastIncident }

-----------------------------------------------------------
-- UTILITY FUNCTIONS
-----------------------------------------------------------

-- Get player's current position from the server
local function GetPlayerPosition(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- Calculate distance between two vector3 positions
local function CalculateDistance(pos1, pos2)
    if not pos1 or not pos2 then return 0 end
    return #(vector3(pos1.x, pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
end

-- Get port coordinates
local function GetPortCoords(portId)
    local port = Config.Ports[portId]
    if not port then return nil end

    -- Use boat spawn as reference point
    if port.boatSpawn then
        return vector3(port.boatSpawn.x, port.boatSpawn.y, port.boatSpawn.z)
    elseif port.coords then
        return vector3(port.coords.x, port.coords.y, port.coords.z)
    end

    return nil
end

-- Log suspicious activity
local function LogSuspicious(source, reason, details)
    if not VALIDATION_CONFIG.LogSuspiciousActivity then return end

    local identifier = Bridge.GetIdentifier(source)
    local playerName = GetPlayerName(source) or 'Unknown'

    print(string.format(
        '^1[SECURITY]^7 Suspicious activity from %s (%s): %s - %s',
        playerName,
        identifier or 'no-id',
        reason,
        json.encode(details)
    ))

    -- Track suspicious activity count
    if identifier then
        SuspiciousPlayers[identifier] = SuspiciousPlayers[identifier] or { count = 0, lastIncident = 0 }
        SuspiciousPlayers[identifier].count = SuspiciousPlayers[identifier].count + 1
        SuspiciousPlayers[identifier].lastIncident = os.time()
    end
end

-----------------------------------------------------------
-- JOB START TRACKING
-----------------------------------------------------------

-- Call this when a job starts to record starting data
function Security.OnJobStart(source, startPort, endPort, jobType)
    local coords = GetPlayerPosition(source)
    local startPortCoords = GetPortCoords(startPort)

    -- Validate player is near start port. This used to log and allow, which meant
    -- a player could stand AT the destination, declare a distant start port, wait
    -- out the minimum job duration and collect full port-to-port pay without
    -- moving. Record the real starting position so completion pays for the
    -- distance actually travelled, and flag the attempt.
    local startedAwayFromPort = false
    if coords and startPortCoords then
        local distToStart = CalculateDistance(coords, startPortCoords)
        if distToStart > VALIDATION_CONFIG.StartPositionRadius then
            startedAwayFromPort = true
            LogSuspicious(source, 'Started job far from port', {
                distance = distToStart,
                expected = VALIDATION_CONFIG.StartPositionRadius,
                port = startPort,
            })
        end
    end

    JobStartData[source] = {
        startedAwayFromPort = startedAwayFromPort,
        startCoords = coords,
        -- when the player did not actually start at the port, treat their real
        -- position as the origin so pay reflects the distance they truly cover
        startPortCoords = startedAwayFromPort and coords or startPortCoords,
        declaredStartPortCoords = startPortCoords,
        endPortCoords = GetPortCoords(endPort),
        startTime = os.time(),
        startPort = startPort,
        endPort = endPort,
        jobType = jobType,
    }

    Maritime.Debug('Security: Job started for source ' .. source)
end

-- Call this when a job is cancelled
function Security.OnJobCancel(source)
    JobStartData[source] = nil
end

-----------------------------------------------------------
-- JOB COMPLETION VALIDATION
-----------------------------------------------------------

---Validate a job completion and return validated distance
---@param source number Player source
---@param clientDistance number Distance reported by client
---@param clientData table Any additional data from client
---@return boolean valid Whether the completion is valid
---@return number distance Server-validated distance
---@return string|nil error Error message if invalid
function Security.ValidateJobCompletion(source, clientDistance, clientData)
    local startData = JobStartData[source]

    -- Check if we have start data
    if not startData then
        LogSuspicious(source, 'Completion without start data', { clientDistance = clientDistance })
        return false, 0, 'No active job found'
    end

    local currentCoords = GetPlayerPosition(source)
    local now = os.time()
    local duration = now - startData.startTime

    -- Check minimum job duration
    if duration < VALIDATION_CONFIG.MinJobDuration then
        LogSuspicious(source, 'Job completed too fast', {
            duration = duration,
            minimum = VALIDATION_CONFIG.MinJobDuration,
        })
        return false, 0, 'Job completed suspiciously fast'
    end

    -- Validate player is near destination
    if currentCoords and startData.endPortCoords then
        local distToEnd = CalculateDistance(currentCoords, startData.endPortCoords)

        if distToEnd > VALIDATION_CONFIG.DestinationRadius then
            LogSuspicious(source, 'Not at destination', {
                distance = distToEnd,
                maxAllowed = VALIDATION_CONFIG.DestinationRadius,
                endPort = startData.endPort,
            })
            return false, 0, 'You must be at the delivery destination'
        end
    end

    -- Calculate server-side distance
    local serverDistance = 0
    if startData.startPortCoords and startData.endPortCoords then
        serverDistance = CalculateDistance(startData.startPortCoords, startData.endPortCoords)
    elseif startData.startCoords and currentCoords then
        serverDistance = CalculateDistance(startData.startCoords, currentCoords)
    end

    -- Validate distance range
    if serverDistance < VALIDATION_CONFIG.MinDeliveryDistance then
        LogSuspicious(source, 'Distance too short', {
            serverDistance = serverDistance,
            minimum = VALIDATION_CONFIG.MinDeliveryDistance,
        })
        return false, 0, 'Delivery distance too short'
    end

    if serverDistance > VALIDATION_CONFIG.MaxDeliveryDistance then
        LogSuspicious(source, 'Distance too long', {
            serverDistance = serverDistance,
            maximum = VALIDATION_CONFIG.MaxDeliveryDistance,
        })
        -- Cap at max but allow
        serverDistance = VALIDATION_CONFIG.MaxDeliveryDistance
    end

    -- Check for speed hacking (if distance is way more than possible)
    local maxPossibleDistance = duration * VALIDATION_CONFIG.SpeedThreshold
    if serverDistance > maxPossibleDistance then
        LogSuspicious(source, 'Impossible travel speed', {
            distance = serverDistance,
            duration = duration,
            avgSpeed = serverDistance / duration,
            maxSpeed = VALIDATION_CONFIG.SpeedThreshold,
        })
        -- Use the max possible as the validated distance
        serverDistance = maxPossibleDistance
    end

    -- Check client distance deviation
    if clientDistance > 0 then
        local deviation = math.abs(clientDistance - serverDistance) / serverDistance
        if deviation > VALIDATION_CONFIG.MaxDistanceDeviation then
            LogSuspicious(source, 'Distance mismatch', {
                clientDistance = clientDistance,
                serverDistance = serverDistance,
                deviation = string.format('%.1f%%', deviation * 100),
            })
            -- Use server distance (more conservative)
        end
    end

    -- Rate limiting check
    local identifier = Bridge.GetIdentifier(source)
    if identifier then
        local history = CompletionHistory[identifier] or {}

        -- Clean old entries (older than 1 hour)
        local cutoff = now - 3600
        local recentCount = 0
        for i = #history, 1, -1 do
            if history[i] < cutoff then
                table.remove(history, i)
            else
                recentCount = recentCount + 1
            end
        end

        -- Check if rate limited
        if recentCount >= VALIDATION_CONFIG.MaxJobsPerHour then
            LogSuspicious(source, 'Rate limit exceeded', {
                jobsInHour = recentCount,
                limit = VALIDATION_CONFIG.MaxJobsPerHour,
            })
            return false, 0, 'Too many deliveries. Please wait before starting another.'
        end

        -- Check minimum time between jobs
        if #history > 0 and (now - history[#history]) < VALIDATION_CONFIG.MinTimeBetweenJobs then
            LogSuspicious(source, 'Jobs too frequent', {
                timeSinceLast = now - history[#history],
                minimum = VALIDATION_CONFIG.MinTimeBetweenJobs,
            })
            return false, 0, 'Please wait before starting another delivery'
        end

        -- Record this completion
        table.insert(history, now)
        CompletionHistory[identifier] = history
    end

    -- Clear start data
    JobStartData[source] = nil

    -- Return validated distance (use server calculation)
    return true, serverDistance, nil
end

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('SecurityOnJobStart', function(source, startPort, endPort, jobType)
    Security.OnJobStart(source, startPort, endPort, jobType)
end)

exports('SecurityOnJobCancel', function(source)
    Security.OnJobCancel(source)
end)

exports('SecurityValidateCompletion', function(source, clientDistance, clientData)
    return Security.ValidateJobCompletion(source, clientDistance, clientData)
end)

exports('GetSuspiciousPlayers', function()
    return SuspiciousPlayers
end)

-----------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------

AddEventHandler('playerDropped', function()
    local source = source
    JobStartData[source] = nil
end)

-----------------------------------------------------------
-- ADMIN COMMANDS
-----------------------------------------------------------

Bridge.RegisterCommand('maritimesecurity', 'View security stats (Admin)', {}, false, function(source)
    local suspiciousCount = 0
    for _ in pairs(SuspiciousPlayers) do
        suspiciousCount = suspiciousCount + 1
    end

    Bridge.Notify(source, 'Maritime Security', string.format(
        'Active jobs: %d\nSuspicious players: %d',
        Maritime.TableLength(JobStartData),
        suspiciousCount
    ), 'inform', 10000)
end, 'admin')

-- Return the Security table for use in other files
return Security
