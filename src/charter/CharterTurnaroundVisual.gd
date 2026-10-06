class_name CharterTurnaroundVisual
extends Node2D

const PLANE_SIZE := Vector2(218, 164)
const SERVICE_SIZE := Vector2(62, 62)
const PALLET_SIZE := Vector2(42, 42)

var charter_active := false
var phase := "IDLE"
var pallet_count := 0
var visual_variant := 0


func set_charter_visual_state(snapshot: Dictionary) -> void:
	charter_active = bool(snapshot.get("active", false))
	phase = String(snapshot.get("phase", "IDLE")).to_upper()
	pallet_count = clampi(
		int(snapshot.get("pallet_count", 0)),
		0,
		4
	)
	visual_variant = posmod(
		int(snapshot.get("visual_variant", 0)),
		2
	)
	visible = charter_active
	queue_redraw()


func clear_charter_visuals() -> void:
	charter_active = false
	phase = "IDLE"
	pallet_count = 0
	visible = false
	queue_redraw()


func get_visual_snapshot() -> Dictionary:
	return {
		"active": charter_active,
		"phase": phase,
		"pallet_count": pallet_count,
		"visual_variant": visual_variant
	}


func _draw() -> void:
	if not charter_active:
		return

	_draw_aircraft()
	_draw_pallet_slots()

	match phase:
		"ARRIVED", "UNLOADING", "LOADING":
			_draw_loading_equipment()
		"READY", "PUSHBACK", "DEPARTING":
			_draw_departure_tug()


func _draw_aircraft() -> void:
	var plane := _first_texture(
		PackedStringArray([
			"cargo_plane",
			"cargo_twin_prop",
			"charter_cargo_plane",
			"twin_prop"
		])
	)
	if plane == null:
		return

	var rect := Rect2(
		Vector2(-PLANE_SIZE.x * 0.5, -PLANE_SIZE.y * 0.5 - 42),
		PLANE_SIZE
	)
	draw_set_transform(
		Vector2(4, 8),
		0.0,
		Vector2(1.0, 0.38)
	)
	draw_circle(
		Vector2(0, -48),
		72.0,
		Color(0.02, 0.04, 0.05, 0.20)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(plane, rect, false)


func _draw_pallet_slots() -> void:
	var pallet := _first_texture(
		PackedStringArray([
			"pallet",
			"cargo_pallet",
			"pallet_stack",
			"crate",
			"cargo_crate"
		])
	)

	var positions := [
		Vector2(-70, 35),
		Vector2(-28, 56),
		Vector2(28, 56),
		Vector2(70, 35)
	]
	for index in range(4):
		var position: Vector2 = positions[index]
		draw_set_transform(
			position,
			0.0,
			Vector2(1.0, 0.42)
		)
		draw_circle(
			Vector2.ZERO,
			16.0,
			Color(0.03, 0.05, 0.05, 0.18)
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		if index < pallet_count and pallet != null:
			draw_texture_rect(
				pallet,
				Rect2(
					position - PALLET_SIZE * 0.5,
					PALLET_SIZE
				),
				false
			)
		else:
			_draw_empty_pallet_slot(position)


func _draw_empty_pallet_slot(position: Vector2) -> void:
	var diamond := PackedVector2Array([
		position + Vector2(0, -8),
		position + Vector2(15, 0),
		position + Vector2(0, 8),
		position + Vector2(-15, 0),
		position + Vector2(0, -8)
	])
	draw_polyline(
		diamond,
		Color(0.82, 0.86, 0.80, 0.36),
		1.4
	)


func _draw_loading_equipment() -> void:
	var forklift := _first_texture(
		PackedStringArray([
			"forklift",
			"cargo_forklift"
		])
	)
	if forklift != null:
		draw_texture_rect(
			forklift,
			Rect2(
				Vector2(-112, 6) - SERVICE_SIZE * 0.5,
				SERVICE_SIZE
			),
			false
		)

	var conveyor := _first_texture(
		PackedStringArray([
			"conveyor",
			"cargo_conveyor",
			"belt_loader"
		])
	)
	if conveyor != null:
		draw_texture_rect(
			conveyor,
			Rect2(
				Vector2(103, 0) - SERVICE_SIZE * 0.5,
				SERVICE_SIZE
			),
			false
		)


func _draw_departure_tug() -> void:
	var tug := _first_texture(
		PackedStringArray([
			"cargo_tug",
			"tug",
			"pushback_tug"
		])
	)
	if tug == null:
		return
	draw_texture_rect(
		tug,
		Rect2(
			Vector2(0, 84) - SERVICE_SIZE * 0.5,
			SERVICE_SIZE
		),
		false
	)


func _first_texture(
	asset_keys: PackedStringArray
) -> Texture2D:
	for asset_key_variant in asset_keys:
		var texture := CharterVisualPack.texture(
			String(asset_key_variant),
			visual_variant
		)
		if texture != null:
			return texture
	return null
