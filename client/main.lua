--[[
    dps-maritime - Jetsam Company
    Main Client Script

    Uses Bridge for framework abstraction (QB/ESX)
    Waits for player loaded event to prevent race conditions
]]

-- Player state
local PlayerData = nil
local IsOnDuty = false
local CurrentJob = nil -- 'dock' or 'boat'
local PlayerLoaded = false -- Track if player is fully loaded

-----------------------------------------------------------
-- INITIALIZATION
-- Wait for player to be fully loaded by multicharacter
-----------------------------------------------------------

local function InitializePlayer()
    if PlayerLoaded then return end

    -- Double-check player is actually loaded via Bridge
    if not Bridge.IsPlayerLoaded() then
        return
    end

    PlayerLoaded = true

    -- Now safe to fetch maritime data
    PlayerData = lib.callback.await('dps-maritime:server:getPlayerData', false)

    if PlayerData then
        Maritime.Debug('Player maritime data loaded: Level ' .. (PlayerData.level or 1))
    end
end

-- Primary load event - uses Bridge for framework abstraction
Bridge.OnPlayerLoaded(function()
    -- Small delay to ensure all framework data is synced
    SetTimeout(500, function()
        InitializePlayer()
    end)
end)

-- Handle resource restart while player is already loaded
CreateThread(function()
    -- Wait for resource to fully initialize
    Wait(2000)

    -- Check if player is already loaded (resource restart scenario)
    if Bridge.IsPlayerLoaded() then
        InitializePlayer()
    end
end)

-- Clean up on logout/character switch
Bridge.OnPlayerUnload(function()
    PlayerData = nil
    IsOnDuty = false
    CurrentJob = nil
    PlayerLoaded = false
end)

-- Also listen for qs-multicharacter specific events if they exist
RegisterNetEvent('qs-multicharacter:client:characterSelected', function()
    -- Character was just selected, OnPlayerLoaded should follow
    -- But add a fallback just in case
    SetTimeout(1500, function()
        if not PlayerLoaded then
            InitializePlayer()
        end
    end)
end)

-----------------------------------------------------------
-- NPC SETUP
-----------------------------------------------------------

CreateThread(function()
    -- Load NPC model
    local model = lib.requestModel(Config.NPC.Model, 5000)
    if not model then return end

    -- Create NPC
    local npc = CreatePed(4, model, Config.NPC.Location.x, Config.NPC.Location.y, Config.NPC.Location.z - 1.0, Config.NPC.Location.w, false, true)
    SetEntityHeading(npc, Config.NPC.Location.w)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)

    if Config.NPC.Scenario then
        TaskStartScenarioInPlace(npc, Config.NPC.Scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)

    -- Create target
    exports.ox_target:addLocalEntity(npc, {
        {
            name = 'maritime_npc',
            icon = 'fa-solid fa-anchor',
            label = 'Talk to ' .. Config.BusinessLabel,
            onSelect = function()
                OpenMainMenu()
            end,
        }
    })

    -- Create blip
    local blip = AddBlipForCoord(Config.NPC.Location.x, Config.NPC.Location.y, Config.NPC.Location.z)
    SetBlipSprite(blip, Config.Blips.Job.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.Blips.Job.scale)
    SetBlipColour(blip, Config.Blips.Job.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextEntry('maritime_blip', Config.Blips.Job.label)
    EndTextCommandSetBlipName(blip)
end)

-----------------------------------------------------------
-- MAIN MENU
-----------------------------------------------------------

