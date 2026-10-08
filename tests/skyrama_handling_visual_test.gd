extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("pico_p8")
	plane.configure_skyrama_handling(true)
	plane.visible = true

	plane.set_handling_action("LAND")
	var ready := plane.get_handling_visual_snapshot()
	if not bool(ready.get("action_visible", false)):
		_fail("RECEIVE bubble should be visible for inbound manual handling.")
		return
	if not String(ready.get("action_text", "")).contains("RECEIVE"):
		_fail("LAND internal action should render as RECEIVE.")
		return
	if bool(ready.get("progress_visible", true)):
		_fail("Ready action should not show a service progress bar.")
		return

	plane.start_simple_fueling(Vector2(100, 100), 10.0)
	plane._process(4.0)
	var fueling := plane.get_handling_visual_snapshot()
	if not bool(fueling.get("status_visible", false)):
		_fail("Fueling should show the progress bubble.")
		return
	if not bool(fueling.get("progress_visible", false)):
		_fail("Fueling should show a visible progress bar.")
		return
	var progress := float(fueling.get("progress_value", 0.0))
	if progress < 35.0 or progress > 45.0:
		_fail("Fuel progress should reflect elapsed service time.")
		return
	if not String(fueling.get("status_text", "")).contains("FUELING"):
		_fail("Fuel progress bubble should clearly name the stage.")
		return

	plane._process(6.1)
	var fuel_done := plane.get_handling_visual_snapshot()
	if bool(fuel_done.get("progress_visible", true)):
		_fail("Completed service should hide the progress bar.")
		return
	if String(fuel_done.get("action", "")) != "LOAD":
		_fail("Completed fueling should expose LOAD.")
		return
	if not bool(fuel_done.get("action_visible", false)):
		_fail("Completed fueling should show the LOAD action bubble.")
		return

	print(
		"SKYRAMA_HANDLING_VISUAL_OK receive=true progress=true "
		+ "fuel_to_load=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
