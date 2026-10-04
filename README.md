# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 9 — Passenger bottleneck + country-resource upgrades

Skyport Online now has a complete local airport loop plus the first destination/route layer.

### Current foundation

- Godot 4 mobile project using a landscape 1280×720 reference viewport.
- Isometric 24×24 airport grid split into 3×3 expansion parcels.
- Level-gated and coin-gated land expansion.
- Pan / pinch zoom on mobile and desktop editor controls.
- Landscape HUD with airport controls around the edge and build catalog on the right.
- Pixel-art airport building assets integrated into the live grid and build catalog.
- Real taxiway connectivity from stands / hangars to compatible runways.
- Placeable service roads used by ground vehicles.
- Ground-service queueing and station vehicle-capacity bottlenecks.
- Shared runway queues for arrivals and departures.
- Two starter aircraft running through the physical airport lifecycle.
- Interactive first Europe World Map.
- Aircraft-specific destination timers, range checks, rewards and level gates.
- Passenger generation, terminal storage, boarding costs, and country-resource passenger-building upgrades.
- Flight-return coin / XP / regional-resource rewards with a return summary.

## Building catalog

| Building | Footprint | Cost | Unlock | Aircraft |
| --- | ---: | ---: | ---: | --- |
| Short Runway | 7×2 | 10,000 | Lv 1 | S |
| Small Aircraft Stand | 2×2 | 4,500 | Lv 1 | S |
| Taxiway | 1×1 | 250 | Lv 1 | S/M/L |
| Service Road | 1×1 | 150 | Lv 1 | Ground vehicles |
| Small Terminal | 3×2 | 8,000 | Lv 1 | Passenger storage |
| Airport Bus Stop | 1×1 | 3,000 | Lv 1 | +8 / 4 min |
| Small Airport Hotel | 2×2 | 6,500 | Lv 2 | +18 / 10 min |
| Taxi Rank | 1×1 | 9,000 | Lv 3 | +1 / 8 min |
| Residential District | 2×2 | 22,000 | Lv 5 | +1 / 3 min |
| Railway Connection | 3×2 | 65,000 | Lv 9 | +1 / 2 min |
| Basic Fuel Station | 2×2 | 7,500 | Lv 2 | S |
| Small Hangar | 3×3 | 12,000 | Lv 3 | S |
| Rapid Small Fuel Station | 2×2 | 30,000 | Lv 6 | S |
| Medium Aircraft Stand | 3×3 | 35,000 | Lv 8 | S/M |
| Regional Fuel Depot | 3×3 | 45,000 | Lv 8 | S/M |
| Regional Rapid Fuel Station | 4×3 | 85,000 | Lv 10 | S/M |
| Regional Runway | 10×3 | 90,000 | Lv 12 | S/M |

## Passenger bottleneck

Passengers are now a real operational resource.

- Starter terminal capacity: **120 passengers**.
- Starting stock: **54 passengers**.
- Departures consume each aircraft's actual passenger capacity: currently 18, 24, and 58 passengers.
- Aircraft without enough passengers remain queued until the terminal has enough stock.
- Passenger buildings generate into local storage, which is collected into the terminal.
- The starter airport includes an Airport Bus Stop and Small Airport Hotel.
- Later passenger infrastructure includes a Taxi Rank, Residential District, and Railway Connection.

Supplemental passenger sources use the same terminal cap:

- Rewarded-ad hook: **+25 passengers**, maximum **3 per day**.
- Friend-gift hook: **+5 passengers per friend**, maximum **50 received per day**.

The ad and friend buttons currently use local prototype hooks. Production ad completion and the online friends backend still need to replace those hooks.

### Country-resource upgrades

Passenger buildings keep the same world art at every upgrade level. Upgrades change mechanics only:

- Production rate.
- Local storage.
- Terminal capacity.

Tapping a passenger building opens its current level, stored passengers, next-level benefits, required resources, and Upgrade button.

Upgrade costs spend the **same shared country-resource inventory** awarded by returned flights and displayed by the flight-return summary. Each supported country has three resources. Resource drops use a **40% base chance per resource**, with the shared aircraft / route modifiers determining the final chance.

## Aircraft operations

