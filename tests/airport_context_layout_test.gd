extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var building := BuildingContextCard.new()
	root.add_child(building)
	var aircraft := AircraftContextCard.new()
	root.add_child(aircraft)
	await process_frame

	for card in [building, aircraft]:
		if card.content_scroll == null:
			_fail("Context cards require scrollable content on short phones.")
			return
		if card.content_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
			_fail("Context card content must scroll if it exceeds the viewport.")
			return
		card._update_card_layout(Vector2i(820, 340))
		if card.panel.offset_top < -335.0:
			_fail("A compact phone must not clip the card above the screen.")
			return
		if card.panel.offset_bottom > -55.0:
			_fail("Cards must sit clear of the bottom airport status strip.")
			return
		if card.panel.offset_right > 810.0:
			_fail("Cards must not extend past a compact phone's right edge.")
			return
		card._update_card_layout(Vector2i(1280, 720))
		if card.panel.offset_left < 12.0 or card.panel.offset_right > 470.0:
			_fail("Desktop/large landscape must preserve the compact left dock.")
			return
		if card.panel.offset_bottom > -75.0:
			_fail("Large-landscape cards must clear the contextual footer.")
			return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")
	plane.configure_skyrama_handling(true)
	plane.start_simple_fueling(Vector2(50, 70), 20.0)
	aircraft.show_aircraft(plane, {}, 40, 80)
	if not aircraft.service_label.text.contains("dedicated fuel parking pad"):
		_fail("Aircraft cards must explain actual roadless fueling behavior.")
		return
	plane._process(21.0)
	aircraft.refresh_card()
	if not aircraft.service_label.text.contains("tap LOAD"):
		_fail("Finished servicing must clearly direct the next player tap.")
		return

	print("AIRPORT_CONTEXT_LAYOUT_OK compact=true scroll=true roadless_actions=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
