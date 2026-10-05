extends SceneTree


var edit_emitted := false
var undo_emitted := false
var done_emitted := false
var store_emitted := false
var stored_uid := -1
var expanded_parcel_id := ""


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
	hud.placement_expand_requested.connect(
		_on_placement_expand_requested
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

	hud.set_player_data(4, 50000, 0)
	hud.show_move_preview(
		definition,
		{
			"valid": false,
			"reason": "This land parcel is still locked.",
			"locked_parcel_id": "north",
			"locked_parcel_level": 5,
			"locked_parcel_cost": 25000
		}
	)
	if not hud.expand_here_button.visible:
		_fail("Locked placement should expose Expand Here.")
		return
	if not hud.expand_here_button.disabled:
		_fail("Expand Here should respect the parcel level requirement.")
		return
	if hud.place_button.visible:
		_fail("Expand Here should replace the blocked confirm button.")
		return

	hud.set_player_data(5, 25000, 0)
	hud.show_move_preview(
		definition,
		{
			"valid": false,
			"reason": "This land parcel is still locked.",
			"locked_parcel_id": "north",
			"locked_parcel_level": 5,
			"locked_parcel_cost": 25000
		}
	)
	if hud.expand_here_button.disabled:
		_fail("Affordable level-eligible expansion should be enabled.")
		return
	hud._on_expand_here_pressed()
	if expanded_parcel_id != "north":
		_fail("Expand Here should emit the blocking parcel id.")
		return

	hud.show_move_preview(
		definition,
		{
			"valid": true,
			"footprint": Vector2i(2, 2)
		}
	)
	if hud.expand_here_button.visible:
		_fail("Expand Here should hide once placement is valid.")
		return
	if not hud.place_button.visible:
		_fail("Confirm Move should return after expansion is resolved.")
		return

	hud.enter_building_mode(definition)
	hud.set_player_data(5, 30000, 0)
	hud.show_build_preview(
		definition,
		{
			"valid": false,
			"reason": "This land parcel is still locked.",
			"locked_parcel_id": "north",
			"locked_parcel_level": 5,
			"locked_parcel_cost": 25000
		},
		5,
		30000
	)
	if not hud.expand_here_button.disabled:
		_fail(
			"New construction expansion should reserve the building cost."
		)
		return

	hud.set_player_data(5, 32500, 0)
	hud.show_build_preview(
		definition,
		{
			"valid": false,
			"reason": "This land parcel is still locked.",
			"locked_parcel_id": "north",
			"locked_parcel_level": 5,
			"locked_parcel_cost": 25000
		},
		5,
		32500
	)
	if hud.expand_here_button.disabled:
		_fail(
			"Parcel plus building affordability should enable expansion."
		)
		return

	hud.exit_building_mode()

	hud.show_parcel(
		{
			"id": "north_west",
			"owned": false,
			"progression_state": "future",
			"level": 30,
			"cost": 1200000
		},
		40,
		3000000
	)
	if hud.purchase_button.text != "NOT CONNECTED":
		_fail("Future parcel should show Not Connected.")
		return
	if not hud.purchase_button.disabled:
		_fail("Future parcel purchase should remain disabled.")
		return

	hud.show_parcel(
		{
			"id": "north",
			"owned": false,
			"progression_state": "available",
			"level": 5,
			"cost": 25000
		},
		5,
		25000
	)
	if hud.purchase_button.disabled:
		_fail("Connected affordable parcel should be purchasable.")
		return
	if hud.parcel_title.text != "NORTH":
		_fail("Legacy parcel data without a district name should still show its location.")
		return

	hud.show_move_preview(
		definition,
		{
			"valid": false,
			"reason": "Expand a neighboring parcel first.",
			"locked_parcel_id": "north_west",
			"locked_parcel_state": "future",
			"locked_parcel_level": 30,
			"locked_parcel_cost": 1200000
		}
	)
	if not hud.expand_here_button.visible:
		_fail("Future placement should still explain the expansion blocker.")
		return
	if not hud.expand_here_button.disabled:
		_fail("Disconnected placement expansion must stay disabled.")
		return
	if not hud.expand_here_button.text.contains("CONNECT LAND"):
		_fail("Future placement should instruct the player to connect land.")
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


func _on_placement_expand_requested(parcel_id: String) -> void:
	expanded_parcel_id = parcel_id


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
