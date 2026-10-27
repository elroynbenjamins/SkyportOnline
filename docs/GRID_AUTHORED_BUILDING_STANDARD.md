# SkyportOnline — Grid-authored building art standard (v6)

> **Geometry/placement contract only (legacy v6 examples).** The current **artistic quality target** is `docs/CASSETTE_QUALITY_PIXEL_AIRPORT_STANDARD.md`. Current gameplay footprints are defined by `src/build/BuildingCatalog.gd`, including small hangar 4×3, medium hangar 5×4, runway 6×2 and 3×2 service parking. Older 3×2 hangar examples below explain the coordinate math, **not** the current building catalog. SVG is not the default final art format for newly produced pixel-world assets.

**Canonical example:** `small_hangar`, `assets/production/airport_buildings_v6/small_hangar_{3x2,2x3}.svg`.

The visual grid must determine the building geometry **before** art is produced. Do not resize, skew, crop or freehand-place a finished illustration onto the footprint.

## One coordinate system

- Logical gameplay tiles are squares, **64×64 logical units**.
- Screen projection is 2:1 isometric, **64×32 pixels per tile diamond**, named `square_grid_iso_v1`.
- Building footprint `w × h` projects to a base width of `32(w+h)` px and depth of `16(w+h)` px.
- In a top-aligned base-local coordinate system, the exact footprint corners in clockwise order are:
  - Rear/top: `(32h, 0)`
  - Right: `(32(h+w), 16w)`
  - Front/bottom: `(32w, 16(w+h))`
  - Left: `(0, 16h)`
- For an art sprite of height `H`, add vertical offset `H - 16(w+h)` to those base vertices. The footprint's **front/bottom vertex is the sprite's ground anchor**.
- Walls must rise **vertically upward** from these fixed polygon ground corners. A barrel roof may curve and project upward, but the building's *ground-level* footprint may not cross a cell edge.

## Production sizes

| Building | Footprint | Exact base | Example transparent art canvas |
| --- | --- | --- | --- |
| Small Hangar | 3×2 | 160×80 | 160×190 |
| Rotated Small Hangar | 2×3 | 160×80 | 160×190 |
| Basic Fuel Station | 2×2 | 128×64 | 128×150 (illustrative) |
| Cargo / Ground Operations | 1×1 | 64×32 | 64×80 (illustrative) |

Canvas height above the base is artistic flexibility. **Canvas width must equal exact projected base width**. Author tall portions within that width so neighboring grid cells remain available.

## Required visual layer and asset rules

1. **The game owns pavement:** the existing `grid_native_surface_paths` draw the placed surface and safety stripes. Building sprites must not bake in a separate platform or grass cutout.
2. Render the building's front and side walls from actual projected tile edges, using the same slopes as the grid (+0.5 and −0.5).
3. Transparent space is primarily **above the footprint**. No sideways overhang or visible ground objects outside the polygon. The engine should not be asked to hide painted defects.
4. Every rotatable structure needs authored 0°/90° art paths. Runtime mirroring/rotating is a fallback only after visually verifying the projection; v6 hangar uses two distinct file paths.
5. `grid_first_structure_width_scale = 1.0`. Do not independently scale artwork to compensate for the wrong asset base width.
6. Do not use `grid_first_structure_clip_base_to_footprint` for grid-authored art. Contact shadows must stay beneath the walls and inside the pad. Disable extra renderer shadows if a fitted shadow is already in the sprite.
7. Favor polished, colorful, original **authored pixel art** and consistent light direction at gameplay zoom. The old v6 geometry examples remain useful but are not an acceptable pixel-art quality baseline. See the canonical style standard.

## Acceptance requirements

- Building catalog preserves the logical footprint and correct rotation.
- Imported sprite width equals `32(w+h)` and is a valid Godot Texture2D.
- Place/build preview snaps to valid tiles in both orientations without clipping or visual floating.
- Alpha near the ground outside footprint is transparent; no sky/terrain holes between a curved roof and its gable.
- Capture and inspect a **real Godot viewport screenshot** for placed and rotated views. Passing code tests alone does not establish acceptable visual quality.
- Run `tests/generated_hangar_grid_test.gd`, `tests/starter_building_grid_fit_test.gd`, `tests/handling_art_v4_test.gd`, and use `tests/capture_generated_hangar_grid_ingame.gd` for visual QA.

## Reuse on other buildings

Calculate footprint polygon -> select visible front/side walls -> build walls from actual polygon corners -> draw roof above -> export 2 variants as needed -> wire 1:1 into catalog -> view in the real airport at 1.75–1.9× zoom. **Never start by resizing a free-form generated building.**

Apply the same math and QA process to all current live footprints from `BuildingCatalog.gd`. Preserve fuel and cargo **parking pads as separate 3×2 assets**; their service buildings are not themselves the parked aircraft stands.
