extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame

	if hud.handling_attention_button == null:
		_fail("HUD should expose a handling-attention chip.")
		return
	if hud.handling_attention_button.visible:
		_fail("Handling-attention chip should start hidden.")
		return

	hud.set_handling_attention(
		"SO-001",
		"LAND",
		2
	)
	if not hud.handling_attention_button.visible:
		_fail("Handling-attention chip should appear when an aircraft needs input.")
		return
	if not hud.handling_attention_button.text.contains("LAND"):
		_fail("Handling-attention chip should show the pending action.")
		return
	if not hud.handling_attention_button.text.contains("SO-001"):
		_fail("Handling-attention chip should identify the aircraft.")
		return
	if not hud.handling_attention_button.text.contains("+1"):
		_fail("Handling-attention chip should summarize additional waiting aircraft.")
		return

	var requested := false
	hud.handling_attention_requested.connect(
		func() -> void:
			requested = true
	)
	hud.handling_attention_button.pressed.emit()
	if not requested:
		_fail("Pressing the handling-attention chip should request aircraft focus.")
		return

	hud.set_handling_attention(
		"",
		"",
		0
	)
	if hud.handling_attention_button.visible:
		_fail("Handling-attention chip should hide when no aircraft needs input.")
		return

	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("pico_p8")
	plane.configure_handling_mode(true, false)
	plane.set_handling_action("TAXI")
	if plane.handling_action_button == null:
		_fail("Manual aircraft should have an in-world handling button.")
		return
	if not plane.handling_action_button.visible:
		_fail("Manual handling button should be visible while TAXI is pending.")
		return

	var alpha_a := plane.handling_action_button.modulate.a
	plane._process(0.35)
	plane._sync_handling_action_transform()
	var alpha_b := plane.handling_action_button.modulate.a
	if is_equal_approx(alpha_a, alpha_b):
		_fail("In-world handling button should pulse to attract attention.")
		return
	if alpha_b < 0.79 or alpha_b > 1.01:
		_fail("Handling pulse should remain subtle and readable.")
		return

	var camera := CameraController.new()
	root.add_child(camera)
	await process_frame
	if not camera.has_method("focus_world_position"):
		_fail("Camera should retain the focus helper used by the handling chip.")
		return
	camera.position = Vector2.ZERO
	camera.focus_world_position(
		Vector2(120, 60),
		0.0,
		0.8
	)
	if camera.position.distance_to(
		Vector2(96, 48)
	) > 0.1:
		_fail("Handling attention should be able to focus the waiting aircraft.")
		return

	print(
		"AIRCRAFT_HANDLING_ATTENTION_OK hud=true focus=true pulse=true queue_count=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
