# Canonical Airport Art Standard

## Minimum quality reference

The canonical minimum visual-quality reference for airport buildings is:

`assets/production/airport_buildings_v2/skyport_buildings_atlas.webp`

All newly generated, regenerated, or replaced airport-building artwork must match or exceed this atlas visually.

A later asset version number (for example `v3` or `v4`) does **not** automatically make an asset acceptable. If a newer asset is visually simpler, flatter, less detailed, less cohesive, or less polished than the v2 atlas, it should be rejected or regenerated before implementation.

## Required visual language

Airport buildings should use a polished 2D isometric game-art style with:

- strong, readable isometric silhouettes
- high-detail architecture appropriate to the building's function
- blue/white Skyport identity with restrained yellow/orange safety accents where appropriate
- layered material treatment for glass, concrete, metal, roof panels, doors, tanks, service areas, landscaping, and ground markings
- consistent upper-left lighting direction
- soft, grounded ambient/contact shadows
- believable rooftop and service detail such as HVAC, antennas, lamps, bollards, signs, vents, railings, cones, equipment, and utility props
- integrated landscaping and apron/forecourt detail where appropriate
- clean transparent-background production assets with no visible generation artifacts
- crisp readability at normal gameplay zoom while retaining detail when zoomed in

## Orientation and implementation

For movable/rotatable buildings, provide the two gameplay-required isometric orientations. Full 360-degree rotation is not required.

Artwork resolution and gameplay footprint remain separate. The art may overhang its logical footprint, but its visible base must align correctly with the isometric tile footprint and preserve reliable depth sorting and interaction.

The exact production asset used in the world should also be reused where practical in build cards, building context cards, and management/upgrade panels.

## What is below standard

Do not ship airport-building artwork that relies on:

- flat placeholder rectangles or primitive procedural geometry as the main visual
- low-detail legacy pixel/SVG art when a production-quality replacement is available
- generic buildings with minimal airport identity
- inconsistent perspective, scale, lighting, or shadow direction
- sparse silhouettes without functional rooftop/service/ground detail
- visibly lower-quality art merely because it has a newer version label

Procedural drawing remains appropriate for dynamic effects such as selection outlines, placement feedback, lights, glows, safety indicators, movement effects, and other transient gameplay feedback.

## Quality gate

Before an airport-building asset is wired into gameplay, compare it against `skyport_buildings_atlas.webp`.

The asset is acceptable only when it is visually equal to or better than that reference in:

1. silhouette quality
2. architectural detail
3. material depth
4. lighting and shadow consistency
5. airport-specific props/details
6. isometric perspective
7. normal-zoom readability
8. overall polish and cohesion

This atlas is the floor, not the ceiling.


## Grid-native asset contract

The airport construction grid is authoritative. The canonical cell is **64 × 32 px in isometric world space**.

All buyable/placeable airport art must be authored as grid-native modular pieces:

- one logical cell uses the exact diamond `(32,0) → (64,16) → (32,32) → (0,16)`
- an `N × M` footprint is the exact union of those cells under the game's isometric transform
- taxiways, service roads and other connectable surfaces must meet neighbouring cells at the exact shared edge midpoint and keep identical connection widths
- runway, apron, stand and building ground-contact art must align to the declared logical footprint; visible architecture may rise upward but the ground base, painted slab and contact shadow must not claim neighbouring logical cells
- rotatable placeables need the gameplay-required grid orientations, with the footprint swapped exactly when rotation swaps X/Y
- build-tray and management previews should be derived from the same grid geometry rather than redrawn with a different perspective
- decorative scenery may overhang visually only when it is not player-placeable; once scenery becomes buyable/placeable, it must gain a grid-native base
- do not use arbitrary free-form diamonds, perspective-skewed rectangles, or oversized painted bases to make an asset appear larger than its logical footprint

Think of placeable airport content as **Lego blocks**: art detail can be rich, but every base and every connector must snap cleanly to the same 64 × 32 construction system.

### Grid-native quality gate

Before shipping a placeable asset, verify:

1. declared footprint matches the visible ground-contact footprint
2. cell edges and connector midpoints line up exactly
3. no ground paint or shadow leaks into an unoccupied neighbouring cell
4. rotation preserves the same grid contract
5. world and preview art share the same perspective and footprint
6. normal gameplay zoom still reads as one coherent airport set
