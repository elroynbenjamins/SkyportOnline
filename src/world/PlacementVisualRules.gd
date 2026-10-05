class_name PlacementVisualRules
extends RefCounted

const SNAP_FEEDBACK_DURATION := 0.20
const BUILD_LIFT_PX := 7.0
const MOVE_LIFT_PX := 14.0


static func profile(
	mode: String,
	valid: bool,
	rotatable: bool,
	connection: Dictionary = {}
) -> Dictionary:
	var is_move := mode == "move"
	var connected := bool(connection.get("connected", false))
	var connection_required := bool(
		connection.get("required", false)
	)

	return {
		"mode": mode,
		"valid": valid,
		"lift_px": MOVE_LIFT_PX if is_move else BUILD_LIFT_PX,
		"shadow_alpha": 0.34 if is_move else 0.22,
		"outline_color": (
			Color("8cf0ad")
			if valid
			else Color("ff817d")
		),
		"fill_color": (
			Color("68d391", 0.52)
			if valid
			else Color("ef6461", 0.60)
		),
		"ghost_color": (
			Color(0.90, 1.0, 0.92, 0.95)
			if valid
			else Color(1.0, 0.62, 0.62, 0.90)
		),
		"show_rotation_hint": rotatable,
		"connection_required": connection_required,
		"connection_connected": connected,
		"connection_color": (
			Color("76d39b")
			if connected
			else Color("ffbf47")
		)
	}


static func snap_progress(remaining: float) -> float:
	if SNAP_FEEDBACK_DURATION <= 0.0:
		return 1.0
	return clampf(
		1.0 - remaining / SNAP_FEEDBACK_DURATION,
		0.0,
		1.0
	)
