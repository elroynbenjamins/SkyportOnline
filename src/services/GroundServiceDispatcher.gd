class_name GroundServiceDispatcher
extends Node2D

signal status_changed(text: String, tone: String)
signal queue_changed(waiting: int, active: int)
signal passenger_boarding_requested(
	aircraft: AircraftPrototype,
	label: String
)
signal departure_route_requested(
	aircraft: AircraftPrototype,
	label: String
)
signal aircraft_serviced(
	aircraft: AircraftPrototype,
	label: String
)

var airport_grid: AirportGrid
var pending_requests: Array[Dictionary] = []
var station_active: Dictionary = {}
var stand_approach_active: Dictionary = {}
var turnaround_jobs: Dictionary = {}
var active_jobs := 0
var service_analytics: Dictionary = {}

const ANALYTICS_SERVICE_TYPES: Array[String] = [
	"fuel",
	"passenger",
	"cargo",
	"cleaning",
	"catering",
	"pushback"
]


func configure(grid: AirportGrid) -> void:
	airport_grid = grid


func request_turnaround(
	aircraft: AircraftPrototype,
	label: String,
	is_returning: bool = true
) -> void:
	if airport_grid == null or aircraft == null:
		return

	var job_id := aircraft.get_instance_id()
	if turnaround_jobs.has(job_id):
		return

	var profile := _profile_for_aircraft(aircraft)
	if profile.is_empty():
		return

	turnaround_jobs[job_id] = {
		"aircraft": aircraft,
		"label": label,
		"profile": profile,
		"is_returning": is_returning,
		"stage": "",
		"stage_pending": {},
		"service_status": {}
	}

	if is_returning:
		_begin_unloading(job_id)
	else:
		_begin_servicing(job_id)


