class_name AirportAmbientLife
extends Node2D

# Lightweight living-airport presentation. Everything in this class is visual-only:
# no service timing, runway authority, economy, or aircraft ownership is changed.
const DRAW_INTERVAL := 1.0 / 12.0
const LAYOUT_REFRESH_INTERVAL := 0.75
const MAX_CREW := 12
const MAX_AMBIENT_CARTS := 2
const MAX_BAGGAGE_TRAINS := 3
const MAX_APRON_PROPS := 18
const MAX_TERMINAL_PASSENGERS := 4
const MAX_PASSENGER_FLOW_SPRITES := 10
const DIRECT_PASSENGER_WALK_MAX_DISTANCE := 190.0
const AMBIENT_CART_ACTIVE_FRACTION := 0.68

var airport_grid: AirportGrid
var passenger_economy: PassengerEconomy
var motion_clock := 0.0
var redraw_elapsed := 0.0
var layout_refresh_elapsed := 0.0

var stand_anchors: Array[Dictionary] = []
var terminal_anchors: Array[Dictionary] = []
var operations_anchors: Array[Dictionary] = []
var windsock_anchors: Array[Dictionary] = []
var service_route := PackedVector2Array()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	AirportAmbientLifeArt.texture()
	AirportAmbientLifeArt.passenger_texture()
	ApronDetailArt.texture()
	set_process(true)


func configure(grid: AirportGrid) -> void:
	airport_grid = grid
	_refresh_layout_anchors()
	queue_redraw()


func configure_passenger_economy(
	economy: PassengerEconomy
) -> void:
	passenger_economy = economy
	queue_redraw()


func _process(delta: float) -> void:
	if airport_grid == null or not is_instance_valid(airport_grid):
		return

	motion_clock += maxf(delta, 0.0)
	redraw_elapsed += maxf(delta, 0.0)
	layout_refresh_elapsed += maxf(delta, 0.0)

	if layout_refresh_elapsed >= LAYOUT_REFRESH_INTERVAL:
		layout_refresh_elapsed = 0.0
		_refresh_layout_anchors()

	if redraw_elapsed >= DRAW_INTERVAL:
		redraw_elapsed = 0.0
		queue_redraw()


func _draw() -> void:
	if airport_grid == null or not is_instance_valid(airport_grid):
		return

	_draw_windsocks()
	_draw_terminal_activity()
	_draw_passenger_flow()
	_draw_operations_activity()
	_draw_apron_staging_props()
	_draw_ambient_service_traffic()
	_draw_baggage_activity()
	_draw_ground_crew()


func _refresh_layout_anchors() -> void:
	stand_anchors.clear()
	terminal_anchors.clear()
	operations_anchors.clear()
	windsock_anchors.clear()

	var road_points: Array[Vector2] = []
	for building_variant in airport_grid.export_airport_layout():
		var building: Dictionary = building_variant
		var definition_id := String(
			building.get("definition_id", "")
		)
		if definition_id.is_empty():
			continue

		var position := _building_center(building)
		var anchor := {
			"uid": int(building.get("uid", -1)),
			"definition_id": definition_id,
			"position": position,
			"rotation": int(building.get("rotation", 0)) % 2
		}

		if definition_id.contains("stand"):
			stand_anchors.append(anchor)
		elif definition_id == "small_terminal" or definition_id.contains("terminal"):
			terminal_anchors.append(anchor)
		elif definition_id == "service_road":
			road_points.append(position)
		elif definition_id in [
			"ground_ops_depot",
			"basic_fuel",
			"rapid_small_fuel",
			"regional_fuel_depot",
			"regional_rapid_fuel",
			"atc_tower"
		]:
			operations_anchors.append(anchor)

		if definition_id.contains("runway"):
			windsock_anchors.append(
				_runway_windsock_anchor(building)
			)

	service_route = _order_route_points(road_points)


func _building_center(building: Dictionary) -> Vector2:
	var definition_id := String(
		building.get("definition_id", "")
	)
	var definition := BuildingCatalog.get_definition(
		definition_id
	)
	if definition.is_empty():
		return Vector2.ZERO

	var origin := Vector2i(
		int(building.get("x", 0)),
		int(building.get("y", 0))
	)
	var footprint: Vector2i = definition.get(
		"footprint",
		Vector2i.ONE
	)
	if (
		bool(definition.get("rotatable", false))
		and int(building.get("rotation", 0)) % 2 == 1
	):
		footprint = Vector2i(footprint.y, footprint.x)

	var center_tile := Vector2(
		float(origin.x) + float(footprint.x - 1) * 0.5,
		float(origin.y) + float(footprint.y - 1) * 0.5
	)
	return airport_grid.tile_to_world(center_tile)


