class_name AirportContextLayout
extends RefCounted

# Both world-selection cards dock above the compact airport footer. At 720p
# they retain their normal proportions; short landscape displays get a
# scrollable panel instead of clipped actions or off-screen close buttons.
static func apply(
	panel: PanelContainer,
	viewport_size: Vector2i,
	preferred_width: float,
	preferred_height: float
) -> void:
	if panel == null:
		return
	var width := maxf(float(viewport_size.x), 320.0)
	var height := maxf(float(viewport_size.y), 200.0)
	var inset := 12.0 if width < 960.0 else 14.0
	var bottom_clearance := 62.0 if height <= 520.0 else 84.0
	var top_clearance := 8.0 if height <= 520.0 else 14.0
	var target_width := minf(preferred_width, width - inset * 2.0)
	var target_height := minf(
		preferred_height,
		height - bottom_clearance - top_clearance
	)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = inset
	panel.offset_right = inset + target_width
	panel.offset_top = -bottom_clearance - target_height
	panel.offset_bottom = -bottom_clearance
