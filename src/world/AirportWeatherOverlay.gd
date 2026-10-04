class_name AirportWeatherOverlay
extends Node2D

signal changed(snapshot: Dictionary)

const WORLD_RECT := Rect2(-3400, -1200, 6800, 5000)

var airport_grid: AirportGrid
var current_condition := WeatherVisualRules.CLEAR
var manual_override := ""
var event_override := ""
var motion_offset := 0.0
var refresh_accumulator := 0.0
var refresh_interval_seconds := 600.0


func _ready() -> void:
	name = "AirportWeather"
	z_index = 510
	z_as_relative = false
	set_process(true)


func configure(grid: AirportGrid) -> void:
	airport_grid = grid
	refresh_from_system_date()


func _process(delta: float) -> void:
	refresh_accumulator += delta
	if refresh_accumulator >= refresh_interval_seconds:
		refresh_accumulator = 0.0
		if manual_override.is_empty() and event_override.is_empty():
			refresh_from_system_date()

	var profile := WeatherVisualRules.profile_for_condition(
		current_condition
	)
	var speed := float(profile.get("motion_speed", 0.0))
	if speed <= 0.0:
		return

	motion_offset = fmod(
		motion_offset + delta * speed,
		4096.0
	)
	queue_redraw()


func refresh_from_system_date() -> void:
	var date := Time.get_date_dict_from_system()
	var month := int(date.get("month", 1))
	var day := int(date.get("day", 1))
	var daily := WeatherVisualRules.daily_condition(
		month,
		day
	)
	_apply_effective_condition(daily)


func set_condition_override(condition: String) -> void:
	manual_override = WeatherVisualRules.normalized_condition(
		condition
	)
	_apply_effective_condition(manual_override)


func clear_condition_override() -> void:
	manual_override = ""
	_refresh_effective_condition()


func set_event_condition(condition: String) -> void:
	event_override = WeatherVisualRules.normalized_condition(
		condition
	)
	_refresh_effective_condition()


func clear_event_condition() -> void:
	event_override = ""
	_refresh_effective_condition()


func get_snapshot() -> Dictionary:
	var profile := WeatherVisualRules.profile_for_condition(
		current_condition
	)
	return {
		"condition": current_condition,
		"display_name": String(
			profile.get("display_name", "Clear")
		),
		"source": _source_name(),
		"cloud_shadow_strength": float(
			profile.get(
				"cloud_shadow_strength",
				0.0
			)
		),
		"wet_strength": float(
			profile.get("wet_strength", 0.0)
		),
		"fog_strength": float(
			profile.get("fog_strength", 0.0)
		),
		"precipitation": WeatherVisualRules.is_precipitation(
			current_condition
		),
		"low_visibility": WeatherVisualRules.is_low_visibility(
			current_condition
		)
	}


func _source_name() -> String:
	if not manual_override.is_empty():
		return "manual"
	if not event_override.is_empty():
		return "event"
	return "daily"


func _refresh_effective_condition() -> void:
	if not manual_override.is_empty():
		_apply_effective_condition(manual_override)
		return
	if not event_override.is_empty():
		_apply_effective_condition(event_override)
		return
	refresh_from_system_date()


func _apply_effective_condition(condition: String) -> void:
	var normalized := WeatherVisualRules.normalized_condition(
		condition
	)
	if normalized == current_condition:
		queue_redraw()
		return

	current_condition = normalized
	motion_offset = 0.0
	queue_redraw()
	changed.emit(get_snapshot())


func _draw() -> void:
	if airport_grid == null:
		return

	var profile := WeatherVisualRules.profile_for_condition(
		current_condition
	)

	_draw_cloud_shadows(
		float(
			profile.get(
				"cloud_shadow_strength",
				0.0
			)
		)
	)
	_draw_wet_pavement(
		float(profile.get("wet_strength", 0.0))
	)

	var tint: Color = profile.get(
		"world_tint",
		Color.TRANSPARENT
	)
	if tint.a > 0.0:
		draw_rect(WORLD_RECT, tint, true)

	_draw_fog(
		float(profile.get("fog_strength", 0.0))
	)
	_draw_rain(
		int(profile.get("rain_count", 0))
	)
	_draw_snow(
		int(profile.get("snow_count", 0))
	)

	if current_condition == WeatherVisualRules.SNOW:
		_draw_snow_accents()


