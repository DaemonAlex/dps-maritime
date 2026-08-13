--[[
    dps-maritime - Jetsam Company
    Vehicle Key Integration (qs-vehiclekeys)
    Uses Bridge for framework abstraction

    Provides temporary key handover for company-owned delivery boats.
    Keys are automatically granted when a job starts and revoked when it ends.
]]

-----------------------------------------------------------
-- KEY SYSTEM STATE
-----------------------------------------------------------

-- Track active job keys: [source] = { plate, model, grantedAt, jobType }
local ActiveJobKeys = {}

-- Company fleet plates (boats that Jetsam "owns")
local CompanyFleet = {}

-----------------------------------------------------------
-- KEY SCRIPT DETECTION
-----------------------------------------------------------

local KeyScript = nil

local function DetectKeyScript()
    if KeyScript then return KeyScript end

    local scripts = {
        'qs-vehiclekeys',
        'qb-vehiclekeys',
        'wasabi_carlock',
        'vehicles_keys',
        'cd_garage', -- Some use this for keys
    }

    for _, script in ipairs(scripts) do
        if GetResourceState(script) == 'started' then
            KeyScript = script
            Maritime.Debug('KeyBridge: Detected ' .. script)
            return script
        end
    end

    Maritime.Debug('KeyBridge: No key script detected')
    return nil
end

local function IsKeySystemEnabled()
    if not Config.VehicleKeys or not Config.VehicleKeys.Enabled then
        return false
    end
    return DetectKeyScript() ~= nil
end

-----------------------------------------------------------
-- KEY OPERATIONS
-----------------------------------------------------------

-- Grant keys to a player for a specific vehicle
---@param source number Player server ID
---@param plate string Vehicle plate
---@param model string Vehicle model name
---@return boolean success
local function GiveKeys(source, plate, model)
    local script = DetectKeyScript()
    if not script then return false end

    Maritime.Debug('KeyBridge: Giving keys to ' .. source .. ' for plate ' .. plate)

    if script == 'qs-vehiclekeys' then
        exports['qs-vehiclekeys']:GiveKeysServer(source, plate, model)
        return true

    elseif script == 'qb-vehiclekeys' then
        TriggerClientEvent('qb-vehiclekeys:client:GiveKeys', source, plate)
        return true

    elseif script == 'wasabi_carlock' then
        exports['wasabi_carlock']:GiveKey(source, plate)
        return true

    elseif script == 'vehicles_keys' then
        exports['vehicles_keys']:giveKeys(source, plate)
        return true
    end

    return false
end

-- Remove keys from a player for a specific vehicle
---@param source number Player server ID
---@param plate string Vehicle plate
---@param model string Vehicle model name
---@return boolean success
local function RemoveKeys(source, plate, model)
    local script = DetectKeyScript()
    if not script then return false end

    Maritime.Debug('KeyBridge: Removing keys from ' .. source .. ' for plate ' .. plate)

    if script == 'qs-vehiclekeys' then
        exports['qs-vehiclekeys']:RemoveKeysServer(source, plate, model)
        return true

    elseif script == 'qb-vehiclekeys' then
        TriggerClientEvent('qb-vehiclekeys:client:RemoveKeys', source, plate)
        return true

    elseif script == 'wasabi_carlock' then
        exports['wasabi_carlock']:RemoveKey(source, plate)
        return true

    elseif script == 'vehicles_keys' then
        exports['vehicles_keys']:removeKeys(source, plate)
        return true
    end

    return false
end

-- Check if player has keys for a vehicle
---@param source number Player server ID
---@param plate string Vehicle plate
---@return boolean hasKeys
local function HasKeys(source, plate)
    local script = DetectKeyScript()
    if not script then return true end -- No key script = always has access

    if script == 'qs-vehiclekeys' then
        return exports['qs-vehiclekeys']:GetKeyServer(source, plate) or false

    elseif script == 'qb-vehiclekeys' then
        -- QB-Vehiclekeys doesn't have a clean server export for this
        return true
    end

    return true
