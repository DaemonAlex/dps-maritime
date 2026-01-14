# dps-maritime - Jetsam Maritime Logistics

A unified maritime job resource for FiveM combining dock work (container hauling) and boat deliveries with a comprehensive progression system.

![Terminal-GTAVe-JetsamRoadSignage](https://github.com/user-attachments/assets/16697ce6-7e1e-46f7-b327-4d7544bf473f)

## Features

- **Dual Job System**: Container hauling at dock and boat cargo deliveries
- **10-Level Progression**: Start as Dock Hand, progress to Port Captain
- **Fleet Ownership**: Own and manage up to 5 boats at higher levels
- **Container Stacking**: Visual container storage system at the port
- **Multiple Cargo Types**: Standard, fragile, perishable, hazmat, and illegal cargo
- **Weather Bonuses**: Extra pay for deliveries in bad weather
- **Streak System**: XP bonuses for consecutive deliveries
- **Framework Bridge**: Supports both QBCore and ESX
- **NUI Dashboard**: Visual stats display with level progress, unlocks, and bonuses
- **Random Sea Events**: Rare encounters during boat deliveries
- **Security Validation**: Server-side anti-cheat protection
- **State Bags**: Real-time player data synchronization

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib) (v3.0.0+)
- [ox_target](https://github.com/overextended/ox_target) (v1.0.0+)
- [oxmysql](https://github.com/overextended/oxmysql) (v2.0.0+)
- [qb-core](https://github.com/qbcore-framework/qb-core) OR [es_extended](https://github.com/esx-framework/esx_core)
- dps-maritime-maps (map assets)

## Installation

1. Copy `dps-maritime` to your resources folder
2. Import `sql/database.sql` into your database
3. Add `ensure dps-maritime` to your server.cfg (after dependencies)
4. Configure `config/config.lua` for your framework

## Progression System

| Level | Title | Tier | Unlocks |
|-------|-------|------|---------|
| 1 | Dock Hand | 1 | Dock work, manual loading |
| 2 | Loader | 1 | Forklift access, fragile containers |
| 3 | Senior Loader | 1 | Company radio, refrigerated containers |
| 4 | Deckhand | 2 | Boat deliveries, Tier 1 boats |
| 5 | Sailor | 2 | Tier 2 boats, hazmat containers |
| 6 | Boatswain | 2 | VIP Transport, high-value cargo |
| 7 | Helmsman | 3 | Fleet ownership, cargo ships, hazmat cargo |
| 8 | First Mate | 3 | Marquis yacht, contraband cargo |
| 9 | Captain | 3 | Tug boat, Smuggler's Radar, weapons cargo |
| 10 | Port Captain | 3 | Large cargo vessel, all cargo types, max pay |

## Boats

### Tier 1 (Level 4+)
- Dinghy - $15,000
- Seashark - $40,000
- Speeder - $55,000
- Suntrap - $25,000

### Tier 2 (Level 5-6)
- Jetmax - $225,000
- Tropic - $150,000
- Squalo - $285,000
- Toro - $375,000

### Tier 3 (Level 7+)
- Coastal Cargo Ship - $450,000
- Marquis Yacht - $1,500,000
- Tug Boat - $2,250,000
- Large Cargo Vessel - $5,000,000

## Cargo Types

### Standard (Level 4+)
- General Cargo, Electronics, Seafood, Supplies

### Medium Value (Level 5+)
- Vehicle Parts, Clothing, Alcohol

### High Value (Level 6+)
- Medical Supplies, Luxury Goods, Yacht Provisions

### Hazmat (Level 7+)
- Hazardous Materials, Industrial Chemicals

### Contraband (Level 8+)
- Unmarked Crates, Weapons, Drugs

## Random Sea Events

Rare encounters during boat deliveries that add dynamic gameplay:

### Negative Events
- **Engine Failure** - Temporary engine stall
- **Rough Seas** - Reduced handling in bad weather
- **Rogue Wave** - Sudden wave impact with damage
- **Coast Guard Patrol** - Inspection risk for illegal cargo
- **Storm Interference** - Navigation disruption during thunder

### Positive Events
- **Wildlife Sighting** - Bonus XP for spotting dolphins
- **Calm Waters** - Speed boost in good weather
- **Tailwind** - Favorable winds increase speed

### Opportunity Events
- **Distress Signal** - Rescue mission for cash and XP bonus
- **Floating Cargo** - Salvage abandoned cargo for rewards

## Configuration

### Framework Settings (`config/config.lua`)
```lua
Config.Framework = 'qb'           -- 'qb' or 'esx'
Config.Target = 'ox_target'       -- 'ox_target', 'qb-target', 'qtarget'
Config.Inventory = 'qs-inventory' -- 'ox_inventory', 'qb-inventory', 'qs-inventory'
```

### Dock Work Settings
```lua
Config.DockWork = {
    PaymentMin = 800,
    PaymentMax = 1500,
    TruckRentalFee = 1500,
    RefundOnReturn = true,
}
```

### Boat Delivery Settings
```lua
Config.BoatDelivery = {
    BasePayoutPerMeter = 0.15, -- $150 per km
    MinimumPayout = 500,
    FuelEnabled = true,
    FuelPricePerLiter = 3,
}
```

## Commands

| Command | Permission | Description |
|---------|------------|-------------|
| `/maritimestats` | Everyone | Open visual stats dashboard |
| `/mstats` | Everyone | Shortcut for stats dashboard |
| `/maritimedash` | Everyone | Shortcut for stats dashboard |
| `/setmaritimelevel [id] [level]` | Admin | Set player's maritime level |
| `/clearcontainers` | Admin | Clear all placed containers |

## Exports

### Client
```lua
-- Player data
exports['dps-maritime']:GetPlayerMaritimeData()
exports['dps-maritime']:GetPlayerLevel()
exports['dps-maritime']:IsOnDuty()
exports['dps-maritime']:GetCurrentJob()
exports['dps-maritime']:SetOnDuty(onDuty, jobType)

-- Dashboard
exports['dps-maritime']:OpenDashboard()
exports['dps-maritime']:CloseDashboard()
exports['dps-maritime']:IsDashboardOpen()

-- Boat jobs
exports['dps-maritime']:GetCurrentBoatJob()
exports['dps-maritime']:GetSpawnedBoatPlate()

-- Sea events
exports['dps-maritime']:IsEventActive()
exports['dps-maritime']:GetCurrentEvent()
exports['dps-maritime']:ForceEvent(eventId)
exports['dps-maritime']:EndCurrentEvent()

-- Navigation
exports['dps-maritime']:StartCompassNavigation(data)
exports['dps-maritime']:StopCompassNavigation()
exports['dps-maritime']:IsCompassNavigating()

-- Radar (Level 9+)
exports['dps-maritime']:IsRadarEnabled()
exports['dps-maritime']:ToggleRadar()

-- Sea life
exports['dps-maritime']:IsAnchored()
exports['dps-maritime']:IsMoored()
exports['dps-maritime']:GetCurrentDepth()
exports['dps-maritime']:DeployAnchor()
exports['dps-maritime']:RetrieveAnchor()
```

### Server
```lua
exports['dps-maritime']:GetPlayerMaritimeData(source)
exports['dps-maritime']:GetPlayerMaritimeLevel(source)
exports['dps-maritime']:AddMaritimeXP(source, amount)
exports['dps-maritime']:GetDatabase()

-- Security
exports['dps-maritime']:SecurityOnJobStart(source, jobType, data)
exports['dps-maritime']:SecurityOnJobCancel(source)
exports['dps-maritime']:SecurityValidateCompletion(source, clientDistance, clientData)
```

## State Bags

Player data is synchronized via State Bags for real-time access:

```lua
-- Client-side access
LocalPlayer.state.maritimeLevel    -- Current level (1-10)
LocalPlayer.state.maritimeXP       -- Current XP
LocalPlayer.state.maritimeTitle    -- Current title
LocalPlayer.state.maritimeOnDuty   -- On duty status
LocalPlayer.state.maritimeJobType  -- Current job type ('dock' or 'boat')

-- Helper functions
Maritime.GetMyLevel()
Maritime.GetMyXP()
Maritime.GetMyTitle()
Maritime.AmIOnDuty()
Maritime.GetMyJobType()
```

## Map

This resource requires `dps-maritime-maps` for port assets. The maps are loaded separately to allow distribution through Vertex Hub.

## Credits

- DPS Development Team

## License

This resource is proprietary to DPS Development.
