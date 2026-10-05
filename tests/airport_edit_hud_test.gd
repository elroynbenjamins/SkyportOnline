extends SceneTree


var edit_emitted := false
var undo_emitted := false
var done_emitted := false
var store_emitted := false
var stored_uid := -1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame

	if hud.edit_airport_button == null:
		_fail("Build tray should expose an Edit Airport button.")
		return

	hud.airport_edit_requested.connect(
		_on_edit_requested
	)
	hud.undo_airport_edit_requested.connect(
		_on_undo_requested
	)
	hud.done_airport_edit_requested.connect(
		_on_done_requested
	)
	hud.store_building_requested.connect(
		_on_store_requested
	)
	hud.stored_building_selected.connect(
		_on_stored_building_selected
	)

	hud._on_airport_edit_pressed()
	if not edit_emitted:
		_fail("Edit Airport button should request edit mode.")
		return

	hud.show_airport_edit_mode(
		true,
		false,
		"Tap a building"
	)
	if not hud.airport_edit_panel.visible:
		_fail("Airport edit toolbar should be visible in edit mode.")
		return
	if hud.catalog_panel.visible:
		_fail("Build tray should hide while editing the airport.")
		return
	if not hud.undo_airport_edit_button.disabled:
		_fail("Undo should start disabled before a confirmed move.")
		return
	if hud.airport_edit_status.text != "Tap a building":
		_fail("Edit toolbar should display the supplied guidance.")
		return

	hud.set_airport_edit_undo_available(true)
	if hud.undo_airport_edit_button.disabled:
		_fail("Undo should enable after a confirmed move.")
		return
	hud._on_undo_airport_edit_pressed()
	if not undo_emitted:
		_fail("Enabled Undo should emit an undo request.")
		return

	var definition := BuildingCatalog.get_definition(
		"basic_fuel"
	)
	var stored_items: Array[Dictionary] = [
		{
			"uid": 77,
			"definition_id": "basic_fuel",
			"rotation": 0,
			"upgrade_level": 2
		}
	]
	hud.set_stored_buildings(stored_items)
	if not hud.storage_button.text.contains("1"):
		_fail("Storage toolbar should show stored building count.")
		return

	hud._on_storage_pressed()
	if not hud.storage_panel.visible:
		_fail("Storage button should open the storage drawer.")
		return

	hud._on_stored_building_pressed(77)
	if stored_uid != 77:
		_fail("Storage item should emit the selected building UID.")
		return
	if hud.storage_panel.visible:
		_fail("Selecting a stored building should close the drawer.")
		return

	hud.enter_move_mode(definition)
	if not hud.store_button.visible:
		_fail("Moving a building should expose the Store action.")
		return
	hud._on_store_building_pressed()
	if not store_emitted:
		_fail("Store action should emit a storage request.")
		return

	hud.enter_stored_building_mode(
		definition,
		{
			"uid": 77,
			"definition_id": "basic_fuel",
			"upgrade_level": 2
		}
	)
	if hud.store_button.visible:
		_fail("Stored placement should not show Store again.")
		return
	if hud.place_button.text != "TAP LAND":
		_fail("Stored placement should wait for a placement preview.")
		return

	hud._on_done_airport_edit_pressed()
	if not done_emitted:
		_fail("Done should emit an edit completion request.")
		return

	hud.show_airport_edit_mode(false)
	if hud.airport_edit_panel.visible:
		_fail("Edit toolbar should hide after leaving edit mode.")
		return
	if not hud.catalog_panel.visible:
		_fail("Build tray should return after leaving edit mode.")
		return

	print(
		"Airport edit HUD passed: enter, guidance, undo, done and tray restore."
	)
	quit(0)


func _on_edit_requested() -> void:
	edit_emitted = true


func _on_undo_requested() -> void:
	undo_emitted = true


func _on_done_requested() -> void:
	done_emitted = true


func _on_store_requested() -> void:
	store_emitted = true


func _on_stored_building_selected(uid: int) -> void:
	stored_uid = uid


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