# Legacy compatibility for tests / simple callers that only need a fuel job.
func request_fuel(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	if airport_grid == null or aircraft == null:
		return

	var profile := _profile_for_aircraft(aircraft)
	_increment_service_analytics("fuel", "requests", 1.0)
	pending_requests.append({
		"legacy_fuel_only": true,
		"job_id": -1,
		"aircraft": aircraft,
		"label": label,
		"service_key": "legacy_fuel",
		"service_type": "fuel",
		"base_duration": float(profile.get("fuel_seconds", 12.0))
	})
	status_changed.emit("%s requested fuel" % label, "normal")
	_try_dispatch()


func approve_passenger_loading(
	aircraft: AircraftPrototype
) -> bool:
	if aircraft == null:
		return false

	var job_id := aircraft.get_instance_id()
	if not turnaround_jobs.has(job_id):
		return false

	var job: Dictionary = turnaround_jobs[job_id]
	if String(job.get("stage", "")) != "WAITING_PASSENGERS":
		return false

	_begin_loading(job_id)
	return true


func resume_after_destination(
	aircraft: AircraftPrototype
) -> bool:
	if aircraft == null:
		return false

	var job_id := aircraft.get_instance_id()
	if not turnaround_jobs.has(job_id):
		return false

	var job: Dictionary = turnaround_jobs[job_id]
	if String(job.get("stage", "")) != "WAITING_DESTINATION":
		return false
	if not aircraft.has_flight_plan():
		return false

	_request_passenger_boarding(job_id)
	return true


func get_waiting_count() -> int:
	return pending_requests.size()


func get_active_count() -> int:
	return active_jobs


func is_station_active(station_uid: int) -> bool:
	if station_uid < 0:
		return false

	var prefix := "%d:" % station_uid
	for key_variant in station_active.keys():
		var key := String(key_variant)
		if (
			key.begins_with(prefix)
			and int(station_active.get(key_variant, 0)) > 0
		):
			return true
	return false


func get_waiting_by_service() -> Dictionary:
	var result := {}
	for request in pending_requests:
		var service_type := String(
			request.get("service_type", "unknown")
		)
		result[service_type] = int(result.get(service_type, 0)) + 1
	return result


func get_service_analytics_snapshot() -> Dictionary:
	var result: Dictionary = {}
	var waiting := get_waiting_by_service()

	for service_type in ANALYTICS_SERVICE_TYPES:
		_ensure_service_analytics(service_type)
		var raw: Dictionary = service_analytics[service_type]
		var capacity := _service_capacity(service_type)
		var current_active := _active_for_service(service_type)
		var current_waiting := int(
			waiting.get(service_type, 0)
		)
		var capacity_seconds := maxf(
			float(raw.get("capacity_seconds", 0.0)),
			0.0
		)
		var active_seconds := maxf(
			float(raw.get("active_vehicle_seconds", 0.0)),
			0.0
		)
		var utilization := 0.0
		if capacity_seconds > 0.001:
			utilization = clampf(
				active_seconds / capacity_seconds * 100.0,
				0.0,
				100.0
			)

		var requests := maxi(
			int(raw.get("requests", 0)),
			0
		)
		var average_wait := 0.0
		if requests > 0:
			average_wait = (
				float(raw.get("queued_seconds", 0.0))
				/ float(requests)
			)

		var stats := raw.duplicate(true)
		stats["service_type"] = service_type
		stats["capacity"] = capacity
		stats["current_active"] = current_active
		stats["current_waiting"] = current_waiting
		stats["utilization_pct"] = utilization
		stats["average_wait_seconds"] = average_wait
		result[service_type] = stats

	return result


func get_service_analytics(
	service_type: String
) -> Dictionary:
	return (
		get_service_analytics_snapshot().get(
			service_type,
			{}
		) as Dictionary
	).duplicate(true)


func get_turnaround_snapshot(
	aircraft: AircraftPrototype
) -> Dictionary:
	if aircraft == null:
		return {}

	var job_id := aircraft.get_instance_id()
	if not turnaround_jobs.has(job_id):
		return {}

	var job: Dictionary = turnaround_jobs[job_id]
	var pending: Dictionary = job.get("stage_pending", {})
	var status: Dictionary = job.get("service_status", {})
	return {
		"stage": String(job.get("stage", "")),
		"pending_services": pending.keys(),
		"service_status": status.duplicate(true),
		"pushback_remaining": float(
			job.get("pushback_remaining", 0.0)
		),
		"is_returning": bool(job.get("is_returning", false))
	}


func _process(delta: float) -> void:
	_tick_service_analytics(delta)

	if turnaround_jobs.is_empty():
		return

	for job_id_variant in turnaround_jobs.keys():
		var job_id := int(job_id_variant)
		if not turnaround_jobs.has(job_id):
			continue

		var job: Dictionary = turnaround_jobs[job_id]
		var aircraft := job.get("aircraft") as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			_remove_job(job_id)
			continue

		_tick_service_status(job_id, delta)
		_refresh_aircraft_status(job_id)


func _begin_unloading(job_id: int) -> void:
	_begin_vehicle_stage(
		job_id,
		"UNLOADING",
		[
			{
				"key": "passenger_out",
				"service": "passenger",
				"timer_key": "deboard_seconds"
			},
			{
				"key": "cargo_out",
				"service": "cargo",
				"timer_key": "cargo_unload_seconds"
			}
		]
	)


func _begin_servicing(job_id: int) -> void:
	_begin_vehicle_stage(
		job_id,
		"SERVICING",
		[
			{
				"key": "fuel",
				"service": "fuel",
				"timer_key": "fuel_seconds"
			},
			{
				"key": "cleaning",
				"service": "cleaning",
				"timer_key": "clean_seconds"
			},
			{
				"key": "catering",
				"service": "catering",
				"timer_key": "catering_seconds"
			}
		]
	)


func _begin_loading(job_id: int) -> void:
	_begin_vehicle_stage(
		job_id,
		"LOADING",
		[
			{
				"key": "passenger_in",
				"service": "passenger",
				"timer_key": "board_seconds"
			},
			{
				"key": "cargo_in",
				"service": "cargo",
				"timer_key": "cargo_load_seconds"
			}
		]
	)


func _begin_vehicle_stage(
	job_id: int,
	stage: String,
	specs: Array
) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var aircraft := job.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		_remove_job(job_id)
		return

	var profile: Dictionary = job.get("profile", {})
	var pending := {}
	var service_status := {}
	job["stage"] = stage
	job["stage_pending"] = pending
	job["service_status"] = service_status
	turnaround_jobs[job_id] = job
	aircraft.begin_ground_service(stage)

	for spec_variant in specs:
		var spec: Dictionary = spec_variant
		var service_key := String(spec.get("key", ""))
		var service_type := String(spec.get("service", ""))
		var timer_key := String(spec.get("timer_key", ""))
		var base_duration := maxf(
			float(profile.get(timer_key, 0.0)),
			0.0
		)
		if service_key.is_empty() or service_type.is_empty():
			continue
		if base_duration <= 0.0:
			continue

		pending[service_key] = true
		service_status[service_key] = {
			"service_type": service_type,
			"state": "queued",
			"remaining": base_duration,
			"duration": base_duration
		}
		_enqueue_service_request(
			job_id,
			aircraft,
			String(job.get("label", "Aircraft")),
			service_key,
			service_type,
			base_duration
		)

	job["stage_pending"] = pending
	job["service_status"] = service_status
	turnaround_jobs[job_id] = job
	_refresh_aircraft_status(job_id)

	status_changed.emit(
		"%s • %s" % [
			String(job.get("label", "Aircraft")),
			_stage_status_text(stage)
		],
		"normal"
	)

	if pending.is_empty():
		_advance_stage(job_id)
	else:
		_try_dispatch()


func _request_passenger_boarding(job_id: int) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var aircraft := job.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		_remove_job(job_id)
		return

	job["stage"] = "WAITING_PASSENGERS"
	job["stage_pending"] = {}
	job["service_status"] = {}
	turnaround_jobs[job_id] = job
	aircraft.mark_waiting_passengers()
	aircraft.set_turnaround_status(
		"Waiting for passengers",
		"warning"
	)
	passenger_boarding_requested.emit(
		aircraft,
		String(job.get("label", "Aircraft"))
	)


func _wait_for_destination(job_id: int) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var aircraft := job.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		_remove_job(job_id)
		return

	job["stage"] = "WAITING_DESTINATION"
	job["stage_pending"] = {}
	job["service_status"] = {}
	turnaround_jobs[job_id] = job
	aircraft.mark_service_complete()
	aircraft.set_turnaround_status(
		"Destination required",
		"warning"
	)
	status_changed.emit(
		"%s serviced • destination required" % String(
			job.get("label", "Aircraft")
		),
		"warning"
	)


func _begin_pushback(job_id: int) -> void:
	if turnaround_jobs.has(job_id):
		var job: Dictionary = turnaround_jobs[job_id]
		var aircraft := job.get("aircraft") as AircraftPrototype
		var label := String(job.get("label", "Aircraft"))
		if aircraft != null and is_instance_valid(aircraft):
			departure_route_requested.emit(
				aircraft,
				label
			)

	_begin_vehicle_stage(
		job_id,
		"PUSHBACK_PREP",
		[
			{
				"key": "pushback",
				"service": "pushback",
				"timer_key": "pushback_seconds"
			}
		]
	)


func _complete_turnaround(job_id: int) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var aircraft := job.get("aircraft") as AircraftPrototype
	var label := String(job.get("label", "Aircraft"))
	turnaround_jobs.erase(job_id)

	if aircraft == null or not is_instance_valid(aircraft):
		return

	aircraft.mark_service_complete()
	aircraft.set_turnaround_status(
		"Ready • runway queue",
		"success"
	)
	aircraft_serviced.emit(aircraft, label)
	status_changed.emit(
		"%s turnaround complete • awaiting runway" % label,
		"success"
	)


func _advance_stage(job_id: int) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var stage := String(job.get("stage", ""))
	var aircraft := job.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		_remove_job(job_id)
		return

	match stage:
		"UNLOADING":
			_begin_servicing(job_id)
		"SERVICING":
			if aircraft.has_flight_plan():
				_request_passenger_boarding(job_id)
			else:
				_wait_for_destination(job_id)
		"LOADING":
			_begin_pushback(job_id)
		"PUSHBACK_PREP":
			_complete_turnaround(job_id)


func _enqueue_service_request(
	job_id: int,
	aircraft: AircraftPrototype,
	label: String,
	service_key: String,
	service_type: String,
	base_duration: float
) -> void:
	_increment_service_analytics(
		service_type,
		"requests",
		1.0
	)
	pending_requests.append({
		"legacy_fuel_only": false,
		"job_id": job_id,
		"aircraft": aircraft,
		"label": label,
		"service_key": service_key,
		"service_type": service_type,
		"base_duration": base_duration
	})


func _try_dispatch() -> void:
	if airport_grid == null:
		return

	var made_progress := true
	while made_progress:
		made_progress = false

		for index in range(pending_requests.size()):
			var request: Dictionary = pending_requests[index]
			var aircraft := request.get("aircraft") as AircraftPrototype
			if aircraft == null or not is_instance_valid(aircraft):
				pending_requests.remove_at(index)
				made_progress = true
				break

			var service_type := String(
				request.get("service_type", "fuel")
			)
			var stations := airport_grid.get_compatible_service_buildings(
				service_type,
				aircraft.aircraft_size
			)
			var station := _first_available_station(
				stations,
				aircraft.stand_uid,
				service_type
			)
			if station.is_empty():
				continue

			pending_requests.remove_at(index)
			_dispatch_service(request, station)
			made_progress = true
			break

	_emit_queue_status()


func _first_available_station(
	stations: Array[Dictionary],
	stand_uid: int,
	service_type: String
) -> Dictionary:
	for station in stations:
		var uid := int(station.get("uid", -1))
		var capacity := maxi(
			int(station.get("vehicle_capacity", 1)),
			1
		)
		var active_key := _station_service_key(uid, service_type)
		var active := int(station_active.get(active_key, 0))
		if active >= capacity:
			continue

		var route := airport_grid.get_service_route(uid, stand_uid)
		if route.size() < 2:
			continue

		var result := station.duplicate(true)
		result["service_route"] = route
		return result

	return {}


func _dispatch_service(
	request: Dictionary,
	station: Dictionary
) -> void:
	var aircraft := request.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		return

	var service_type := String(
		request.get("service_type", "fuel")
	)
	var station_uid := int(station.get("uid", -1))
	var active_key := _station_service_key(
		station_uid,
		service_type
	)
	var station_active_before := int(
		station_active.get(active_key, 0)
	)
	station_active[active_key] = station_active_before + 1
	active_jobs += 1

	var speed := maxf(
		float(station.get("service_speed", 1.0)),
		0.1
	)
	var base_duration := maxf(
		float(request.get("base_duration", 1.0)),
		0.25
	)
	var duration := base_duration / speed
	var route: PackedVector2Array = station.get(
		"service_route",
		PackedVector2Array()
	)
	var label := String(request.get("label", "Aircraft"))
	var job_id := int(request.get("job_id", -1))
	var service_key := String(
		request.get("service_key", service_type)
	)
	var stand_uid := aircraft.stand_uid
	var approach_count := int(
		stand_approach_active.get(stand_uid, 0)
	)
	var launch_delay := maxf(
		ApronTrafficRules.stagger_delay(
			approach_count
		),
		ApronTrafficRules.station_stagger_delay(
			station_active_before
		)
	)
	stand_approach_active[stand_uid] = approach_count + 1

	route = _route_to_aircraft_service_anchor(
		route,
		aircraft,
		service_type,
		service_key
	)
	var docking_rotation := (
		aircraft.get_service_docking_rotation(
			service_type,
			service_key
		)
	)
	var legacy_fuel_only := bool(
		request.get("legacy_fuel_only", false)
	)

	route = ApronTrafficRules.offset_route(
		route,
		service_type
	)

	if not legacy_fuel_only and job_id >= 0:
		_set_service_status(
			job_id,
			service_key,
			"en_route",
			duration
		)

	if service_type == "fuel":
		var truck := FuelTruckPrototype.new()
		truck.z_index = 90
		add_child(truck)
		truck.service_started.connect(
			_on_service_started.bind(
				label,
				service_type,
				duration,
				job_id,
				service_key,
				stand_uid
			)
		)
		truck.service_completed.connect(
			_on_service_completed.bind(
				aircraft,
				label,
				job_id,
				service_key,
				legacy_fuel_only
			)
		)
		truck.returned_to_station.connect(
			_on_vehicle_returned.bind(
				station_uid,
				service_type
			)
		)
		truck.set_launch_delay(launch_delay)
		truck.set_service_pose_rotation(
			docking_rotation
		)
		truck.set_service_connection_target(
			aircraft.global_position
		)
		truck.start_service(route, duration)
	else:
		var vehicle := GroundServiceVehiclePrototype.new()
		vehicle.z_index = 90
		add_child(vehicle)
		vehicle.service_started.connect(
			_on_service_started.bind(
				label,
				service_type,
				duration,
				job_id,
				service_key,
				stand_uid
			)
		)
		vehicle.service_completed.connect(
			_on_service_completed.bind(
				aircraft,
				label,
				job_id,
				service_key,
				false
			)
		)
		vehicle.returned_to_station.connect(
			_on_vehicle_returned.bind(
				station_uid,
				service_type
			)
		)
		vehicle.set_launch_delay(launch_delay)
		vehicle.set_service_pose_rotation(
			docking_rotation
		)
		vehicle.set_service_connection_target(
			aircraft.global_position
		)
		if service_type == "pushback":
			vehicle.configure_tow(
				aircraft,
				aircraft.get_pushback_target_position()
			)
		vehicle.start_service(
			route,
			duration,
			service_type
		)

	status_changed.emit(
		"%s %s dispatched • %.0fs • x%.2f" % [
			label,
			_service_display_name(service_type),
			duration,
			speed
		],
		"normal"
	)


func _route_to_aircraft_service_anchor(
	base_route: PackedVector2Array,
	aircraft: AircraftPrototype,
	service_type: String,
	service_key: String
) -> PackedVector2Array:
	if base_route.size() < 2:
		return base_route

	var docking := aircraft.get_service_docking_position(
		service_type,
		service_key
	)
	var from_aircraft := docking - aircraft.global_position
	var staging := docking
	if from_aircraft.length() > 0.01:
		staging = docking + from_aircraft.normalized() * 18.0

	var result := base_route.duplicate()
	result[result.size() - 1] = staging
	result.append(docking)
	return result


func _on_service_started(
	label: String,
	service_type: String,
	duration: float,
	job_id: int,
	service_key: String,
	stand_uid: int
) -> void:
	_release_stand_approach(stand_uid)
	if job_id >= 0:
		_set_service_status(
			job_id,
			service_key,
			"active",
			duration
		)
	status_changed.emit(
		"%s %s • %.0fs" % [
			label,
			_service_action_text(service_type),
			duration
		],
		"normal"
	)


func _on_service_completed(
	aircraft: AircraftPrototype,
	label: String,
	job_id: int,
	service_key: String,
	legacy_fuel_only: bool
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	if legacy_fuel_only:
		_increment_service_analytics(
			"fuel",
			"completed",
			1.0
		)
		aircraft.mark_service_complete()
		aircraft_serviced.emit(aircraft, label)
		status_changed.emit(
			"%s fueled • service complete" % label,
			"success"
		)
		return

	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var pending: Dictionary = job.get("stage_pending", {})
	var service_status: Dictionary = job.get(
		"service_status",
		{}
	)
	if service_status.has(service_key):
		var entry: Dictionary = service_status[service_key]
		var completed_service_type := String(
			entry.get("service_type", "")
		)
		if not completed_service_type.is_empty():
			_increment_service_analytics(
				completed_service_type,
				"completed",
				1.0
			)
		entry["state"] = "done"
		entry["remaining"] = 0.0
		service_status[service_key] = entry
	pending.erase(service_key)
	job["stage_pending"] = pending
	job["service_status"] = service_status
	turnaround_jobs[job_id] = job
	_refresh_aircraft_status(job_id)

	if pending.is_empty():
		_advance_stage(job_id)


func _on_vehicle_returned(
	station_uid: int,
	service_type: String
) -> void:
	var active_key := _station_service_key(
		station_uid,
		service_type
	)
	station_active[active_key] = maxi(
		int(station_active.get(active_key, 1)) - 1,
		0
	)
	active_jobs = maxi(active_jobs - 1, 0)
	_try_dispatch()


func get_stand_approach_count(stand_uid: int) -> int:
	return int(stand_approach_active.get(stand_uid, 0))


func _release_stand_approach(stand_uid: int) -> void:
	if stand_uid < 0:
		return
	var remaining := maxi(
		int(stand_approach_active.get(stand_uid, 1)) - 1,
		0
	)
	if remaining <= 0:
		stand_approach_active.erase(stand_uid)
	else:
		stand_approach_active[stand_uid] = remaining


func _set_service_status(
	job_id: int,
	service_key: String,
	state_value: String,
	remaining: float
) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var service_status: Dictionary = job.get(
		"service_status",
		{}
	)
	if not service_status.has(service_key):
		return

	var entry: Dictionary = service_status[service_key]
	entry["state"] = state_value
	entry["remaining"] = maxf(remaining, 0.0)
	if state_value == "active":
		entry["duration"] = maxf(remaining, 0.0)
	service_status[service_key] = entry
	job["service_status"] = service_status
	turnaround_jobs[job_id] = job
	_refresh_aircraft_status(job_id)


func _tick_service_status(
	job_id: int,
	delta: float
) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var service_status: Dictionary = job.get(
		"service_status",
		{}
	)
	var changed := false

	for service_key in service_status.keys():
		var entry: Dictionary = service_status[service_key]
		if String(entry.get("state", "")) != "active":
			continue
		entry["remaining"] = maxf(
			float(entry.get("remaining", 0.0)) - delta,
			0.0
		)
		service_status[service_key] = entry
		changed = true

	if changed:
		job["service_status"] = service_status
		turnaround_jobs[job_id] = job


func _refresh_aircraft_status(job_id: int) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var aircraft := job.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		return

	var stage := String(job.get("stage", ""))
	if stage in [
		"WAITING_PASSENGERS",
		"WAITING_DESTINATION"
	]:
		return

	var status: Dictionary = job.get("service_status", {})
	var parts: Array[String] = []
	for service_key in status.keys():
		var entry: Dictionary = status[service_key]
		var state_value := String(entry.get("state", ""))
		if state_value == "done":
			continue

		var service_type := String(
			entry.get("service_type", "")
		)
		var label := _service_short_name(
			service_type,
			String(service_key)
		)
		match state_value:
			"queued":
				parts.append("%s WAIT" % label)
			"en_route":
				parts.append("%s →" % label)
			"active":
				parts.append(
					"%s %.0fs" % [
						label,
						float(entry.get("remaining", 0.0))
					]
				)

	var header := _stage_short_name(stage)
	var text := header
	if not parts.is_empty():
		text += "\n" + " • ".join(parts)
	aircraft.set_turnaround_status(text)


func _stage_short_name(stage: String) -> String:
	match stage:
		"UNLOADING":
			return "Turnaround • unload"
		"SERVICING":
			return "Turnaround • service"
		"LOADING":
			return "Turnaround • load"
		"PUSHBACK_PREP":
			return "Turnaround • pushback"
		_:
			return "Turnaround"


func _service_short_name(
	service_type: String,
	service_key: String
) -> String:
	match service_type:
		"passenger":
			return "Pax"
		"cargo":
			return "Bag"
		"cleaning":
			return "Clean"
		"catering":
			return "Cater"
		"pushback":
			return "Tow"
		_:
			return "Fuel"


func _profile_for_aircraft(
	aircraft: AircraftPrototype
) -> Dictionary:
	var profile := aircraft.get_aircraft_profile()
	if not profile.is_empty():
		return profile

	if aircraft.aircraft_size == "M":
		return AircraftCatalog.get_profile("nimbus_n40")
	return AircraftCatalog.get_profile("pico_p8")


func _remove_job(job_id: int) -> void:
	turnaround_jobs.erase(job_id)

	for index in range(
		pending_requests.size() - 1,
		-1,
		-1
	):
		if int(
			pending_requests[index].get("job_id", -1)
		) == job_id:
			pending_requests.remove_at(index)

	_emit_queue_status()


func _ensure_service_analytics(
	service_type: String
) -> void:
	if (
		service_type.is_empty()
		or service_analytics.has(service_type)
	):
		return
	service_analytics[service_type] = {
		"tracked_seconds": 0.0,
		"queued_seconds": 0.0,
		"active_vehicle_seconds": 0.0,
		"capacity_seconds": 0.0,
		"requests": 0,
		"completed": 0,
		"peak_waiting": 0
	}


func _increment_service_analytics(
	service_type: String,
	key: String,
	amount: float
) -> void:
	if service_type.is_empty():
		return
	_ensure_service_analytics(service_type)
	var data: Dictionary = service_analytics[service_type]
	if key in ["requests", "completed", "peak_waiting"]:
		data[key] = int(data.get(key, 0)) + int(round(amount))
	else:
		data[key] = float(
			data.get(key, 0.0)
		) + amount
	service_analytics[service_type] = data


func _tick_service_analytics(delta: float) -> void:
	if delta <= 0.0:
		return

	var waiting := get_waiting_by_service()
	for service_type in ANALYTICS_SERVICE_TYPES:
		_ensure_service_analytics(service_type)
		var data: Dictionary = service_analytics[service_type]
		var waiting_count := int(
			waiting.get(service_type, 0)
		)
		var active_count := _active_for_service(
			service_type
		)
		var capacity := _service_capacity(
			service_type
		)

		data["tracked_seconds"] = float(
			data.get("tracked_seconds", 0.0)
		) + delta
		data["queued_seconds"] = float(
			data.get("queued_seconds", 0.0)
		) + float(waiting_count) * delta
		data["active_vehicle_seconds"] = float(
			data.get("active_vehicle_seconds", 0.0)
		) + float(active_count) * delta
		data["capacity_seconds"] = float(
			data.get("capacity_seconds", 0.0)
		) + float(capacity) * delta
		data["peak_waiting"] = maxi(
			int(data.get("peak_waiting", 0)),
			waiting_count
		)
		service_analytics[service_type] = data


func _active_for_service(
	service_type: String
) -> int:
	var total := 0
	for key_variant in station_active.keys():
		var key := String(key_variant)
		if not key.ends_with(":" + service_type):
			continue
		total += int(
			station_active.get(key_variant, 0)
		)
	return total


func _service_capacity(
	service_type: String
) -> int:
	if airport_grid == null:
		return 0

	var by_uid: Dictionary = {}
	for size_class in ["S", "M"]:
		for station in airport_grid.get_compatible_service_buildings(
			service_type,
			size_class
		):
			var uid := int(station.get("uid", -1))
			if uid < 0:
				continue
			by_uid[uid] = maxi(
				int(by_uid.get(uid, 0)),
				int(station.get("vehicle_capacity", 1))
			)

	var total := 0
	for capacity_variant in by_uid.values():
		total += int(capacity_variant)
	return total


func _station_service_key(
	station_uid: int,
	service_type: String
) -> String:
	return "%d:%s" % [station_uid, service_type]


func _stage_status_text(stage: String) -> String:
	match stage:
		"UNLOADING":
			return "deboarding + baggage unload"
		"SERVICING":
			return "fuel + cleaning + catering"
		"LOADING":
			return "boarding + baggage load"
		"PUSHBACK_PREP":
			return "tow tug pushback"
		_:
			return stage.to_lower()


func _service_display_name(service_type: String) -> String:
	match service_type:
		"passenger":
			return "passenger vehicle"
		"cargo":
			return "baggage tractor"
		"cleaning":
			return "cleaning van"
		"catering":
			return "catering truck"
		"pushback":
			return "tow tug"
		_:
			return "fuel truck"


func _service_action_text(service_type: String) -> String:
	match service_type:
		"passenger":
			return "handling passengers"
		"cargo":
			return "handling baggage / cargo"
		"cleaning":
			return "cleaning cabin"
		"catering":
			return "restocking catering"
		"pushback":
			return "pushing aircraft back"
		_:
			return "fueling"


func _emit_queue_status() -> void:
	queue_changed.emit(
		pending_requests.size(),
		active_jobs
	)
