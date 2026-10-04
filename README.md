# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 1 — Airport foundation

The repository currently contains the first playable foundation:

- Godot 4 mobile project targeting a portrait 720×1280 reference viewport.
- Isometric 24×24 airport grid split into 3×3 expansion parcels.
- One owned starting parcel with temporary runway/apron/terminal/fuel markers.
- Level-gated and coin-gated land expansion parcels.
- Example costs ranging from 25,000 to 2,000,000 coins.
- Tap/click parcel selection.
- One-finger pan and two-finger pinch zoom on mobile.
- Right-mouse drag and mouse-wheel zoom for desktop/editor testing.
- Basic Skyport Online HUD with level, coins, gems, build objective, expansion panel, and navigation placeholders.

The current graphics are intentionally code-drawn placeholders. They establish layout, scale, interaction, and the expansion economy before we introduce the final pixel-art asset pack.

## Run

1. Install Godot 4.3 or newer.
2. Import this repository by selecting `project.godot`.
3. Run the project.

## Next pass

**Pass 2 — Build mode and physical infrastructure**

Planned first placeable structures:

- Short runway
- Small aircraft stand
- Taxiway
- Small terminal
- Small hangar
- Basic fuel station

Buildings will use explicit grid footprints and later support S / M / L aircraft compatibility.
