extends SceneTree

# The modern HUD intentionally uses editable Godot styles, not old textured
# browser-era surfaces. The same control signals and exact amount data remain.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud = preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame

	var pills: Array[PanelContainer] = [
		hud.hud_level_card, hud.hud_identity_card, hud.hud_passenger_chip,
		hud.hud_fuel_chip, hud.hud_coin_chip, hud.hud_premium_chip
	]
	for pill in pills:
		var surface := pill.get_theme_stylebox("panel")
		if not (surface is StyleBoxFlat):
			_fail("Resource pills must use native editable modern surfaces.")
			return
		if (surface as StyleBoxFlat).corner_radius_top_left < 14:
			_fail("Resource pills need consistently soft rounded corners.")
			return

	hud.set_player_data(12, 1250000, 37500)
	if hud.coins_label.text != "1.2M" or hud.gems_label.text != "37.5K":
		_fail("Large resource counts should not overflow their pills.")
		return
	if not hud.hud_coin_chip.tooltip_text.contains("1,250,000"):
		_fail("Short currency labels must retain their exact amount.")
		return
	hud.set_passenger_data(842, 1000, 2.0)
	hud.set_fuel_data(180, 360, 1.6)
	if hud.passenger_label.text != "842 / 1000":
		_fail("Small passenger amounts must preserve exact values.")
		return
	if hud.fuel_label.text != "180 / 360":
		_fail("Small fuel amounts must preserve exact values.")
		return
	if not hud.hud_fuel_chip.tooltip_text.contains("1.6 per minute"):
		_fail("Full regeneration rates should remain accessible.")
		return

	hud._update_top_bar_layout(850)
	if not hud.hud_compact_layout or hud.xp_label.visible:
		_fail("Phone landscape should hide secondary XP text.")
		return
	if hud.hud_identity_card.custom_minimum_size.x > 150:
		_fail("Phone landscape should shrink the identity panel.")
		return
	if hud.passenger_rate_label.visible or hud.fuel_rate_label.visible:
		_fail("Phone landscape should hide redundant rate sublabels.")
		return
	hud._update_top_bar_layout(1280)
	if hud.hud_compact_layout or not hud.passenger_rate_label.visible:
		_fail("Wide landscape should restore supporting resource details.")
		return

	var definitions: Array[Dictionary] = [
		BuildingCatalog.get_definition("small_hangar"),
		BuildingCatalog.get_definition("short_runway")
	]
	hud.set_build_catalog(definitions)
	var card := hud.catalog_buttons.get("small_hangar") as Button
	if card == null or not (card.get_theme_stylebox("normal") is StyleBoxFlat):
		_fail("Build cards must use modern native buttons.")
		return
	if not card.text.contains("4×3") or not card.text.contains("COINS"):
		_fail("Build cards need their real footprint and price.")
		return
	if card.custom_minimum_size.y < 80:
		_fail("Build cards must offer comfortable touch targets.")
		return
	for chip in hud.catalog_filter_buttons.values():
		if (chip as Button).custom_minimum_size.y < 42:
			_fail("Build filters need comfortable landscape touch targets.")
			return

	var filter := hud.catalog_filter_buttons.get("Infrastructure") as Button
	if filter == null or not (filter.get_theme_stylebox("normal") is StyleBoxFlat):
		_fail("Build category filters must not fall back to glossy legacy textures.")
		return
	hud._on_catalog_filter_pressed("Infrastructure")
	if String(filter.get_meta("game_style_key", "")) != "build_filter_selected:compact":
		_fail("Chosen category should retain an obvious native selection state.")
		return

	for status_button in [
		hud.airside_status_chip, hud.operation_status_chip, hud.atc_status_chip
	]:
		if not (status_button.get_theme_stylebox("normal") is StyleBoxFlat):
			_fail("Airport status chips should share native pill controls.")
			return

	print("MODERN_RESOURCE_BUILD_UI_OK native_pills=true responsive=true build_cards=true")
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
