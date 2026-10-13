# Handling Structure Art Pass V4

This pass refines the existing **in-game production assets**, not the gameplay rules. It preserves the square logical 64 × 64 grid and exact Skyrama 2:1 isometric visual footprint `square_grid_iso_v1`.

| Asset | Grid size | Production files |
| --- | --- | --- |
| Basic Fuel Station + fueling pad | 2×2 | `airport_buildings_v3/basic_fuel_structure.svg`, `airfield_v3/service/basic_fuel_pad_2x2.svg` |
| Cargo / Ground Operations Depot + handling pad | 1×1 | `airport_buildings_v3/ground_ops_structure.svg`, `airfield_v3/service/ground_ops_pad_1x1.svg` |
| Closed Small Hangar + apron | 3×2 or 2×3 | `airport_buildings_v3/small_hangar_0.svg`, `small_hangar_90.svg`, both `airfield_v3/service/small_hangar_pad_*.svg` orientations |
| Touchdown smoke, taxi puffs and takeoff wake | 4×2 FX atlas (64×64 cells) | `aircraft_motion_v4/aircraft_motion_fx_v4.svg` |

All paths above are inside `assets/production/` and remain bound in `BuildingCatalog.gd` or `AircraftMotionArt.gd`.

Refinements include tank inspection hatches, steel service pipework, control glazing, cargo loading shutters, conveyors, parcels, hangar roller-door bands, rooftop HVAC, apron guidance and subdued motion wisps. Materials retain blue/white airport identity with restrained yellow hazard markings. Pad overlays remain clipped within projected footprint diamonds; both hangar orientations are maintained.

The manual airplane sequence is **not changed**: RECEIVE → landing → UNLOAD → cargo handling → HANGAR; choose destination → fuel → LOAD → cargo handling → SEND → takeoff. The runway remains single-occupancy. The build tutorial, costs, passenger/fuel rules and navigation are untouched.

## Validation

Run from the project root with Godot available:

```sh
godot --headless --path . --script tests/handling_art_v4_test.gd
godot --headless --path . --script tests/skyrama_service_visual_test.gd
godot --headless --path . --script tests/skyrama_simple_handling_test.gd
```

For actual visual QA on a graphical Godot build, run `tests/capture_handling_structures_ingame.gd` and `tests/capture_skyrama_flight_fx.gd`. Screenshot captures are separate QA actions; visual parity with the canonical `skyport_buildings_atlas.webp` must still be reviewed at playable zoom.

