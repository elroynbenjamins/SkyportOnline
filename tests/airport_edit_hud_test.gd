extends SceneTree


var edit_emitted := false
var undo_emitted := false
var done_emitted := false


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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
