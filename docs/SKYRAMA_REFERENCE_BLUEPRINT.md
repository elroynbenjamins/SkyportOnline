# SkyportOnline — Skyrama reference-reconstruction blueprint

Status: **research/implementation reference, not executable Skyrama code**  
Created: 2026-10-27  
Scope: publicly observable design and documented behavior, translated into an independent implementation for SkyportOnline.

## Purpose and guardrails

Skyrama is a reference for game feel: a lively airport that dominates the screen, satisfying aircraft dispatch/arrival, manual tap-to-complete handling, readable action bubbles, passenger and cargo production, a playful build/shop rail, steady unlocks, and reciprocal social flights.

This is **not** a plan to copy Skyrama code, download/extract proprietary graphics, reproduce its trademarks, automate access to private services, or imitate its exact economy. Use independently authored code, aircraft, textures, UI assets, audio, branding and balanced values. Historical FAQ values are references to mechanics, not current game implementation constants.

Research confidence levels:
- **Verified source** = published on Skyrama website/forum/wiki (older guides may describe historical versions).
- **Verified local code** = directly inspected in SkyportOnline's repository at 2026-10-27.
- **Design choice** = intentional SkyportOnline departure from Skyrama.
- **Unverified** = only observable via actual gameplay/client or screenshots, and needs testing before being treated as fact.

## Public Skyrama gameplay: reference inventory

| Area | Documented Skyrama behavior | SkyportOnline design response | Primary implementation |
| --- | --- | --- | --- |
| Airport presentation | Airport map/planes/buildings form primary play screen; world flight selection and social flights coexist | Keep airport visually dominant in landscape; compact overlay controls and contextual bubbles, not an admin dashboard | `src/world/AirportGrid.gd`, `src/ui/HUD.gd`, `src/ui/AircraftContextCard.gd` |
| Construction | Build runways, hangars, bays, terminals, decor; grow an airport | Independent pixel art, strict square logical occupancy / 2:1 projection, concrete/aligned foundations | `src/build/BuildingPlacementGrid.gd`, `src/build/BuildingCatalog.gd`, `src/world/AirportGrid.gd` |
| Own-flight dispatch | Choose plane/destination; passenger requirement for passenger planes; plane returns with rewards | Country selection, fuel and cargo parking, manual LOAD/SEND, flight timer and mastery/resource rewards | `src/worldmap/WorldMapScreen.gd`, `src/flight/FlightRules.gd`, `src/aircraft/AircraftPrototype.gd` |
| Arrival/handling | Landing, servicing, time-sensitive buddy turnarounds, manual progression | Manual RECEIVE → landing → UNLOAD → timed unload → HANGAR; one operational aircraft per runway | `src/services/RunwayDispatcher.gd`, `src/services/SkyramaParkingRules.gd`, `src/services/TurnaroundRules.gd` |
| Passenger loop | Buildings periodically generate collectable passengers; passenger aircraft spend passengers to launch | Passenger-generation buildings, collection/boost display, sustainable early-game dispatch rhythm | `src/passenger/PassengerEconomy.gd`, `src/passenger/PassengerDemandRules.gd` |
| Cargo / goods | Aircraft bring goods; shops sell stocked goods for coins | Preserve SkyportOnline country-specific resources, cargo handling, upgrades and separate charter district instead of porting historical shop stats | `src/data/CountryResourceCatalog.gd`, `src/flight/ResourceDropRules.gd`, `src/charter/CharterRules.gd` |
| Social | Service friends' inbound planes, gain reciprocity/reputation, visit airports | Expand existing social/friend services and meaningful visits; use independent names and balance | `src/social/SocialAirportService.gd`, `src/social/SocialFlightRules.gd`, `src/social/FriendshipRules.gd` |
| Progression | Intro quests, more advanced plane classes, bigger airport, cargo/passenger unlocks | Keep own S/M launch progression, tutorial steps, missions, upgrades, events, alliances | `src/progression/StarterAirportTutorial.gd`, `src/progression/AirportProgressionRules.gd`, `src/events/EventManager.gd` |
| UI | Busy compact resource/status strip; picture-led aircraft/building inventory, contextual world icons | Modern mobile readability, touch targets >=44 px, less clutter, friendlier palette, readable bubbles | `src/ui/GameUIStyle.gd`, `src/ui/GlossyWorldBubble.gd`, `src/ui/HUD.gd` |

### Reference flight sequences to implement and regress