func _runway_windsock_anchor(
	building: Dictionary
) -> Dictionary:
	var definition := BuildingCatalog.get_definition(
		String(building.get("definition_id", ""))
	)
	var footprint: Vector2i = definition.get(
		"footprint",
		Vector2i.ONE
	)
	if (
		bool(definition.get("rotatable", false))
		and int(building.get("rotation", 0)) % 2 == 1
	):
		footprint = Vector2i(footprint.y, footprint.x)

	var origin := Vector2i(
		int(building.get("x", 0)),
		int(building.get("y", 0))
	)
	var center_tile := Vector2(
		float(origin.x) + float(footprint.x - 1) * 0.5,
		float(origin.y) + float(footprint.y - 1) * 0.5
	)
	var offset := (
		Vector2(0.0, -1.35)
		if footprint.x >= footprint.y
		else Vector2(-1.35, 0.0)
	)

	return {
		"position": airport_grid.tile_to_world(
			center_tile + offset
		),
		"axis": "horizontal"
		if footprint.x >= footprint.y
		else "vertical"
	}


func _order_route_points(
	points: Array[Vector2]
) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.is_empty():
		return result

	var remaining: Array[Vector2] = points.duplicate()
	var start_index := 0
	for index in range(1, remaining.size()):
		var candidate := remaining[index]
		var current := remaining[start_index]
		if (
			candidate.y < current.y
			or (
				is_equal_approx(candidate.y, current.y)
				and candidate.x < current.x
			)
		):
			start_index = index

	var current := remaining[start_index]
	remaining.remove_at(start_index)
	result.append(current)

	while not remaining.is_empty():
		var closest_index := 0
		var closest_distance := INF
		for index in range(remaining.size()):
			var distance := current.distance_squared_to(
				remaining[index]
			)
			if distance < closest_distance:
				closest_distance = distance
				closest_index = index
		# Decorative traffic must never jump across disconnected road islands.
		if closest_distance > 80.0 * 80.0:
			break
		current = remaining[closest_index]
		remaining.remove_at(closest_index)
		result.append(current)

	return result


static func behavior_profile_for_size(
	size: String
) -> Dictionary:
	match size:
		"XL":
			return {
				"crew_count": 5,
				"bustle_speed": 0.72,
				"service_radius": 49.0,
				"marshaller_distance": 46.0
			}
		"L":
			return {
				"crew_count": 4,
				"bustle_speed": 0.82,
				"service_radius": 44.0,
				"marshaller_distance": 42.0
			}
		"M":
			return {
				"crew_count": 3,
				"bustle_speed": 0.92,
				"service_radius": 37.0,
				"marshaller_distance": 36.0
			}
		_:
			return {
				"crew_count": 2,
				"bustle_speed": 1.08,
				"service_radius": 31.0,
				"marshaller_distance": 31.0
			}


func _passenger_stock_snapshot() -> Dictionary:
	if (
		passenger_economy == null
		or not is_instance_valid(passenger_economy)
	):
		return {
			"stock": 0,
			"capacity": 0,
			"ratio": 0.0,
			"connected": false
		}

	var stock := maxi(
		passenger_economy.get_passengers(),
		0
	)
	var capacity := maxi(
		passenger_economy.get_capacity(),
		0
	)
	return {
		"stock": stock,
		"capacity": capacity,
		"ratio": (
			clampf(
				float(stock) / float(capacity),
				0.0,
				1.0
			)
			if capacity > 0
			else 0.0
		),
		"connected": true
	}


func _terminal_passenger_count() -> int:
	var stock := _passenger_stock_snapshot()
	if not bool(stock.get("connected", false)):
		# Preserve a little life in isolated visual tests / editor scenes.
		return 2

	var passengers := int(stock.get("stock", 0))
	var capacity := int(stock.get("capacity", 0))
	if passengers <= 0 or capacity <= 0:
		return 0

	var ratio := float(stock.get("ratio", 0.0))
	if ratio < 0.20:
		return 1
	if ratio < 0.50:
		return 2
	if ratio < 0.80:
		return 3
	return MAX_TERMINAL_PASSENGERS


func _visible_passenger_count(
	manifest: int,
	size_class: String
) -> int:
	if manifest <= 0:
		return 0
	var count := clampi(
		1 + ceili(float(manifest) / 14.0),
		1,
		5
	)
	if size_class in ["M", "L", "XL"]:
		count = mini(count + 1, 6)
	return count


func _nearest_terminal_anchor(
	position: Vector2
) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for anchor_variant in terminal_anchors:
		var anchor: Dictionary = anchor_variant
		var candidate: Vector2 = anchor.get(
			"position",
			Vector2.ZERO
		)
		var distance := candidate.distance_squared_to(
			position
		)
		if distance < best_distance:
			best_distance = distance
			best = anchor
	return best


func _terminal_front_point(
	anchor: Dictionary
) -> Vector2:
	var center: Vector2 = anchor.get(
		"position",
		Vector2.ZERO
	)
	var orientation := (
		-1.0
		if int(anchor.get("rotation", 0)) == 1
		else 1.0
	)
	return center + Vector2(
		30.0 * orientation,
		26.0
	)


func _aircraft_passenger_point(
	aircraft: AircraftPrototype
) -> Vector2:
	if aircraft == null or not is_instance_valid(aircraft):
		return Vector2.ZERO
	var local_offset := aircraft.get_service_docking_local_offset(
		"passenger"
	)
	var global_target := (
		aircraft.global_position
		+ local_offset.rotated(
			aircraft.global_rotation
		)
	)
	return to_local(global_target)