end

-----------------------------------------------------------
-- JOB KEY MANAGEMENT
-----------------------------------------------------------

-- Grant temporary keys for a job boat
---@param source number Player server ID
---@param plate string Vehicle plate
---@param model string Vehicle model
---@param jobType string 'boat' or 'dock'
---@return boolean success
function GrantJobKeys(source, plate, model, jobType)
    if not IsKeySystemEnabled() then
        return true -- No key system = always allow
    end

    if not plate or plate == '' then
        return false
    end

    -- Grant the keys
    local success = GiveKeys(source, plate, model)

    if success then
        -- Track this key grant
        ActiveJobKeys[source] = {
            plate = plate,
            model = model,
            grantedAt = os.time(),
            jobType = jobType or 'boat',
        }

        -- Notify player
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Keys Received',
            description = 'You have been given keys for the company vessel',
            type = 'success',
            icon = 'key',
        })

        Maritime.Debug('KeyBridge: Granted job keys to ' .. source .. ' for ' .. plate)
    end

    return success
end

-- Revoke temporary keys when job ends
---@param source number Player server ID
---@param reason string|nil Reason for revocation
---@return boolean success
function RevokeJobKeys(source, reason)
    if not IsKeySystemEnabled() then
        return true
    end

    local keyData = ActiveJobKeys[source]
    if not keyData then
        return false
    end

    -- Remove the keys
    local success = RemoveKeys(source, keyData.plate, keyData.model)

    -- Release the company-boat registration if this player owned it (H1 cleanup)
    if keyData.plate then
        local company = CompanyFleet[keyData.plate]
        if company and company.source == source then
            UnregisterCompanyBoat(keyData.plate)
        end
    end

    if success then
        -- Clear tracking
        ActiveJobKeys[source] = nil

        -- Notify player
        local desc = reason or 'Your temporary vessel keys have been returned'
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Keys Returned',
            description = desc,
            type = 'inform',
            icon = 'key',
        })

        Maritime.Debug('KeyBridge: Revoked job keys from ' .. source)
    end

    return success
end

-- Get active job key data for a player
---@param source number Player server ID
---@return table|nil keyData
function GetActiveJobKeys(source)
    return ActiveJobKeys[source]
end

-- Check if player has active job keys
---@param source number Player server ID
---@return boolean hasJobKeys
function HasActiveJobKeys(source)
    return ActiveJobKeys[source] ~= nil
end

-----------------------------------------------------------
-- DOCK MANAGER KEY HANDOVER (for RP)
-----------------------------------------------------------

-- Allow a dock manager to manually give keys to another player
---@param managerSource number Manager's server ID
---@param targetSource number Target player's server ID
---@param plate string Vehicle plate
---@param model string Vehicle model
---@param duration number|nil Duration in minutes (nil = until job ends)
---@return boolean success
function ManagerKeyHandover(managerSource, targetSource, plate, model, duration)
    if not IsKeySystemEnabled() then
        return false
    end

    -- M3: Manager/Target were undefined globals. Resolve real player objects.
    local Manager = Bridge.GetPlayer(managerSource)
    local Target = Bridge.GetPlayer(targetSource)
    if not Manager or not Target then
        return false
    end

    -- Only company (Jetsam) boats may be handed over - same plate gate as H1.
    if not IsCompanyPlateFormat(plate) then
        Bridge.Notify(managerSource, 'Invalid Vessel', 'You can only hand over keys for company vessels', 'error')
        return false
    end

    -- Check if manager has permission (high level maritime worker or admin)
    local managerLevel = exports['dps-maritime']:GetPlayerMaritimeLevel(managerSource)
    local requiredLevel = Config.VehicleKeys and Config.VehicleKeys.ManagerKeyLevel or 8

    if managerLevel < requiredLevel and not IsPlayerAceAllowed(managerSource, 'command') then
        Bridge.Notify(managerSource, 'No Permission', 'You need to be level ' .. requiredLevel .. ' to hand over keys', 'error')
        return false
    end

    -- Grant keys to target
    local success = GiveKeys(targetSource, plate, model)

    if success then
        -- Track with expiration if duration specified
        ActiveJobKeys[targetSource] = {
            plate = plate,
            model = model,
            grantedAt = os.time(),
            grantedBy = Manager.PlayerData and Manager.PlayerData.citizenid,
            jobType = 'handover',
            expiresAt = duration and (os.time() + (duration * 60)) or nil,
        }

        -- Notify both parties
        TriggerClientEvent('ox_lib:notify', targetSource, {
            title = 'Keys Received',
            description = 'You have been given temporary vessel keys by a dock manager',
            type = 'success',
            icon = 'key',
        })

        local targetFirstName = (Target.PlayerData and Target.PlayerData.charinfo and Target.PlayerData.charinfo.firstname) or 'the player'
        TriggerClientEvent('ox_lib:notify', managerSource, {
            title = 'Keys Handed Over',
            description = 'Vessel keys transferred to ' .. targetFirstName,
            type = 'success',
            icon = 'key',
        })

        Maritime.Debug('KeyBridge: Manager ' .. managerSource .. ' handed keys to ' .. targetSource)
    end

    return success
