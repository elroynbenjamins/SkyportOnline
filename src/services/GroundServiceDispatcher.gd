class_name GroundServiceDispatcher
extends Node2D

signal status_changed(text: String, tone: String)
signal queue_changed(waiting: int, active: int)
signal aircraft_serviced(aircraft: AircraftPrototype, label: String)

var airport_grid: AirportGrid
var pending_requests: Array[Dictionary] = []
var station_active: Dictionary = {}
var turnaround_jobs: Dictionary = {}
var active_jobs := 0


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
	var timing := TurnaroundRules.timing_for_profile(profile)
	if timing.is_empty():
		return

	var stage := "UNLOADING" if is_returning else "SERVICING"
	var stage_remaining := (
		TurnaroundRules.arrival_block_seconds(profile)
		if is_returning
		else maxf(
			float(timing.get("clean_seconds", 0.0)),
			float(timing.get("catering_seconds", 0.0))
		)
	)

	turnaround_jobs[job_id] = {
		"aircraft": aircraft,
		"label": label,
		"profile": profile,
		"timing": timing,
		"is_returning": is_returning,
		"stage": stage,
		"stage_remaining": stage_remaining,
		"fuel_queued": false,
		"fuel_done": false,
		"ground_service_done": false
	}

	aircraft.begin_ground_service(stage)
	if is_returning:
		status_changed.emit(
			"%s unloading passengers / cargo • %.0fs" % [
				label,
				stage_remaining
			],
			"normal"
		)
	else:
		_begin_service_stage(job_id)


# Compatibility entry point for older callers. A fuel request now means an
# outbound turnaround: fuel, cleaning/catering, loading, then pushback prep.
func request_fuel(aircraft: AircraftPrototype, label: String) -> void:
	request_turnaround(aircraft, label, false)


func get_waiting_count() -> int:
	return pending_requests.size()


func get_active_count() -> int:
	return active_jobs


func get_turnaround_snapshot(aircraft: AircraftPrototype) -> Dictionary:
	if aircraft == null:
		return {}
	var job_id := aircraft.get_instance_id()
	if not turnaround_jobs.has(job_id):
		return {}
	var job: Dictionary = turnaround_jobs[job_id]
	var timing: Dictionary = job.get("timing", {})
	return {
		"stage": String(job.get("stage", "")),
		"stage_remaining": float(job.get("stage_remaining", 0.0)),
		"fuel_done": bool(job.get("fuel_done", false)),
		"timing": timing.duplicate(true)
	}


func _process(delta: float) -> void:
	if turnaround_jobs.is_empty():
		return

	var job_ids := turnaround_jobs.keys()
	for job_id_variant in job_ids:
		var job_id := int(job_id_variant)
		if not turnaround_jobs.has(job_id):
			continue

		var job: Dictionary = turnaround_jobs[job_id]
		var aircraft := job.get("aircraft") as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			_remove_job(job_id)
			continue

		var stage := String(job.get("stage", ""))
		match stage:
			"UNLOADING":
				job["stage_remaining"] = maxf(
					float(job.get("stage_remaining", 0.0)) - delta,
					0.0
				)
				turnaround_jobs[job_id] = job
				if float(job["stage_remaining"]) <= 0.0:
					_begin_service_stage(job_id)

			"SERVICING":
				if not bool(job.get("ground_service_done", false)):
					job["stage_remaining"] = maxf(
						float(job.get("stage_remaining", 0.0)) - delta,
						0.0
					)
					if float(job["stage_remaining"]) <= 0.0:
						job["ground_service_done"] = true
					turnaround_jobs[job_id] = job
				_try_advance_service_stage(job_id)

			"LOADING":
				job["stage_remaining"] = maxf(
					float(job.get("stage_remaining", 0.0)) - delta,
					0.0
				)
				turnaround_jobs[job_id] = job
				if float(job["stage_remaining"]) <= 0.0:
					_begin_pushback_stage(job_id)

			"PUSHBACK_PREP":
				job["stage_remaining"] = maxf(
					float(job.get("stage_remaining", 0.0)) - delta,
					0.0
				)
				turnaround_jobs[job_id] = job
				if float(job["stage_remaining"]) <= 0.0:
					_complete_turnaround(job_id)


func _begin_service_stage(job_id: int) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var aircraft := job.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		_remove_job(job_id)
		return

	var timing: Dictionary = job.get("timing", {})
	var ground_seconds := maxf(
		float(timing.get("clean_seconds", 0.0)),
		float(timing.get("catering_seconds", 0.0))
	)

	job["stage"] = "SERVICING"
	job["stage_remaining"] = ground_seconds
	job["ground_service_done"] = ground_seconds <= 0.0
	turnaround_jobs[job_id] = job

	aircraft.begin_ground_service("SERVICING")
	status_changed.emit(
		"%s servicing • fuel + cabin + catering" % String(
			job.get("label", "Aircraft")
		),
		"normal"
	)

	_enqueue_fuel(job_id)
	_try_advance_service_stage(job_id)


