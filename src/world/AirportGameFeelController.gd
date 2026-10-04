class_name AirportGameFeelController
extends Node2D

const DISCOVERY_INTERVAL := 0.35

var camera_controller: CameraController
var airport_grid: AirportGrid
var discovery_accumulator := 0.0
var connected_aircraft: Dictionary = {}
var connected_reward_summaries: Dictionary = {}
var pulses: Array[Dictionary] = []
var feedback_layer: CanvasLayer
var feedback_root: Control


func _ready() -> void:
	z_index = 620
	z_as_relative = false
	_build_feedback_layer()
	call_deferred("_auto_configure")
	set_process(true)


func _auto_configure() -> void:
	var parent := get_parent()
	if parent == null:
		return

	var camera_candidate := parent.get_node_or_null("Camera")
	if camera_candidate is CameraController:
		camera_controller = camera_candidate
		if not camera_controller.world_tapped.is_connected(
			_on_world_tapped
		):
			camera_controller.world_tapped.connect(
				_on_world_tapped
			)

	var grid_candidate := parent.get_node_or_null("AirportGrid")
	if grid_candidate is AirportGrid:
		airport_grid = grid_candidate
		if not airport_grid.building_selected_world.is_connected(
			_on_building_selected
		):
			airport_grid.building_selected_world.connect(
				_on_building_selected
			)
		if not airport_grid.building_placed.is_connected(
			_on_building_placed
		):
			airport_grid.building_placed.connect(
				_on_building_placed
			)

	_discover_dynamic_nodes()


func _process(delta: float) -> void:
	discovery_accumulator += delta
	if discovery_accumulator >= DISCOVERY_INTERVAL:
		discovery_accumulator = 0.0
		_discover_dynamic_nodes()

	var changed := false
	for pulse in pulses:
		pulse["age"] = float(pulse.get("age", 0.0)) + delta
		changed = true

	for index in range(pulses.size() - 1, -1, -1):
		var pulse: Dictionary = pulses[index]
		if float(pulse.get("age", 0.0)) >= float(
			pulse.get("duration", 0.5)
		):
			pulses.remove_at(index)

	if changed:
		queue_redraw()


func _discover_dynamic_nodes() -> void:
	var parent := get_parent()
	if parent == null:
		return

	for child in parent.get_children():
		if child is AircraftPrototype:
			_connect_aircraft(child)
		elif child is FlightReturnSummary:
			_connect_reward_summary(child)


func _connect_aircraft(aircraft: AircraftPrototype) -> void:
	var instance_id := aircraft.get_instance_id()
	if connected_aircraft.has(instance_id):
		return

	connected_aircraft[instance_id] = weakref(aircraft)
	aircraft.state_changed.connect(
		_on_aircraft_state_changed.bind(aircraft)
	)


func _connect_reward_summary(summary: FlightReturnSummary) -> void:
	var instance_id := summary.get_instance_id()
	if connected_reward_summaries.has(instance_id):
		return

	connected_reward_summaries[instance_id] = weakref(summary)
	if not summary.reward_displayed.is_connected(
		_on_reward_displayed
	):
		summary.reward_displayed.connect(
			_on_reward_displayed
	)


