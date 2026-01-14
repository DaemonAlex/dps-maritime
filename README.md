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

## Dependencies

- [qb-core](https://github.com/qbcore-framework/qb-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. Copy `dps-maritime` to your resources folder
2. Import `sql/database.sql` into your database
3. Add `ensure dps-maritime` to your server.cfg
4. Configure `config/config.lua` as needed

## Progression System

| Level | Title | Tier | Unlocks |
|-------|-------|------|---------|
| 1 | Dock Hand | 1 | Dock work |
| 2 | Loader | 1 | - |
| 3 | Senior Loader | 1 | - |
| 4 | Deckhand | 2 | Boat deliveries, Tier 1 boats |
| 5 | Sailor | 2 | Tier 2 boats |
| 6 | Boatswain | 2 | Medium cargo |
| 7 | Helmsman | 3 | Fleet ownership, Cargo ships, Hazmat |
| 8 | First Mate | 3 | Marquis yacht |
| 9 | Captain | 3 | Tug boat, Illegal cargo |
| 10 | Port Captain | 3 | All boats, Max pay multiplier |

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

## Configuration

### Main Settings (`config/config.lua`)
```lua
Config.BusinessName = 'Jetsam'
Config.Framework = 'qb' -- 'qb' or 'esx'
Config.Target = 'ox_target'
Config.Inventory = 'ox_inventory'
```

### Dock Work Settings
```lua
Config.DockWork = {
    PaymentMin = 500,
    PaymentMax = 900,
    TruckRentalFee = 1000,
    RefundOnReturn = true,
}
```

### Boat Delivery Settings
```lua
Config.BoatDelivery = {
    BasePayoutPerMeter = 0.015, -- $15 per km
    FuelEnabled = true,
    FuelPricePerLiter = 3,
}
```

## Commands

| Command | Permission | Description |
|---------|------------|-------------|
| `/maritimestats` | Everyone | View your maritime stats |
| `/setmaritimelevel [id] [level]` | Admin | Set player's maritime level |
| `/clearcontainers` | Admin | Clear all placed containers |

## Exports

### Client
```lua
exports['dps-maritime']:GetPlayerMaritimeData()
exports['dps-maritime']:GetPlayerLevel()
exports['dps-maritime']:IsOnDuty()
exports['dps-maritime']:GetCurrentJob()
```

### Server
```lua
exports['dps-maritime']:GetPlayerMaritimeData(source)
exports['dps-maritime']:GetPlayerMaritimeLevel(source)
exports['dps-maritime']:AddMaritimeXP(source, amount)
exports['dps-maritime']:GetDatabase()
```

## Map

This resource includes the port map from estrp-emptyport. The map assets are located in `map/stream/`.

## Credits

- DPS Development Team
- Based on concepts from ocean-delivery

## License

This resource is proprietary to DPS Development.
