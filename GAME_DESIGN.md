# Chrome District: Game Design

A living reference for the game's direction. Update it as ideas firm up.
Items under **Status** reflect what is actually in the code.

## Premise

A sprawling megacity on a distant colony world. For generations an autocratic
regime ruled it from a central palace. The regime has just been **overthrown**,
which leaves a power vacuum and a city that is mostly **shanty town**: dense,
improvised housing built from scrap, tarps and salvaged regime materials.

With the regime gone, off-world **corporations flood in**. Each one wants to
turn the city into its own industrial base. The player runs one of them.

## Core loop (target)

1. **Acquire land**: buy plots from the post-regime authority, from squatters or
   from rival owners.
2. **Clear the shanty town**: demolish shanties to free up land. Clearing costs
   money and displaces residents.
3. **Build up**: factories, power, farms, housing and services.
4. **Trade off-world**: export goods through landing pads and spaceports and
   import what the planet lacks.
5. **Fight for districts**: once space runs out, corporations compete
   (economically at first, then openly) for control of districts.

## Progression arc

| Phase | Player focus | Pressure |
|---|---|---|
| Landing | Small cleared lot around a landing pad. Clear nearby shanties and build first power and housing. | Limited credits |
| Expansion | Buy and clear land, set up industry and food. | Rival corps buying up nearby land |
| Trade | Off-world exports and spaceport upgrades. | Supply chains, power demand |
| Conflict | Contest and hold districts. | Rival corps, unrest |

## World and map

- **Grid**: isometric tiles. The starting map is 40×40 (see `CityState.SIZE`).
- **Terrain layer** (under buildings):
  - `Open lot`: buildable.
  - `Boulevard / alley`: old regime boulevards in a rough grid, plus
    narrow, winding alleys cut by residents. Not buildable.
  - `Shanty`: dense improvised housing, density 1–3. Must be cleared before
    building. Each tile has residents.
  - `Rubble`: damage left from the revolution. Cheap to clear.
  - `Regime ruins`: the toppled palace in the city centre. Cannot be cleared yet
    (idea: salvage or monument mechanics later).
  - `Landing pad`: the player corporation's arrival point and future trade hub.
- **Starting position**: a small cleared lot with a landing pad near one corner,
  surrounded by shanty town.

## Logistics: landing pad and distribution hubs

Every resource starts off-world. The flow is:

1. **Buy at the landing pad.** Ordered cargo lands on the pad and waits there.
   The pad holds a limited amount (`CityState.PAD_CAPACITY`, 120 units), so
   you can't keep buying until it has been unloaded.
2. **Distribution hubs pull from the pad.** A hub (warehouse) unloads cargo
   when it is:
   - **in range**: within `Warehouse.RANGE` (10) tiles of the pad, by
     Manhattan distance;
   - **accepting that good**: each hub has a per-good on/off filter, set by
     clicking the hub;
   - **not full**: each hub stores 100 units in total.
   Each hub pulls up to `Warehouse.PULL_RATE` (8) units per second, nearest hub
   first, taking goods round-robin so one good can't starve the others.
3. **Stored goods** wait in hubs for future consumers (construction, factories,
   housing). Demolishing a hub destroys what it holds.

Starting goods (`GoodsDefs`): building materials, ration packs, fuel cells and
components, each with an off-world price per unit.

Ideas for later:
- Hubs pass goods along to other hubs (daisy-chaining range out from the pad).
- Pull rate and range depend on road access instead of straight-line distance.
- Trucks or drones you can see moving cargo.
- Hubs need power or workers to run at full speed.
- Selling goods off-world from the pad (exports).
- Buildings consume goods from the nearest hub (e.g. construction uses materials).

## Shanty residents

Shanty residents are not the corporation's citizens. They are a separate
population living on land the corporations want.

Ideas to explore:
- A **labour pool** that factories hire from (cheap, unskilled labour).
- **Displacement** when clearing: residents move to nearby shanties
  (raising density), leave, or become unrest.
- **Unrest / resistance**: aggressive clearing could cause protests, sabotage or
  an opening for rivals.
- Option to **upgrade** shanties into proper housing instead of razing them.

## Corporations

- The player is one corporation. Rival AI corporations arrive over time.
- Each has a colour and an identity (e.g. energy conglomerate, agri-combine,
  arms manufacturer, trade cartel). Specialities to be decided.
- They compete for the same land: bidding, buyouts and eventually force.

## Buildings (planned categories)

- **Industry**: factories that turn raw input into goods.
- **Power**: reactors and other generators (the reactor exists already).
- **Food**: farms and vat-growth facilities.
- **Housing**: capsule towers for corporate workers (exists already).
- **Commerce**: markets and data hubs (exist already).
- **Trade**: landing pads and spaceports for off-world import and export.
- **Security / military**: needed for the district conflict phase.

## Districts and conflict (later)

- The map is divided into named districts (likely following the boulevards).
- Control comes from the share of land owned and buildings in a district.
- Controlling a district gives bonuses (tax, access, influence).
- Conflict mechanics are undecided: economic takeover, sabotage, security
  forces, open fighting.

## Open questions

- How does land purchase work: fixed price per tile, auctions, or a
  post-regime council?
- How many rival corporations, and when do they arrive?
- Is there a win condition (control X districts) or is it open-ended?
- Does the regime have remnants or loyalists acting as a third force?

## Status

- [x] Basic build / demolish loop with power, housing, jobs and income
- [x] Starting map: shanty town, boulevards, alleys, rubble, regime ruins and a landing pad
- [x] Clearing shanties and rubble (costs credits, displaces residents)
- [x] Buying cargo at the landing pad (limited pad capacity)
- [x] Distribution hubs: range, per-good filters, limited storage, pull rate
- [ ] Buildings consuming stored goods
- [ ] Land ownership and purchase
- [ ] Shanty residents as labour / unrest
- [ ] Industry, farms and off-world trade
- [ ] Rival corporations
- [ ] Districts and conflict
