class_name CharterDistrictLayout
extends RefCounted

const PARCEL_ID := "south_west"
const PARCEL_SIZE := 8


static func structure_items() -> Array[Dictionary]:
	return [
		{
			"id": "cargo_aircraft_stand",
			"origin": Vector2i(0, 0),
			"rotation": 0,
			"layer": 10
		},
		{
			"id": "cargo_warehouse",
			"origin": Vector2i(0, 4),
			"rotation": 0,
			"layer": 30
		},
		{
			"id": "cargo_charter_office",
			"origin": Vector2i(6, 4),
			"rotation": 1,
			"layer": 32
		},
		{
			"id": "logistics_gate_checkpoint",
			"origin": Vector2i(6, 0),
			"rotation": 1,
			"layer": 34
		}
	]


static func surface_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{
			"id": "loading_dock_pad",
			"origin": Vector2i(2, 3),
			"rotation": 0,
			"layer": 6
		},
		{
			"id": "pallet_sorting_yard",
			"origin": Vector2i(4, 2),
			"rotation": 0,
			"layer": 6
		},
		{
			"id": "container_storage_pad",
			"origin": Vector2i(4, 4),
			"rotation": 0,
			"layer": 6
		}
	]

	# Airport-facing gate -> road spine -> stand / warehouse loading spur.
	for x in range(3, 7):
		result.append({
			"id": "service_road_tile",
			"origin": Vector2i(x, 1),
			"rotation": 0,
			"layer": 4
		})
	for y in range(2, 6):
		result.append({
			"id": "service_road_tile",
			"origin": Vector2i(3, y),
			"rotation": 1,
			"layer": 4
		})
	return result


static func future_pad_items() -> Array[Dictionary]:
	return [
		{
			"id": "future_logistics_pad_1",
			"origin": Vector2i(0, 6),
			"footprint": Vector2i(2, 2)
		},
		{
			"id": "future_logistics_pad_2",
			"origin": Vector2i(2, 6),
			"footprint": Vector2i(2, 2)
		},
		{
			"id": "future_logistics_pad_3",
			"origin": Vector2i(4, 6),
			"footprint": Vector2i(2, 2)
		}
	]


static func all_visual_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(surface_items())
	result.append_array(structure_items())
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("layer", 0)) < int(
				b.get("layer", 0)
			)
	)
	return result


static func footprint_for_item(item: Dictionary) -> Vector2i:
	var visual := CharterVisualCatalog.visual_for(
		String(item.get("id", ""))
	)
	if visual.is_empty():
		return Vector2i.ONE
	var footprint: Vector2i = visual.get(
		"footprint",
		Vector2i.ONE
	)
	if (
		bool(visual.get("rotatable", false))
		and int(item.get("rotation", 0)) % 2 == 1
	):
		return Vector2i(
			footprint.y,
			footprint.x
		)
	return footprint


static func reserved_relative_cells() -> Array[Vector2i]:
	var unique: Dictionary = {}
	for item in all_visual_items():
		var origin: Vector2i = item.get(
			"origin",
			Vector2i.ZERO
		)
		var footprint := footprint_for_item(item)
		for y in range(footprint.y):
			for x in range(footprint.x):
				var cell := origin + Vector2i(x, y)
				unique[
					"%d:%d" % [cell.x, cell.y]
				] = cell

	var result: Array[Vector2i] = []
	for value_variant in unique.values():
		result.append(value_variant)
	result.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			return a.x < b.x
	)
	return result


static func future_relative_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pad in future_pad_items():
		var origin: Vector2i = pad.get(
			"origin",
			Vector2i.ZERO
		)
		var footprint: Vector2i = pad.get(
			"footprint",
			Vector2i(2, 2)
		)
		for y in range(footprint.y):
			for x in range(footprint.x):
				result.append(
					origin + Vector2i(x, y)
				)
	return result


static func layout_validation() -> Dictionary:
	var errors: Array[String] = []
	var reserved := reserved_relative_cells()
	var future := future_relative_cells()
	var reserved_keys: Dictionary = {}

	for cell in reserved:
		if (
			cell.x < 0
			or cell.y < 0
			or cell.x >= PARCEL_SIZE
			or cell.y >= PARCEL_SIZE
		):
			errors.append(
				"Reserved cell %s is outside the Logistics parcel."
				% str(cell)
			)
		reserved_keys[
			"%d:%d" % [cell.x, cell.y]
		] = true

	for cell in future:
		if (
			cell.x < 0
			or cell.y < 0
			or cell.x >= PARCEL_SIZE
			or cell.y >= PARCEL_SIZE
		):
			errors.append(
				"Future cell %s is outside the Logistics parcel."
				% str(cell)
			)
		var key := "%d:%d" % [cell.x, cell.y]
		if reserved_keys.has(key):
			errors.append(
				"Future logistics cell %s overlaps the active Charter district."
				% str(cell)
			)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"reserved_cells": reserved.size(),
		"future_cells": future.size(),
		"future_pads": future_pad_items().size()
	}
