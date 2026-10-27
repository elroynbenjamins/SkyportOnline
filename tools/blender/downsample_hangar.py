#!/usr/bin/env python3
"""Convert 4x Blender renders to anti-aliased transparent Godot sprites.

No upscaling. PNG alpha is verified; both rotations use the exact same canvas.
"""
from PIL import Image
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "production" / "airport_buildings_blender_v1"
SRC = ROOT / "assets" / "source" / "blender"
OUT.mkdir(parents=True, exist_ok=True)
manifest = json.loads((SRC / "small_hangar_grid_contract.json").read_text())
expected = tuple(manifest["sprite_px"])
scale = int(manifest["supersample_factor"])
stats = {}

for footprint in ("4x3", "3x4"):
    raw = OUT / ("_hires_" + footprint + ".png")
    with Image.open(raw) as loaded:
        image = loaded.convert("RGBA")
    assert image.size == (expected[0] * scale, expected[1] * scale), image.size
    # Premultiplied RGBA resize prevents dark/white outlines at alpha edges.
    rgba = image.split()
    alpha = rgba[3]
    channels = []
    for channel in rgba[:3]:
        premult = Image.merge("LA", (channel, alpha))
        # Pillow cannot directly premultiply LA with good gamma, do per-channel
        # with ImageMath and smooth resize.
        from PIL import ImageChops
        x = ImageChops.multiply(channel, alpha)
        channels.append(x.resize(expected, Image.Resampling.LANCZOS))
    a = alpha.resize(expected, Image.Resampling.LANCZOS)
    from PIL import ImageMath
    unpremultiplied = []
    for channel in channels:
        px = ImageMath.eval("convert(min(255, (c*255)/(a+1)), 'L')", c=channel, a=a)
        unpremultiplied.append(px)
    final = Image.merge("RGBA", (*unpremultiplied, a))
    bbox = a.getbbox()
    assert bbox is not None and bbox[2]-bbox[0] > 100, (footprint, bbox)
    assert bbox[3] <= expected[1] and bbox[1] >= 0
    target = OUT / ("small_hangar_" + footprint + ".png")
    final.save(target,optimize=True)
    stats[footprint] = {
        "size":list(final.size),
        "alpha_bbox":list(bbox),
        "file":target.name,
        "source_render":raw.name,
        "render_scale":scale,
    }
    raw.unlink()
manifest["exports"] = stats
(SRC / "small_hangar_grid_contract.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("SKYPORT_BLENDER_SPRITES_OK",json.dumps(stats))
