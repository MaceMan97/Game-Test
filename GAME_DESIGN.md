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
- Buildings take goods from the nearest hub rather than from all hubs at once.

## Economy: the company town

The company makes money by selling to the people it employs and houses:
company-store economics. Wages go out, and most come back as meal sales and
rent. Real profit comes from margins and from off-world income.

**People** (`Population`) are simulated one by one (about 9,800 at the start).
Each person has a home (a shanty tile or a company apartment), maybe a job, and
a wallet. Everyone starts with 5–25 credits (`CityState.STARTING_WALLET`) to
seed the economy.

**Every tick:** unemployed people fill open job slots in your buildings.

**Every day** (`CityState.DAY_TICKS`, 10 ticks), in `Economy.run_day`:
1. **Upkeep**: each building charges its daily upkeep.
2. **Inputs**: buildings take their daily goods from hubs. Reactors burn
   2 fuel cells; data hubs use 2 components. Without them they produce nothing
   that day.
3. **Income**: data hubs sell data off-world (350/day when fully staffed,
   powered and supplied).
4. **Payday**: every worker gets their building's wage: `Economy.WAGE` (10)
   by default, 12 for tier 2 industry, 18 for skilled tier 3 jobs.
5. **Meals**: company stores sell one ration pack per person per day for
   `Economy.MEAL_PRICE` (5 credits; it costs 3 to import). They are limited by
   store capacity (60 a day per fully staffed store) and by food in your hubs.
   Unemployed shanty dwellers spend their starting money here too.
6. **Rent**: apartment residents pay rent. Anyone who can't pay is evicted.
7. **Production**: factories and farms put their output into hubs that accept
   that good and have room. Whatever doesn't fit is wasted (tile info warns
   you).
8. **Moving**: workers move into vacant apartments, best apartments first, up to
   2 per building per day. A worker moves in if their wage minus a meal covers
   the rent, they have two days' rent saved, and it's an upgrade on where they
   live now. So skilled workers leave capsule towers for Skyline suites.
   Homeless people (evicted, or from cleared shanties) squat in any shanty with
   room.
9. **Exports**: goods with auto-export on are sold off-world, keeping
   `CityState.EXPORT_RESERVE` (40) of each in your hubs. You can also sell by
   hand at the pad.
10. **Debt**: ending `Economy.BANKRUPT_DAYS` (3) days in a row below zero
    credits bankrupts the company. Game over.

**Where the money comes from:** wages mostly come back as meals and rent,
but never all of it. Real profit needs outside money: shanty dwellers' savings
(early, and finite), **exports** of goods made on-world, and **data hubs**.

**Staffing matters**: a building's output scales with how many of its job
slots are filled (and with power, for consumers). An understaffed hub pulls
cargo more slowly.

**Goods** (import price / export price per unit):
| Good | Import / export | Used by | Made by |
|---|---|---|---|
| Building materials | 4 / 3 | Construction, component fab (6/day) | Fabrication plant (40/day) |
| Ration packs | 3 / 2 | Sold to people at company stores | Hydroponic farm (20), protein vats (50) |
| Fuel cells | 8 / 6 | Fusion reactor (2/day), fabrication plant (1/day) | Fuel refinery (14/day) |
| Components | 12 / 9 | Data hub (2/day) | Component fab (16/day) |

**How you go bankrupt:** buildings cost wages and upkeep every day whether or
not they earn anything. Overbuying cargo, building hubs and reactors before
you have income, or letting a data hub run out of components all drain
credits.

Ideas for later:
- Hunger consequences: people who go days without a company meal could grow
  unrest, work worse, or leave. (Hungry days are already tracked per person.)
- Wage and price sliders, with unrest as the cost of squeezing too hard.
- Shanty dwellers paying informal rent or "protection".
- Apartments needing power, with unhappiness during blackouts.
- Shanty savings eventually run out, so early meal sales fade. Watch whether
  mid-game income needs another source.

## Shanty residents

Shanty residents are not the corporation's citizens. They are a separate
population living on land the corporations want. They are now simulated as
people (see Economy): they work your jobs and spend their savings at your
stores.

Ideas to explore:
- **Displacement** when clearing: evicted residents currently squat in any
  shanty with room, or become homeless. They could also leave or become unrest.
- **Unrest / resistance**: aggressive clearing could cause protests, sabotage or
  an opening for rivals.
- Option to **upgrade** shanties into proper housing instead of razing them.

## Corporations

- The player is one corporation. Rival AI corporations arrive over time.
- Each has a colour and an identity (e.g. energy conglomerate, agri-combine,
  arms manufacturer, trade cartel). Specialities to be decided.
- They compete for the same land: bidding, buyouts and eventually force.

## Buildings and progression

The construction menu is grouped by category (`BuildingDefs.CATEGORIES`):
number keys 1–6 open a category, 7 is demolish, and Esc steps back out
(first stops building, then closes the menu). Hover a button to see its full
stats.

Buildings unlock in **tiers**, gated by how many people live in company housing
(`BuildingDefs.TIER_RESIDENTS`). Unlocks are permanent. To house more people you
need more workers, so each tier is earned by building out jobs and housing,
not just by saving credits.

| Tier | Unlocks at | Category | Building | Role |
|---|---|---|---|---|
| 1 | start | Logistics | Distribution hub | Pulls pad cargo, stores goods |
| 1 | start | Commerce | Company store | Sells meals |
| 1 | start | Housing | Capsule tower | 20 homes, rent 4 |
| 1 | start | Food | Hydroponic farm | 20 food/day, no power |
| 2 | 20 housed | Power | Fusion reactor | 40 power, burns fuel |
| 2 | 20 housed | Food | Protein vats | 50 food/day |
| 2 | 20 housed | Industry | Fabrication plant | Fuel → 40 materials/day |
| 2 | 20 housed | Industry | Fuel refinery | 14 fuel/day |
| 3 | 60 housed | Industry | Component fab | Materials → 16 components/day |
| 3 | 60 housed | Commerce | Data hub | Components → 350 credits/day |
| 3 | 60 housed | Housing | Skyline suites | 12 homes, rent 12 (needs wage 17+) |

Balance notes (from a scripted test run): a reasonable player reaches tier 2
around day 15–20 and needs to expand jobs deliberately to reach tier 3. Tier 1
earns tens of credits a day, and tier 2 industry with exports earns hundreds.

Still planned:
- **Trade**: spaceport upgrades to the pad (more capacity, better prices).
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
- [x] Buildings consuming stored goods (construction, fuel, components, food)
- [x] Simulated people: homes, jobs, wallets, wages, meals, rent
- [x] Daily ledger and bankruptcy
- [x] Categorized construction menu with tiered unlocks
- [x] Farms, factories, skilled jobs and luxury housing
- [x] Off-world exports (manual and auto with reserve)
- [ ] Land ownership and purchase
- [ ] Unrest / hunger consequences
- [ ] Rival corporations
- [ ] Districts and conflict