func _passenger_manifest_for(
	aircraft: AircraftPrototype,
	state: String
) -> int:
	if aircraft == null or not is_instance_valid(aircraft):
		return 0

	var boarded := aircraft.get_boarded_passengers()
	var seats := maxi(
		int(
			aircraft.get_aircraft_profile().get(
				"passengers",
				0
			)
		),
		0
	)
	if state == "LOADING":
		if boarded > 0:
			return boarded
		if aircraft.is_social_visitor():
			return seats
		return 0
	if state == "UNLOADING":
		return maxi(boarded, seats if aircraft.is_social_visitor() else 0)
	return 0


func _passenger_flow_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var stock := _passenger_stock_snapshot()
	var stock_count := int(stock.get("stock", 0))

	for aircraft in _collect_live_aircraft():
		var state := String(aircraft.state)
		if state not in [
			"LOADING",
			"UNLOADING",
			"WAITING_PASSENGERS"
		]:
			continue

		var aircraft_point := _aircraft_passenger_point(
			aircraft
		)
		var terminal := _nearest_terminal_anchor(
			aircraft_point
		)
		if terminal.is_empty():
			continue
		var terminal_point := _terminal_front_point(
			terminal
		)

		var direction := "waiting"
		var source := terminal_point
		var target := aircraft_point
		var count := 0
		if state == "LOADING":
			direction = "boarding"
			count = _visible_passenger_count(
				_passenger_manifest_for(
					aircraft,
					state
				),
				aircraft.aircraft_size
			)
		elif state == "UNLOADING":
			direction = "deplaning"
			source = aircraft_point
			target = terminal_point
			count = _visible_passenger_count(
				_passenger_manifest_for(
					aircraft,
					state
				),
				aircraft.aircraft_size
			)
		else:
			count = (
				1
				if stock_count > 0
				else 0
			)
			target = terminal_point

		var distance := source.distance_to(target)
		var mode := "waiting"
		if direction != "waiting":
			mode = (
				"walk"
				if distance <= DIRECT_PASSENGER_WALK_MAX_DISTANCE
				else "shuttle"
			)

		rows.append({
			"aircraft": aircraft,
			"aircraft_name": String(aircraft.name),
			"stand_uid": int(aircraft.stand_uid),
			"state": state,
			"direction": direction,
			"mode": mode,
			"count": count,
			"source": source,
			"target": target,
			"terminal_uid": int(
				terminal.get("uid", -1)
			),
			"distance": distance
		})

	return rows


func get_passenger_flow_snapshot() -> Dictionary:
	var stock := _passenger_stock_snapshot()
	var flows: Array[Dictionary] = []
	var total_sprites := 0
	var waiting_aircraft := 0
	var boarding_aircraft := 0
	var deplaning_aircraft := 0

	for row in _passenger_flow_rows():
		var direction := String(
			row.get("direction", "")
		)
		if direction == "waiting":
			waiting_aircraft += 1
		elif direction == "boarding":
			boarding_aircraft += 1
		elif direction == "deplaning":
			deplaning_aircraft += 1

		var count := maxi(
			int(row.get("count", 0)),
			0
		)
		total_sprites += count
		flows.append({
			"aircraft_name": String(
				row.get("aircraft_name", "")
			),
			"stand_uid": int(
				row.get("stand_uid", -1)
			),
			"state": String(
				row.get("state", "")
			),
			"direction": direction,
			"mode": String(
				row.get("mode", "")
			),
			"count": count,
			"distance": float(
				row.get("distance", 0.0)
			)
		})

	return {
		"stock": int(stock.get("stock", 0)),
		"capacity": int(stock.get("capacity", 0)),
		"stock_ratio": float(
			stock.get("ratio", 0.0)
		),
		"economy_connected": bool(
			stock.get("connected", false)
		),
		"terminal_bustle_count": (
			_terminal_passenger_count()
		),
		"active_flow_count": flows.size(),
		"flow_sprite_count": mini(
			total_sprites,
			MAX_PASSENGER_FLOW_SPRITES
		),
		"waiting_aircraft": waiting_aircraft,
		"boarding_aircraft": boarding_aircraft,
		"deplaning_aircraft": deplaning_aircraft,
		"bottleneck_visible": waiting_aircraft > 0,
		"flows": flows
	}