func _begin_loading_stage(job_id: int) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var aircraft := job.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		_remove_job(job_id)
		return

	var timing: Dictionary = job.get("timing", {})
	var loading_seconds := maxf(
		float(timing.get("board_seconds", 0.0)),
		float(timing.get("cargo_load_seconds", 0.0))
	)

	job["stage"] = "LOADING"
	job["stage_remaining"] = loading_seconds
	turnaround_jobs[job_id] = job

	aircraft.begin_ground_service("LOADING")
	status_changed.emit(
		"%s loading passengers / cargo • %.0fs" % [
			String(job.get("label", "Aircraft")),
			loading_seconds
		],
		"normal"
	)

	if loading_seconds <= 0.0:
		_begin_pushback_stage(job_id)


func _begin_pushback_stage(job_id: int) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	var aircraft := job.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		_remove_job(job_id)
		return

	var timing: Dictionary = job.get("timing", {})
	var pushback_seconds := maxf(
		float(timing.get("pushback_seconds", 0.0)),
		0.0
	)

	job["stage"] = "PUSHBACK_PREP"
	job["stage_remaining"] = pushback_seconds
	turnaround_jobs[job_id] = job

	aircraft.begin_ground_service("PUSHBACK_PREP")
	status_changed.emit(
		"%s pushback checks • %.0fs" % [
			String(job.get("label", "Aircraft")),
			pushback_seconds
		],
		"normal"
	)

	if pushback_seconds <= 0.0:
		_complete_turnaround(job_id)


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
	if aircraft.has_flight_plan():
		aircraft_serviced.emit(aircraft, label)
		status_changed.emit(
			"%s turnaround complete • awaiting runway" % label,
			"success"
		)
	else:
		status_changed.emit(
			"%s turnaround complete • destination required" % label,
			"warning"
		)


func _try_advance_service_stage(job_id: int) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	if String(job.get("stage", "")) != "SERVICING":
		return
	if not bool(job.get("ground_service_done", false)):
		return
	if not bool(job.get("fuel_done", false)):
		return

	_begin_loading_stage(job_id)


func _enqueue_fuel(job_id: int) -> void:
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	if bool(job.get("fuel_queued", false)) or bool(job.get("fuel_done", false)):
		return

	var aircraft := job.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		_remove_job(job_id)
		return

	job["fuel_queued"] = true
	turnaround_jobs[job_id] = job
	pending_requests.append({
		"job_id": job_id,
		"aircraft": aircraft,
		"label": String(job.get("label", "Aircraft")),
		"service": "fuel"
	})
	status_changed.emit(
		"%s requested fuel" % String(job.get("label", "Aircraft")),
		"normal"
	)
	_try_dispatch()


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

			var stations: Array[Dictionary] = airport_grid.get_compatible_service_buildings(
				String(request.get("service", "fuel")),
				aircraft.aircraft_size
			)
			var station: Dictionary = _first_available_station(
				stations,
				aircraft.stand_uid
			)
			if station.is_empty():
				continue

			pending_requests.remove_at(index)
			_dispatch_fuel(request, station)
			made_progress = true
			break

	_emit_queue_status()


func _first_available_station(
	stations: Array[Dictionary],
	stand_uid: int
) -> Dictionary:
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
	var job_id := int(request.get("job_id", aircraft.get_instance_id()))
	var service_speed := maxf(
		float(station.get("service_speed", 1.0)),
		0.1
	)
	var profile := _profile_for_aircraft(aircraft)
	var service_duration := TurnaroundRules.fuel_seconds(
		profile,
		service_speed
	)

	truck.service_started.connect(
		_on_service_started.bind(label, service_duration)
	)
	truck.service_completed.connect(
		_on_service_completed.bind(aircraft, label, job_id)
	)
	truck.returned_to_station.connect(
		_on_truck_returned.bind(uid, label)
	)

	var route: PackedVector2Array = station.get(
		"service_route",
		PackedVector2Array()
	)
	truck.start_service(route, service_duration)

	status_changed.emit(
		"%s fuel truck dispatched • %.0fs • x%.1f" % [
			label,
			service_duration,
			service_speed
		],
		"normal"
	)


func _on_service_started(label: String, duration: float) -> void:
	status_changed.emit(
		"%s fueling • %.0fs" % [label, duration],
		"normal"
	)


func _on_service_completed(
	aircraft: AircraftPrototype,
	label: String,
	job_id: int
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return
	if not turnaround_jobs.has(job_id):
		return

	var job: Dictionary = turnaround_jobs[job_id]
	job["fuel_done"] = true
	turnaround_jobs[job_id] = job

	status_changed.emit(
		"%s fueled • completing ground handling" % label,
		"success"
	)
	_try_advance_service_stage(job_id)


func _on_truck_returned(station_uid: int, _label: String) -> void:
	station_active[station_uid] = maxi(
		int(station_active.get(station_uid, 1)) - 1,
		0
	)
	active_jobs = maxi(active_jobs - 1, 0)
	_try_dispatch()


func _profile_for_aircraft(aircraft: AircraftPrototype) -> Dictionary:
	var profile := aircraft.get_aircraft_profile()
	if not profile.is_empty():
		return profile

	if aircraft.aircraft_size == "M":
		return AircraftCatalog.get_profile("nimbus_n40")
	return AircraftCatalog.get_profile("pico_p8")


func _remove_job(job_id: int) -> void:
	turnaround_jobs.erase(job_id)

	for index in range(pending_requests.size() - 1, -1, -1):
		if int(pending_requests[index].get("job_id", -1)) == job_id:
			pending_requests.remove_at(index)

	_emit_queue_status()


func _emit_queue_status() -> void:
	queue_changed.emit(pending_requests.size(), active_jobs)
