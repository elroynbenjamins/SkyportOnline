class_name PassengerEconomy
extends Node

signal changed(passengers: int, capacity: int, per_minute: float)

var airport_grid: AirportGrid
var passengers := 0.0
var capacity := 0
var production_per_minute := 0.0
var persist_accumulator := 0.0


func configure(grid: AirportGrid, starting_passengers: float = 20.0) -> void:
	airport_grid = grid
	passengers = maxf(starting_passengers, 0.0)
	refresh_building_stats()
	set_process(true)


func _process(delta: float) -> void:
	if capacity <= 0 or production_per_minute <= 0.0:
		return

	var old_whole := int(floor(passengers))
	passengers = minf(
		passengers + production_per_minute / 60.0 * delta,
		float(capacity)
	)

	if int(floor(passengers)) != old_whole:
		_emit_changed()

	persist_accumulator += delta


func refresh_building_stats() -> void:
	if airport_grid == null:
		return

	capacity = 0
	production_per_minute = 0.0

	for building in airport_grid.get_passenger_economy_buildings():
		var building_id := String(building.get("definition_id", ""))
		var level := int(building.get("upgrade_level", 1))
		var stats := PassengerUpgradeCatalog.passenger_stats(
			building_id,
			level
		)
		capacity += int(stats.get("storage", 0))
		production_per_minute += float(
			stats.get("passengers_per_minute", 0.0)
		)

	passengers = minf(passengers, float(capacity))
	_emit_changed()


func add_passengers(amount: int) -> int:
	if amount <= 0 or capacity <= 0:
		return 0

	var before := passengers
	passengers = minf(passengers + float(amount), float(capacity))
	var added := int(floor(passengers - before))
	_emit_changed()
	return added


func spend_passengers(amount: int) -> bool:
	if amount <= 0:
		return true
	if int(floor(passengers)) < amount:
		return false

	passengers -= float(amount)
	_emit_changed()
	return true


func set_passengers(value: float) -> void:
	passengers = clampf(value, 0.0, float(maxi(capacity, 0)))
	_emit_changed()


func get_passengers() -> int:
	return int(floor(passengers))


func get_capacity() -> int:
	return capacity


func get_production_per_minute() -> float:
	return production_per_minute


func _emit_changed() -> void:
	changed.emit(
		get_passengers(),
		capacity,
		production_per_minute
	)