**Sending owned planes (SkyportOnline's approved V1)**

1. Select available plane and destination country.
2. Validate country, passenger and fuel requirements, compatible infrastructure, and vacant fuel parking.
3. Instantly appear at a separate fuel parking slab; run fuel timer and show a non-interactive progress state.
4. On completion show exactly one tappable LOAD action.
5. On tap transfer plane to vacant compatible cargo parking; run loading timer.
6. On completion show exactly one tappable SEND action.
7. On tap request runway. If occupied, retain plane safely at prior stage; never duplicate requests.
8. Once runway clear, place at START, animate takeoff, then enter flight timer.
9. Award flight completion once; preserve aircraft identity, destination, resources and mastery.

**Receiving owned planes (SkyportOnline's approved V1)**

1. Flight timer completes; show RECEIVE action.
2. When runway available, tap RECEIVE; animate approach/landing to END.
3. Occupied runway blocks both arrivals and departures.
4. Tapping UNLOAD transfers aircraft to compatible separate cargo parking and releases runway.
5. Timed unloading runs; progress bubble is not an actionable completion bubble.
6. On completion show HANGAR; tapping HANGAR returns plane to the fleet ready state.
7. Guard against repeated taps, foreground/background timer catch-up and conflicting runway/parking occupancy.

**Friend flight servicing (Skyrama gameplay reference; validate current SkyportOnline behavior)**

- Friend inbound aircraft must have explicit visibility/attention, a remaining service timer and a safe expiration/missed-service policy.
- On-time service should deliver meaningful rewards, without copying Skyrama's historical fixed values.
- Avoid making friend flights mandatory for solo players.
- If not currently wired, treat as a separate future development task, not a silent dependency of owned-plane V1.

## Important differences: do not regress accepted project decisions

1. **No required taxiing or road connectivity in V1.** Landing/takeoff animate; ground transfers are instantaneous after manual bubble actions. Decorative taxi/roads are not prerequisites.
2. **Separate service parking from service buildings.** Plane sits on a small dedicated fuel or cargo slab (small 3×2); service building determines processing capacity, not visual aircraft parking.
3. **One runway slot.** A plane waiting at END blocks another movement until UNLOAD. SEND-ready planes wait safely off-runway.
4. **Current grid is logically square.** A logical cell is 64×64; the 2:1 isometric projected diamond is 64×32. Do not confuse isometric projection with rectangular logical occupancy.
5. **Own visual identity.** Modern friendly HUD and independently authored pixel art—not a literal copy of old Skyrama panels.
6. **Country choice should not punish distant countries.** SkyportOnline has country-specific resource drops; preserve its intended launch balance.
7. **S/M classes for V1; L/XL later.** Avoid adding infrastructure/plane classes purely because a Skyrama FAQ mentions them.
8. **Do not add legacy taxiway/pathfinding dependencies back into gameplay.**

## Verified repository state and document conflicts to resolve first

Based on directly read source:
- `src/build/BuildingCatalog.gd` defines `short_runway` as **6×2** with `airfield_v5` art. `docs/GRID_VISUAL_CONTRACT.md` still says **5×2** and describes old taxiway connectivity. **Action:** treat current code and `docs/AIRPORT_V1_VISUAL_SCOPE.md` (6×2) as the intended V1 reference until regression-tested; update older docs afterward.
- `docs/AIRPORT_V1_VISUAL_SCOPE.md` specifies **Small Hangar 4×3**, **Medium Hangar 5×4** and removes mandatory taxi-road placement.
- `src/build/BuildingCatalog.gd` defines `fuel_parking_s` and `cargo_parking_s` each as **3×2** independent pads with one parking slot and no road-connection requirement.
- `src/services/SkyramaParkingRules.gd` distinguishes service processing capacity from occupancy of individual parking slabs; a completed aircraft retains its pad until it moves.
- `docs/SKYRAMA_HANDLING_V1.md` defines the complete owned-plane click-and-transfer cycle and one-aircraft runway rule.
- `docs/MODERN_HUD_CODE_VISUAL_HANDOFF.md` identifies working action rail, bubble, countdown and layout contracts. UI restyling must preserve signal names and action state changes.
- `src/world/AirportGrid.gd` has `GRID_FIRST_VISUAL_RESET := true`. Verify actual visuals in Godot screenshots before assuming all placed structures display production assets.

This audit is source-level only. It does **not** assert Godot execution, screenshot validation, or access to Skyrama's current interactive client.

## Priority implementation plan

### Pass 0 — Establish a trustworthy baseline
- Reconcile roadmap/docs with current code, prioritizing V1 decisions above.
- Run existing regression tests; capture real Godot airport at 1280×720 and narrow ~980×500 landscape.
- Record exact UI screenshots and flags for startup, airport after tutorial, landing, fuel parking, cargo parking, world map and build mode.
- Mark each system as functional / visually incomplete / unverified / missing. Avoid starting new mechanics until the golden path is stable.

### Pass 1 — The recognizable airport experience
- Make airport scene dominate playfield. Keep the top resources compact and action rail readable.
- Consistent grid-native airport-office/hangar/runway/service-pad visuals; visible plane-to-building scale and base grounding.
- Use one concrete family and predictable placement projections so the airport reads as one built space.
- Improve camera framing and zoom such that runway, pads, hangars and several planes can be understood in one glance.

### Pass 2 — Manual aircraft handling feel
- Audit RECEIVE/UNLOAD/HANGAR and FUEL/LOAD/SEND paths for stuck timers, tap duplication, runway blocking and parking deadlocks.
- Ensure every bubble has consistent progress vs ready affordance, with friendly icon and readable state.
- Add restrained landing/takeoff effects; never block the player's tap flow behind unnecessary animation.

### Pass 3 — Rewarding airport management loop
- Tie terminal passenger collection, airplane dispatch, resources, upgrades and hangar constraints to a coherent onboarding loop.
- Progress should reveal new destinations/aircraft/buildings naturally.
- Balance early flights around meaningful short sessions; do not import historical Skyrama resource costs or monetization rules.

### Pass 4 — Social and long-term play
- Verify social send/receive, visiting, cooperative benefits, alliance actions, contracts and events.
- Design social rewards that do not become mandatory to progress.
- Add later-size assets and facilities only after S/M vertical slice is polished.

## Acceptance criteria for the first playable slice

- Brand-new profile with only airport office can finish the guided airport build and send a first plane without unsupported dependencies.
- Grid occupancy, rotation and visual foundations exactly match each 6×2 runway, 4×3 small hangar, 5×4 medium hangar, 3×2 fuel pad and 3×2 cargo pad.
- One full send/receive operation can be played via bubbles with no page of diagnostic text required.
- No aircraft can occupy two processing positions simultaneously, be double-awarded, or land on an occupied runway.
- Timers have stable progress→ready transition after app resume; no duplicate clicks grant rewards twice.
- Plane proportions and click areas make sense at both desktop and mobile landscape zoom.
- Godot screenshots (not generated concept renders) meet asset placement and HUD checks.

Candidate tests already present in repository: 
`tests/skyrama_simple_handling_test.gd`, `tests/skyrama_runway_slot_test.gd`,
`tests/separate_service_parking_test.gd`, `tests/roadless_airport_grid_test.gd`,
`tests/airport_three_asset_focus_test.gd`, `tests/skyrama_hud_rail_test.gd`,
`tests/short_runway_grid_art_test.gd`, `tests/medium_hangar_grid_test.gd`.
Review/re-run them in the existing Godot CI rather than claiming they passed without execution.

## Research sources

- Official overview: https://www.skyrama.com/?locale=en
- Official English community forum: https://board-en.skyrama.com/
- Public beginners FAQ (friend servicing, rewards, missed service, shop goods): https://board-en.skyrama.com/threads/faq-beginners-guide-terminology.9871/
- Public basic game FAQ (tutorial, timers, layout, hangars): https://board-en.skyrama.com/threads/basic-game-questions-faq.749/
- Public passenger FAQ: https://board-en.skyrama.com/threads/faq-passengers.9944/
- Public goal progression FAQ: https://board-en.skyrama.com/threads/faq-main-goals.9861/
- Public airside-building FAQ: https://board-en.skyrama.com/threads/faq-airside-buildings.9864/
- Public event plane examples (do not copy economy values): https://board-en.skyrama.com/threads/faq-event-planes.9878/

## Guidance for a coding agent / Codex

Work in small PRs. Read this reference plus `docs/SKYRAMA_HANDLING_V1.md`, `docs/AIRPORT_V1_VISUAL_SCOPE.md` and current runtime code **before editing**. Identify source-of-truth discrepancies, state what is implemented versus missing, avoid modifying the accepted transfer/timer flow unless fixing a demonstrated bug, and run relevant Godot tests. Attach actual in-game before/after screenshots for art/HUD changes. Never treat third-party screenshots as licensed assets.
