class_name RunwayDispatcher
extends Node

signal status_changed(text: String, tone: String)
signal queue_changed(waiting: int, active: int)

var active_by_runway: Dictionary = {}
var queues_by_runway: Dictionary = {}


func request_departure(aircraft: AircraftPrototype, label: String) -> void:
	_request_operation(aircraft, label, "departure")


func request_arrival(aircraft: AircraftPrototype, label: String) -> void:
	_request_operation(aircraft, label, "arrival")


func _request_operation(
	aircraft: AircraftPrototype,
	label: String,
	operation: String
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	var runway_uid := aircraft.runway_uid
	if runway_uid < 0:
		status_changed.emit("%s has no compatible runway." % label, "warning")
		return

	var request := {
		"aircraft": aircraft,
		"label": label,
		"operation": operation
	}

	if not active_by_runway.has(runway_uid):
		_grant_clearance(request, runway_uid)
		return

	if not queues_by_runway.has(runway_uid):
		queues_by_runway[runway_uid] = []

	var queue: Array = queues_by_runway[runway_uid]
	queue.append(request)
	queues_by_runway[runway_uid] = queue

	var action_text := "departure" if operation == "departure" else "landing"
	status_changed.emit(
		"%s waiting for %s clearance" % [label, action_text],
		"warning"
	)
	_emit_queue_status()


func get_waiting_count() -> int:
	var total := 0
	for queue_variant in queues_by_runway.values():
		var queue: Array = queue_variant
		total += queue.size()
	return total


func get_active_count() -> int:
	return active_by_runway.size()


func _grant_clearance(request: Dictionary, runway_uid: int) -> void:
	var aircraft := request.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		return

	var label := String(request.get("label", "Aircraft"))
	var operation := String(request.get("operation", "departure"))

	active_by_runway[runway_uid] = request
	aircraft.runway_cleared.connect(
		_on_aircraft_cleared_runway.bind(runway_uid, label),
		Object.CONNECT_ONE_SHOT
	)

	if operation == "arrival":
		aircraft.begin_arrival_after_clearance()
		status_changed.emit("%s cleared to land" % label, "success")
	else:
		aircraft.begin_departure_after_clearance()
		status_changed.emit("%s cleared for departure" % label, "success")

	_emit_queue_status()


func _on_aircraft_cleared_runway(runway_uid: int, _label: String) -> void:
	active_by_runway.erase(runway_uid)
	_grant_next(runway_uid)
	_emit_queue_status()


func _grant_next(runway_uid: int) -> void:
	if not queues_by_runway.has(runway_uid):
		return

	var queue: Array = queues_by_runway[runway_uid]
	while not queue.is_empty():
		var request: Dictionary = queue.pop_front()
		var aircraft := request.get("aircraft") as AircraftPrototype
		if aircraft != null and is_instance_valid(aircraft):
			queues_by_runway[runway_uid] = queue
			_grant_clearance(request, runway_uid)
			return

	if queue.is_empty():
		queues_by_runway.erase(runway_uid)
	else:
		queues_by_runway[runway_uid] = queue


func _emit_queue_status() -> void:
	queue_changed.emit(get_waiting_count(), get_active_count())
