# SkyportOnline — canonical visual direction (2026-10-27)

## Decision

**Visual-quality benchmark: _Cassette Beasts_.**  
**Gameplay/interaction reference: _Skyrama_.**  
**SkyportOnline's visual identity: original, charming high-detail pixel-art airport diorama with friendly modern UI.**

This document is the project's **primary style authority** for *new or replaced* airport/world sprites, ground art, aircraft, building exteriors, environmental props and world-level visual effects. Older standards that identify a v2 SVG/isometric atlas as the final quality baseline are superseded for *artistic direction*, **not** for geometry or already-functional assets. Do not replace stable art with worse work merely to meet a file format.

This is inspiration, not an instruction to copy Cassette Beasts sprites, tilemaps, palette files, textures, models, logos, characters or proprietary artwork. We want a comparable level of polish and coherence with an independent airport theme.

## Why this style is practical in Godot

Cassette Beasts was created in Godot. The developers describe 2D pixel-art character sprites in a 3D environment; their world geometry uses voxel-authored tiles, a fixed camera perspective and grid-based terrain. That pipeline is an **option**, not a requirement for SkyportOnline.

Technical primary reference:
- https://godotengine.org/article/godot-showcase-cassette-beasts/
- https://www.cassettebeasts.com/2021/08/09/technical-look-the-park/ (historical developer technical description; URL may move)
- https://www.pockettactics.com/cassette-beasts/interview (art director describes "GBA HD", shared colour economy and 2D sprites in 3D environments)

