# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 3 — Airside network + first moving aircraft

The repository now contains a playable airport-building foundation with real airside connectivity:

- Godot 4 mobile project targeting a portrait 720×1280 reference viewport.
- Isometric 24×24 airport grid split into 3×3 expansion parcels.
- Level-gated and coin-gated land expansion parcels.
- One-finger pan and two-finger pinch zoom on mobile.
- Right-mouse drag and mouse-wheel zoom for desktop/editor testing.
- Build catalog with level locks, costs, aircraft-size compatibility, and footprints.
- Green/red placement preview based on land ownership and occupied tiles.
- Rotation for rotatable buildings.
- Coin deduction on confirmed placement.
- Pixel-art airport building assets integrated into the live grid and build catalog.
- Taxiway network connectivity from stands / hangars to runways.
- Live Airfield Status HUD with disconnected-building warnings.
- Placement preview warning when an airside building has no runway-connected taxiway.
- First S-class aircraft prototype that follows the real stand → taxiway → runway route.

### Current building catalog

| Building | Footprint | Cost | Unlock | Aircraft |
| --- | ---: | ---: | ---: | --- |
| Short Runway | 7×2 | 10,000 | Lv 1 | S |
| Small Aircraft Stand | 2×2 | 4,500 | Lv 1 | S |
| Taxiway | 1×1 | 250 | Lv 1 | S/M/L |
| Small Terminal | 3×2 | 8,000 | Lv 1 | S |
| Basic Fuel Station | 2×2 | 7,500 | Lv 2 | S |
| Small Hangar | 3×3 | 12,000 | Lv 3 | S |
| Rapid Small Fuel Station | 2×2 | 30,000 | Lv 6 | S |
| Medium Aircraft Stand | 3×3 | 35,000 | Lv 8 | S/M |
| Regional Fuel Depot | 3×3 | 45,000 | Lv 8 | S/M |
| Regional Rapid Fuel Station | 4×3 | 85,000 | Lv 10 | S/M |
| Regional Runway | 10×3 | 90,000 | Lv 12 | S/M |

Fuel infrastructure already stores service speed and vehicle capacity, so normal and rapid stations can differ by aircraft size, truck count, and turnaround speed.

## Airside connectivity

Taxiway cells form the operational airside network.

A stand or hangar is considered connected only when:

1. it touches a taxiway, and
2. that taxiway network reaches a runway.

Disconnected airside buildings remain placeable for layout flexibility, but the game shows a warning marker, changes the building label, and updates the Airfield Status HUD.

The starter airport currently passes an automated connectivity test that checks:

- the starter stand is connected;
- a newly placed disconnected stand is detected;
- the disconnected stand preview warns the player;
- extending the taxiway connects that stand;
- a valid stand-to-runway departure route is exposed.

## First aircraft prototype

The starter airport spawns one temporary S-class commuter aircraft.

Current behavior:

**Parked at stand → taxi to runway → roll to runway end → hold**

The aircraft uses the same taxiway graph as the connectivity system. Its visual is still code-drawn; the dedicated pixel aircraft sprite pack should replace it after movement and sizing are finalized.

## Run

1. Install Godot 4.3 or newer.
2. Import this repository by selecting `project.godot`.
3. Run the project.

GitHub Actions currently performs:

- Godot project import / script parsing.
- Main-scene headless startup smoke test.
- Airside connectivity and departure-route regression test.

## Next pass

**Pass 4 — Aircraft servicing foundation**

Recommended next work:

- Aircraft S/M compatibility checks against runway and stand.
- Parked aircraft state and turnaround/service requirements.
- Basic fuel request and fuel-station assignment.
- Standard vs rapid fuel service timing.
- First visible fuel-truck prototype.
- Replace the temporary aircraft drawing with the proper Skyport Online pixel aircraft asset.
