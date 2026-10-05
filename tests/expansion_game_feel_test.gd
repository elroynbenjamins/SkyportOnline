extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	if grid.is_parcel_unlock_animation_active("north"):
		_fail("Locked parcel should not animate before purchase.")
		return
	if not grid.purchase_parcel("north"):
		_fail("North parcel should be purchasable from the initial frontier.")
		return
	if not grid.is_parcel_unlock_animation_active("north"):
		_fail("Purchased parcel should start its unlock animation.")
		return
	if grid.get_parcel_tile_count("north") != 64:
		_fail("Expansion banner should report the parcel build-tile count.")
		return
	if grid.get_parcel_world_center("north") == Vector2.ZERO:
		_fail("Purchased parcel should expose a valid camera focus point.")
		return

	var camera := preload(
		"res://src/world/CameraController.gd"
	).new()
	root.add_child(camera)
	await process_frame
	camera.position = Vector2(100, 100)
	camera.focus_world_position(
		Vector2(300, 200),
		0.0,
		1.0
	)
	if camera.position != Vector2(300, 200):
		_fail("Immediate camera focus should reach the parcel center.")
		return

	camera.position = Vector2(100, 100)
	camera.focus_world_position(
		Vector2(300, 200),
		0.0,
		0.5
	)
	if camera.position != Vector2(200, 150):
		_fail("Camera focus strength should allow a gentle partial pan.")
		return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.show_airport_expanded("North", 64)
	if not hud.expansion_banner.visible:
		_fail("Airport Expanded banner should become visible.")
		return
	if hud.expansion_banner_title.text != "AIRPORT EXPANDED":
		_fail("Expansion banner should use the expected reward title.")
		return
	if not hud.expansion_banner_detail.text.contains(
		"NORTH"
	):
		_fail("Expansion banner should name the unlocked parcel.")
		return
	if not hud.expansion_banner_detail.text.contains(
		"+64"
	):
		_fail("Expansion banner should show newly unlocked build tiles.")
		return

	hud._hide_expansion_banner()
	if hud.expansion_banner.visible:
		_fail("Expansion banner should be hideable after its reward moment.")
		return

	print(
		"Expansion game feel passed: parcel pulse, camera focus and reward banner."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
