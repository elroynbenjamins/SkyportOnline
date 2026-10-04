class_name AirportLightingOverlay
extends Node2D

signal changed(snapshot: Dictionary)

const WORLD_RECT := Rect2(-3600, -1400, 7200, 5200)

var airport_grid: AirportGrid
var current_hour := 12
var current_phase := TimeOfDayRules.PHASE_DAY
var phase_override := ""
var refresh_accumulator := 0.0
var refresh_interval_seconds := 30.0


func _ready() -> void:
	z_index = 500
	z_as_relative = false
	set_process(true)


func configure(grid: AirportGrid) -> void:
	airport_grid = grid
	if airport_grid != null:
		if not airport_grid.building_placed.is_connected(
			_on_airport_visual_changed
		):
			airport_grid.building_placed.connect(
				_on_airport_visual_changed
			)
		if not airport_grid.network_status_changed.is_connected(
			_on_airport_visual_changed
		):
			airport_grid.network_status_changed.connect(
				_on_airport_visual_changed
			)
	refresh_from_system()


func _process(delta: float) -> void:
	if not phase_override.is_empty():
		return

	refresh_accumulator += delta
	if refresh_accumulator < refresh_interval_seconds:
		return

	refresh_accumulator = 0.0
	refresh_from_system()


func refresh_from_system() -> void:
	var time := Time.get_time_dict_from_system()
	var hour := int(time.get("hour", 12))
	_apply_hour(hour)


func set_phase_override(phase: String) -> void:
	phase_override = TimeOfDayRules.normalized_phase(phase)
	_set_phase(phase_override)


func clear_phase_override() -> void:
	phase_override = ""
	refresh_from_system()


func get_snapshot() -> Dictionary:
	var profile := TimeOfDayRules.profile_for_phase(
		current_phase
	)
	return {
		"hour": current_hour,
		"phase": current_phase,
		"display_name": TimeOfDayRules.display_name(
			current_phase
		),
		"source": (
			"override"
			if not phase_override.is_empty()
			else "system"
		),
		"window_strength": float(
			profile.get("window_strength", 0.0)
		),
		"airfield_light_strength": float(
			profile.get(
				"airfield_light_strength",
				0.0
			)
		),
		"floodlight_strength": float(
			profile.get(
				"floodlight_strength",
				0.0
			)
		)
	}


func get_lighting_inventory() -> Dictionary:
	var result := {
		"runways": 0,
		"taxiways": 0,
		"stands": 0,
		"window_buildings": 0,
		"floodlights": 0
	}
	if airport_grid == null:
		return result

	for building in airport_grid.placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if definition.is_empty():
			continue

		var building_id := String(
			definition.get("id", "")
		)
		if building_id.contains("runway"):
			result["runways"] += 1
		elif building_id == "taxiway":
			result["taxiways"] += 1
		elif building_id.contains("stand"):
			result["stands"] += 1

		if building_id == "apron_light":
			result["floodlights"] += 1

		if _supports_window_glow(definition):
			result["window_buildings"] += 1

	return result


func _supports_window_glow(definition: Dictionary) -> bool:
	var category := String(
		definition.get("category", "")
	)
	var building_id := String(
		definition.get("id", "")
	)
	if category not in [
		"Passenger",
		"Services",
		"Operations"
	]:
		return false
	if building_id.contains("runway"):
		return false
	if building_id.contains("stand"):
		return false
	if building_id == "taxiway":
		return false
	return true


func _apply_hour(hour: int) -> void:
	current_hour = posmod(hour, 24)
	if phase_override.is_empty():
		_set_phase(
			TimeOfDayRules.phase_for_hour(
				current_hour
			)
		)


func _set_phase(phase: String) -> void:
	var normalized := TimeOfDayRules.normalized_phase(
		phase
	)
	var changed_phase := normalized != current_phase
	current_phase = normalized
	queue_redraw()
	if changed_phase:
		changed.emit(get_snapshot())


func _on_airport_visual_changed(_data = {}) -> void:
	queue_redraw()


func _draw() -> void:
	if airport_grid == null:
		return

	var profile := TimeOfDayRules.profile_for_phase(
		current_phase
	)
	var tint: Color = profile.get(
		"world_tint",
		Color.TRANSPARENT
	)

	if tint.a > 0.0:
		draw_rect(
			WORLD_RECT,
			tint,
			true
		)

	var light_strength := float(
		profile.get(
			"airfield_light_strength",
			0.0
		)
	)
	var window_strength := float(
		profile.get(
			"window_strength",
			0.0
		)
	)
	var floodlight_strength := float(
		profile.get(
			"floodlight_strength",
			0.0
		)
	)

	for building in airport_grid.placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if definition.is_empty():
			continue

		var footprint := _footprint_for(
			definition,
			int(building.get("rotation", 0))
		)
		var origin: Vector2i = building.get(
			"origin",
			Vector2i.ZERO
		)
		var center := _footprint_center_world(
			origin,
			footprint
		)
		var building_id := String(
			definition.get("id", "")
		)

		if building_id.contains("runway"):
			_draw_runway_lights(
				origin,
				footprint,
				light_strength
			)
		elif building_id == "taxiway":
			_draw_taxiway_lights(
				center,
				light_strength
			)
		elif building_id.contains("stand"):
			_draw_stand_lights(
				center,
				footprint,
				light_strength
			)

		if building_id == "apron_light":
			_draw_floodlight_glow(
				center,
				floodlight_strength
			)

		_draw_building_window_glow(
			definition,
			center,
			int(building.get("rotation", 0)),
			window_strength
		)


