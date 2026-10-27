# SkyportOnline — Visual-quality acceptance gate

Created: 2026-10-27  
Goal: Skyrama's immediately readable, inviting airport-game feeling, with *higher quality original artwork*, a cleaner HUD, and consistent grid-native rendering. Do not declare a visual pass complete based on mockups, asset-generation output, vector-source previews, version numbers, or CI passing alone.

## Evidence: actual Godot screenshot audit (main commit `92e635fb...`)

Source: [Godot Actions run 40470673725](https://github.com/elroynbenjamins/SkyportOnline/actions/runs/40470673725) (documentation PR based on same runtime), screenshot artifacts `current-grid-first-airport`, `airport-core-art-ingame`, `small-medium-hangars-ingame`, `separate-service-parking-ingame`, `skyrama-handling-bubbles`, and `skyrama-hud-world-and-build`.

**What was observed:**

- Plain green airport ground with construction diamonds in normal-play shots; the grid overpowers the airport.
- Hangar art has attractive blue/white roof details, but the rest of the airport is visually sparse and disconnected.
- Runway surfaces are small relative to large architectural silhouettes; the scene needs gameplay-zoom ratio checks, not arbitrary rescaling of sprites.
- Service planes, parked planes and their bubbles are present, but the environment has little sense of a working airport.
- HUD structure is compact and functional, but palette, small icon detail, visual hierarchy and panel finishing are not release-grade yet.
- Many screenshot fixtures deliberately show only an empty tutorial airport. These are useful **negative-space** tests but cannot prove a busy functioning airport looks good.
- The normal-airport screenshot fixture did **not** instantiate the authored `AirportBackdrop`, producing black empty surround. This fixture gap is corrected in the companion code pass.

These are assessment findings from real test screenshots, **not** a claim that all visuals are bad in a loaded game, nor a comparison made from a live Skyrama client.

## Non-negotiable quality criteria

| Area | Requirement | Failure / must rework |
| --- | --- | --- |
| Airport framing | Visible built airport fills a useful central share of a 1280×720 landscape viewport, with smooth surrounding environment | Tiny island of content in a large empty background |
| Terrain | Layered, gentle authored texture or environment and perimeter scenery; uninterrupted beneath footprints | Solid green debug slab or permanent bright placement grid |
| Construction grid | Only visible while placing, moving, restoring or explicitly editing; land-expansion mode shows eligible plots without revealing all cells | Permanent lattice during normal play |
| Ground coherence | Same concrete/asphalt material family across runways, service pads, hangar foundations and apron pieces; clean contact edges | Each building looks like it was pasted onto grass |
| Geometry | Exact authored footprint, 2:1 projection, rotations and anchors | Runtime stretch, clipped corners, off-grid footings, floating |
| Building art | Polished, toy-like airport architecture with blue/white accents, consistent highlights and meaningful roof/door/service details | Primitive blocks, low-detail monochrome substitutes, random perspectives |
| Aircraft | Distinct original sprites for each class; crisp directional appearance, readable at default zoom, appropriately proportional to apron/hangar and runway | Tiny unrecognizable dots or unrealistically oversized planes |
| HUD | Friendly, compact resource strip, distinct primary action icons, clear inactive/ready states, strong contrast at 980×500 and 1280×720 | Dark technical dashboard, overwhelming panel coverage, text overflow |
| Bubbles | Clear action vs progress visual language; never mistake timed service for tap-ready action | Ambiguous icons, hard-to-tap bubbles, multiple attention prompts over each other |
| Active scene | Aircraft, cargo and passenger loop visibly alive with moderate ambient detail and readable rewards | Functional state machine but visually empty and static |
| Performance | Crisp stable frame presentation with no unnecessary redraw churn; test device/viewport readability | Significant slowdowns from full-scene textures or SVG paths |

## Required screenshots for every visual PR

Use *real Godot viewport captures*, before and after, at the same camera coordinates and zoom.

1. New airport: office only; tutorial/placement grid visible only while editing.
2. Early operating airport: runway + small hangar + separate fuel and cargo pads + 2–3 planes.
3. Midgame S/M scene: at least 2 different hangars, runway, terminal, service facilities, landscape perimeter.
4. Handling interaction: at least one waiting action bubble and one non-tappable service-progress bubble.
5. Build mode: all logical diamonds visible, a correctly snapped footprint preview, and unobstructed confirm/cancel actions.
6. Compact landscape HUD around 980×500; full landscape 1280×720.

Do not approve an asset from a standalone render. Compare the actual assembled airport and the assets' native game-size display.

## Implementation order, not a list of cosmetic distractions

**V0 — Remove prototype presentation:** hide construction lines during ordinary play, ensure backdrop renders in all QA fixtures, inspect captures. (Companion code pass.)

**V1 — Environment + ground cohesion:** redesign regular play grass, property edges, paved aprons and base pads so there is no disconnected building-on-grass effect. Preserve grid identity and placement math.

**V2 — Airport visual scale:** align small aircraft / service slabs / 6×2 runway / 4×3 small hangar / 5×4 medium hangar using *in-game* ratios. Improve runway silhouettes and plane proportions without changing logical occupancy.

**V3 — UI/interaction art:** modernize the HUD, resource chips, build catalog, building cards and five bubble states with cohesive colors, professional iconography and subtle animation.

**V4 — Richness + polish:** refined terrain/environment, decorative airport activity, responsive effects, zoom performance and seasonal dressing.

## Review rule

A pass is complete only when:
- mechanics and regression suite pass;
- grid contract tests pass;
- before/after captures exist;
- normal-play scene is materially clearer and more cohesive;
- art is original and production-ready at the actual gameplay zoom;
- no important screen looks worse than it did before.

A successful build is **not** proof of better visuals. If screenshot comparison is inconclusive, record that explicitly instead of marking the visual work complete.