func get_ambient_snapshot() -> Dictionary:
	var live_aircraft := _collect_live_aircraft()
	var passenger_flow := get_passenger_flow_snapshot()
	var crew_count := 0
	var baggage_trains := 0
	var apron_props := 0
	var npc_aircraft := 0
	var npc_tiers: Dictionary = {}

	for aircraft in live_aircraft:
		crew_count += _crew_count_for_aircraft(aircraft)
		if aircraft.state in ["UNLOADING", "LOADING"]:
			baggage_trains += 1
		apron_props += _apron_prop_count_for_aircraft(aircraft)
		if aircraft.has_meta("npc_behavior"):
			npc_aircraft += 1
			var npc_profile: Dictionary = aircraft.get_meta(
				"npc_behavior",
				{}
			)
			var tier := String(
				npc_profile.get("tier", "standard")
			)
			npc_tiers[tier] = int(
				npc_tiers.get(tier, 0)
			) + 1

	return {
		"stands": stand_anchors.size(),
		"terminals": terminal_anchors.size(),
		"operations_anchors": operations_anchors.size(),
		"windsocks": windsock_anchors.size(),
		"service_route_points": service_route.size(),
		"ambient_cart_cap": MAX_AMBIENT_CARTS,
		"baggage_train_cap": MAX_BAGGAGE_TRAINS,
		"apron_prop_cap": MAX_APRON_PROPS,
		"apron_prop_count": mini(apron_props, MAX_APRON_PROPS),
		"draw_hz": 1.0 / DRAW_INTERVAL,
		"live_aircraft": live_aircraft.size(),
		"crew_count": mini(crew_count, MAX_CREW),
		"baggage_trains": mini(
			baggage_trains,
			MAX_BAGGAGE_TRAINS
		),
		"art_atlas_ready": AirportAmbientLifeArt.texture() != null,
		"apron_detail_ready": ApronDetailArt.texture() != null,
		"apron_detail_profile": ApronDetailArt.visual_profile(),
		"passenger_art_ready": AirportAmbientLifeArt.passenger_texture() != null,
		"passenger_variant_count": AirportAmbientLifeArt.PASSENGER_ARCHETYPES.size(),
		"passenger_flow": passenger_flow,
		"terminal_passenger_count": int(
			passenger_flow.get(
				"terminal_bustle_count",
				0
			)
		),
		"passenger_flow_sprites": int(
			passenger_flow.get(
				"flow_sprite_count",
				0
			)
		),
		"art_profile": AirportAmbientLifeArt.visual_profile(),
		"npc_aircraft": npc_aircraft,
		"npc_tiers": npc_tiers.duplicate(true)
	}


func _collect_live_aircraft() -> Array[AircraftPrototype]:
	var result: Array[AircraftPrototype] = []
	var source := get_parent()
	if source == null:
		return result

	for child in source.get_children():
		var aircraft := child as AircraftPrototype
		if (
			aircraft == null
			or not is_instance_valid(aircraft)
			or not aircraft.visible
			or aircraft.state in [
				"EN_ROUTE",
				"HOLDING_FOR_ARRIVAL"
			]
		):
			continue
		result.append(aircraft)

	return result


func _activity_profile_for_aircraft(
	aircraft: AircraftPrototype
) -> Dictionary:
	var profile := behavior_profile_for_size(
		aircraft.aircraft_size
	).duplicate(true)

	if aircraft.has_meta("npc_behavior"):
		var npc_profile: Dictionary = aircraft.get_meta(
			"npc_behavior",
			{}
		)
		profile["crew_count"] = clampi(
			int(profile.get("crew_count", 2))
			+ int(npc_profile.get("crew_bonus", 0)),
			1,
			5
		)
		profile["bustle_speed"] = maxf(
			float(profile.get("bustle_speed", 1.0))
			* float(
				npc_profile.get(
					"ground_activity_scale",
					1.0
				)
			),
			0.35
		)

	return profile


func _crew_count_for_aircraft(
	aircraft: AircraftPrototype
) -> int:
	var base := int(
		_activity_profile_for_aircraft(aircraft).get(
			"crew_count",
			2
		)
	)

	match aircraft.state:
		"UNLOADING", "SERVICING", "LOADING":
			return base
		"WAITING_UNLOAD", "WAITING_SERVICE":
			return mini(base, 1)
		"WAITING_FUEL", "WAITING_PASSENGERS":
			return mini(base, 2)
		"PUSHBACK_PREP", "READY_FOR_DEPARTURE":
			return 1
		_:
			return 0


func _draw_ground_crew() -> void:
	var drawn := 0
	for aircraft in _collect_live_aircraft():
		if drawn >= MAX_CREW:
			break

		var count := _crew_count_for_aircraft(aircraft)
		if count <= 0:
			continue

		var profile := _activity_profile_for_aircraft(
			aircraft
		)
		var radius := float(
			profile.get("service_radius", 31.0)
		)
		var bustle := float(
			profile.get("bustle_speed", 1.0)
		)
		var center := to_local(
			aircraft.global_position
		)
		var heading := aircraft.global_rotation

		for index in range(count):
			if drawn >= MAX_CREW:
				break

			var base_offset := _crew_offset(
				index,
				count,
				radius,
				aircraft.state
			)
			base_offset = base_offset.rotated(
				heading
			)

			var phase := (
				motion_clock * bustle
				+ float(index) * 1.73
				+ float(aircraft.get_instance_id() % 11)
			)
			var walking := aircraft.state in [
				"UNLOADING",
				"SERVICING",
				"LOADING",
				"WAITING_PASSENGERS"
			]
			var walk_offset := Vector2.ZERO
			if walking:
				walk_offset = Vector2(
					sin(phase * 2.0) * 2.5,
					cos(phase * 1.6) * 1.4
				)

			var marshaller := (
				aircraft.state in [
					"PUSHBACK_PREP",
					"READY_FOR_DEPARTURE"
				]
				and index == 0
			)
			_draw_ground_crew_member(
				center + base_offset + walk_offset,
				marshaller,
				phase
			)
			drawn += 1


