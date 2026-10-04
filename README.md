# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 8 — Country resources + completed-flight economy

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
- Three country resources per configured destination country.
- Independent resource rolls on successful flight returns.
- Completed-flight coin, XP, and regional-resource rewards.

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

## Country resources

Each configured country currently exposes exactly **3 regional resources**.

Examples:

- Netherlands — Flowers, Dairy, Horticulture.
- Belgium — Chocolate, Chemicals, Precision Parts.
- United Kingdom — Aerospace Parts, Financial Documents, Specialty Goods.
- Germany — Machinery, Automotive Parts, Industrial Tools.
- France — Luxury Goods, Gourmet Food, Cosmetics.
- Denmark — Pharma Goods, Design Goods, Renewable Parts.

The first World Map shows the destination's three resources before a flight is assigned.

The larger country catalog can be expanded later when the final V1 country list is locked.

## Resource drop chance

The base chance remains:

**40% per resource, rolled independently.**

A successful return therefore rolls all three destination resources separately. A flight can return with:

**0, 1, 2, or all 3 resources.**

The 40% base chance is modified by three factors.

### 1. Aircraft-specific modifier

Aircraft profiles support:

**−20% to +20% relative resource chance**

This is separate from speed and capacity and gives individual aircraft another strategic identity.

Current prototype examples:

- Aerolet 100 — 0%.
- Aerolet 120 — −20%.
- Regional 200 — +20%.

### 2. Travel-time modifier

Longer flight timers improve the chance while very short flights reduce it:

| Flight timer | Relative modifier |
| --- | ---: |
| Under 5 min | −10% |
| 5–10 min | −5% |
| 10–20 min | 0% |
| 20–40 min | +5% |
| 40+ min | +10% |

Because the timer is aircraft-specific, a slower aircraft can naturally receive a better resource chance on the same destination than a very fast aircraft.

### 3. Aircraft-size modifier

Larger aircraft receive a modest additional resource benefit:

| Size | Relative modifier |
| --- | ---: |
| S | 0% |
| M | +5% |
| L | +10% |
| XL | +15% |

L and XL remain future-ready and do not need to be part of the V1 aircraft implementation.

### Formula

The modifiers are multiplicative:

**Final chance = 40% × aircraft factor × travel-time factor × size factor**

The final chance is currently clamped between **20% and 70%** so stacking bonuses never produces guaranteed country resources.

Current automated balance examples:

| Aircraft / route | Resource chance per item |
| --- | ---: |
| Aerolet 100 → London | 40.0% |
| Aerolet 120 → London | 30.4% |
| Regional 200 → London | 47.9% |
| Regional 200 → Copenhagen | 50.4% |

This means longer travel, larger aircraft, and aircraft designed around resource hauling all become meaningful without making short flights useless.

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
- View the adjusted resource chance for that exact aircraft / route combination.
- See the aircraft, flight-time, and size modifier components.
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
- Aircraft −20% / +20% resource modifiers.
- Short vs longer flight-time modifiers.
- S vs M size effects.
- Completed-flight reward construction.

Current CI balance check:

**Baseline 40.0% • Fast aircraft 30.4% • Regional aircraft 47.9% • Longer regional flight 50.4%**

## Next pass

**Pass 9 — Resource inventory + construction / upgrade sinks**

Recommended next work:

- Add a proper regional-resource inventory screen.
- Start using country resources for airport building upgrades.
- Keep distinct physical building families while allowing internal production / storage upgrades.
- Add resource requirements to passenger-generation buildings first.
- Begin tying the passenger bottleneck and country economy together.
- Later add friend / Alliance destinations as alternative ways to obtain country resources.
