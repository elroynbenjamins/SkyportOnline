# Aircraft sprite assets

The V1 aircraft renderer looks for four directional PNGs per aircraft:

- `<id>_ne.png`
- `<id>_se.png`
- `<id>_sw.png`
- `<id>_nw.png`

Folder convention:

`res://assets/pixel/aircraft/<aircraft_id>/<aircraft_id>_<direction>.png`

Current V1 IDs:

- pico_p8
- swift_s14
- comet_c22
- voyager_v32
- nimbus_n40
- arrow_a52
- atlas_a64
- falcon_f72
- horizon_h88

Only S and M aircraft are part of V1. L / XL remain future-ready.

AircraftPrototype selects the closest of the four headings while retaining the
continuous Node2D rotation for taxi/runway/service logic. The sprite itself is
counter-rotated so the pixel art is never continuously rotated. If any sprite
is missing, the previous procedural aircraft drawing remains as a safe fallback.