The physical aircraft lifecycle is:

**Parked → Fuel request → Fuel truck → Ready → Runway queue → Taxi out → Line up → Takeoff roll → Climb → En route → Holding for arrival → Approach → Landing roll → Taxi in → Parked**

Aircraft release their stand when taxiing out. Returning aircraft reserve a free compatible stand before approach. If every compatible stand is occupied, they remain in a holding state until one becomes available.

Arrivals and departures use the same runway dispatcher, so a runway can only handle one active aircraft operation at a time.

## Ground services

Fuel trucks require a real:

**Fuel Station → Service Road → Aircraft Stand**

route.

The dispatcher also respects each station's service speed and vehicle capacity.

Example starter bottleneck:

- Basic Fuel Station — S aircraft, x1.0 speed, 1 truck.
- Rapid Small Fuel Station — S aircraft, x1.6 speed, 2 trucks.

With two aircraft, the basic station produces a queue while the rapid station can handle both simultaneously.

## Aircraft-specific flight timers

The old fixed demo flight timer has been removed from the gameplay path.

Each aircraft type now has flight data including:

- Size class.
- Cruise speed.
- Range.
- Passenger capacity used directly by the boarding bottleneck.
- Timer balancing factor.

Flight duration is calculated from:

**Destination distance ÷ aircraft cruise speed × gameplay time compression × aircraft timer factor**

This means different aircraft types can remain away for different lengths of time on exactly the same route.

Current prototype example for Amsterdam → London:

- Aerolet 100 — about 11m 15s.
- Aerolet 120 — about 8m 26s.

These aircraft names and values are temporary prototype data and can be replaced by the final V1 plane catalog without rewriting the flight system.

Longer-distance aircraft introduced later can therefore naturally support much longer flight timers.

## First World Map

The bottom **WORLD** button now opens the first interactive Europe network screen.

Current development destinations:

- Brussels, Belgium.
- London, United Kingdom.
- Frankfurt, Germany.
- Paris, France.
- Berlin, Germany.
- Copenhagen, Denmark.

The map currently supports:

- Selecting one of the player's aircraft.
- Selecting a destination visually.
- Destination level locks.
- Aircraft range validation.
- Per-aircraft calculated flight duration.
- Coin / XP reward preview.
- Current aircraft state.
- Current assigned route.
- En-route countdown.
- Reassigning a destination while the aircraft is still available on the ground.

Amsterdam is only the **development home airport**. The airport-creation / country-selection system will replace it with the player's selected home country and airport.

## Flight data model

Each assigned flight carries:

- Destination ID.
- City and country.
- Distance.
- Calculated duration.
- Coin reward.
- XP reward.

An aircraft cannot depart after servicing unless it has a valid destination plan.

Once airborne, its local airport sprite disappears and its assigned flight timer runs. When the timer completes, the aircraft requests a compatible stand and runway before physically returning to the airport.

## Automated validation

GitHub Actions currently validates:

- Godot project import / GDScript parsing.
- Landscape main-scene startup.
- Airside taxiway connectivity.
- Service-road vehicle routing.
- Fuel speed and truck capacity.
- Departure runway queues.
- Arrival runway queues.
- Full takeoff → flight → landing → parking lifecycle.
- Aircraft range limits.
- Flight-plan creation.
- Aircraft-specific flight duration differences.
- Multi-minute timers replacing the old demo-duration behavior.
- Regional resource-drop rules and flight-return rewards.
- Passenger generation/collection, terminal capacity, ad/friend daily caps, shared-resource upgrades, and boarding gates.

## Run

1. Install Godot 4.3 or newer.
2. Import this repository by selecting `project.godot`.
3. Run the project.

## Next pass

**Pass 10 — Persistence + production social/ad hooks**

Recommended next work:

- Persist passenger balances, producer storage, upgrade levels, country resources, and daily limits.
- Calculate true elapsed-time passenger generation while the app is closed.
- Replace the local +25 passenger button with the production rewarded-ad completion callback.
- Replace prototype friend identities with the real daily friends-gifting backend.
- Add friend-gift send/receive UI and claim states.
- Continue replacing the temporary Amsterdam development origin with the player's selected home country.
