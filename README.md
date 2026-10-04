# Skyport Online — V1 aircraft sprites

Production-ready four-direction sprite set for the current V1 S/M aircraft catalog.

## Required directions

Each aircraft has:

- `*_ne.png`
- `*_se.png`
- `*_sw.png`
- `*_nw.png`

The game renderer selects the closest direction from the aircraft's actual
movement heading. The Node2D still keeps its continuous rotation for runway,
taxi and ground-service logic; the sprite is counter-rotated so the pixel art
itself is never continuously rotated/blurry.

## Aircraft included

S class:
- Pico P8
- Swift S14
- Comet C22
- Voyager V32

M class:
- Nimbus N40
- Arrow A52
- Atlas A64
- Falcon F72
- Horizon H88

No L / XL assets are included in this V1 pack.

## Installation

Copy the included `assets` folder into the repository root, preserving the
folder structure. Godot will import the PNGs automatically.

The code integration expects paths like:

`res://assets/pixel/aircraft/pico_p8/pico_p8_ne.png`

If an asset is missing, the game automatically falls back to the previous
procedurally drawn aircraft, so a partial upload does not break gameplay.
