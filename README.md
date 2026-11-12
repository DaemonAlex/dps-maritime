# dps-maritime - Jetsam Maritime Logistics

A unified maritime job resource for FiveM combining dock work (container hauling) and boat deliveries with a comprehensive progression system.
![Terminal-GTAVe-JetsamRoadSignage](https://github.com/user-attachments/assets/16697ce6-7e1e-46f7-b327-4d7544bf473f)

## Status

Not running on DelPerroSands. It was not in the server's resource list on 1 November 2026. The
date it was taken off is not recorded. The code is complete (version 1.6.0). The server runs
prompt_jetsam_script for the Jetsam docks job now.

## What it is for

It is a job at the port. A player starts by moving containers on the dock, earns levels, and
moves up to running cargo by boat. At higher levels they can own a small fleet and carry
hazardous or illegal cargo.

## On its own, and with other scripts

**On its own.** It needs `ox_lib`, `ox_target`, `oxmysql` and a framework (Qbox, QBCore or ESX,
set in `config/config.lua`). The player talks to the dock NPC, rents a truck or takes a job boat,
delivers the cargo and gets paid. Ten levels unlock bigger boats and better cargo. `/maritimestats`
shows a stats screen. The port map pieces are in a separate resource, dps-maritime-maps. The job
runs without it.

**With ox_inventory.** Cargo manifests and crates are real items. The script also has code for
qs-inventory and qb-inventory. DelPerroSands does not run those.

**With a paid garage (jg-advancedgarages).** A fleet boat that is already out cannot be spawned a
second time.

**With a paid key script (wasabi_carlock).** The player gets keys to the job boat at the start
and loses them at the end.

**With ox_fuel.** Job boats use fuel.

**With a paid MDT (wasabi_mdt).** When a smuggling run is spotted, police get a dispatch call
with the boat's position.

**With paid housing (qs-housing).** Owning a listed dock warehouse or island safehouse can be
required for bulk and illegal cargo. The property lists in the config are empty, so nothing is
locked until you fill them in.

**With [dps-vehiclepersistence](https://github.com/DaemonAlex/dps-vehiclepersistence).** Job
boats are left out of persistence, so they do not come back after a restart.

**With jg-hud.** The script sends the water depth to the HUD as an event. Whether jg-hud shows it
has not been checked.

**What is out of date.** `Config.Phone` lists phone apps but no code uses it. There is no phone
integration. The weather zones no longer change the weather (removed 19 August 2026). They only
change the job's risk and pay.

## Features

- **Dual Job System**: Container hauling at dock and boat cargo deliveries
- **10-Level Progression**: Start as Dock Hand, progress to Port Captain
- **Fleet Ownership**: Own and manage up to 5 boats at higher levels
- **Container Stacking**: Visual container storage system at the port
- **Multiple Cargo Types**: Standard, fragile, perishable, hazmat, and illegal cargo
- **Weather Bonuses**: Extra pay for deliveries in bad weather
- **Streak System**: XP bonuses for consecutive deliveries

## Dependencies

- A framework: [qbx_core](https://github.com/Qbox-project/qbx_core), [qb-core](https://github.com/qbcore-framework/qb-core) or es_extended (set `Config.Framework`)
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

The port map pieces are not in this repo. They load from a separate resource, dps-maritime-maps. The job runs without it.

## Credits

- DPS Development Team
- Based on concepts from ocean-delivery

## License

This resource is proprietary to DPS Development.

## Recent changes

- **12 November 2026.** README: status, what it is for, how it works alone and with paid scripts, other DPS scripts.
  Dependencies and the Map section corrected.
- **28 August 2026.** Synced with the live server.
- **19 August 2026.** The script no longer changes the weather. One weather script should own it.
- **18 August 2026.** Audit fixes: ways to print money closed, a broken job-start path repaired,
  and a weather zone crash fixed.

## Author

Made by [DaemonAlex](https://github.com/DaemonAlex) for DelPerroSands.

## Other DPS scripts

All of these are made for DelPerroSands and run together on one Qbox server. Each one works on
its own. The ones marked "pairs with" do more when both are running.

| Script | What it does |
|---|---|
| [dps-inventory](https://github.com/DaemonAlex/dps-inventory) | The inventory: ox_inventory with equipment slots, backpacks, armour plates and a self status panel, in the DelPerroSands colours. |
| [dps-medical](https://github.com/DaemonAlex/dps-medical) | Patient records, illness and diagnostic tests. A companion to wasabi_ambulance. Pairs with dps-inventory: symptoms and diagnoses show on the status panel. |
| [dps-insurance](https://github.com/DaemonAlex/dps-insurance) | Ties m-Insurance into the MDT, impound, hospital and medical chart. Pairs with dps-medical. |
| [dps-studio](https://github.com/DaemonAlex/dps-studio) | Build rooms, doors and portals in game from one panel (`/studio`), with owners and managers so staff do not have to support them. |
| [dps-shops](https://github.com/DaemonAlex/dps-shops) | Shop clerks who greet and react to a robbery, then player-owned shops. |
| [dps-fleet](https://github.com/DaemonAlex/dps-fleet) | Vehicle browser and workshop on one panel: extras, liveries and mods for emergency vehicles. |
| [dps-parking](https://github.com/DaemonAlex/dps-parking) | Parking with valet, impound, violations and reserved spots. |
| [dps-vehiclepersistence](https://github.com/DaemonAlex/dps-vehiclepersistence) | Vehicles stay where they were parked. Pairs with dps-parking. |
| [dps-towjob](https://github.com/DaemonAlex/dps-towjob) | Queue-based tow job with jg-mechanic integration. |
| [dps-services](https://github.com/DaemonAlex/dps-services) | Request a tow and follow it live on the lb-phone and lb-tablet. Pairs with dps-towjob. |
| [dps-autoshops](https://github.com/DaemonAlex/dps-autoshops) | Self-service repair shops when no mechanic is on duty. |
| [dps-cityworker](https://github.com/DaemonAlex/dps-cityworker) | City infrastructure job and career. |
| [dps-ainpcs](https://github.com/DaemonAlex/dps-ainpcs) | NPCs you can talk to, with trust, quests and intel. |
| [dps-badpeds](https://github.com/DaemonAlex/dps-badpeds) | Police interaction with NPCs: stops, arrests, intel and jail records. |
| [dps-gangwars](https://github.com/DaemonAlex/dps-gangwars) | Ambient gang NPCs, territory population and war reinforcements. |
| [dps-rotations](https://github.com/DaemonAlex/dps-rotations) | Moves dealers, harvests and other spots on a fixed schedule. |
| [dps-trains](https://github.com/DaemonAlex/dps-trains) | The train system. Pairs with dps-trains-stock, dps-traintools and dps-transitapp. |
| [dps-transitapp](https://github.com/DaemonAlex/dps-transitapp) | Live train arrival boards on the lb-phone. |
| [dps-faceplant](https://github.com/DaemonAlex/dps-faceplant) | City help, reports and staff tools on the lb-phone and lb-tablet. |
| [dps-chat](https://github.com/DaemonAlex/dps-chat) | A command box for voice-only servers. No chat feed. |
| [dps-filmmode](https://github.com/DaemonAlex/dps-filmmode) | One key hides every HUD layer and gives a smooth free camera for recording. |
