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


## Environment and background standard

The airport background should support the same polished stylized game-art level as the building atlas without competing with placeable content.

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

The **5×2 Small Runway** is the canonical base style for grid-native airfield surfaces.

Taxiways, runway connectors, apron transitions and future airfield pavement should visually inherit:

- the same dark blue-grey asphalt material depth;
- the same warm beige stone/concrete curb treatment;
- the same small inset blue edge-light treatment where lights are appropriate;
- restrained warm yellow taxi guidance markings;
- crisp upper-left highlights and lower-right contact shading;
- exact `square_grid_iso_v1` footprint boundaries with no visual overhang.

A connected taxiway network must read as one continuous paved system. Players place one Taxiway object; straight, corner, dead-end, T and cross visuals are selected automatically from adjacency rather than exposed as separate shop items.
