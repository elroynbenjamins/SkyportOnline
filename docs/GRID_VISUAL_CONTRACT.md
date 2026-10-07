# Grid → Visual Contract

The airport uses a **square logical construction grid** with a separate **Skyrama-style isometric screen projection**.

## Logical grid

Gameplay never uses 64×32 cells.

- Every logical cell is **64 × 64**.
- Footprints remain exact square-cell counts such as `1×1`, `2×2`, `3×2` and `5×2`.
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
- Short Runway: **5×2**
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
| 5×2 | 224 × 112 px |
| 12×3 | 480 × 240 px |

This keeps future buildings, runway pieces and roads visually aligned with the same projected ground diamonds the player sees.

## Current reset mode

`AirportGrid.GRID_FIRST_VISUAL_RESET` is still active.

The airport therefore uses primitive footprint blocks for **placeable gameplay content** while we validate geometry. Deleted legacy buildings and misaligned ground-piece art are still not allowed back into the placement layer.

The independent scene backdrop is now an exception by design: it may use authored environment art because it does not own placement, collision, routing, or footprints. The production background is `environment_v3/airport_landscape_v3.svg`.

The reset view now intentionally resembles the Skyrama composition more closely:

- angled 2:1 ground grid;
- richer authored grass, distant hills, water and tree framing around the airport;
- a quiet continuous grass center so placement cells remain easy to read;
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


## Expansion visibility

Expansion parcels are gameplay data, not permanent scenery.

- normal airport play shows only land the player already owns;
- unowned parcel outlines, labels and future lock markers remain hidden;
- the Build/Shop drawer contains **Expand Land**;
- choosing Expand Land enters a temporary expansion-selection mode;
- only currently connected, adjacent plots are revealed;
- disconnected future plots remain hidden even in expansion mode;
- selecting a highlighted plot opens its level/cost requirements;
- after purchase or cancel, the expansion overlay disappears and the clean landscape returns.

Do not reintroduce a permanent expansion-slot board around the airport.


## Short Runway production surface

The small-aircraft **Short Runway** is the first placeable surface promoted from reset geometry to grid-native production art.

- logical footprint: **5×2** cells;
- rotated footprint: **2×5** cells;
- authored image size: **224×112 px** in either orientation;
- runtime scale: **1:1**;
- no horizontal overhang;
- bottom-center asset anchor maps to the projected front footprint corner;
- two production orientations are supplied under `assets/production/airfield_v3/`;
- the visible runway shoulder, asphalt, markings and edge lights all stay inside the exact projected footprint.

This asset is allowed to render during `GRID_FIRST_VISUAL_RESET` because its artwork is authored directly against `square_grid_iso_v1`. Other placeable art remains blocked until it meets the same contract.


## Taxiway production surface

The starter **Taxiway** uses the same grid-native contract as the Small Runway.

- logical footprint: **1×1** cell;
- authored image size: **64×32 px**;
- runtime scale: **1:1**;
- exact projected diamond: `(32,0) → (64,16) → (32,32) → (0,16)`;
- base art contains the concept-style curb/asphalt material;
- connection openings are drawn dynamically from the actual neighboring gameplay cells.

Taxiway visual connectivity uses the same adjacency rule as routing. A taxiway automatically opens and extends toward neighboring:

- taxiways;
- runways;
- aircraft stands;
- hangars.

When a taxiway touches a runway cell, the connection overlay extends slightly past the shared grid edge and covers the runway curb at that seam. This makes the asphalt and yellow taxi centerline visually enter the runway without requiring a separate connector object. The overlay remains inside the union of the two connected gameplay footprints.