func _draw_cloud_shadows(strength: float) -> void:
	if strength <= 0.01:
		return

	var alpha := 0.10 * clampf(strength, 0.0, 1.0)
	var anchors := [
		Vector2(-880, 120),
		Vector2(-520, 420),
		Vector2(-120, 220),
		Vector2(280, 560),
		Vector2(680, 260),
		Vector2(940, 700)
	]

	for index in range(anchors.size()):
		var base: Vector2 = anchors[index]
		var drift := fmod(
			motion_offset * 0.55 + float(index) * 97.0,
			520.0
		) - 260.0
		var center := base + Vector2(drift, drift * 0.22)
		var width := 110.0 + float(index % 3) * 24.0
		var height := 42.0 + float(index % 2) * 12.0

		draw_set_transform(
			center,
			0.0,
			Vector2(1.0, height / width)
		)
		draw_circle(
			Vector2.ZERO,
			width,
			Color(0.02, 0.05, 0.06, alpha)
		)
		draw_set_transform(
			Vector2.ZERO,
			0.0,
			Vector2.ONE
		)


func _draw_wet_pavement(strength: float) -> void:
	if strength <= 0.01:
		return

	var shine := Color(
		0.70,
		0.84,
		0.92,
		0.10 * clampf(strength, 0.0, 1.0)
	)
	var bright := Color(
		0.83,
		0.92,
		0.97,
		0.20 * clampf(strength, 0.0, 1.0)
	)

	for building in airport_grid.placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if definition.is_empty():
			continue

		var building_id := String(
			definition.get("id", "")
		)
		if not (
			building_id.contains("runway")
			or building_id == "taxiway"
			or building_id == "service_road"
			or building_id.contains("stand")
		):
			continue

		var footprint := _footprint_for(
			definition,
			int(building.get("rotation", 0))
		)
		var center := _footprint_center_world(
			building.get("origin", Vector2i.ZERO),
			footprint
		)
		var span := 18.0
		if building_id.contains("runway"):
			span = 34.0
		elif building_id.contains("stand"):
			span = 24.0

		draw_line(
			center + Vector2(-span, -4),
			center + Vector2(span, -4),
			shine,
			2.4
		)
		draw_line(
			center + Vector2(-span * 0.55, 3),
			center + Vector2(span * 0.40, 3),
			bright,
			1.3
		)


func _draw_fog(strength: float) -> void:
	if strength <= 0.01:
		return

	var alpha := 0.08 * clampf(strength, 0.0, 1.0)
	for index in range(5):
		var y := -120.0 + float(index) * 260.0
		var drift := fmod(
			motion_offset * 0.18 + float(index) * 73.0,
			240.0
		) - 120.0
		draw_rect(
			Rect2(
				Vector2(-1500 + drift, y),
				Vector2(3000, 110)
			),
			Color(0.82, 0.88, 0.88, alpha)
		)


func _draw_rain(count: int) -> void:
	if count <= 0:
		return

	var area := Rect2(-1300, -480, 2600, 2300)
	for index in range(count):
		var x_seed := posmod(index * 137 + 53, 997)
		var y_seed := posmod(index * 211 + 29, 991)

		var x := area.position.x + (
			float(x_seed) / 996.0
		) * area.size.x
		var y_base := area.position.y + (
			float(y_seed) / 990.0
		) * area.size.y
		var y := area.position.y + fmod(
			(y_base - area.position.y)
			+ motion_offset,
			area.size.y
		)

		var start := Vector2(x, y)
		var finish := start + Vector2(-7, 18)
		draw_line(
			start,
			finish,
			Color(0.72, 0.86, 0.96, 0.44),
			1.25
		)


func _draw_snow(count: int) -> void:
	if count <= 0:
		return

	var area := Rect2(-1300, -480, 2600, 2300)
	for index in range(count):
		var x_seed := posmod(index * 151 + 41, 983)
		var y_seed := posmod(index * 197 + 67, 977)

		var sway := sin(
			(motion_offset + float(index) * 19.0) * 0.025
		) * 10.0
		var x := area.position.x + (
			float(x_seed) / 982.0
		) * area.size.x + sway
		var y_base := area.position.y + (
			float(y_seed) / 976.0
		) * area.size.y
		var y := area.position.y + fmod(
			(y_base - area.position.y)
			+ motion_offset,
			area.size.y
		)

		var radius := 1.8 + float(index % 3) * 0.45
		draw_circle(
			Vector2(x, y),
			radius,
			Color(0.93, 0.97, 1.0, 0.72)
		)


func _draw_snow_accents() -> void:
	for building in airport_grid.placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if definition.is_empty():
			continue

		var building_id := String(
			definition.get("id", "")
		)
		if building_id in [
			"taxiway",
			"service_road"
		]:
			continue
		if building_id.contains("runway"):
			continue

		var footprint := _footprint_for(
			definition,
			int(building.get("rotation", 0))
		)
		var center := _footprint_center_world(
			building.get("origin", Vector2i.ZERO),
			footprint
		)

		draw_line(
			center + Vector2(-12, -18),
			center + Vector2(14, -18),
			Color(0.92, 0.97, 1.0, 0.32),
			2.0
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
