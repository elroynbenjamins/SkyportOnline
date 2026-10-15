# Airport V1 — Focused visual scope

**Approved gameplay:** Skyrama-style manual bubble actions; landing or takeoff animation only on the 5×2 short runway; instant transfers to/from handling pads and hangars. **No plane taxi movement and no taxi-road placement requirement**. Road network reachability is not a condition for receiving, servicing or sending aircraft.

## Priority art and exact square-grid contracts

| Asset | Cells | Ground canvas | Source |
|---|---|---|---|
| Small Hangar | 3×2 / 2×3 | 160×80 px | `assets/production/airport_buildings_v6/small_hangar_{3x2,2x3}.svg` |
| Medium Hangar | 4×3 / 3×4 | 224×112 px | `assets/production/airport_buildings_v7/medium_hangar_{4x3,3x4}.svg` |
| Small Runway | 5×2 / 2×5 | 224×112 px | `assets/production/airfield_v4/short_runway_{5x2,2x5}.svg` |

Hangars draw their separate matching concrete pad beneath a transparent building sprite. All decorative footings, edge stripes and inset markings must follow the exact projected grid footprint. Never scale a free-form illustration to compensate for a mismatched footprint.

## Retired taxi feature

- The building catalog currently does **not** sell taxiways.
- The active airside network classifies stand/hangar buildings as available without road connectivity. The manual handling loop teleports aircraft; physical taxi simulation and taxiway purchases are out of scope.
- Legacy taxiway shaders/assets, tests and pathfinding helper functions still exist in the repository for compatibility with older code and fixtures. Do not re-enable them or make new visuals for them. Remove only after confirming no exported runtime methods, scripts, tests or save readers reference them; deleting the helpers abruptly would break loads and tests.

## Visual quality gate

The production sprites (not standalone generated concepts) must be validated in Godot. The screenshot `tests/capture_small_medium_hangars_ingame.gd` places all three assets directly on the actual airport grid, without a taxi connection. Use the `small-medium-hangars-ingame` GitHub Actions artifact to inspect at playable zoom. Keep iterating on readable silhouettes, blue roof highlights, concrete joints and safe ramp markings until this capture is approved.

Tests include `tests/airport_three_asset_focus_test.gd`, `tests/generated_hangar_grid_test.gd`, `tests/medium_hangar_grid_test.gd` and `tests/short_runway_grid_art_test.gd`.
