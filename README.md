# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 8 — Fleet catalog + player route selection

The repository now contains a playable airport-building and airport-operations foundation:

- Godot 4 mobile project using a landscape 1280×720 reference viewport.
- Isometric 24×24 airport grid split into 3×3 expansion parcels.
- Level-gated and coin-gated land expansion.
- One-finger pan and two-finger pinch zoom on mobile.
- Right-mouse drag and mouse-wheel zoom for desktop/editor testing.
- Landscape HUD with build catalog on the right and airport controls around the edges.
- Build catalog with level locks, costs, aircraft-size compatibility, and footprints.
- Green/red placement preview based on land ownership and occupied tiles.
- Rotation for rotatable buildings.
- Pixel-art airport building assets integrated into the live grid and catalog.
- Taxiway connectivity from stands / hangars to compatible runways.
- Service-road routing for ground vehicles.
- Runway occupancy and arrival/departure queues.
- Two connected starter stands, a 3-slot starter hangar, and two Pico P8 aircraft.
- Player-selected routes with real manifests, passenger loads, operating costs, profit, and airport XP.

### Current building catalog

| Building | Footprint | Cost | Unlock | Aircraft |
| --- | ---: | ---: | ---: | --- |
| Short Runway | 7×2 | 10,000 | Lv 1 | S |
| Small Aircraft Stand | 2×2 | 4,500 | Lv 1 | S |
| Taxiway | 1×1 | 250 | Lv 1 | S/M/L |
| Service Road | 1×1 | 150 | Lv 1 | Ground vehicles |
| Small Terminal | 3×2 | 8,000 | Lv 1 | S |
| Basic Fuel Station | 2×2 | 7,500 | Lv 2 | S |
| Small Hangar | 3×3 | 12,000 | Lv 3 | S |
| Rapid Small Fuel Station | 2×2 | 30,000 | Lv 7 | S |
| Medium Aircraft Stand | 3×3 | 45,000 | Lv 8 | S/M |
| Regional Fuel Depot | 3×3 | 60,000 | Lv 8 | S/M |
| Regional Rapid Fuel Station | 4×3 | 130,000 | Lv 13 | S/M |
| Regional Hangar | 4×3 | 105,000 | Lv 8 | S/M |
| Regional Runway | 10×3 | 150,000 | Lv 8 | S/M |

Fuel infrastructure stores both service speed and vehicle capacity. Normal and rapid stations therefore differ mechanically by aircraft compatibility, truck count, and turnaround speed.

## Airside connectivity

Taxiway cells form the operational aircraft network.

A stand or hangar is operational only when:

1. it touches a taxiway; and
2. that taxiway network reaches a compatible runway.

Disconnected buildings remain placeable for layout freedom, but the game shows warnings in the world view and Airfield Status HUD.

## Ground-service roads

Fuel trucks no longer cross the airport in a direct line.

A compatible fuel station must have a valid:

**Fuel Station → Service Road → Aircraft Stand**

route before the dispatcher can assign one of its trucks.

The truck follows that route outbound, services the aircraft, and follows the same route back to its station.

## Ground-service capacity

The starter airport demonstrates real servicing bottlenecks:

**Basic Fuel Station**
- S-class aircraft
- x1.0 service speed
- 1 truck
- two waiting aircraft = one serviced, one queued

**Rapid Small Fuel Station**
- S-class aircraft
- x1.6 service speed
- 2 trucks
- two waiting aircraft = both can be serviced simultaneously

The dispatcher automatically prefers faster compatible stations that still have an available truck and valid road access.

## Runway traffic

Every departure and arrival route identifies its runway.

A runway can handle only one active aircraft operation at a time.

Operations use a shared queue:

**Departure ready → request runway → clearance → taxi / takeoff**

or:

**Inbound aircraft → request runway → clearance → approach / landing**

When the runway is occupied, later aircraft wait automatically. The next compatible operation is released as soon as the previous aircraft clears the runway.

## Aircraft lifecycle

The starter airport continuously runs two temporary S-class aircraft through the local airport loop:

**Parked → Fuel request → Fuel truck → Ready → Runway queue → Taxi out → Line up → Takeoff roll → Climb → En route → Holding for arrival → Approach → Landing roll → Taxi in → Parked**

After parking, the flight is settled and net profit plus Airport XP are credited. The aircraft then waits for the player to choose its next destination in the Fleet screen before fueling begins.

