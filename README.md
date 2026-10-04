# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 6 — Landscape airport + full local flight lifecycle

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
- Two connected starter stands with two S-class aircraft.
- Continuous aircraft turnaround and flight demo loop.

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
| Rapid Small Fuel Station | 2×2 | 30,000 | Lv 6 | S |
| Medium Aircraft Stand | 3×3 | 35,000 | Lv 8 | S/M |
| Regional Fuel Depot | 3×3 | 45,000 | Lv 8 | S/M |
| Regional Rapid Fuel Station | 4×3 | 85,000 | Lv 10 | S/M |
| Regional Runway | 10×3 | 90,000 | Lv 12 | S/M |

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

After parking, the aircraft re-enters the turnaround flow and requests fuel again.

Aircraft release their stand when taxiing out. Returning aircraft reserve a free compatible stand before requesting landing clearance. If every compatible stand is occupied, they remain in a holding state until one becomes available.

The en-route segment is still a short local demo timer. The future World Map / route system will replace that temporary timer with real destination travel.

Aircraft and fuel-truck visuals are still temporary code-drawn prototypes. The airport buildings already use the first Skyport Online pixel-art asset set.

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

## Run

1. Install Godot 4.3 or newer.
2. Import this repository by selecting `project.godot`.
3. Run the project.

## Next pass

**Pass 7 — Flight destinations + first World Map bridge**

Recommended next work:

- Replace the temporary en-route timer with a small flight-data model.
- Add the first local destination list and flight duration / reward data.
- Make an aircraft remain airborne until its assigned route completes.
- Prepare a dedicated World Map scene without yet building the final global resource economy.
- Begin first proper pixel aircraft and fuel-truck sprites once their required angles are locked.