end

-----------------------------------------------------------
-- CLEANUP HANDLERS
-----------------------------------------------------------

-- Cleanup on player disconnect
AddEventHandler('playerDropped', function(reason)
    local source = source

    if ActiveJobKeys[source] then
        Maritime.Debug('KeyBridge: Player ' .. source .. ' disconnected with active job keys')
        -- Release any company-boat registration tied to this player (H1 cleanup)
        local keyData = ActiveJobKeys[source]
        if keyData.plate then
            local company = CompanyFleet[keyData.plate]
            if company and company.source == source then
                UnregisterCompanyBoat(keyData.plate)
            end
        end
        -- Keys are automatically invalid when player leaves, just clear tracking
        ActiveJobKeys[source] = nil
    end
end)

-- Periodic check for expired handover keys
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute

        local now = os.time()
        for source, keyData in pairs(ActiveJobKeys) do
            if keyData.expiresAt and now >= keyData.expiresAt then
                -- Key has expired
                RevokeJobKeys(source, 'Your temporary key access has expired')
            end
        end
    end
end)

-----------------------------------------------------------
-- INTEGRATION WITH BOAT JOBS
-----------------------------------------------------------

-- Hook into boat job start to grant keys.
-- H1: NEVER trust a raw client-supplied plate. Owned boats derive their plate
-- from the server's own fleet record (with an ownership check); company (job)
-- boats must carry a reserved Jetsam plate prefix and are registered/validated
-- server-side before any key is granted. This closes the "key ANY plate on the
-- server" exploit.
RegisterNetEvent('dps-maritime:server:startBoatJob', function(data)
    local source = source
    if type(data) ~= 'table' then return end

    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end

    if data.ownedBoatId then
        -- Owned boat: derive the plate from the server-side fleet record and
        -- confirm the requester actually owns it. Owned boats belong to the
        -- player already, so no temporary key handover is needed here.
        local Database = exports['dps-maritime']:GetDatabase()
        local boat = Database and Database.GetBoatById(data.ownedBoatId)
        if not boat or boat.owner ~= identifier then
            Maritime.Debug('KeyBridge: refused owned-boat key - ownership mismatch for ' .. source)
        end
        return
    end

    -- Company (job) boat path: validate the plate is a real Jetsam company plate.
    local plate = data.plate
    if not IsCompanyPlateFormat(plate) then
        Maritime.Debug('KeyBridge: refused key grant - non-company plate from ' .. source)
        return
    end

    -- Prevent hijacking another player's active company boat keys.
    local existing = CompanyFleet[plate]
    if existing and existing.source and existing.source ~= source then
        Maritime.Debug('KeyBridge: refused key grant - plate already active for another player')
        return
    end

    -- Register as company property (tracked to this player) and grant temp keys.
    RegisterCompanyBoat(plate, data.boatModel, source)
    GrantJobKeys(source, plate, data.boatModel, 'boat')
end)

