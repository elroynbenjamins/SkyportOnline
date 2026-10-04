# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 8B — Guest airport creation + country resource economy

Skyport Online now has a complete local airport loop, a first World Map, aircraft-specific route timers, and the first destination economy.

### Current foundation

- Godot 4 mobile project using a landscape 1280×720 reference viewport.
- Isometric airport grid with level-gated and coin-gated land expansion.
- Landscape airport HUD and interactive Europe World Map.
- Placeable airport buildings, taxiways, and service roads.
- Airside connectivity validation.
- Ground-service queues and fuel-station vehicle-capacity bottlenecks.
- Shared runway arrival / departure queues.
- Physical takeoff, landing, taxi-out, and taxi-in lifecycle.
- Aircraft-specific range, speed, and flight timers.
- Guest-first airport creation with persistent airport name, code, and home country.
- Interactive curated world-map country selector.
- Three country resources per launch country.
- Fixed 40% independent resource rolls on successful flight returns.
- Completed-flight coin, XP, and regional-resource rewards.
- Persistent guest-profile country-resource inventory.

## Aircraft lifecycle

The physical loop is:

**Parked → Fuel request → Fuel truck → Destination → Ready → Runway queue → Taxi out → Line up → Takeoff → Climb → En route → Inbound → Approach → Landing → Taxi in → Parked → Rewards**

The flight is not rewarded when it is dispatched.

Coins, XP, and country resources are awarded only after the aircraft physically returns and reaches its stand.

## Aircraft-specific flight timers

The fixed demo timer has been removed from the real flight path.

Flight duration comes from:

**Destination distance ÷ aircraft cruise speed × gameplay compression × aircraft timer factor**

Current tested prototype example for Amsterdam → London:

- Aerolet 100 — about 11m 15s.
- Aerolet 120 — about 8m 26s.

These aircraft names and balance values are prototype data. The final V1 plane catalog can replace them without rewriting the flight or reward systems.

## Guest airport creation

First launch now opens the airport-establishment flow before normal gameplay.

The player starts as a **guest** and chooses:

- Airport name.
- Three-character airport code.
- Home country from an interactive schematic world map.

The local profile stores a separate guest ID and airport ID. This is intentional: when online account linking is added, the authenticated account can attach to the same airport rather than replacing its progress.

The current repository can validate the airport name format locally, but **global name uniqueness requires the future server/backend** and is not faked by the offline client.

## Country resources

The curated launch roster currently contains **23 countries** across Europe, North America, South America, Africa, the Middle East, Asia, and Oceania.

Every selectable country exposes exactly **3 regional resources**. Examples:

- Netherlands — Flowers, Dairy, Horticulture.
- Belgium — Chocolate, Specialty Chemicals, Precision Parts.
- Germany — Machinery, Automotive Parts, Industrial Tools.
- United Kingdom — Aerospace Parts, Financial Documents, Specialty Goods.
- Brazil — Coffee, Biofuel, Regional Aircraft Parts.
- Japan — Precision Electronics, Robotics Parts, Optical Instruments.
- Australia — Iron Ore, Wool, Lithium Components.

The airport-creation screen shows all three resources before the home country is confirmed. The flight World Map also shows the three resources belonging to a destination country.

## Resource drop chance

The resource rule is deliberately simple and predictable:

**40% per resource, rolled independently.**

There are no aircraft-speed, flight-time, or aircraft-size modifiers to this chance.

Every successful qualifying return rolls the destination country's three resources separately. Therefore one flight can return with **0, 1, 2, or all 3** materials.

For three independent 40% rolls:

- No resources — **21.6%**.
- Exactly one — **43.2%**.
- Exactly two — **28.8%**.
- All three — **6.4%**.
- Expected return — **1.2 resources per completed flight**.

## Flight-return rewards

After the aircraft lands and parks, the game now awards:

- Destination coins.
- Destination XP.
- Three independent country-resource rolls.

A return summary appears with:

- Flight / destination.
- Coins earned.
- XP earned.
- Final resource chance.
- Each of the three resource successes / failures.
- Updated owned count for resources that dropped.

Example flow:

**SO-001 returned from London**  
**Coins +760 • XP +48**  
**Country resource chance: 40.0% each**  
**✓ Aerospace Parts +1**  
**✕ Financial Documents**  
**✓ Specialty Goods +1**

Resource results are stored in the player's resource inventory for later construction, upgrades, contracts, and other systems.

## World Map

The current first Europe network contains:

- Brussels.
- London.
- Frankfurt.
- Paris.
- Berlin.
- Copenhagen.

The player can:

- Select an aircraft.
- Select a destination.
- View route distance.
- View that aircraft's flight timer.
- View range compatibility.
- View coin and XP rewards.
- View all three regional resources.
- View the fixed 40% chance for each of the three country resources.
- See that the three resource rolls are independent.
- Assign or change a route while the aircraft is still available on the ground.
- Watch the remaining timer while the aircraft is en route.

Amsterdam remains only the temporary development origin. The airport-creation / country-selection flow will replace it with the player's selected home country.

## Automated validation

GitHub Actions currently validates:

- Godot project import and GDScript parsing.
- Landscape main-scene startup.
- Taxiway / runway connectivity.
- Service-road vehicle routing.
- Fuel speed and vehicle-capacity queues.
- Arrival and departure runway queues.
- Full takeoff → flight → landing → parking lifecycle.
- Aircraft range validation.
- Aircraft-specific flight timers.
- Country code propagation through flight plans.
- Exactly three configured resources per country.
- Independent resource rolls.
- Fixed 40% chance for every country resource.
- 0 / 1 / 2 / 3 independent-drop outcomes and probability math.
- Curated country catalog integrity and exactly three resources per country.
- Airport name / airport-code validation.
- Completed-flight reward construction and country-resource persistence.

## Next pass

**Pass 9 — Resource inventory + social airport destinations**

Recommended next work:

- Add a dedicated regional-resource inventory screen.
- Start using country resources for airport building production/storage upgrades.
- Add player, friend, and Alliance airports as destination choices.
- Award Gold / XP to the receiving player when another player services a visit.
- Keep NPC destinations as a fallback so resource progression never depends completely on friends.
- Add server-backed globally unique airport-name reservation and guest-account linking.
- Expand the destination network beyond the current Europe prototype while recalculating route distance from the selected home country.