function OpenMainMenu()
    -- Ensure player is fully loaded before opening menu
    if not PlayerLoaded then
        lib.notify({
            title = 'Please Wait',
            description = 'Loading your maritime data...',
            type = 'info',
        })

        -- Try to initialize
        InitializePlayer()

        if not PlayerLoaded then
            lib.notify({
                title = 'Not Ready',
                description = 'Please wait for your character to fully load',
                type = 'error',
            })
            return
        end
    end

    if not PlayerData then
        PlayerData = lib.callback.await('dps-maritime:server:getPlayerData', false)
    end

    if not PlayerData then
        lib.notify({
            title = 'Error',
            description = 'Failed to load maritime data. Try again.',
            type = 'error',
        })
        return
    end

    local levelData = Config.GetLevelData(PlayerData.level)
    local canDockWork = Config.CanDoDockWork(PlayerData.level)
    local canBoatDelivery = Config.CanDoBoatDelivery(PlayerData.level)
    local canOwnFleet = Config.CanOwnFleet(PlayerData.level)

    local options = {
        {
            title = 'Your Profile',
            description = string.format('Level %d - %s\nXP: %d | Next: %d XP',
                PlayerData.level,
                levelData.title,
                PlayerData.xp,
                Maritime.GetXPToNextLevel(PlayerData.xp, PlayerData.level)
            ),
            icon = 'user',
            arrow = true,
            onSelect = function()
                OpenProfileMenu()
            end,
        },
    }

    -- Dock Work Option
    if canDockWork then
        table.insert(options, {
            title = 'Dock Work',
            description = 'Container hauling with truck and handler',
            icon = 'box',
            arrow = true,
            onSelect = function()
                OpenDockWorkMenu()
            end,
        })
    else
        table.insert(options, {
            title = 'Dock Work (Locked)',
            description = 'Reach level ' .. Config.Progression.DockWorkMinLevel .. ' to unlock',
            icon = 'lock',
            disabled = true,
        })
    end

    -- Boat Delivery Option
    if canBoatDelivery then
        table.insert(options, {
            title = 'Boat Deliveries',
            description = 'Maritime cargo transport',
            icon = 'ship',
            arrow = true,
            onSelect = function()
                OpenBoatDeliveryMenu()
            end,
        })
    else
        table.insert(options, {
            title = 'Boat Deliveries (Locked)',
            description = 'Reach level ' .. Config.Progression.BoatDeliveryMinLevel .. ' to unlock',
            icon = 'lock',
            disabled = true,
        })
    end

    -- Fleet Management Option
    if canOwnFleet then
        table.insert(options, {
            title = 'My Fleet',
            description = 'Manage your owned vessels',
            icon = 'anchor',
            arrow = true,
            onSelect = function()
                OpenFleetMenu()
            end,
        })
    else
        table.insert(options, {
            title = 'Fleet Ownership (Locked)',
            description = 'Reach level ' .. Config.Progression.FleetOwnershipMinLevel .. ' to own boats',
            icon = 'lock',
            disabled = true,
        })
    end

    -- VIP Leisure Transport Option
    local canVIPTransport = Config.VIPTransport and Config.VIPTransport.Enabled and PlayerData.level >= Config.VIPTransport.MinLevel
    if canVIPTransport then
        table.insert(options, {
            title = 'VIP Transport',
            description = 'High-paying passenger transport to leisure destinations',
            icon = 'user-tie',
            arrow = true,
            onSelect = function()
                OpenVIPTransportMenu()
            end,
        })
    elseif Config.VIPTransport and Config.VIPTransport.Enabled then
        table.insert(options, {
            title = 'VIP Transport (Locked)',
            description = 'Reach level ' .. Config.VIPTransport.MinLevel .. ' to unlock',
            icon = 'lock',
            disabled = true,
        })
    end

    -- Boat Shop
    table.insert(options, {
        title = 'Boat Shop',
        description = 'Browse available vessels',
        icon = 'store',
        arrow = true,
        onSelect = function()
            OpenBoatShopMenu()
        end,
    })

    lib.registerContext({
        id = 'maritime_main_menu',
        title = Config.BusinessLabel,
        options = options,
    })

    lib.showContext('maritime_main_menu')
end

-----------------------------------------------------------
-- PROFILE MENU
-----------------------------------------------------------

function OpenProfileMenu()
    local levelData = Config.GetLevelData(PlayerData.level)
    local progress = Maritime.GetLevelProgress(PlayerData.xp, PlayerData.level)

    local options = {
        {
            title = 'Level ' .. PlayerData.level .. ' - ' .. levelData.title,
            description = string.format('XP: %d | Progress: %d%%', PlayerData.xp, progress),
            icon = 'star',
            progress = progress,
        },
        {
            title = 'Pay Multiplier',
            description = string.format('%.0f%% base pay', levelData.payMultiplier * 100),
            icon = 'dollar-sign',
        },
        {
            title = 'Boat Deliveries',
            description = tostring(PlayerData.boat_deliveries or 0),
            icon = 'ship',
        },
        {
            title = 'Dock Deliveries',
            description = tostring(PlayerData.dock_deliveries or 0),
            icon = 'box',
        },
        {
            title = 'Total Earnings',
            description = Maritime.FormatMoney(PlayerData.total_earnings or 0),
            icon = 'coins',
        },
        {
            title = 'Current Streak',
            description = tostring(PlayerData.current_streak or 0) .. ' deliveries',
            icon = 'fire',
        },
    }

    lib.registerContext({
        id = 'maritime_profile_menu',
        title = 'Your Maritime Profile',
        menu = 'maritime_main_menu',
        options = options,
    })

    lib.showContext('maritime_profile_menu')
