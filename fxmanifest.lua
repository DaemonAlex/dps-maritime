--[[
    dps-maritime - Jetsam Maritime Logistics
    A unified maritime job with dock work and boat deliveries
]]

fx_version 'cerulean'
game 'gta5'

name 'dps-maritime'
author 'DPS Development'
description 'Jetsam Maritime Logistics - Container hauling and boat delivery job with progression'
version '1.5.0'
repository 'https://github.com/DaemonAlex/dps-maritime'

lua54 'yes'

-- Shared scripts (loaded on both client and server)
shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'config/boats.lua',
    'config/cargo.lua',
    'config/locations.lua',
    'config/containers.lua',
    'shared/functions.lua',
    'shared/bridge.lua',   -- Framework abstraction (must load after config)
}

-- Client scripts
client_scripts {
    'client/cleanup.lua',       -- Port cleanup (removes default GTA props)
    'client/main.lua',          -- Core client, NPC, menus
    'client/dock.lua',          -- Container hauling job
    'client/handler.lua',       -- Handler vehicle mechanics
    'client/boats.lua',         -- Boat delivery job
    'client/fleet.lua',         -- Fleet management
    'client/radar.lua',         -- Smuggler's Radar (Level 9+)
    'client/minigames.lua',     -- Hazmat pressure, crane, forklift mini-games
    'client/sealife.lua',       -- Anchoring, mooring, depth awareness
    'client/vip_transport.lua', -- VIP Leisure Transport (RCore integration)
    'client/navigation.lua',    -- Compass navigation for distant destinations
    'client/weather_zones.lua', -- Localized weather zones
    'client/events.lua',        -- Random sea events (rare encounters)
    'client/dashboard.lua',     -- NUI stats dashboard
}

-- Server scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',  -- Database operations (must load first - exports GetDatabase)
    'server/security.lua',  -- Security validation (must load before jobs)
    'server/main.lua',      -- Core server, progression
    'server/dock.lua',      -- Container job logic
    'server/boats.lua',     -- Boat job logic
    'server/fleet.lua',     -- Fleet ownership + garage bridge
    'server/keys.lua',      -- Vehicle keys integration (qs-vehiclekeys)
    'server/events.lua',    -- Random sea event rewards
}

-- Files accessible to client
files {
    'locales/*.lua',
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

-- NUI configuration
ui_page 'html/index.html'

-- Map assets are loaded from separate resource: dps-maritime-maps
-- This allows the maps to be loaded through Vertex Hub

-- Dependencies with version requirements
-- ox_lib: Requires v3.0.0+ for lib.callback, lib.requestModel, etc.
-- oxmysql: Requires v2.0.0+ for MySQL.query.await syntax
-- ox_target: v1.0.0+ for addLocalEntity, addSphereZone
-- Framework: qb-core OR es_extended (set in config)
dependencies {
    'ox_lib',
    'oxmysql',
    'ox_target',
    'dps-maritime-maps', -- Map assets (warehouse, dock props, port exterior)
}

-- This resource provides these exports
provide 'dps-maritime'
