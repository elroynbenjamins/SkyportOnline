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


## Asset authoring coordinate system

The contract now exposes the values a visual generator/importer must use directly:

- `authoring_width_px` = exact projected footprint width;
- `base_depth_px` = exact projected footprint depth;
- `base_polygon_from_anchor` = the four base corners relative to the ground anchor;
- the **front-center ground contact is (0, 0)** in anchor-relative coordinates;
- `runtime_scale = (1, 1)` and `asset_pixels_per_world_pixel = 1`;
- the asset body may extend **upward only** from the footprint base;
- transparent padding is permitted **above only**;
- no horizontal transparent padding or visual overhang is allowed.

This means a future asset is not “fit to the grid” after generation. It is authored against the grid contract in the first place. Runtime placement only translates the asset so its front-center anchor matches the grid-authored anchor; it does not resize or hand-offset it.

### Example projected bases

| Footprint | Authoring width | Base depth |
| --- | ---: | ---: |
| 1×1 | 64 px | 32 px |
| 2×1 | 96 px | 48 px |
| 2×2 | 128 px | 64 px |
| 3×2 | 160 px | 80 px |
| 7×2 | 288 px | 144 px |

A building may be taller than its base depth because the body rises above the ground plane. Its width still stays inside the contract width.


## Runtime placement rule

A future texture is accepted only when its source width exactly matches `authoring_width_px` and its height is at least `base_depth_px`. The runtime then uses `asset_draw_rect()`:

1. compute the footprint's front-center ground anchor;
2. keep the source texture at **1:1 scale**;
3. place the texture so its **bottom-center pixel** lands on that anchor;
4. reject a wrong-width asset instead of auto-scaling it.

There is therefore no alpha-bound scan, guessed offset, per-building nudge, or “fit this image into the cell” stage in the new path. Incorrect art fails the contract and must be regenerated/fixed.
