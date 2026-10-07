# Grid → Visual Contract

The airport grid is now the authority for every placeable object's world geometry.

## Projection

- Isometric 2:1.
- One logical cell is **64 px wide × 32 px tall** at 1× world scale.
- A cell coordinate represents the center of its diamond.
- Screen/world picking snaps to the **nearest cell center**, never by flooring the inverse transform.

## Placeable-object rules

Every placeable definition owns only a logical footprint such as `1×1`, `2×2`, `3×2` or `7×2`.

The grid derives:

- occupied cells;
- footprint polygon;
- visual base bounds;
- depth order;
- selection/hover/placement outlines;
- collision and placement checks;
- the future asset render box and anchor.

Art must never change the footprint, move the ground contact point, or introduce horizontal footprint overhang.

For a `W × H` footprint:

- base width = `(W + H) × 32 px`;
- base height = `(W + H) × 16 px`;
- ground anchor = **front-center** of the grid-authored base;
- 90° logical rotation swaps `W × H` to `H × W`.

## Current reset mode

`AirportGrid.GRID_FIRST_VISUAL_RESET` keeps the live airport intentionally primitive. The scene renders only grid-derived terrain diamonds, exact placeable footprints, network guide lines and placement/selection feedback.

No airport background, building atlas, authored runway/taxiway texture, environmental decoration, ambient-life sprite or catalog preview is part of the live airport rendering path.

Future visuals should be authored *for* these footprint contracts rather than scaled or offset after import.