The current SkyportOnline game is **Godot 4**, primarily 2D \`Node2D\`/CanvasItem rendering, with a square logical construction grid and 2:1 isometric projection. A quality upgrade does **not** require throwing away the functioning aircraft/service logic. We should **test the visual pipeline before migrating it**.

## The visual target

- **A handcrafted miniature airport**, not a UI/debug board. Viewed from a fixed friendly isometric angle, rich but readable.
- **Pixel art is real art direction**, not a filter applied to a smooth vector: deliberate pixel clusters, confident silhouettes, shaded material planes, readable edges and a controlled detail hierarchy.
- **Pixel-rich but not noisy**: small grass patches, seams, flower clusters, trees, windows, roof vents, shadow transitions, bollards, safety paint, signs, luggage, vehicles and subtle activity. Most important gameplay objects remain easy to spot.
- **Coherent color family**, not unrelated saturation per asset: lively grass, sky, warm stone, slate/blue-gray asphalt, cool glass, blue/white Skyport buildings, restrained amber/yellow aircraft safety accents. Borrow the *principle* of a shared palette from Cassette Beasts; construct an original palette.
- **Layers and depth**: terrain transitions, contact shadows, occlusion, tree groups and perimeter landscape make structures feel embedded in their world. Building pads are functional paved surfaces and should not look like floating stickers.
- **Modern casual UX**, not fake pixel-art text everywhere. World sprites can use pixel art while HUD fonts remain crisp, accessible and modern.

### Canonical per-element guidance

| Element | Style requirement | Reject |
| --- | --- | --- |
| Grass/terrain | Pixel-textured, tile-compatible grass variations, soft readable transitions, trees/bushes at appropriate layer, no repeating obvious stamps | Blank flat green plane with permanent white construction grid |
| Runway (small 6×2) | Crisp high-detail runway surface with threshold markings, asphalt noise, edge lights and contact edges; correct exact world footprint | A narrow gray strip floating in empty grass |
| Hangars (small 4×3, medium 5×4) | Friendly stylized roof/walls, rich pixel clusters, windows/doors, signage, believable depth, consistent lighting | Flat glossy SVG roofs / smoothed gradients posing as pixel art |
| Cargo/fuel pads (3×2) | Same pavement family and seams as runway/aprons; markings and low-profile props; physical parking bay is visible | A separate abstract icon or patch with no material continuity |
| Planes (S/M) | Distinct, readable directional original sprites; shaded wings/fuselage, windows and subtle animated accents; correctly sized against building doors and service bays | Tiny dots, blurred rotation, mismatched relative size |
| Terminal/office/utility | Function-specific architecture with distinct silhouette, signage, roof detail and fitted shadows | Generic recolored rectangle |
| Trees/fences/lamps | Repeatable modular groups with organic variation, clean depth sorting and restrained ambient motion | Repetitive copy-paste tiles or clutter on playable cells |
| UI | Friendly compact UI with larger legible labels and status indicators; pixel-art illustrations in cards but smooth typography for accessibility | Busy brown retro browser chrome or developer-diagnostic overlays |
| Service bubbles | High-contrast actionable icon, separate timer/progress state, thumb-size hitbox independent of image | Inconsistent glow, non-clickable small icon, progress mistaken for ready |

## Geometry and logical system: DO NOT CHANGE

The existing \`square_grid_iso_v1\` contract remains canonical:
- 64×64 logical square cell; 2:1 screen projection, one cell = 64×32 projected diamond.
- Author art **for** the W×H footprint and fixed camera. Never warp a beautiful but wrong perspective asset into a tile.
- Current V1 example footprints: short runway **6×2**, small hangar **4×3**, medium hangar **5×4**, small cargo/fuel parking **3×2**. Verify each against \`BuildingCatalog.gd\` before exporting.
- Plane service logic is still **Skyrama-style instant transfers**, landing and takeoff animation only. **Do not add mandatory taxiway roads.**
- Placement grid is a tool; show in build/move mode, not as a normal-play ground texture.
- Buildings need normal and rotated view assets where applicable; no automatic smooth rotation of pixel-art images.
- Rendering resolution can be greater than logical resolution but the projected *world size and grid anchor* must remain unchanged.

## Production asset pipeline — first safe approach (2D)

1. **World-specific concept and pixel-art production**: design an original airport asset with the exact footprint, camera angle, light direction and intended screen-space sprite size stated up front.
2. **Raster production**: create/paint pixel art in layered raster source; export RGBA PNG sprites and tile atlases with intentional pixel clusters and transparency. No unreviewed AI artifacts or plain SVG renderings as final world sprites.
3. **Palette/density controls**: begin with an original shared ~24–32 color *base* palette with deliberate material ramps; extend sparingly for distinctive planes/seasonal features. Keep one consistent pixel density across adjacent world assets.
4. **Godot import**: nearest-neighbor for *world pixel-art textures* and sprite-aligned presentation. HUD/fonts and nonpixel UI elements may use linear filtering; evaluate zoom/shimmer before setting project-wide filtering.
5. **Environment assembly**: layered grass and ground/pavement textures; separate tree/fence/prop sprites; fixed lighting/shadow direction; real contact edges/foundation treatment.
6. **Preview and runtime**: show actual Godot 1280×720 and ~980×500 viewport at typical play zoom *and* building placement rotation. No acceptance by standalone image alone.
7. **Safe rollout**: convert one set of core assets to this style and compare with existing runtime images. Keep fallbacks until fully validated, then replace the legacy art incrementally.

Suggested new production path for exploratory assets: \`assets/production/pixel_airport_v1/\`. Do not rename working assets or change the catalog en masse before the pilot is approved.

## Optional 2.5D voxel/3D pipeline — proof before migration

Cassette Beasts' look also benefits from actual three-dimensional world geometry. This could be valuable for hangars, terrain elevation and depth/lighting, but SkyportOnline does not have player-controlled 3D traversal or a rotating camera. A full conversion of the 2D airport to 3D is **high-cost and currently unapproved**.

If the 2D pilot cannot achieve the target quality, create an **isolated Godot 4 art spike**:
- Orthographic fixed-angle \`Camera3D\` and small 3D/voxel-styled terrain, hangar, runway and aprons;
- plane as a billboard/pixel-art sprite or a deliberately styled voxel mesh;
- explicit projection mapping for existing grid and tap coordinates;
- comparable screenshot at the *same composition*, camera zoom and level of detailing;
- frame/performance check on target landscape mobile hardware.

Do not migrate authoritative placement/collision/flight/services until this side-by-side comparison justifies it. 3D does not automatically guarantee good art.

## First pilot slice (required before bulk regeneration)

Make ONE small, believable airport scene:
- grass and perimeter environment, transitions and a few trees;
- a single **6×2 short runway**;
- **4×3 small hangar** and **5×4 medium hangar**;
- separate **3×2 fuel pad** and **3×2 cargo pad**, coherent asphalt/concrete;
- two **original S-class planes** with correct directionality and scaling;
- at least one active service bubble with progress, one ready bubble, and a compact HUD;
- ambient details (lights, cones, crate, service prop) but no excessive clutter.

**Quality gate:** a player must immediately recognize a complete charming pixel-art airport rather than individually pasted components, at 1280×720 and compact landscape. The new scene must compare favorably to reference screenshots for material richness, environment cohesion, readability and polish, while respecting original IP boundaries. A working code test is not sufficient.

### Production tests

- Existing grid/placement/orientation/handling tests must pass unmodified where appropriate; if tests assert old art properties, update **only** the relevant art contract tests along with the pilot.
- Capture a **real gameplay screenshot**, before/after, not a mockup.
- Check alpha and contact shadows, anchors, outline separation, nearest-filter crispness and zoom behavior.
- Check legibility at multiple screen sizes and on a mobile GPU. Profile performance and reduce overdraw if necessary.
- The old art remains available as a fallback until the pilot passes visual review.

## Implementation order

**Phase A — Art direction + technical spike:** establish original pixel palette and asset scale; paint one high-quality hangar, one concrete pad, one plane and one terrain block. Integrate into a side-by-side Godot scene without disrupting current play.

**Phase B — Unified ground system:** blend grass/paving/foundations, add modular landscaping and safe animated details. This is the largest current visual improvement.

**Phase C — Buildings and aircraft:** finish runway/hangar/pads/terminal/office S/M catalog in the same art style; polish plane size and four directional sprites.

**Phase D — UI and motion:** contemporary compact HUD with pixel-art icon accents, world bubbles, small feedback animation and transitions, better in-game camera composition.

**Phase E — Optional 2.5D comparison:** only if 2D assets plus lighting still cannot meet the Cassette Beasts-inspired quality bar.

## Existing documentation reconciliation

- \`docs/AIRPORT_ART_STANDARD.md\` must now point here as artistic authority; its older v2 atlas remains a **historical in-project reference**, not the final standard.
- \`docs/GRID_AUTHORED_BUILDING_STANDARD.md\` stays authoritative for **2D placement/projection math**; older small-hangar dimensions and file paths are historical examples.
- \`docs/AIRPORT_V1_VISUAL_SCOPE.md\` and live \`BuildingCatalog.gd\` are authoritative for current V1 footprints and approved simplified handling.
- \`docs/MODERN_HUD_CODE_VISUAL_HANDOFF.md\` keeps working UI signal and touch contracts.
- \`docs/SKYRAMA_HANDLING_V1.md\` remains authoritative for instant-transfer gameplay flow.

**No claim of achieved style:** this document records a new target and path. The current Godot screenshots are not yet at this quality.