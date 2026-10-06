extends SceneTree


var selected_building: Dictionary = {}
var primary_emitted := false
var move_emitted := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	grid.building_selected_world.connect(_on_building_selected)

	var fuel_world := grid.tile_to_world(Vector2(13, 13))
	grid.select_world_position(fuel_world)

	if selected_building.is_empty():
		_fail("Tapping a placed building should emit building selection.")
		return
	if String(
		selected_building.get("definition_id", "")
	) != "basic_fuel":
		_fail("Fuel-station tap should select the Basic Fuel Station.")
		return

	var selected_uid := int(
		selected_building.get("uid", -1)
	)
	if grid.selected_synergy_uid != selected_uid:
		_fail(
			"World building selection should retain the selected UID for visual feedback."
		)
		return
	var selection_polygon := grid._selected_building_polygon()
	if selection_polygon.size() != 4:
		_fail(
			"Selected high-detail building should expose a four-corner footprint highlight."
		)
		return
	if not grid.building_labels.is_empty():
		_fail(
			"Clean starter airport should not cover production building art with generic labels."
		)
		return

	grid.clear_synergy_selection()
	if not grid._selected_building_polygon().is_empty():
		_fail(
			"Clearing building selection should remove the in-world selection outline."
		)
		return

	grid.select_world_position(fuel_world)
	if grid.selected_synergy_uid != selected_uid:
		_fail(
			"Fuel building should be reselectable after clearing visual selection."
		)
		return

	var card := BuildingContextCard.new()
	root.add_child(card)
	await process_frame

	card.show_building(
		selected_building,
		{
			"role": "Ground service",
			"status": "No queue • service available",
			"tone": "success",
			"stat_one": "SERVICE SPEED\nx1.00",
			"stat_two": "VEHICLES\n1",
			"primary_label": "UPGRADE",
			"primary_kind": "primary",
			"show_move": true,
			"move_enabled": true,
			"move_reason": "Move is free."
		}
	)

	if not card.is_open():
		_fail("Building context card should open.")
		return
	if not card.title_label.text.contains("Basic Fuel Station"):
		_fail("Building card should show selected building name.")
		return
	if not card.title_label.text.contains("LV 1"):
		_fail("Building card should show upgrade level.")
		return
	if card.building_image.texture == null:
		_fail("Building card should load the building icon.")
		return

	var fuel_definition := BuildingCatalog.get_definition(
		"basic_fuel"
	)
	if String(
		fuel_definition.get("art_tier", "")
	) != "canonical_v2":
		_fail("Basic Fuel should use the canonical v2 quality tier.")
		return
	if String(
		fuel_definition.get("world_sprite_atlas_path", "")
	) != BuildingCatalog.PRODUCTION_BUILDING_ATLAS:
		_fail("Basic Fuel should resolve to the canonical production atlas.")
		return
	var fuel_regions: Array = fuel_definition.get(
		"world_sprite_regions",
		[]
	)
	var expected_fuel_regions := [
		Rect2(896, 448, 448, 448),
		Rect2(1344, 448, 448, 448)
	]
	if fuel_regions != expected_fuel_regions:
		_fail("Basic Fuel should expose both approved canonical atlas views.")
		return
	if not (card.building_image.texture is AtlasTexture):
		_fail("Basic Fuel context card should use canonical v2 atlas art.")
		return
	var fuel_preview := card.building_image.texture as AtlasTexture
	if fuel_preview.atlas == null:
		_fail("Basic Fuel context-card atlas preview should retain its atlas.")
		return
	if String(
		fuel_preview.atlas.resource_path
	) != BuildingCatalog.PRODUCTION_BUILDING_ATLAS:
		_fail("Basic Fuel context card should preview the canonical production atlas.")
		return
	if fuel_preview.region != fuel_regions[0]:
		_fail("Basic Fuel context card should preview its first canonical atlas view.")
		return
	if (
		card.building_image.texture_filter
		!= CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	):
		_fail(
			"Building context art should use smooth mipmapped filtering."
		)
		return

	var fuel_definition := BuildingCatalog.get_definition(
		"basic_fuel"
	)
	var fuel_regions: Array = fuel_definition.get(
		"world_sprite_regions",
		[]
	)
	if fuel_regions.size() < 2:
		_fail(
			"Basic Fuel should expose two production atlas orientations."
		)
		return
	var rotation_b_texture := card._building_texture(
		fuel_definition,
		1
	)
	if not (rotation_b_texture is AtlasTexture):
		_fail(
			"Rotated Basic Fuel context preview should still use production atlas art."
		)
		return
	if (
		(rotation_b_texture as AtlasTexture).region
		!= fuel_regions[1]
	):
		_fail(
			"Building context preview should use the atlas region matching placed rotation."
		)
		return
	if not card.stat_one_label.text.contains("x1.00"):
		_fail("Building card should show service speed stat.")
		return
	if not card.stat_two_label.text.contains("1"):
		_fail("Building card should show vehicle capacity stat.")
		return
	if card.primary_button.text != "UPGRADE":
		_fail("Upgradeable service building should expose Upgrade action.")
		return

	card.primary_action_requested.connect(
		_on_primary_action_requested
	)
	card._on_primary_pressed()
	if not primary_emitted:
		_fail("Building card primary action should emit selected building.")
		return

	if not card.move_button.visible or card.move_button.disabled:
		_fail("Movable building should expose an enabled Move action.")
		return
	card.move_requested.connect(
		_on_move_requested
	)
	card._on_move_pressed()
	if not move_emitted:
		_fail("Building card Move action should emit selected building.")
		return

	var stand := grid.get_building(5)
	if stand.is_empty():
		# Starter stand UIDs can shift as starter content evolves.
		for uid in range(1, 30):
			var candidate := grid.get_building(uid)
			if String(
				candidate.get("definition_id", "")
			) == "small_stand":
				stand = candidate
				break

	if stand.is_empty():
		_fail("Starter airport should contain a Small Stand.")
		return

	card.show_building(
		stand,
		{
			"role": "Infrastructure",
			"status": "Connected to taxiway network",
			"tone": "success",
			"stat_one": "AIRCRAFT\nS",
			"stat_two": "FOOTPRINT\n2x2",
			"primary_label": ""
		}
	)

	if card.primary_button.visible:
		_fail("Non-upgradeable stand should not show management action.")
		return

	card.close_card()
	if card.is_open():
		_fail("Building context card should close cleanly.")
		return

	print(
		"Building context passed: airport tap, icon, live stats, "
		+ "upgrade action and non-upgradeable building state."
	)
	quit(0)


func _on_building_selected(building: Dictionary) -> void:
	selected_building = building.duplicate(true)


func _on_primary_action_requested(
	_building: Dictionary
) -> void:
	primary_emitted = true


func _on_move_requested(
	_building: Dictionary
) -> void:
	move_emitted = true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
