# Grid → Visual Contract

The airport uses a **square logical construction grid** with a separate **Skyrama-style isometric screen projection**.

## Logical grid

Gameplay never uses 64×32 cells.

- Every logical cell is **64 × 64**.
- Footprints remain exact square-cell counts such as `1×1`, `2×2`, `3×2` and `8×2`.
- Placement, collision, routing, ownership and rotation all operate on those logical square cells.
- 90° rotation swaps `W × H` to `H × W`.

This is the Lego-block rule.

## Skyrama-style view

The square ground is projected into a fixed 2:1 isometric view for presentation:

- logical cell: **64 × 64**;
- projected cell diamond: **64 px wide × 32 px deep**;
- logical X projects down-right;
- logical Y projects down-left;
- the camera itself stays fixed-angle;
- pointer input is inverse-projected back to the nearest logical square cell.

So a tile **looks** like a 64×32 diamond on screen, but it **is** still one square 64×64 gameplay cell.

## Placeable footprints

The logical sizes currently locked for the starter airport are:

- Fixed Airport Office: **2×2** — the only structure present on a brand-new airport
- Short Runway: **8×2**
- Small Aircraft Stand: **2×2**
- Small Terminal: **3×2**
- Small Hangar: **3×2**
- Basic Fuel Station: **2×2**
- Taxiway / Service Road / Apron: **1×1**
- Regional Runway: **12×3**

The upper **16×8 logical cells** of the initial 16×16 owned construction area remain free of pre-positioned buildings for player-built airside infrastructure.

## Projected art bases

Art is authored against the projected footprint, while gameplay remains square.

For a logical `W × H` footprint:

- projected base width = `(W + H) × 32 px`;
- projected base depth = `(W + H) × 16 px`;
- the projected front corner is the ground anchor;
- the asset body may rise upward from that base;
- runtime does not resize or hand-offset a valid asset.

Examples:

| Logical footprint | Projected base |
| --- | ---: |
| 1×1 | 64 × 32 px |
| 2×1 | 96 × 48 px |
| 2×2 | 128 × 64 px |
| 3×2 | 160 × 80 px |
| 8×2 | 320 × 160 px |
| 12×3 | 480 × 240 px |

This keeps future buildings, runway pieces and roads visually aligned with the same projected ground diamonds the player sees.

## Current reset mode

`AirportGrid.GRID_FIRST_VISUAL_RESET` is still active.

The airport therefore uses primitive footprint blocks for **placeable gameplay content** while we validate geometry. Deleted legacy buildings and misaligned ground-piece art are still not allowed back into the placement layer.

The independent scene backdrop is now an exception by design: it may use authored environment art because it does not own placement, collision, routing, or footprints. The production background is `environment_v3/airport_landscape_v3.svg`.

The reset view now intentionally resembles the Skyrama composition more closely:

- angled 2:1 ground grid;
- richer authored grass, field, road and tree framing around the airport;
- a quieter central airport land shoulder so placement cells remain easy to read;
- fixed landscape framing;
- buildable land extending toward the foreground;
- no opaque reset rectangle covering the scene backdrop.

## Asset contract

The current placeable contract identifier is:

`visual_contract = "square_grid_iso_v1"`

The contract exposes both logical and visual geometry:

- `logical_tile_size = (64, 64)`;
- `projected_tile_width = 64`;
- `projected_tile_height = 32`;
- projected footprint polygon and bounds;
- exact projected art width/depth;
- projected front ground anchor;
- `runtime_scale = (1, 1)`.

Future airport art should be generated specifically for this contract.


## New-player construction flow

A brand-new airport begins with only the fixed **Airport Office**. It is hidden from the construction catalog and cannot be moved.

The tutorial forces the player through eight free construction grants in order: **Short Runway → Small Hangar → Small Stand → Taxiways → Basic Fuel Station → Ground Operations Depot → Service Roads → Small Terminal**.

Only the exact active tutorial target is free and exempt from its normal level requirement. Normal catalog prices remain unchanged. The first aircraft is spawned only after the construction sequence is complete; the tutorial then teaches taxi, service, destination selection, loading, pushback/send and takeoff.

Tutorial completion is persisted so an interrupted tutorial resumes, while legacy airports with an existing layout are treated as already onboarded.
