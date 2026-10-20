# Pico P8 sprite refinement — V2 candidate

This sprite refinement is a non-destructive visual candidate for the starter Pico P8 plane.

- Four transparent 128 × 128 pixel-art directions in a single optimized, 256 × 256 PNG atlas.
- Directions are packed NE top-left, SE top-right, SW bottom-left, NW bottom-right.
- Blue-and-white airport livery, stronger wing panels, windows, cockpit shading, landing gear and propeller details.
- World `CareerAircraft`, Fleet screen and aircraft context card use the same directional sprite source.
- Previous `assets/pixel/aircraft/pico_p8/*.png` remain in the repo and will load automatically if the new atlas is missing.
- Runtime footprint and aircraft interaction radius remain unchanged; flight handling and economy are unaffected.
- Compared against the existing sprites and resampled to stay legible at the existing 78px nominal world render size.
- Godot validation checks import, direction regions, cache, world, Fleet and card views. `capture_pico_refined_visual.gd` captures runway and fuel-pad scenes.

This branch stacks on PR #210; merge #210 before this PR, or retarget afterward.
