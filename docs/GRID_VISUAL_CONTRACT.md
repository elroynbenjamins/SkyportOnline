# Grid → Visual Contract

The airport grid is the authority for every placeable object's world geometry.

## Grid

- **True square Cartesian grid**, Skyrama-style.
- One logical cell is **64 × 64 px** at 1× world scale.
- A cell coordinate represents the center of its square.
- X moves horizontally by 64 px.
- Y moves vertically by 64 px.
- Screen/world picking snaps to the nearest square-cell center.

There is no isometric diamond projection in the placement system.

## Placeable-object rules

Every placeable definition owns a logical footprint such as `1×1`, `2×2`, `3×2` or `7×2`.

The grid derives occupied cells, rectangular footprint bounds, selection/hover/placement outlines, collision, routing positions and the future art anchor.

For a `W × H` footprint:

- base width = `W × 64 px`;
- base height = `H × 64 px`;
- 90° rotation swaps `W × H` to `H × W`;
- ground anchor = **bottom-center of the rectangular footprint**.

Art never changes the logical footprint.

## Examples

| Footprint | Grid base |
| --- | ---: |
| 1×1 | 64 × 64 px |
| 2×1 | 128 × 64 px |
| 2×2 | 128 × 128 px |
| 3×2 | 192 × 128 px |
| 7×2 | 448 × 128 px |

This is the Lego-block rule: roads, taxiways, buildings, stands and runways all occupy exact square-cell rectangles.

## Current reset mode

`AirportGrid.GRID_FIRST_VISUAL_RESET` keeps the live airport intentionally primitive.

The airport currently renders square land cells, exact placeable footprints, square road/taxiway cells, network guide lines, and placement/selection feedback. Legacy airport building/background/surface art is not in the active rendering path.

## Future artwork

The artwork can still have perspective, depth and a Skyrama-like illustrated appearance. That perspective belongs **inside the asset**, not in the placement grid.

The square grid remains unchanged underneath it.

The asset contract exposes:

- `authoring_width_px` = exact footprint width;
- `base_depth_px` = exact footprint height;
- `base_polygon_from_anchor` = rectangular base corners;
- `runtime_scale = (1, 1)`;
- `asset_pixels_per_world_pixel = 1`;
- no horizontal footprint overhang.

A future texture is accepted only when its source width exactly matches the footprint width and its height is at least the footprint height. Runtime places its bottom-center on the footprint's bottom-center anchor without resizing or hand-tuned offsets.

Buildings may visually rise upward above their occupied rectangle. Their logical occupied cells remain exact squares.

## Contract identifier

New placeables expose:

`visual_contract = "square_grid_v1"`

Any future airport asset should be generated against this square-grid contract from the start.
