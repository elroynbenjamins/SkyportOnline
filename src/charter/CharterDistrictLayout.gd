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
			"layer": 30
		},
		{
			"id": "logistics_gate_checkpoint",
			"origin": Vector2i(6, 0),
			"rotation": 0,
			"layer": 30
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
			var a_layer := int(a.get("layer", 0))
			var b_layer := int(b.get("layer", 0))
			if a_layer != b_layer:
				return a_layer < b_layer

			var a_origin: Vector2i = a.get(
				"origin",
				Vector2i.ZERO
			)
			var b_origin: Vector2i = b.get(
				"origin",
				Vector2i.ZERO
			)
			var a_footprint := footprint_for_item(a)
			var b_footprint := footprint_for_item(b)
			var a_depth := (
				a_origin.x
				+ a_origin.y
				+ a_footprint.x
				+ a_footprint.y
			)
			var b_depth := (
				b_origin.x
				+ b_origin.y
				+ b_footprint.x
				+ b_footprint.y
			)
			if a_depth != b_depth:
				return a_depth < b_depth
			if a_origin.y != b_origin.y:
				return a_origin.y < b_origin.y
			return a_origin.x < b_origin.x
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


static func placement_status(
	visual_id: String,
	relative_origin: Vector2i,
	rotation: int = 0
) -> Dictionary:
	var definition := CharterVisualCatalog.visual_for(
		visual_id
	)
	if definition.is_empty():
		return {
			"valid": false,
			"reason": "Unknown Charter visual."
		}

	var default_item: Dictionary = {}
	for item in structure_items():
		if String(item.get("id", "")) == visual_id:
			default_item = item
			break
	if default_item.is_empty():
		return {
			"valid": false,
			"reason": "Only Charter district structures can be repositioned."
		}

	if visual_id == "cargo_aircraft_stand":
		var default_origin: Vector2i = default_item.get(
			"origin",
			Vector2i.ZERO
		)
		if relative_origin != default_origin:
			return {
				"valid": false,
				"reason": "Cargo aircraft stand is fixed.",
				"fixed": true
			}

	var preview_item := default_item.duplicate(true)
	preview_item["origin"] = relative_origin
	preview_item["rotation"] = rotation % 2
	var footprint := footprint_for_item(preview_item)
	var future_keys: Dictionary = {}
	for cell in future_relative_cells():
		future_keys[
			"%d:%d" % [cell.x, cell.y]
		] = true

	for y in range(footprint.y):
		for x in range(footprint.x):
			var cell := relative_origin + Vector2i(x, y)
			if (
				cell.x < 0
				or cell.y < 0
				or cell.x >= PARCEL_SIZE
				or cell.y >= PARCEL_SIZE
			):
				return {
					"valid": false,
					"reason": "Charter structures must stay inside the Logistics District.",
					"logistics_only": true
				}
			var key := "%d:%d" % [cell.x, cell.y]
			if future_keys.has(key):
				return {
					"valid": false,
					"reason": "Reserved for future Charter logistics buildings.",
					"future_reserved": true
				}

	return {
		"valid": true,
		"reason": "Valid Logistics District placement.",
		"footprint": footprint,
		"logistics_only": true
	}


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