Aircraft release their stand when taxiing out. Returning aircraft reserve a free compatible stand before requesting landing clearance. If every compatible stand is occupied, they remain in a holding state until one becomes available.

The en-route segment now uses a compressed version of the calculated route duration. Aircraft range and cruise speed therefore change how long a plane remains away while keeping development/testing sessions short.

Aircraft and fuel-truck visuals are still temporary code-drawn prototypes. The airport buildings already use the first Skyport Online pixel-art asset set.

## V1 aircraft catalog

Pass 7 defines the first nine player aircraft while keeping the size model future-ready for L and XL aircraft:

| Unlock | Aircraft | Size | Capacity | Range |
| ---: | --- | :---: | ---: | ---: |
| Lv 1 | Pico P8 | S | 8 | 320 km |
| Lv 2 | Swift S14 | S | 14 | 430 km |
| Lv 4 | Comet C22 | S | 22 | 600 km |
| Lv 6 | Voyager V32 | S | 32 | 900 km |
| Lv 8 | Nimbus N40 | M | 40 | 1,050 km |
| Lv 10 | Arrow A52 | M | 52 | 1,300 km |
| Lv 12 | Atlas A64 | M | 64 | 1,500 km |
| Lv 15 | Falcon F72 | M | 72 | 1,900 km |
| Lv 17 | Horizon H88 | M | 88 | 2,350 km |

Each definition stores purchase price, passenger capacity, range, cruise speed, fixed operating cost, distance fuel cost, passenger service cost, turnaround time, and hangar-space usage.

## Flight economy

Prototype routes now store level unlock, distance, passenger demand, ticket yield, completion bonus, maximum aircraft size, Airport XP, and country-resource bridge metadata.

A flight manifest calculates passenger load, gross revenue, fuel cost, fixed operating cost, passenger service cost, net profit, duration, XP, and profit per minute.

This deliberately prevents a bigger-is-always-better fleet. S-only routes preserve small-aircraft value, while oversized M aircraft lose efficiency when demand is too low for their extra capacity and operating cost.

Country-linked routes already retain the planned **40% resource-roll chance** through a resource-pool key; the later World Map/country pass can resolve that key into each country's three unique resources.

## Fleet & route planner

The landscape Fleet screen now exposes three working columns:

- **Owned Fleet** — select any owned aircraft and see whether it is parked, stored, servicing, en route, or inbound.
- **Aircraft Catalog** — browse all nine V1 S/M aircraft with level lock, purchase price, capacity, range, specialty, and live infrastructure/hangar requirements.
- **Route Planner** — compare unlocked destinations before dispatch. Compatible rows show passenger load, calculated duration, gross revenue, operating cost, net profit, and Airport XP.

Aircraft purchases use physical hangar capacity. The starter airport begins with a **3-slot Small Hangar** and **2× Pico P8**, so only one additional S aircraft fits before another hangar is required.

Purchased aircraft may remain stored in the hangar while all stands are occupied. Once a compatible stand becomes free, selecting a route deploys the stored aircraft onto that stand and starts its fuel/service/departure lifecycle.

Connected infrastructure is required for purchases: a suitable hangar, stand/runway path, and reachable fuel service must exist for the aircraft size. This is already generic across **S → M → L → XL**, even though only S and M aircraft are currently exposed.

## Automated validation

GitHub Actions currently performs:

- Godot project import / GDScript parsing.
- Landscape main-scene headless startup smoke test.
- Airside connectivity tests.
- Service-road routing tests.
- Fuel speed and truck-capacity tests.
- Departure runway queue tests.
- Arrival runway queue tests.
- Full aircraft lifecycle test from takeoff through landing and parking.
- Aircraft catalog, route compatibility, profitability, and Airport XP tests.
- Fleet hangar-capacity and infrastructure-readiness tests.

## Run

1. Install Godot 4.3 or newer.
2. Import this repository by selecting `project.godot`.
3. Run the project.

## Next pass

**Pass 9 — Interactive World Map + country route resources**

Recommended next work:

- Turn the WORLD navigation button into the first landscape world-map screen.
- Reuse the route catalog as selectable destination markers/regions.
- Wire each country into its three unique resource drops.
- Resolve the existing 40% per-resource roll after a completed flight.
- Show route range, aircraft suitability, passenger demand, expected economics, and possible country resources on the map.
- Let the Fleet route planner and World Map open the same underlying dispatch flow.
