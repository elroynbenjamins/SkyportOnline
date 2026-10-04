class_name RunwayDispatcher
extends Node

signal status_changed(text: String, tone: String)
signal queue_changed(waiting: int, active: int)
signal runway_visual_state_changed(
	runway_uid: int,
	state: Dictionary
)
signal atc_state_changed(snapshot: Dictionary)

var active_by_runway: Dictionary = {}
var queues_by_runway: Dictionary = {}
var departure_taxi_pending: Dictionary = {}
var planned_departures: Dictionary = {}
var last_operation_by_runway: Dictionary = {}
var separation_elapsed_by_runway: Dictionary = {}
var atc_emit_accumulator := 0.0
var airport_grid: AirportGrid
var separation_multiplier := 1.0
var active_atc_building: Dictionary = {}


func configure(grid: AirportGrid) -> void:
	airport_grid = grid
	refresh_air_traffic_control()


func refresh_air_traffic_control() -> void:
	separation_multiplier = 1.0
	active_atc_building = {}
	if airport_grid != null:
		var tower := airport_grid.get_best_air_traffic_control()
		if not tower.is_empty():
			active_atc_building = tower.duplicate(true)
			separation_multiplier = clampf(
				float(
					tower.get(
						"separation_multiplier",
						1.0
					)
				),
				0.50,
				1.0
			)

	for runway_uid in _known_runway_uids():
		_emit_runway_visual_state(runway_uid)
	_emit_atc_state()


func get_separation_multiplier() -> float:
	return separation_multiplier


func _process(delta: float) -> void:
	var runway_uids := _known_runway_uids()
	for runway_uid in runway_uids:
		if active_by_runway.has(runway_uid):
			continue
		if last_operation_by_runway.has(runway_uid):
			separation_elapsed_by_runway[runway_uid] = minf(
				float(
					separation_elapsed_by_runway.get(
						runway_uid,
						0.0
					)
				) + delta,
				60.0
			)
		_grant_next(runway_uid)

	atc_emit_accumulator += delta
	if atc_emit_accumulator >= 0.25:
		atc_emit_accumulator = 0.0
		for runway_uid in runway_uids:
			_emit_runway_visual_state(runway_uid)
		_emit_atc_state()


