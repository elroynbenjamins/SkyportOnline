class_name RunwayDispatcher
extends Node

signal status_changed(text: String, tone: String)
signal queue_changed(waiting: int, active: int)

var active_by_runway: Dictionary = {}
var queues_by_runway: Dictionary = {}
var departure_taxi_pending: Dictionary = {}


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
		"label": label
	}
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

	if not active_by_runway.has(runway_uid):
		_grant_clearance(
			request,
			runway_uid
		)
		return

	if not queues_by_runway.has(runway_uid):
		queues_by_runway[runway_uid] = []

	var queue: Array = queues_by_runway[runway_uid]
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

	var action_text := (
		"runway entry"
		if operation == "departure"
		else "landing"
	)
	status_changed.emit(
		"%s waiting for %s clearance" % [
			label,
			action_text
		],
		"warning"
	)
	_emit_queue_status()


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
	active_by_runway.erase(runway_uid)
	_grant_next(runway_uid)
	_emit_queue_status()


func _grant_next(runway_uid: int) -> void:
	if not queues_by_runway.has(runway_uid):
		return

	var queue: Array = queues_by_runway[runway_uid]
	_remove_invalid_requests(queue)
	if queue.is_empty():
		queues_by_runway.erase(runway_uid)
		return

	# Arrivals always take priority over departures already holding short.
	var selected_index := -1
	for index in range(queue.size()):
		var request: Dictionary = queue[index]
		if String(
			request.get("operation", "")
		) == "arrival":
			selected_index = index
			break

	if selected_index < 0:
		selected_index = 0

	var request: Dictionary = queue[selected_index]
	queue.remove_at(selected_index)
	if queue.is_empty():
		queues_by_runway.erase(runway_uid)
	else:
		queues_by_runway[runway_uid] = queue

	_grant_clearance(
		request,
		runway_uid
	)


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


func _cleanup_pending_departures() -> void:
	for key_variant in departure_taxi_pending.keys():
		var key := int(key_variant)
		var request: Dictionary = departure_taxi_pending[key]
		var aircraft := request.get(
			"aircraft"
		) as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			departure_taxi_pending.erase(key)


func _emit_queue_status() -> void:
	queue_changed.emit(
		get_waiting_count(),
		get_active_count()
	)
