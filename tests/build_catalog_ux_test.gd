extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var sample := {
		"id": "sample",
		"name": "Sample Building",
		"menu_name": "SAMPLE",
		"category": "Infrastructure",
		"footprint": Vector2i(2, 3),
		"cost": 5000,
		"level": 4,
		"sizes": PackedStringArray(["S", "M"]),
		"description": "A useful test building."
	}

	var locked := BuildCatalogPresentation.availability(
		sample,
		2,
		10000
	)
	if String(locked.get("status", "")) != "locked":
		_fail("Low-level building state should be locked.")
		return
	if not bool(locked.get("inspectable", false)):
		_fail("Locked buildings should remain inspectable.")
		return
	if not BuildCatalogPresentation.card_text(
		sample,
		2,
		10000
	).contains("LV 4"):
		_fail("Locked card should expose required level.")
		return

	var shortfall := BuildCatalogPresentation.availability(
		sample,
		4,
		3200
	)
	if String(shortfall.get("status", "")) != "shortfall":
		_fail("Insufficient coins should create shortfall state.")
		return
	if int(shortfall.get("coin_shortfall", 0)) != 1800:
		_fail("Coin shortfall should be calculated exactly.")
		return
	if not BuildCatalogPresentation.card_text(
		sample,
		4,
		3200
	).contains("NEED 1,800"):
		_fail("Shortfall card should show the missing coin amount.")
		return

	var ready := BuildCatalogPresentation.availability(
		sample,
		4,
		5000
	)
	if not bool(ready.get("can_build", false)):
		_fail("Affordable unlocked building should be ready.")
		return

	var definitions := BuildingCatalog.get_menu_definitions()
	var summary := BuildCatalogPresentation.visible_summary(
		definitions,
		"ALL",
		1,
		1000
	)
	if int(summary.get("visible", 0)) != definitions.size():
		_fail("ALL summary should include the whole build catalog.")
		return
	if int(summary.get("locked", 0)) <= 0:
		_fail("Early airport should expose future locked buildings.")
		return

	var hud_script := load("res://src/ui/HUD.gd")
	if hud_script == null:
		_fail("HUD script should load.")
		return

	var hud = hud_script.new()
	root.add_child(hud)
	await process_frame

	hud.set_build_catalog(definitions)
	hud.set_player_data(1, 1000, 0)
	await process_frame

	if hud.catalog_summary_label == null:
		_fail("Build Tray should expose an availability summary.")
		return
	if not hud.catalog_summary_label.text.contains("ready"):
		_fail("Build Tray summary should show ready building count.")
		return
	if hud.build_preview_icon == null:
		_fail("Placement context should expose a building preview.")
		return
	if hud.build_meta_label == null:
		_fail("Placement context should expose building specs.")
		return

	var runway := BuildingCatalog.get_definition("short_runway")
	hud.enter_building_mode(runway)
	if hud.build_preview_icon.texture == null:
		_fail("Selected building should load its catalog artwork.")
		return
	if not hud.build_meta_label.text.contains("INFRASTRUCTURE"):
		_fail("Selected building should show its category/spec line.")
		return

	var regional := BuildingCatalog.get_definition("regional_runway")
	hud.show_build_preview(regional, {}, 1, 1000)
	var regional_button: Button = hud.catalog_buttons.get(
		"regional_runway"
	)
	if regional_button == null:
		_fail("Regional Runway should have a build card.")
		return
	if regional_button.disabled:
		_fail("Locked build cards should remain tappable for inspection.")
		return
	if not regional_button.text.contains("LV"):
		_fail("Locked build card should visibly show its unlock level.")
		return
	if not hud.place_button.disabled:
		_fail("Locked building must still prevent placement.")
		return

	print(
		"Build Tray UX passed: inspectable locked cards, coin shortfalls, "
		+ "availability summary, artwork preview and safe placement gating."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
