extends SceneTree

const OUTPUT := "res://artifacts/pico_four_direction_polish.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.color = Color("d8e8e5")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var headings := [-PI * 0.25, PI * 0.25, PI * 0.75, -PI * 0.75]
	var states := ["PARKED", "APPROACH", "LANDING_ROLL", "TAKEOFF_ROLL"]
	var captions := [
		"NE • PARKED", "SE • APPROACH",
		"SW • TOUCHDOWN", "NW • TAKEOFF"
	]
	for i in range(headings.size()):
		var card := PanelContainer.new()
		card.position = Vector2(18 + i * 315, 85)
		card.custom_minimum_size = Vector2(296, 420)
		card.size = Vector2(296, 420)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("eaf6f3")
		style.border_color = Color("94c9c9")
		style.set_border_width_all(2)
		style.set_corner_radius_all(16)
		card.add_theme_stylebox_override("panel", style)
		root.add_child(card)

		var tarmac := ColorRect.new()
		tarmac.color = Color("b4ced2")
		tarmac.position = Vector2(20 + i * 315, 310)
		tarmac.size = Vector2(292, 115)
		root.add_child(tarmac)
		var ground_line := ColorRect.new()
		ground_line.color = Color("e8f7df")
		ground_line.position = Vector2(55 + i * 315, 365)
		ground_line.size = Vector2(220, 3)
		root.add_child(ground_line)

		var title := Label.new()
		title.position = Vector2(35 + i * 315, 112)
		title.text = captions[i]
		title.add_theme_color_override("font_color", Color("23536a"))
		title.add_theme_font_size_override("font_size", 19)
		root.add_child(title)

		var plane := CareerAircraft.new()
		plane.name = "SO-%03d" % (i + 1)
		root.add_child(plane)
		await process_frame
		plane.configure_aircraft_type("pico_p8")
		plane.set_process(false)
		plane.position = Vector2(165 + i * 315, 290)
		plane.rotation = headings[i]
		plane.scale = Vector2(2.25, 2.25)
		plane._set_state(states[i])
		plane.visible = true
		plane.z_index = 8
		plane.queue_redraw()

	var page_title := Label.new()
	page_title.position = Vector2(24, 24)
	page_title.text = "PICO P8  •  FOUR-DIRECTION VISUAL QA"
	page_title.add_theme_font_size_override("font_size", 25)
	page_title.add_theme_color_override("font_color", Color("214e62"))
	root.add_child(page_title)

	var note := Label.new()
	note.position = Vector2(35, 541)
	note.text = "Production sprites • directional propeller blur • matched wingtip lights • soft ground shadows"
	note.add_theme_color_override("font_color", Color("285d6c"))
	note.add_theme_font_size_override("font_size", 16)
	root.add_child(note)

	for _frame in range(5):
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Could not capture Pico four-direction QA.")
		quit(1)
		return
	var absolute := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if image.save_png(absolute) != OK:
		push_error("Could not save four-direction Pico screenshot.")
		quit(1)
		return
	print("PICO_DIRECTIONAL_SCREENSHOT_OK path=%s" % OUTPUT)
	quit(0)