-- Hook into job completion to revoke keys
RegisterNetEvent('dps-maritime:server:completeBoatJob', function(data)
    local source = source

    if HasActiveJobKeys(source) then
        RevokeJobKeys(source, 'Delivery complete - keys returned to Jetsam')
    end
end)

-- Hook into job cancellation to revoke keys
RegisterNetEvent('dps-maritime:server:cancelBoatJob', function()
    local source = source

    if HasActiveJobKeys(source) then
        RevokeJobKeys(source, 'Job cancelled - keys returned to Jetsam')
    end
end)

-----------------------------------------------------------
-- COMPANY FLEET MANAGEMENT
-----------------------------------------------------------

-- Register a boat as company property
---@param plate string Vehicle plate
---@param model string Vehicle model
---@param src number|nil Server ID of the player currently using this company boat
function RegisterCompanyBoat(plate, model, src)
    CompanyFleet[plate] = {
        model = model,
        source = src,
        registeredAt = os.time(),
    }
    Maritime.Debug('KeyBridge: Registered company boat ' .. plate)
end

-- Unregister a company boat (called when a job ends / player disconnects)
---@param plate string Vehicle plate
function UnregisterCompanyBoat(plate)
    if plate then
        CompanyFleet[plate] = nil
    end
end

-- Check if a plate belongs to company fleet
---@param plate string Vehicle plate
---@return boolean isCompany
function IsCompanyBoat(plate)
    return CompanyFleet[plate] ~= nil
end

-- Validate that a plate LOOKS like a Jetsam company plate (prefix match). This
-- is the server-side gate that prevents a client from requesting keys for an
-- arbitrary vehicle plate (H1) - real player vehicles do not carry the reserved
-- Jetsam prefixes.
---@param plate string Vehicle plate
---@return boolean isCompanyFormat
function IsCompanyPlateFormat(plate)
    if not plate or plate == '' then return false end
    local prefixes = Config.VehicleKeys and Config.VehicleKeys.CompanyPlatePrefixes or {}
    local normalized = (plate:gsub('%s+', '')):upper()
    for _, prefix in ipairs(prefixes) do
        prefix = prefix:upper()
        if normalized:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

-- Get all company fleet plates
---@return table fleet
function GetCompanyFleet()
    return CompanyFleet
end

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('GrantJobKeys', GrantJobKeys)
exports('RevokeJobKeys', RevokeJobKeys)
exports('HasActiveJobKeys', HasActiveJobKeys)
exports('GetActiveJobKeys', GetActiveJobKeys)
exports('ManagerKeyHandover', ManagerKeyHandover)
exports('IsKeySystemEnabled', IsKeySystemEnabled)
exports('RegisterCompanyBoat', RegisterCompanyBoat)
exports('IsCompanyBoat', IsCompanyBoat)

-----------------------------------------------------------
-- CALLBACKS
-----------------------------------------------------------

-- Manager key handover via menu
lib.callback.register('dps-maritime:server:requestKeyHandover', function(source, targetId, plate, model, duration)
    return ManagerKeyHandover(source, targetId, plate, model, duration)
end)

-- Check key status
lib.callback.register('dps-maritime:server:checkKeyStatus', function(source, plate)
    return {
        hasKeys = HasKeys(source, plate),
        hasJobKeys = HasActiveJobKeys(source),
        keyData = GetActiveJobKeys(source),
    }
end)

-----------------------------------------------------------
-- INITIALIZATION
-----------------------------------------------------------

CreateThread(function()
    Wait(2000)
    local script = DetectKeyScript()
    if script then
        print('^2[dps-maritime] Key integration: hooked into ' .. script .. '^0')
    else
        print('^3[dps-maritime] Key integration: no key script detected (keys disabled)^0')
    end
end)