func _on_aircraft_state_changed(
	state: String,
	aircraft: AircraftPrototype
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	match state:
		"TAKEOFF_ROLL":
			_add_pulse(
				aircraft.global_position,
				Color("78b7e8"),
				0.78,
				36.0
			)
			if camera_controller != null:
				camera_controller.play_emphasis(
					aircraft.global_position,
					"takeoff",
					1.055,
					0.72,
					0.13
				)
		"LANDING_ROLL":
			_add_pulse(
				aircraft.global_position,
				Color("76d39b"),
				0.82,
				40.0
			)
			if camera_controller != null:
				camera_controller.play_emphasis(
					aircraft.global_position,
					"landing",
					1.065,
					0.82,
					0.15
				)
		"PARKED":
			_add_pulse(
				aircraft.global_position,
				Color("76d39b"),
				0.52,
				28.0
			)
		"READY_FOR_DEPARTURE":
			_add_pulse(
				aircraft.global_position,
				Color("f0c95d"),
				0.48,
				26.0
			)


func _on_world_tapped(world_position: Vector2) -> void:
	var aircraft := _aircraft_at_world_position(
		world_position
	)
	if aircraft == null:
		return

	_add_pulse(
		aircraft.global_position,
		Color("8fdcf2"),
		0.46,
		25.0
	)


func _aircraft_at_world_position(
	world_position: Vector2
) -> AircraftPrototype:
	var parent := get_parent()
	if parent == null:
		return null

	var closest: AircraftPrototype = null
	var closest_distance := INF
	for child in parent.get_children():
		if not (child is AircraftPrototype):
			continue
		var aircraft := child as AircraftPrototype
		if not aircraft.contains_world_point(world_position):
			continue

		var distance := aircraft.global_position.distance_to(
			world_position
		)
		if distance < closest_distance:
			closest = aircraft
			closest_distance = distance

	return closest


func _on_building_selected(building: Dictionary) -> void:
	var position_world := _building_world_center(building)
	if position_world == Vector2.INF:
		return

	_add_pulse(
		position_world,
		Color("ffd166"),
		0.50,
		34.0
	)


func _on_building_placed(building: Dictionary) -> void:
	var position_world := _building_world_center(building)
	if position_world == Vector2.INF:
		return

	_add_pulse(
		position_world,
		Color("76d39b"),
		0.82,
		46.0
	)


func _building_world_center(building: Dictionary) -> Vector2:
	if airport_grid == null or building.is_empty():
		return Vector2.INF

	var definition := BuildingCatalog.get_definition(
		String(building.get("definition_id", ""))
	)
	if definition.is_empty():
		return Vector2.INF

	var footprint: Vector2i = definition.get(
		"footprint",
		Vector2i.ONE
	)
	if (
		bool(definition.get("rotatable", false))
		and int(building.get("rotation", 0)) % 2 == 1
	):
		footprint = Vector2i(footprint.y, footprint.x)

	var origin: Vector2i = building.get(
		"origin",
		Vector2i.ZERO
	)
	return airport_grid.tile_to_world(
		Vector2(origin.x, origin.y)
		+ Vector2(
			float(footprint.x - 1) * 0.5,
			float(footprint.y - 1) * 0.5
		)
	)


func _add_pulse(
	position_world: Vector2,
	color: Color,
	duration: float,
	max_radius: float
) -> void:
	pulses.append({
		"position": position_world,
		"color": color,
		"age": 0.0,
		"duration": maxf(duration, 0.1),
		"max_radius": maxf(max_radius, 12.0)
	})
	queue_redraw()


func get_active_pulse_count() -> int:
	return pulses.size()


func get_connected_aircraft_count() -> int:
	_cleanup_connections()
	return connected_aircraft.size()


func _cleanup_connections() -> void:
	for key in connected_aircraft.keys():
		var ref: WeakRef = connected_aircraft[key]
		if ref.get_ref() == null:
			connected_aircraft.erase(key)

	for key in connected_reward_summaries.keys():
		var ref: WeakRef = connected_reward_summaries[key]
		if ref.get_ref() == null:
			connected_reward_summaries.erase(key)


func _draw() -> void:
	for pulse in pulses:
		var age := float(pulse.get("age", 0.0))
		var duration := maxf(
			float(pulse.get("duration", 0.5)),
			0.1
		)
		var progress := clampf(age / duration, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - progress, 2.0)
		var radius := lerpf(
			8.0,
			float(pulse.get("max_radius", 30.0)),
			eased
		)
		var color: Color = pulse.get(
			"color",
			Color.WHITE
		)
		var alpha := (1.0 - progress) * 0.86

		draw_circle(
			pulse.get("position", Vector2.ZERO),
			radius + 4.0,
			Color(color.r, color.g, color.b, alpha * 0.08)
		)
		draw_circle(
			pulse.get("position", Vector2.ZERO),
			radius,
			Color(color.r, color.g, color.b, alpha),
			false,
			2.4
		)


func _build_feedback_layer() -> void:
	feedback_layer = CanvasLayer.new()
	feedback_layer.layer = 58
	add_child(feedback_layer)

	feedback_root = Control.new()
	feedback_root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	feedback_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_layer.add_child(feedback_root)


func _on_reward_displayed(
	flight_label: String,
	reward: Dictionary
) -> void:
	if feedback_root == null:
		return

	var coins := int(reward.get("coins", 0))
	var xp := int(reward.get("xp", 0))
	var resources: Array = reward.get(
		"resources_won",
		[]
	)

	var pill := PanelContainer.new()
	pill.custom_minimum_size = Vector2(390, 46)
	pill.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pill.offset_left = 445
	pill.offset_top = 88
	pill.offset_right = -445
	pill.offset_bottom = 134
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_root.add_child(pill)
	GameUIStyle.apply_panel(pill, "gold")

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	label.text = "%s  •  +%d coins  •  +%d XP" % [
		flight_label,
		coins,
		xp
	]
	if not resources.is_empty():
		label.text += "  •  %d resource%s" % [
			resources.size(),
			"" if resources.size() == 1 else "s"
		]
	pill.add_child(label)

	pill.modulate = Color(1, 1, 1, 0)
	pill.position.y += 10.0
	var tween := pill.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		pill,
		"modulate:a",
		1.0,
		0.18
	)
	tween.parallel().tween_property(
		pill,
		"position:y",
		pill.position.y - 10.0,
		0.18
	)
	tween.tween_interval(1.15)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(
		pill,
		"modulate:a",
		0.0,
		0.22
	)
	tween.finished.connect(pill.queue_free)