func _crew_offset(
	index: int,
	count: int,
	radius: float,
	state: String
) -> Vector2:
	if state in ["PUSHBACK_PREP", "READY_FOR_DEPARTURE"]:
		return Vector2(radius, 0)

	var presets := [
		Vector2(-0.78, 0.55),
		Vector2(0.18, 0.92),
		Vector2(0.78, -0.45),
		Vector2(-0.18, -0.92),
		Vector2(0.92, 0.24)
	]
	var normalized: Vector2 = presets[
		index % presets.size()
	]
	var crowd_scale := (
		0.84
		if count <= 2
		else 1.0
	)
	return normalized * radius * crowd_scale


func _draw_atlas_sprite(
	position: Vector2,
	key: String,
	size: Vector2,
	ground_anchor: float = 0.75,
	mirror_x: bool = false,
	modulate: Color = Color.WHITE
) -> void:
	var atlas := AirportAmbientLifeArt.texture()
	if atlas == null:
		return

	draw_set_transform(
		position,
		0.0,
		Vector2(
			-1.0 if mirror_x else 1.0,
			1.0
		)
	)
	draw_texture_rect_region(
		atlas,
		Rect2(
			Vector2(
				-size.x * 0.5,
				-size.y * ground_anchor
			),
			size
		),
		AirportAmbientLifeArt.source_rect(key),
		modulate
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _draw_passenger_sprite(
	position: Vector2,
	archetype: String,
	frame: int,
	mirror_x: bool = false
) -> void:
	var atlas := AirportAmbientLifeArt.passenger_texture()
	if atlas == null:
		return
	var size := AirportAmbientLifeArt.passenger_world_size(
		archetype
	)
	draw_set_transform(
		position,
		0.0,
		Vector2(
			-1.0 if mirror_x else 1.0,
			1.0
		)
	)
	draw_texture_rect_region(
		atlas,
		Rect2(
			Vector2(
				-size.x * 0.5,
				-size.y * 0.78
			),
			size
		),
		AirportAmbientLifeArt.passenger_source_rect(
			archetype,
			frame
		)
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _quadratic_point(
	a: Vector2,
	control: Vector2,
	b: Vector2,
	t: float
) -> Vector2:
	var clamped := clampf(t, 0.0, 1.0)
	var inv := 1.0 - clamped
	return (
		a * inv * inv
		+ control * 2.0 * inv * clamped
		+ b * clamped * clamped
	)


func _draw_passenger_flow() -> void:
	var drawn := 0
	for row in _passenger_flow_rows():
		if drawn >= MAX_PASSENGER_FLOW_SPRITES:
			break

		var count := mini(
			maxi(int(row.get("count", 0)), 0),
			MAX_PASSENGER_FLOW_SPRITES - drawn
		)
		if count <= 0:
			continue

		var source: Vector2 = row.get(
			"source",
			Vector2.ZERO
		)
		var target: Vector2 = row.get(
			"target",
			Vector2.ZERO
		)
		var mode := String(
			row.get("mode", "")
		)
		var direction := String(
			row.get("direction", "")
		)
		var aircraft := row.get(
			"aircraft"
		) as AircraftPrototype
		var seed := (
			int(row.get("stand_uid", 0))
			+ int(row.get("terminal_uid", 0)) * 7
		)

		if mode == "waiting":
			for index in range(count):
				var position := source + Vector2(
					float(index) * 10.0 - 5.0,
					float(index % 2) * 5.0
				)
				var archetype := AirportAmbientLifeArt.passenger_archetype(
					seed + index
				)
				var frame := AirportAmbientLifeArt.animation_frame(
					motion_clock,
					1.4,
					float(index) * 0.5
				)
				_draw_passenger_sprite(
					position,
					archetype,
					frame,
					index % 2 == 1
				)
				drawn += 1
			continue

		if mode == "shuttle":
			var travel_direction := (
				target - source
			).normalized()
			var side := Vector2(
				-travel_direction.y,
				travel_direction.x
			)
			for index in range(count):
				var at_destination := (
					index >= ceili(float(count) * 0.5)
				)
				var base := (
					target
					if at_destination
					else source
				)
				var position := (
					base
					+ side * (
						float(index % 3) - 1.0
					) * 9.0
					+ travel_direction * (
						5.0
						+ float(index % 2) * 6.0
					) * (
						-1.0
						if at_destination
						else 1.0
					)
				)
				var archetype := AirportAmbientLifeArt.passenger_archetype(
					seed + index * 2
				)
				var frame := AirportAmbientLifeArt.animation_frame(
					motion_clock,
					2.1,
					float(index) * 0.31
				)
				_draw_passenger_sprite(
					position,
					archetype,
					frame,
					travel_direction.x < 0.0
				)
				drawn += 1
			continue

		var midpoint := source.lerp(
			target,
			0.5
		)
		var control := midpoint + Vector2(
			0,
			18.0
		)
		var speed := (
			0.19
			if direction == "boarding"
			else 0.17
		)
		for index in range(count):
			var progress := fmod(
				motion_clock * speed
				+ float(index) / float(maxi(count, 1))
				+ float(seed % 9) * 0.07,
				1.0
			)
			var position := _quadratic_point(
				source,
				control,
				target,
				progress
			)
			var archetype := AirportAmbientLifeArt.passenger_archetype(
				seed + index
			)
			var frame := AirportAmbientLifeArt.animation_frame(
				motion_clock,
				3.2 + float(index % 2) * 0.35,
				float(index) * 0.23
			)
			_draw_passenger_sprite(
				position,
				archetype,
				frame,
				target.x < source.x
			)
			drawn += 1


func _draw_apron_detail_sprite(
	position: Vector2,
	key: String,
	size: Vector2,
	ground_anchor: float = 0.76,
	mirror_x: bool = false,
	modulate: Color = Color.WHITE
) -> void:
	var atlas := ApronDetailArt.texture()
	if atlas == null:
		return

	draw_set_transform(
		position,
		0.0,
		Vector2(
			-1.0 if mirror_x else 1.0,
			1.0
		)
	)
	draw_texture_rect_region(
		atlas,
		Rect2(
			Vector2(
				-size.x * 0.5,
				-size.y * ground_anchor
			),
			size
		),
		ApronDetailArt.source_rect(key),
		modulate
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _apron_prop_count_for_aircraft(
	aircraft: AircraftPrototype
) -> int:
	if aircraft == null or not is_instance_valid(aircraft):
		return 0
	match String(aircraft.state):
		"WAITING_UNLOAD":
			return 3
		"UNLOADING", "LOADING":
			return 5
		"WAITING_SERVICE":
			return 3
		"SERVICING":
			return 4
		"WAITING_FUEL":
			return 3
		"WAITING_PASSENGERS":
			return 3
		"PUSHBACK_PREP", "READY_FOR_DEPARTURE":
			return 2
		_:
			return 0


func _aircraft_service_point(
	aircraft: AircraftPrototype,
	service_type: String
) -> Vector2:
	var local_offset := aircraft.get_service_docking_local_offset(
		service_type
	)
	var global_target := (
		aircraft.global_position
		+ local_offset.rotated(
			aircraft.global_rotation
		)
	)
	return to_local(global_target)


func _draw_apron_staging_props() -> void:
	var drawn := 0
	for aircraft in _collect_live_aircraft():
		if drawn >= MAX_APRON_PROPS:
			break
		var state := String(aircraft.state)
		if _apron_prop_count_for_aircraft(aircraft) <= 0:
			continue

		var profile := _activity_profile_for_aircraft(
			aircraft
		)
		var radius := float(
			profile.get(
				"service_radius",
				31.0
			)
		)
		var center := to_local(
			aircraft.global_position
		)
		var heading := aircraft.global_rotation
		var forward := Vector2.RIGHT.rotated(
			heading
		)
		var side := Vector2(
			-forward.y,
			forward.x
		)

		# Safety kit sits just outside the aircraft envelope so it reads
		# clearly without obscuring wings or the live service vehicles.
		if drawn < MAX_APRON_PROPS:
			_draw_apron_detail_sprite(
				center
				- forward * radius * 0.50
				+ side * radius * 0.82,
				"cones",
				ApronDetailArt.world_size(
					"cones"
				),
				0.78
			)
			drawn += 1

		if drawn < MAX_APRON_PROPS:
			_draw_apron_detail_sprite(
				center
				- forward * radius * 0.12
				- side * radius * 0.36,
				"chocks",
				ApronDetailArt.world_size(
					"chocks"
				),
				0.78,
				cos(heading) < 0.0
			)
			drawn += 1

		if state in [
			"WAITING_UNLOAD",
			"UNLOADING",
			"WAITING_SERVICE",
			"SERVICING",
			"WAITING_PASSENGERS",
			"LOADING"
		] and drawn < MAX_APRON_PROPS:
			var passenger_point := _aircraft_service_point(
				aircraft,
				"passenger"
			)
			_draw_apron_detail_sprite(
				passenger_point
				+ side * 6.0,
				ApronDetailArt.directional_key(
					"stairs",
					heading
				),
				ApronDetailArt.world_size(
					"stairs"
				),
				0.76
			)
			drawn += 1

		if state in ["LOADING", "UNLOADING"]:
			var cargo_point := _aircraft_service_point(
				aircraft,
				"cargo"
			)
			var equipment_kind := (
				"cargo_loader"
				if aircraft.aircraft_size in [
					"M",
					"L",
					"XL"
				]
				else "belt"
			)
			if drawn < MAX_APRON_PROPS:
				_draw_apron_detail_sprite(
					cargo_point
						- side * 5.0,
					ApronDetailArt.directional_key(
						equipment_kind,
						heading
					),
					ApronDetailArt.world_size(
						equipment_kind
					),
					0.76
				)
				drawn += 1
			if drawn < MAX_APRON_PROPS:
				_draw_apron_detail_sprite(
					cargo_point
						- forward * 20.0
						+ side * 14.0,
					(
						"uld"
						if aircraft.aircraft_size in [
							"M",
							"L",
							"XL"
						]
						else "cargo_pallet"
					),
					ApronDetailArt.world_size(
						"uld"
						if aircraft.aircraft_size in [
							"M",
							"L",
							"XL"
						]
						else "cargo_pallet"
					),
					0.78
				)
				drawn += 1

		if state in [
			"SERVICING",
			"WAITING_FUEL"
		] and drawn < MAX_APRON_PROPS:
			var fuel_point := _aircraft_service_point(
				aircraft,
				"fuel"
			)
			_draw_apron_detail_sprite(
				fuel_point
					- forward * 18.0,
				ApronDetailArt.directional_key(
					"gpu",
					heading
				),
				ApronDetailArt.world_size(
					"gpu"
				),
				0.76
			)
			drawn += 1


func get_apron_choreography_snapshot(
	aircraft: AircraftPrototype
) -> Dictionary:
	if aircraft == null or not is_instance_valid(aircraft):
		return {}

	var state := String(aircraft.state)
	return {
		"state": state,
		"prop_count": _apron_prop_count_for_aircraft(aircraft),
		"crew_count": _crew_count_for_aircraft(aircraft),
		"stairs": state in [
			"WAITING_UNLOAD",
			"UNLOADING",
			"WAITING_SERVICE",
			"SERVICING",
			"WAITING_PASSENGERS",
			"LOADING"
		],
		"cargo_equipment": state in [
			"UNLOADING",
			"LOADING"
		],
		"gpu": state in [
			"SERVICING",
			"WAITING_FUEL"
		],
		"marshaller": state in [
			"PUSHBACK_PREP",
			"READY_FOR_DEPARTURE"
		]
	}


func _draw_ground_crew_member(
	position: Vector2,
	marshaller: bool,
	phase: float
) -> void:
	var frame := ApronDetailArt.animation_frame(
		motion_clock,
		2.35 if marshaller else 3.15,
		phase * 0.12
	)
	var key := ApronDetailArt.crew_key(
		marshaller,
		frame
	)
	var size := ApronDetailArt.world_size(
		"marshaller" if marshaller else "crew"
	)
	var mirror_x := (
		sin(phase * 0.61) < 0.0
		and not marshaller
	)
	var bob := sin(phase * 2.2) * 0.35
	_draw_apron_detail_sprite(
		position + Vector2(0, bob),
		key,
		size,
		0.78,
		mirror_x
	)


func _draw_windsocks() -> void:
	var count := mini(windsock_anchors.size(), 2)
	for index in range(count):
		var anchor: Dictionary = windsock_anchors[index]
		var base: Vector2 = anchor.get(
			"position",
			Vector2.ZERO
		)
		var frame := AirportAmbientLifeArt.animation_frame(
			motion_clock,
			0.82,
			float(index) * 0.55
		)
		_draw_atlas_sprite(
			base + Vector2(0, 4),
			AirportAmbientLifeArt.windsock_key(frame),
			AirportAmbientLifeArt.world_size("windsock"),
			0.82
		)


func _draw_terminal_activity() -> void:
	for terminal in terminal_anchors:
		var center: Vector2 = terminal.get(
			"position",
			Vector2.ZERO
		)
		var uid := int(terminal.get("uid", 0))
		var orientation := (
			-1.0
			if int(terminal.get("rotation", 0)) == 1
			else 1.0
		)
		var pulse := (
			0.55
			+ 0.45 * sin(
				motion_clock * 1.45
				+ float(uid % 7)
			)
		)

		# Keep the subtle window/entrance glow as a light effect, while
		# people and flags use the same production atlas as the apron.
		for offset in [
			Vector2(-18 * orientation, 7),
			Vector2(0, 11),
			Vector2(18 * orientation, 7)
		]:
			draw_circle(
				center + offset,
				2.2,
				Color(
					0.60,
					0.88,
					1.0,
					0.24 + pulse * 0.20
				)
			)

		var terminal_passenger_count := _terminal_passenger_count()
		for index in range(terminal_passenger_count):
			var walk_speed := (
				0.050 + float(index % 3) * 0.010
			)
			var raw_walk_phase := (
				motion_clock * walk_speed
				+ float(index) * 0.52
			)
			var walk_phase := fmod(
				raw_walk_phase,
				1.0
			)
			var walk_cycle := floori(raw_walk_phase)
			var pedestrian := center + Vector2(
				lerpf(
					-30.0,
					30.0,
					walk_phase
				) * orientation,
				18.0 + float(index % 2) * 8.0
			)
			# Keep one traveler identity for an entire crossing. A new
			# archetype is selected only after that traveler loops back.
			var archetype := AirportAmbientLifeArt.passenger_archetype(
				uid + index * 3 + walk_cycle * 2
			)
			var frame := AirportAmbientLifeArt.animation_frame(
				motion_clock,
				3.4 + float(index) * 0.35,
				float(uid % 7) * 0.17 + float(index) * 0.5
			)
			_draw_passenger_sprite(
				pedestrian,
				archetype,
				frame,
				orientation < 0.0
			)

		_draw_terminal_flag(
			center + Vector2(
				44.0 * orientation,
				17.0
			),
			orientation,
			uid
		)


func _draw_terminal_flag(
	base: Vector2,
	orientation: float,
	uid: int
) -> void:
	var frame := AirportAmbientLifeArt.animation_frame(
		motion_clock,
		0.76,
		float(uid % 5) * 0.3
	)
	_draw_atlas_sprite(
		base + Vector2(0, 2),
		AirportAmbientLifeArt.flag_key(frame),
		AirportAmbientLifeArt.world_size("flag"),
		0.82,
		orientation < 0.0
	)


func _draw_operations_activity() -> void:
	for anchor in operations_anchors:
		var center: Vector2 = anchor.get(
			"position",
			Vector2.ZERO
		)
		var uid := int(anchor.get("uid", 0))
		var pulse := (
			0.5
			+ 0.5 * sin(
				motion_clock * 2.6
				+ float(uid % 13)
			)
		)
		draw_circle(
			center + Vector2(0, -22),
			4.5 + pulse * 1.2,
			Color(1.0, 0.72, 0.18, 0.05 + pulse * 0.06)
		)
		draw_circle(
			center + Vector2(0, -22),
			1.8,
			Color(1.0, 0.72 + pulse * 0.16, 0.22, 0.75)
		)


func _draw_ambient_service_traffic() -> void:
	if service_route.size() < 2:
		return

	var cart_count := (
		1
		if service_route.size() < 14
		else MAX_AMBIENT_CARTS
	)
	for index in range(cart_count):
		var cycle := 20.0 + float(index) * 4.0
		var cycle_phase := fmod(
			motion_clock + float(index) * 8.0,
			cycle
		) / cycle
		if cycle_phase >= AMBIENT_CART_ACTIVE_FRACTION:
			continue

		var progress := (
			cycle_phase
			/ AMBIENT_CART_ACTIVE_FRACTION
		)
		var sample := _sample_service_route(
			progress
		)
		if sample.is_empty():
			continue
		_draw_ambient_cart(
			sample.get("position", Vector2.ZERO),
			float(sample.get("heading", 0.0)),
			index
		)


func _sample_service_route(
	progress: float
) -> Dictionary:
	if service_route.size() < 2:
		return {}

	var total := 0.0
	var lengths: Array[float] = []
	for index in range(service_route.size() - 1):
		var length := service_route[index].distance_to(
			service_route[index + 1]
		)
		lengths.append(length)
		total += length

	if total <= 0.001:
		return {}

	var target := clampf(progress, 0.0, 1.0) * total
	var walked := 0.0
	for index in range(lengths.size()):
		var segment := lengths[index]
		if target <= walked + segment or index == lengths.size() - 1:
			var local_progress := (
				0.0
				if segment <= 0.001
				else clampf(
					(target - walked) / segment,
					0.0,
					1.0
				)
			)
			var a := service_route[index]
			var b := service_route[index + 1]
			return {
				"position": a.lerp(
					b,
					local_progress
				),
				"heading": (b - a).angle()
			}
		walked += segment

	return {}


func _draw_baggage_activity() -> void:
	var drawn := 0
	for aircraft in _collect_live_aircraft():
		if drawn >= MAX_BAGGAGE_TRAINS:
			break
		if aircraft.state not in ["UNLOADING", "LOADING"]:
			continue

		var profile := _activity_profile_for_aircraft(
			aircraft
		)
		var radius := float(
			profile.get("service_radius", 31.0)
		)
		var center := to_local(
			aircraft.global_position
		)
		var heading := aircraft.global_rotation
		var forward := Vector2.RIGHT.rotated(heading)
		var side := Vector2(
			-forward.y,
			forward.x
		)
		var phase := (
			motion_clock * 0.95
			+ float(aircraft.get_instance_id() % 17)
		)
		var position := (
			center
			+ side * radius * 0.92
			+ forward * sin(phase) * 7.0
		)
		_draw_apron_detail_sprite(
			position,
			ApronDetailArt.directional_key(
				"baggage",
				heading
			),
			ApronDetailArt.world_size(
				"baggage"
			),
			0.76
		)
		drawn += 1


func _draw_ambient_cart(
	position: Vector2,
	heading: float,
	index: int
) -> void:
	var bob := sin(
		motion_clock * 4.6 + float(index)
	) * 0.45
	_draw_apron_detail_sprite(
		position + Vector2(0, bob),
		ApronDetailArt.directional_key(
			"utility",
			heading
		),
		ApronDetailArt.world_size(
			"utility"
		),
		0.76
	)

	# The amber beacon remains procedural so it can genuinely pulse rather
	# than forcing a large multi-frame vehicle atlas.
	var pulse := (
		0.5
		+ 0.5 * sin(
			motion_clock * 7.0
			+ float(index)
		)
	)
	draw_circle(
		position + Vector2(0, -14),
		2.8 + pulse * 0.7,
		Color(
			1.0,
			0.72,
			0.20,
			0.08 + pulse * 0.08
		)
	)
	draw_circle(
		position + Vector2(0, -14),
		1.2,
		Color(
			1.0,
			0.78,
			0.26,
			0.72 + pulse * 0.25
		)
	)

