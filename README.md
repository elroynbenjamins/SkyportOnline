# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 2 — Build mode foundation

The repository now contains a playable airport-building foundation:

- Godot 4 mobile project targeting a portrait 720×1280 reference viewport.
- Isometric 24×24 airport grid split into 3×3 expansion parcels.
- One owned starting parcel with a small starter airport.
- Level-gated and coin-gated land expansion parcels.
- Expansion costs ranging from 25,000 to 2,000,000 coins.
- One-finger pan and two-finger pinch zoom on mobile.
- Right-mouse drag and mouse-wheel zoom for desktop/editor testing.
- Build catalog with level locks, costs, aircraft-size compatibility, and footprints.
- Green/red placement preview based on land ownership and occupied tiles.
- Rotation for rotatable buildings.
- Coin deduction on confirmed placement.
- Future regional infrastructure visible in the same catalog architecture.

### Current building catalog

| Building | Footprint | Cost | Unlock | Aircraft |
| --- | ---: | ---: | ---: | --- |
| Short Runway | 7×2 | 10,000 | Lv 1 | S |
| Small Aircraft Stand | 2×2 | 4,500 | Lv 1 | S |
| Taxiway | 1×1 | 250 | Lv 1 | S/M/L |
| Small Terminal | 3×2 | 8,000 | Lv 1 | S |
| Small Hangar | 3×3 | 12,000 | Lv 3 | S |
| Basic Fuel Station | 2×2 | 7,500 | Lv 2 | S |
| Regional Rapid Fuel Station | 4×3 | 65,000 | Lv 10 | S/M |
| Regional Runway | 10×3 | 90,000 | Lv 12 | S/M |

The fuel data model already stores service speed and vehicle capacity so later fuel stations can differ by aircraft size, truck count, and turnaround speed.

## Visual state

The airport is still rendered with code-drawn pixel-style placeholder shapes. This is deliberate: the grid, economy, placement rules, and building footprints are being proven before final pixel sprites are wired in.

## Run

1. Install Godot 4.3 or newer.
2. Import this repository by selecting `project.godot`.
3. Run the project.

GitHub Actions imports the project and runs the main scene headlessly to catch parser and startup errors.

## Next pass

**Pass 3 — Infrastructure behavior and visual upgrade**

Recommended next work:

- Explicit runway / taxiway / stand connectivity.
- Standard vs rapid fuel-station variants.
- Small vs medium aircraft compatibility validation.
- Basic service-vehicle capacity.
- Replace the code-drawn starter buildings with the first real Skyport Online pixel-art asset set.
