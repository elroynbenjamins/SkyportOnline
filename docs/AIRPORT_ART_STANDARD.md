# Canonical Airport Art Standard

> **Updated 2026-10-27 — primary visual quality reference is now [Cassette Beasts-quality pixel airport art](CASSETTE_QUALITY_PIXEL_AIRPORT_STANDARD.md).** Skyrama remains an interaction/airport-layout reference. This file records supporting rules and legacy asset guidance; the new style target supersedes older SVG/glossy-vector recommendations.

## Minimum quality reference

**Artistic standard:** an original, lively, high-detail pixel-art airport diorama with the world depth, environment integration and polish associated with Cassette Beasts. New production world art should be carefully authored raster pixel art or a separately validated 2.5D/voxel solution, not smooth SVG building illustrations.

The historical project comparison atlas is:

`assets/production/airport_buildings_v2/skyport_buildings_atlas.webp`

It remains useful for building identities and relative silhouettes **but is not the visual-quality ceiling or the required final style**. New assets must be judged in assembled Godot screenshots under the new reference standard, not accepted merely for matching the old atlas or having a newer version suffix.

## Required visual language

Airport buildings should use an independently designed, richly detailed isometric **pixel-art / miniature-diorama** style with:

- strong, readable isometric silhouettes
- high-detail architecture appropriate to the building's function
- blue/white Skyport identity with restrained yellow/orange safety accents where appropriate
- deliberate pixel clusters and shared original palette; no smooth gradients disguised as pixel art
- layered material treatment for glass, concrete, metal, roof panels, doors, tanks, service areas, landscaping, and ground markings
- consistent upper-left lighting direction
- soft, grounded ambient/contact shadows
- believable rooftop and service detail such as HVAC, antennas, lamps, bollards, signs, vents, railings, cones, equipment, and utility props
- integrated landscaping and apron/forecourt detail where appropriate
- clean transparent-background production assets with no visible generation artifacts
- crisp nearest-filtered world-sprite readability at normal gameplay zoom while retaining deliberately authored detail when zoomed in

## Orientation and implementation

For movable/rotatable buildings, provide the two gameplay-required isometric orientations. Full 360-degree rotation is not required.

Artwork resolution and gameplay footprint remain separate. Respect the exact projected 2:1 ground footprint and its contact polygon, depth sorting and reliable interaction. Sideways overhangs at ground level must not break cell boundaries. Taller roof silhouettes may rise above the base within the world-art contract.

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

Before an airport-building asset is wired into gameplay, compare it with the **Cassette Beasts-quality visual direction** in `docs/CASSETTE_QUALITY_PIXEL_AIRPORT_STANDARD.md` and actual game screenshots. The old v2 atlas is historical context only.

The asset is acceptable only when the **assembled in-game scene** meets or exceeds the agreed benchmark in:

1. silhouette quality
2. architectural detail
3. material depth
4. lighting and shadow consistency
5. airport-specific props/details
6. isometric perspective
7. normal-zoom readability
8. overall polish and cohesion

The prior atlas is an interim compatibility reference, **not** the new production quality floor.


## Environment and background standard

The airport background should support a cohesive, richly layered pixel-art diorama without competing with placeable content.

- use authored landscape shapes rather than a single flat green fill;
- keep upper-left lighting and lower-right contact shading consistent with buildings;
- use layered grass, rolling hills, distant water and tree belts at the scene edges;
- keep the central airport land quieter and lower-contrast so the construction grid remains immediately readable;
- preserve the fixed 2:1 isometric presentation in field and scenery direction;
- never bake gameplay footprints, collision, routing or placement ownership into the background image;
- never cover the background with an opaque grid-reset rectangle;
- background scenery must remain visually outside or beneath the logical build layer and must not imply false usable tiles.

The current production landscape baseline is:

`assets/production/environment_v3/airport_landscape_v3.svg`

It is a scene backdrop, not a substitute for grid-native runway, taxiway, apron or building art.

Decorative roads do not belong in the default backdrop. Roads, taxiways, service routes, parking and other airport infrastructure should come from explicit placeable/gameplay assets so the landscape remains open and Skyrama-like.


## Airfield surface art standard

The current **6×2 Short Runway** is the canonical logical V1 runway footprint (verify against `src/build/BuildingCatalog.gd`). Its **new pixel-art replacement** should establish the shared runway/apron material family.

Taxiways, runway connectors, apron transitions and future airfield pavement should visually inherit:

- the same dark blue-grey asphalt material depth;
- the same warm beige stone/concrete curb treatment;
- the same small inset blue edge-light treatment where lights are appropriate;
- restrained warm yellow taxi guidance markings;
- crisp upper-left highlights and lower-right contact shading;
- exact `square_grid_iso_v1` footprint boundaries with no visual overhang.

V1 aircraft service uses instant transfers between separate parking pads and the runway. Taxiways and service roads are **not required buildable dependencies** in the approved V1, and must not be reintroduced through visual modernization. Any future airport pavement should use the same world-texture family while respecting gameplay-owned footprints.
