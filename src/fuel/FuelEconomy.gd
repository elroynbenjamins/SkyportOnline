class_name FuelEconomy
extends Node

signal changed(fuel: int, capacity: int, per_minute: float)
signal passive_fuel_delivered(amount: int)

var airport_grid: AirportGrid
var fuel := 0.0
var capacity := 0
var delivery_per_minute := 0.0


func configure(grid: AirportGrid, starting_fuel: float) -> void:
	airport_grid = grid
	fuel = maxf(starting_fuel, 0.0)
	refresh_building_stats()
	set_process(true)


func _process(delta: float) -> void:
	if delta <= 0.0 or capacity <= 0 or delivery_per_minute <= 0.0:
		return

	var old_whole := int(floor(fuel))
	fuel = minf(
		fuel + delivery_per_minute / 60.0 * delta,
		float(capacity)
	)
	var new_whole := int(floor(fuel))
	if new_whole != old_whole:
		passive_fuel_delivered.emit(maxi(new_whole - old_whole, 0))
		_emit_changed()


func refresh_building_stats() -> void:
	if airport_grid == null:
		return

	var by_uid: Dictionary = {}
	for size_class in ["S", "M"]:
		for building in airport_grid.get_compatible_service_buildings(
			"fuel",
			size_class
		):
			var uid := int(building.get("uid", -1))
			if uid >= 0:
				by_uid[uid] = building

	capacity = 0
	delivery_per_minute = 0.0
	for building_variant in by_uid.values():
		var building: Dictionary = building_variant
		capacity += maxi(int(building.get("fuel_storage", 0)), 0)
		delivery_per_minute += maxf(
			float(building.get("fuel_delivery_per_minute", 0.0)),
			0.0
		)

	fuel = minf(fuel, float(maxi(capacity, 0)))
	_emit_changed()


func spend_fuel(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_fuel() < amount:
		return false
	fuel -= float(amount)
	_emit_changed()
	return true


func add_fuel(amount: int) -> int:
	if amount <= 0 or capacity <= 0:
		return 0
	var before := fuel
	fuel = minf(fuel + float(amount), float(capacity))
	var added := int(floor(fuel - before))
	_emit_changed()
	return added


func set_fuel(value: float) -> void:
	fuel = clampf(value, 0.0, float(maxi(capacity, 0)))
	_emit_changed()


func get_fuel() -> int:
	return int(floor(fuel))


func get_capacity() -> int:
	return capacity


func get_delivery_per_minute() -> float:
	return delivery_per_minute


func _emit_changed() -> void:
	changed.emit(get_fuel(), capacity, delivery_per_minute)