func request_departure(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return
	if aircraft.runway_uid < 0:
		status_changed.emit(
			"%s has no compatible runway." % label,
			"warning"
		)
		return

	release_departure_assignment(aircraft)

	if aircraft.state == "HOLD_SHORT":
		_on_departure_hold_short(
			aircraft,
			label
		)
		return

	var aircraft_id := aircraft.get_instance_id()
	if departure_taxi_pending.has(aircraft_id):
		return

	departure_taxi_pending[aircraft_id] = {
		"aircraft": aircraft,
		"label": label,
		"runway_uid": aircraft.runway_uid
	}
	_emit_runway_visual_state(aircraft.runway_uid)
	_emit_atc_state()

	aircraft.hold_short_reached.connect(
		_on_departure_hold_short.bind(
			aircraft,
			label
		),
		Object.CONNECT_ONE_SHOT
	)
	aircraft.begin_taxi_to_hold_short()
	status_changed.emit(
		"%s taxiing to runway hold short" % label,
		"normal"
	)


func request_arrival(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	_request_operation(
		aircraft,
		label,
		"arrival"
	)


func _on_departure_hold_short(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	departure_taxi_pending.erase(
		aircraft.get_instance_id()
	)
	_request_operation(
		aircraft,
		label,
		"departure"
	)


func _request_operation(
	aircraft: AircraftPrototype,
	label: String,
	operation: String
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	var runway_uid := aircraft.runway_uid
	if runway_uid < 0:
		status_changed.emit(
			"%s has no compatible runway." % label,
			"warning"
		)
		return

	var request := {
		"aircraft": aircraft,
		"label": label,
		"operation": operation
	}

	if (
		not active_by_runway.has(runway_uid)
		and _separation_remaining_for_operation(
			runway_uid,
			operation
		) <= 0.001
	):
		_grant_clearance(
			request,
			runway_uid
		)
		return

	_enqueue_request(
		runway_uid,
		request
	)

	var spacing := _separation_remaining_for_operation(
		runway_uid,
		operation
	)
	var action_text := (
		"runway entry"
		if operation == "departure"
		else "landing"
	)
	if spacing > 0.001 and not active_by_runway.has(runway_uid):
		status_changed.emit(
			"%s waiting for %s • separation %.0fs" % [
				label,
				action_text,
				ceilf(spacing)
			],
			"warning"
		)
	else:
		status_changed.emit(
			"%s waiting for %s clearance" % [
				label,
				action_text
			],
			"warning"
		)

	_emit_runway_visual_state(runway_uid)
	_emit_queue_status()
	_emit_atc_state()


func _enqueue_request(
	runway_uid: int,
	request: Dictionary
) -> void:
	if not queues_by_runway.has(runway_uid):
		queues_by_runway[runway_uid] = []

	var queue: Array = queues_by_runway[runway_uid]
	var operation := String(
		request.get("operation", "")
	)
	if operation == "arrival":
		var insert_index := queue.size()
		for index in range(queue.size()):
			var queued: Dictionary = queue[index]
			if String(
				queued.get("operation", "")
			) == "departure":
				insert_index = index
				break
		queue.insert(insert_index, request)
	else:
		queue.append(request)
	queues_by_runway[runway_uid] = queue


func get_waiting_count() -> int:
	var total := 0
	for queue_variant in queues_by_runway.values():
		var queue: Array = queue_variant
		total += queue.size()
	return total


func get_waiting_arrival_count() -> int:
	return _waiting_count_for_operation(
		"arrival"
	)


func get_waiting_departure_count() -> int:
	return _waiting_count_for_operation(
		"departure"
	)


func get_taxiing_to_hold_count() -> int:
	_cleanup_pending_departures()
	return departure_taxi_pending.size()


func get_active_count() -> int:
	return active_by_runway.size()


func reserve_departure_assignment(
	aircraft: AircraftPrototype,
	runway_uid: int
) -> void:
	if (
		aircraft == null
		or not is_instance_valid(aircraft)
		or runway_uid < 0
	):
		return
	planned_departures[aircraft.get_instance_id()] = {
		"aircraft": aircraft,
		"runway_uid": runway_uid
	}
	_emit_runway_visual_state(runway_uid)
	_emit_atc_state()


func release_departure_assignment(
	aircraft: AircraftPrototype
) -> void:
	if aircraft == null:
		return
	var aircraft_id := aircraft.get_instance_id()
	if not planned_departures.has(aircraft_id):
		return
	var planned: Dictionary = planned_departures[aircraft_id]
	var runway_uid := int(
		planned.get("runway_uid", -1)
	)
	planned_departures.erase(aircraft_id)
	if runway_uid >= 0:
		_emit_runway_visual_state(runway_uid)
	_emit_atc_state()


func select_best_runway_option(
	options: Array[Dictionary],
	operation: String
) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	var best_distance := INF
	var best_runway_uid := 2147483647

	for option in options:
		var runway_uid := int(
			option.get("runway_uid", -1)
		)
		if runway_uid < 0:
			continue

		var taxi_distance := maxf(
			float(
				option.get(
					"taxi_distance",
					0.0
				)
			),
			0.0
		)
		var score := get_runway_assignment_score(
			runway_uid,
			operation,
			taxi_distance
		)

		if (
			score < best_score - 0.001
			or (
				absf(score - best_score) <= 0.001
				and taxi_distance < best_distance - 0.01
			)
			or (
				absf(score - best_score) <= 0.001
				and absf(
					taxi_distance - best_distance
				) <= 0.01
				and runway_uid < best_runway_uid
			)
		):
			best = option.duplicate(true)
			best["assignment_score"] = score
			best_score = score
			best_distance = taxi_distance
			best_runway_uid = runway_uid

	return best


func get_runway_assignment_score(
	runway_uid: int,
	operation: String,
	taxi_distance: float = 0.0
) -> float:
	if runway_uid < 0:
		return 1000000.0

	var active_penalty := (
		120.0
		if active_by_runway.has(runway_uid)
		else 0.0
	)

	var waiting_arrivals := 0
	var waiting_departures := 0
	if queues_by_runway.has(runway_uid):
		var queue: Array = queues_by_runway[runway_uid]
		for request_variant in queue:
			var request: Dictionary = request_variant
			match String(
				request.get("operation", "")
			):
				"arrival":
					waiting_arrivals += 1
				"departure":
					waiting_departures += 1

	var planned_count := 0
	for planned_variant in planned_departures.values():
		var planned: Dictionary = planned_variant
		if int(
			planned.get("runway_uid", -1)
		) == runway_uid:
			planned_count += 1

	var taxiing_departures := 0
	for pending_variant in departure_taxi_pending.values():
		var pending: Dictionary = pending_variant
		if int(
			pending.get("runway_uid", -1)
		) == runway_uid:
			taxiing_departures += 1

	var spacing := _separation_remaining_for_operation(
		runway_uid,
		operation
	)
	var score := active_penalty
	score += float(waiting_arrivals) * 36.0
	score += float(waiting_departures) * 22.0
	score += float(planned_count) * 12.0
	score += float(taxiing_departures) * 8.0
	score += spacing * 8.0
	score += maxf(taxi_distance, 0.0) / 160.0

	if (
		operation == "departure"
		and waiting_arrivals > 0
	):
		score += 24.0

	return score


func get_runway_visual_state(
	runway_uid: int
) -> Dictionary:
	return _build_runway_visual_state(runway_uid)


func get_separation_remaining(
	runway_uid: int
) -> float:
	var next_request := _peek_next_request(runway_uid)
	if next_request.is_empty():
		return 0.0
	return _separation_remaining_for_operation(
		runway_uid,
		String(next_request.get("operation", ""))
	)


func get_atc_snapshot() -> Dictionary:
	var runways: Array[Dictionary] = []
	var runway_uids := _known_runway_uids()
	for runway_uid in runway_uids:
		runways.append(
			_build_atc_runway_state(runway_uid)
		)

	var primary: Dictionary = {}
	for runway in runways:
		if (
			not String(runway.get("active_operation", "")).is_empty()
			or float(runway.get("separation_remaining", 0.0)) > 0.001
			or int(runway.get("waiting", 0)) > 0
		):
			primary = runway
			break
	if primary.is_empty() and not runways.is_empty():
		primary = runways[0]

	return {
		"runways": runways,
		"primary_runway": primary,
		"waiting": get_waiting_count(),
		"active": get_active_count(),
		"taxiing_to_hold": get_taxiing_to_hold_count(),
		"separation_multiplier": separation_multiplier,
		"atc_level": int(
			active_atc_building.get(
				"upgrade_level",
				0
			)
		),
		"atc_building_uid": int(
			active_atc_building.get(
				"uid",
				-1
			)
		)
	}


func _waiting_count_for_operation(
	operation: String
) -> int:
	var total := 0
	for queue_variant in queues_by_runway.values():
		var queue: Array = queue_variant
		for request_variant in queue:
			var request: Dictionary = request_variant
			if String(
				request.get("operation", "")
			) == operation:
				total += 1
	return total


func _grant_clearance(
	request: Dictionary,
	runway_uid: int
) -> void:
	var aircraft := request.get(
		"aircraft"
	) as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		return

	var label := String(
		request.get("label", "Aircraft")
	)
	var operation := String(
		request.get("operation", "departure")
	)

	active_by_runway[runway_uid] = request
	_emit_runway_visual_state(runway_uid)
	_emit_atc_state()

	aircraft.runway_cleared.connect(
		_on_aircraft_cleared_runway.bind(
			runway_uid,
			label
		),
		Object.CONNECT_ONE_SHOT
	)

	if operation == "arrival":
		aircraft.begin_arrival_after_clearance()
		status_changed.emit(
			"%s cleared to land" % label,
			"success"
		)
	else:
		aircraft.begin_departure_after_clearance()
		status_changed.emit(
			"%s cleared onto runway" % label,
			"success"
		)

	_emit_queue_status()


func _on_aircraft_cleared_runway(
	runway_uid: int,
	_label: String
) -> void:
	if active_by_runway.has(runway_uid):
		var completed: Dictionary = active_by_runway[runway_uid]
		last_operation_by_runway[runway_uid] = String(
			completed.get("operation", "")
		)
		separation_elapsed_by_runway[runway_uid] = 0.0

	active_by_runway.erase(runway_uid)
	_grant_next(runway_uid)
	_emit_runway_visual_state(runway_uid)
	_emit_queue_status()
	_emit_atc_state()


func _grant_next(runway_uid: int) -> void:
	if active_by_runway.has(runway_uid):
		return
	if not queues_by_runway.has(runway_uid):
		return

	var queue: Array = queues_by_runway[runway_uid]
	_remove_invalid_requests(queue)
	if queue.is_empty():
		queues_by_runway.erase(runway_uid)
		_emit_runway_visual_state(runway_uid)
		_emit_atc_state()
		return

	var selected_index := _selected_queue_index(queue)
	if selected_index < 0:
		return

	var request: Dictionary = queue[selected_index]
	var operation := String(
		request.get("operation", "")
	)
	var spacing := _separation_remaining_for_operation(
		runway_uid,
		operation
	)
	if spacing > 0.001:
		return

	queue.remove_at(selected_index)
	if queue.is_empty():
		queues_by_runway.erase(runway_uid)
	else:
		queues_by_runway[runway_uid] = queue

	_grant_clearance(
		request,
		runway_uid
	)


func _selected_queue_index(queue: Array) -> int:
	if queue.is_empty():
		return -1

	for index in range(queue.size()):
		var request: Dictionary = queue[index]
		if String(
			request.get("operation", "")
		) == "arrival":
			return index
	return 0


func _peek_next_request(
	runway_uid: int
) -> Dictionary:
	if not queues_by_runway.has(runway_uid):
		return {}

	var queue: Array = queues_by_runway[runway_uid]
	_remove_invalid_requests(queue)
	if queue.is_empty():
		return {}

	var index := _selected_queue_index(queue)
	if index < 0:
		return {}
	return (queue[index] as Dictionary).duplicate(true)


func _separation_remaining_for_operation(
	runway_uid: int,
	next_operation: String
) -> float:
	if not last_operation_by_runway.has(runway_uid):
		return 0.0

	var previous_operation := String(
		last_operation_by_runway.get(runway_uid, "")
	)
	var required := RunwayPacingRules.separation_seconds(
		previous_operation,
		next_operation,
		separation_multiplier
	)
	var elapsed := float(
		separation_elapsed_by_runway.get(runway_uid, 0.0)
	)
	return maxf(required - elapsed, 0.0)


func _remove_invalid_requests(
	queue: Array
) -> void:
	for index in range(
		queue.size() - 1,
		-1,
		-1
	):
		var request: Dictionary = queue[index]
		var aircraft := request.get(
			"aircraft"
		) as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			queue.remove_at(index)


func _cleanup_planned_departures() -> void:
	for key_variant in planned_departures.keys():
		var key := int(key_variant)
		var planned: Dictionary = planned_departures[key]
		var aircraft := planned.get(
			"aircraft"
		) as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			planned_departures.erase(key)


func _cleanup_pending_departures() -> void:
	for key_variant in departure_taxi_pending.keys():
		var key := int(key_variant)
		var request: Dictionary = departure_taxi_pending[key]
		var aircraft := request.get(
			"aircraft"
		) as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			departure_taxi_pending.erase(key)


func _known_runway_uids() -> Array[int]:
	_cleanup_pending_departures()
	_cleanup_planned_departures()
	var seen: Dictionary = {}

	if airport_grid != null:
		for runway in airport_grid.get_runway_buildings():
			var runway_uid := int(
				runway.get("uid", -1)
			)
			if runway_uid >= 0:
				seen[runway_uid] = true

	for key_variant in active_by_runway.keys():
		seen[int(key_variant)] = true
	for key_variant in queues_by_runway.keys():
		seen[int(key_variant)] = true
	for key_variant in last_operation_by_runway.keys():
		seen[int(key_variant)] = true
	for pending_variant in departure_taxi_pending.values():
		var pending: Dictionary = pending_variant
		var runway_uid := int(
			pending.get("runway_uid", -1)
		)
		if runway_uid >= 0:
			seen[runway_uid] = true
	for planned_variant in planned_departures.values():
		var planned: Dictionary = planned_variant
		var runway_uid := int(
			planned.get("runway_uid", -1)
		)
		if runway_uid >= 0:
			seen[runway_uid] = true

	var result: Array[int] = []
	for key_variant in seen.keys():
		result.append(int(key_variant))
	result.sort()
	return result


func _build_runway_visual_state(
	runway_uid: int
) -> Dictionary:
	var active_operation := ""
	if active_by_runway.has(runway_uid):
		var active: Dictionary = active_by_runway[runway_uid]
		active_operation = String(
			active.get("operation", "")
		)

	var waiting_arrivals := 0
	var waiting_departures := 0
	if queues_by_runway.has(runway_uid):
		var queue: Array = queues_by_runway[runway_uid]
		for request_variant in queue:
			var request: Dictionary = request_variant
			match String(request.get("operation", "")):
				"arrival":
					waiting_arrivals += 1
				"departure":
					waiting_departures += 1

	var planned_departures_count := 0
	for planned_variant in planned_departures.values():
		var planned: Dictionary = planned_variant
		if int(
			planned.get("runway_uid", -1)
		) == runway_uid:
			planned_departures_count += 1

	var taxiing_departures := 0
	for pending_variant in departure_taxi_pending.values():
		var pending: Dictionary = pending_variant
		if int(pending.get("runway_uid", -1)) == runway_uid:
			taxiing_departures += 1

	var spacing_remaining := get_separation_remaining(
		runway_uid
	)
	var next_request := _peek_next_request(runway_uid)
	var next_operation := String(
		next_request.get("operation", "")
	)

	var status := "clear"
	var stop_bar := "off"
	if active_operation == "arrival":
		status = "occupied_arrival"
		stop_bar = "red"
	elif active_operation == "departure":
		status = "occupied_departure"
		stop_bar = "red"
	elif spacing_remaining > 0.001:
		if waiting_arrivals > 0:
			status = "arrival_priority_spacing"
			stop_bar = "amber"
		else:
			status = "runway_spacing"
			stop_bar = "red"
	elif waiting_arrivals > 0:
		status = "arrival_priority"
		stop_bar = "amber"
	elif waiting_departures > 0:
		status = "departure_wait"
		stop_bar = "red"
	elif taxiing_departures > 0:
		status = "departure_approaching"
		stop_bar = "amber"

	return {
		"runway_uid": runway_uid,
		"status": status,
		"stop_bar": stop_bar,
		"active_operation": active_operation,
		"waiting_arrivals": waiting_arrivals,
		"waiting_departures": waiting_departures,
		"planned_departures": planned_departures_count,
		"taxiing_departures": taxiing_departures,
		"arrival_priority": waiting_arrivals > 0,
		"separation_remaining": spacing_remaining,
		"next_operation": next_operation
	}


func _build_atc_runway_state(
	runway_uid: int
) -> Dictionary:
	var visual := _build_runway_visual_state(runway_uid)
	var active_label := ""
	var active_operation := String(
		visual.get("active_operation", "")
	)
	if active_by_runway.has(runway_uid):
		var active: Dictionary = active_by_runway[runway_uid]
		active_label = String(
			active.get("label", "Aircraft")
		)

	var queue: Array = []
	if queues_by_runway.has(runway_uid):
		queue = (
			queues_by_runway[runway_uid] as Array
		).duplicate(true)
	_remove_invalid_requests(queue)

	var sequence: Array[Dictionary] = []
	var tokens: Array[String] = []
	if not active_operation.is_empty():
		sequence.append({
			"operation": active_operation,
			"label": active_label,
			"state": "active"
		})
		tokens.append(
			"%s %s" % [
				RunwayPacingRules.operation_token(
					active_operation
				),
				active_label
			]
		)

	var spacing_remaining := float(
		visual.get("separation_remaining", 0.0)
	)
	if spacing_remaining > 0.001:
		tokens.append(
			"SEP %.0fs" % ceilf(spacing_remaining)
		)

	for request_variant in queue:
		var request: Dictionary = request_variant
		var operation := String(
			request.get("operation", "")
		)
		var label := String(
			request.get("label", "Aircraft")
		)
		sequence.append({
			"operation": operation,
			"label": label,
			"state": "queued"
		})
		if tokens.size() < 4:
			tokens.append(
				"%s %s" % [
					RunwayPacingRules.operation_token(
						operation
					),
					label
				]
			)

	var taxiing := 0
	for pending_variant in departure_taxi_pending.values():
		var pending: Dictionary = pending_variant
		if int(pending.get("runway_uid", -1)) == runway_uid:
			taxiing += 1

	if tokens.is_empty() and taxiing > 0:
		tokens.append(
			"TAXI %d" % taxiing
		)
	if tokens.is_empty():
		tokens.append("CLEAR")

	var result := visual.duplicate(true)
	result["active_label"] = active_label
	result["waiting"] = queue.size()
	result["taxiing_to_hold"] = taxiing
	result["sequence"] = sequence
	result["sequence_text"] = "  →  ".join(tokens)
	return result


func _emit_runway_visual_state(
	runway_uid: int
) -> void:
	if runway_uid < 0:
		return
	runway_visual_state_changed.emit(
		runway_uid,
		_build_runway_visual_state(runway_uid)
	)


func _emit_atc_state() -> void:
	atc_state_changed.emit(
		get_atc_snapshot()
	)


func _emit_queue_status() -> void:
	queue_changed.emit(
		get_waiting_count(),
		get_active_count()
	)