end

-----------------------------------------------------------
-- BOAT SHOP MENU
-----------------------------------------------------------

function OpenBoatShopMenu()
    local options = {}
    local canOwnFleet = Config.CanOwnFleet(PlayerData.level)

    for model, boat in pairs(Config.Boats) do
        local locked = PlayerData.level < boat.levelRequired
        local tierLabel = 'Tier ' .. boat.tier

        table.insert(options, {
            title = boat.label,
            description = string.format('%s | %s | Level %d Required',
                Maritime.FormatMoney(boat.price),
                tierLabel,
                boat.levelRequired
            ),
            icon = locked and 'lock' or 'ship',
            disabled = locked or not canOwnFleet,
            metadata = {
                { label = 'Speed', value = boat.speed },
                { label = 'Cargo Capacity', value = boat.cargoCapacity },
                { label = 'Fuel Capacity', value = boat.fuelCapacity .. 'L' },
                { label = 'Hazmat Rated', value = boat.hazmatRated and 'Yes' or 'No' },
            },
            onSelect = function()
                PurchaseBoatPrompt(model, boat)
            end,
        })
    end

    -- Sort by level requirement
    table.sort(options, function(a, b)
        return (a.metadata and a.metadata[1] and a.metadata[1].value or 0) < (b.metadata and b.metadata[1] and b.metadata[1].value or 0)
    end)

    lib.registerContext({
        id = 'maritime_boat_shop',
        title = 'Boat Shop',
        menu = 'maritime_main_menu',
        options = options,
    })

    lib.showContext('maritime_boat_shop')
end

function PurchaseBoatPrompt(model, boat)
    local input = lib.inputDialog('Purchase ' .. boat.label, {
        { type = 'input', label = 'Boat Name', placeholder = boat.label, max = 30 },
    })

    if not input then return end

    local boatName = input[1] or boat.label

    local result = lib.callback.await('dps-maritime:server:purchaseBoat', false, model, boatName)

    if result.error then
        lib.notify({ description = result.error, type = 'error' })
    end
end

-----------------------------------------------------------
-- XP UPDATE
-----------------------------------------------------------

RegisterNetEvent('dps-maritime:client:updateXP', function(data)
    PlayerData.xp = data.xp
    PlayerData.level = data.level

    if data.xpGained then
        lib.notify({
            title = 'XP Gained',
            description = '+' .. data.xpGained .. ' XP',
            type = 'success',
            duration = 3000,
        })
    end
end)

RegisterNetEvent('dps-maritime:client:levelUp', function(data)
    PlayerData.level = data.level

    lib.notify({
        title = 'Level Up!',
        description = 'You are now Level ' .. data.level .. ' - ' .. data.title,
        type = 'success',
        duration = 8000,
    })

    -- Play sound
    PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', false)
end)

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('GetPlayerMaritimeData', function()
    return PlayerData
end)

exports('GetPlayerLevel', function()
    return PlayerData and PlayerData.level or 1
end)

exports('IsOnDuty', function()
    return IsOnDuty
end)

exports('GetCurrentJob', function()
    return CurrentJob
end)

function SetOnDuty(duty, jobType)
    IsOnDuty = duty
    CurrentJob = jobType
end

exports('SetOnDuty', SetOnDuty)

-----------------------------------------------------------
-- MANIFEST SYSTEM EVENTS
-----------------------------------------------------------

-- Play sound when manifest is printed/received
RegisterNetEvent('dps-maritime:client:playManifestSound', function()
    if Config.Manifest and Config.Manifest.PrintSound then
        PlaySoundFrontend(-1, Config.Manifest.PrintSound, Config.Manifest.PrintSoundSet or 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    else
        -- Default print sound
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
end)
