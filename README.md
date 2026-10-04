# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 7 — Aircraft-specific flight timers + first World Map

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

## Building catalog

| Building | Footprint | Cost | Unlock | Aircraft |
| --- | ---: | ---: | ---: | --- |
| Short Runway | 7×2 | 10,000 | Lv 1 | S |
| Small Aircraft Stand | 2×2 | 4,500 | Lv 1 | S |
| Taxiway | 1×1 | 250 | Lv 1 | S/M/L |
| Service Road | 1×1 | 150 | Lv 1 | Ground vehicles |
| Small Terminal | 3×2 | 8,000 | Lv 1 | S |
| Basic Fuel Station | 2×2 | 7,500 | Lv 2 | S |
| Small Hangar | 3×3 | 12,000 | Lv 3 | S |
| Rapid Small Fuel Station | 2×2 | 30,000 | Lv 6 | S |
| Medium Aircraft Stand | 3×3 | 35,000 | Lv 8 | S/M |
| Regional Fuel Depot | 3×3 | 45,000 | Lv 8 | S/M |
| Regional Rapid Fuel Station | 4×3 | 85,000 | Lv 10 | S/M |
| Regional Runway | 10×3 | 90,000 | Lv 12 | S/M |

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
- Passenger capacity placeholder.
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

## Run

1. Install Godot 4.3 or newer.
2. Import this repository by selecting `project.godot`.
3. Run the project.

## Next pass

**Pass 8 — World Map resources + flight completion economy**

Recommended next work:

- Connect destination countries to the agreed three-resource country system.
- Apply the independent ~40% drop chance per resource on completed flights.
- Award coins / XP only when a flight successfully returns.
- Add a flight-return summary showing rewards and country-resource rolls.
- Begin replacing the temporary Amsterdam development origin with the player's selected home country.
- Add favorites / recent destinations once the send-flow is established.
