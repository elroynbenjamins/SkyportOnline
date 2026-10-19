# Modern airport HUD — code / visual handoff

The behavior is implemented first; the visual art can be upgraded later without
rebuilding the airport gameplay or changing button signals. Target: modern casual
mobile airport game with restrained Skyrama character, **not** a dated browser HUD.

## Interaction contract (already wired)

- `src/ui/HUD.gd` owns the airport overlay. Top: level / XP / coins / Aero /
  passengers / fuel; bottom: live contextual operation text.
- Right action rail defaults to **Build, Fleet, World, Tasks, Tools, More**.
  **Tools** toggles Edit, Storage, Social. On small landscape screens the
  rail scrolls rather than drawing beneath the bottom dock.
- Attention on Social also marks the collapsed Tools shortcut; the notification
  must not disappear merely because the underlying Social button is hidden.
- Drawer, building placement, editing and land-expansion modes hide the rail.
  Closing a drawer restores it. Keep the `nav_buttons` keys and existing signals.
- The builder uses existing `BuildingCatalog` definitions to show cost,
  level requirement and true grid footprint. Prefer native production artwork;
  never display a blank thumbnail if an old file is missing.
- `src/ui/AircraftContextCard.gd` shows a disabled live countdown during
  Skyrama service. Its action automatically becomes active (LOAD, SEND, HANGAR)
  once service completes. **Do not** skip a state or start a duplicate job.
- `src/aircraft/AircraftPrototype.gd` owns the action bubble and countdown.
  Keep 44px minimum touch height and independent READY/PROGRESS states.
- Plane rendering proportions are changed separately in PR #204; do not
  rescale logical tap/parking/runway geometry as part of UI artwork changes.

## Later art pass (Codex)

Replace the look, **not the controls**:

1. Refine `GameUIStyle.gd` panel/button presets into consistent light teal,
   restrained gold, navy and white surfaces. Reduce hard outlines and heavy
   bevels; use soft depth, gentle highlights and compact padding.
2. Update the vector or texture assets exposed through `ProductionUIAssets.gd`
   rather than hardcoding per-screen graphic assets.
3. Build a consistent 24px icon family for the shortcut rail, status chips and
   resources. Icons must remain recognizable at mobile scale.
4. Redesign resource pills and level/XP panel with clean typography and clear
   numeric hierarchy, including overflowing values such as 999,999 coins.
5. Design separate action bubble accents for RECEIVE, UNLOAD, LOAD, SEND,
   HANGAR. The timed progress bubble should read as *working*, not *tap now*.
6. Make build-menu thumbnail framing and lock/price/footprint badges consistent.
   Avoid putting non-grid-aware art in the airport world.
7. Keep contrast readable against bright terrain; avoid full-screen overlays.

## Acceptance / QA

- Check `tests/skyrama_hud_rail_test.gd` and
  `tests/aircraft_context_card_test.gd`.
- Run the Godot Actions screenshots from `tests/capture_skyrama_hud.gd`
  at 1280×720, and manually test a short ~980×500 landscape viewport.
- Tap every shortcut, close/reopen both drawers, enter/exit editing, watch a
  service timer become an action, and verify handling bubbles are tappable.
- No new taxiing system, economy changes or asset-footprint changes in this pass.
