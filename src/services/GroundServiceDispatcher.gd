class_name GroundServiceDispatcher
extends Node2D

signal status_changed(text: String, tone: String)
signal queue_changed(waiting: int, active: int)
signal aircraft_serviced(aircraft: AircraftPrototype, label: String)

var airport_grid: AirportGrid
var pending_requests: Array[Dictionary] = []
var station_active: Dictionary = {}
var active_jobs := 0


func configure(grid: AirportGrid) -> void:
	airport_grid = grid


func request_fuel(aircraft: AircraftPrototype, label: String) -> void:
	if airport_grid == null or aircraft == null:
		return

	pending_requests.append({
		"aircraft": aircraft,
		"label": label,
		"service": "fuel"
	})
	status_changed.emit("%s requested fuel" % label, "normal")
	_try_dispatch()


func get_waiting_count() -> int:
	return pending_requests.size()


func get_active_count() -> int:
	return active_jobs


func _try_dispatch() -> void:
	if airport_grid == null:
		return

	var made_progress := true
	while made_progress:
		made_progress = false

		for index in range(pending_requests.size()):
			var request := pending_requests[index]
			var aircraft := request.get("aircraft") as AircraftPrototype
			if aircraft == null or not is_instance_valid(aircraft):
				pending_requests.remove_at(index)
				made_progress = true
				break

				var stations := airport_grid.get_compatible_service_buildings(
				String(request.get("service", "fuel")),
				aircraft.aircraft_size
			)
			var station := _first_available_station(stations, aircraft.stand_uid)
			if station.is_empty():
				continue

			pending_requests.remove_at(index)
			_dispatch_fuel(request, station)
			made_progress = true
			break

	_emit_queue_status()


func _first_available_station(stations: Array[Dictionary], stand_uid: int) -> Dictionary:
	for station in stations:
		var uid := int(station.get("uid", -1))
		var capacity := maxi(int(station.get("vehicle_capacity", 1)), 1)
		var active := int(station_active.get(uid, 0))
		if active >= capacity:
			continue

		var route := airport_grid.get_service_route(uid, stand_uid)
		if route.size() < 2:
			continue

		var result := station.duplicate(true)
		result["service_route"] = route
		return result
	return {}


func _dispatch_fuel(request: Dictionary, station: Dictionary) -> void:
	var aircraft := request.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		return

	var uid := int(station.get("uid", -1))
	station_active[uid] = int(station_active.get(uid, 0)) + 1
	active_jobs += 1

	var truck := FuelTruckPrototype.new()
	truck.z_index = 90
	add_child(truck)

	var label := String(request.get("label", "Aircraft"))
	var service_speed := maxf(float(station.get("service_speed", 1.0)), 0.1)
	var service_duration := 6.0 / service_speed

	truck.service_started.connect(_on_service_started.bind(label))
	truck.service_completed.connect(_on_service_completed.bind(aircraft, label))
	truck.returned_to_station.connect(_on_truck_returned.bind(uid, label))

	var route: PackedVector2Array = station.get("service_route", PackedVector2Array())
	truck.start_service(route, service_duration)

	status_changed.emit(
		"%s fuel truck dispatched • x%.1f" % [label, service_speed],
		"normal"
	)


func _on_service_started(label: String) -> void:
	status_changed.emit("%s fueling..." % label, "normal")


func _on_service_completed(aircraft: AircraftPrototype, label: String) -> void:
	if aircraft != null and is_instance_valid(aircraft):
		aircraft.mark_service_complete()
		aircraft_serviced.emit(aircraft, label)
	status_changed.emit("%s fueled • awaiting runway" % label, "success")


func _on_truck_returned(station_uid: int, _label: String) -> void:
	station_active[station_uid] = maxi(int(station_active.get(station_uid, 1)) - 1, 0)
	active_jobs = maxi(active_jobs - 1, 0)
	_try_dispatch()


func _emit_queue_status() -> void:
	queue_changed.emit(pending_requests.size(), active_jobs)