func _footprint_for(
	definition: Dictionary,
	rotation: int
) -> Vector2i:
	var base: Vector2i = definition.get(
		"footprint",
		Vector2i.ONE
	)
	if (
		bool(definition.get("rotatable", false))
		and rotation % 2 == 1
	):
		return Vector2i(base.y, base.x)
	return base


func _footprint_center_world(
	origin: Vector2i,
	footprint: Vector2i
) -> Vector2:
	return airport_grid.tile_to_world(
		Vector2(origin.x, origin.y)
		+ Vector2(
			float(footprint.x - 1) * 0.5,
			float(footprint.y - 1) * 0.5
		)
	)


func _draw_runway_lights(
	origin: Vector2i,
	footprint: Vector2i,
	strength: float
) -> void:
	if strength <= 0.05:
		return

	var start: Vector2
	var finish: Vector2
	if footprint.x >= footprint.y:
		start = airport_grid.tile_to_world(
			Vector2(
				origin.x,
				origin.y + float(footprint.y - 1) * 0.5
			)
		)
		finish = airport_grid.tile_to_world(
			Vector2(
				origin.x + footprint.x - 1,
				origin.y + float(footprint.y - 1) * 0.5
			)
		)
	else:
		start = airport_grid.tile_to_world(
			Vector2(
				origin.x + float(footprint.x - 1) * 0.5,
				origin.y
			)
		)
		finish = airport_grid.tile_to_world(
			Vector2(
				origin.x + float(footprint.x - 1) * 0.5,
				origin.y + footprint.y - 1
			)
		)

	var direction := (finish - start).normalized()
	if direction == Vector2.ZERO:
		return

	var normal := Vector2(-direction.y, direction.x)
	var samples := 9 if max(footprint.x, footprint.y) >= 9 else 7
	var edge_offset := 18.0

	for index in range(samples + 1):
		var t := float(index) / float(samples)
		var along := start.lerp(finish, t)
		for side in [-1.0, 1.0]:
			var p := along + normal * edge_offset * float(side)
			_draw_glow_dot(
				p,
				Color("dff4ff"),
				1.7,
				strength
			)

	for threshold in [start, finish]:
		_draw_glow_dot(
			threshold,
			Color("8be5a5"),
			2.1,
			strength
		)


func _draw_taxiway_lights(
	center: Vector2,
	strength: float
) -> void:
	if strength <= 0.08:
		return

	for offset in [
		Vector2(-18, 0),
		Vector2(18, 0)
	]:
		_draw_glow_dot(
			center + offset,
			Color("65bfff"),
			1.45,
			strength
		)


func _draw_stand_lights(
	center: Vector2,
	footprint: Vector2i,
	strength: float
) -> void:
	if strength <= 0.10:
		return

	var spread := 19.0 if footprint.x <= 2 else 26.0
	for offset in [
		Vector2(-spread, 7),
		Vector2(spread, -7)
	]:
		_draw_glow_dot(
			center + offset,
			Color("f4e9bd"),
			1.35,
			strength * 0.75
		)


func _draw_floodlight_glow(
	center: Vector2,
	strength: float
) -> void:
	if strength <= 0.05:
		return

	var glow_center := center + Vector2(0, -18)
	draw_circle(
		glow_center,
		42.0,
		Color(1.0, 0.88, 0.60, 0.07 * strength)
	)
	draw_circle(
		glow_center,
		25.0,
		Color(1.0, 0.91, 0.66, 0.10 * strength)
	)
	draw_circle(
		glow_center,
		9.0,
		Color(1.0, 0.95, 0.78, 0.22 * strength)
	)


func _draw_building_window_glow(
	definition: Dictionary,
	center: Vector2,
	rotation: int,
	strength: float
) -> void:
	if strength <= 0.10:
		return

	var category := String(
		definition.get("category", "")
	)
	var building_id := String(
		definition.get("id", "")
	)

	if not _supports_window_glow(definition):
		return

	var warm := Color(
		1.0,
		0.82,
		0.42,
		clampf(0.22 * strength, 0.0, 0.28)
	)
	var bright := Color(
		1.0,
		0.90,
		0.58,
		clampf(0.72 * strength, 0.0, 0.82)
	)

	if building_id == "atc_tower":
		_draw_glow_dot(
			center + Vector2(0, -54),
			Color("ffe49a"),
			3.0,
			strength
		)
		return

	if building_id.contains("fuel"):
		_draw_glow_dot(
			center + Vector2(0, -22),
			Color("ffc75e"),
			1.8,
			strength * 0.75
		)
		return

	var offsets := [
		Vector2(-16, -18),
		Vector2(-5, -13),
		Vector2(7, -14),
		Vector2(18, -20)
	]
	if category == "Services":
		offsets = [
			Vector2(-9, -14),
			Vector2(7, -16)
		]
	elif category == "Operations":
		offsets = [
			Vector2(-10, -18),
			Vector2(8, -17)
		]

	if rotation % 2 == 1:
		for index in range(offsets.size()):
			offsets[index].x *= -1.0

	for offset in offsets:
		var p: Vector2 = center + offset
		draw_circle(
			p,
			7.0,
			warm
		)
		draw_rect(
			Rect2(p + Vector2(-2.5, -1.5), Vector2(5, 3)),
			bright
		)


func _draw_glow_dot(
	position_world: Vector2,
	color: Color,
	radius: float,
	strength: float
) -> void:
	var alpha := clampf(strength, 0.0, 1.0)
	draw_circle(
		position_world,
		radius * 3.2,
		Color(color.r, color.g, color.b, 0.08 * alpha)
	)
	draw_circle(
		position_world,
		radius * 1.9,
		Color(color.r, color.g, color.b, 0.18 * alpha)
	)
	draw_circle(
		position_world,
		radius,
		Color(color.r, color.g, color.b, 0.94 * alpha)
	)
