extends SceneTree

# Native visual QA: when a 3D/grid-native asset has not yet been drawn,
# buildings should still have differentiated illustrated catalog thumbnails.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ids := [
		"basic_fuel", "short_runway", "small_hangar",
		"small_terminal", "cargo_parking_s"
	]
	var seen: Dictionary = {}
	for id in ids:
		var definition := BuildingCatalog.get_definition(id)
		if definition.is_empty():
			_fail("QA definition was removed: " + id)
			return
		var thumbnail := AirportBuildThumbnails.for_definition(definition)
		if thumbnail == null:
			_fail("All build entries should have a thumbnail: " + id)
			return
		seen[id] = thumbnail

	# Missing assets must never be an empty/identical square for every item.
	var fuel_fallback: Texture2D = AirportBuildThumbnails.for_definition({
		"id": "basic_fuel",
		"category": "Services",
		"world_sprite_path": "res://assets/not-existing/unknown-fuel.svg"
	})
	var cargo_fallback: Texture2D = AirportBuildThumbnails.for_definition({
		"id": "cargo_storage",
		"category": "Services"
	})
	if fuel_fallback == null or cargo_fallback == null:
		_fail("Missing building artwork must resolve to an illustrated fallback.")
		return
	if fuel_fallback == cargo_fallback:
		_fail("Fuel and cargo placeholders should not use an identical icon.")
		return
	if fuel_fallback.get_width() < 64 or fuel_fallback.get_height() < 64:
		_fail("Procedural icons should remain sharp at 42–108px preview sizes.")
		return

	# Different facilities deserve different fallback illustrations even
	# when they share a category or have no production artwork yet.
	var fallback_ids := [
		"short_runway", "regional_runway", "fuel_parking_s",
		"cargo_parking_s", "small_hangar", "medium_hangar",
		"basic_fuel", "rapid_small_fuel", "ground_ops_depot",
		"cleaning_center", "shuttle_station", "atc_tower",
		"autumn_event_flag", "winter_event_flag"
	]
	var references: Dictionary = {}
	for id in fallback_ids:
		var definition := BuildingCatalog.get_definition(id)
		if definition.is_empty():
			_fail("Building inventory no longer defines " + id)
			return
		var art := AirportBuildThumbnails._illustration(definition)
		if art == null:
			_fail("Failed to draw distinctive fallback for " + id)
			return
		if references.has(art):
			_fail("Two separate buildings share the same fallback instance.")
			return
		references[art] = true
		if art != AirportBuildThumbnails._illustration(definition):
			_fail("Fallback art should be cached per building identity.")
			return
	if AirportBuildThumbnails._kind("fuel_parking_s", "Infrastructure") != "parking":
		_fail("Fuel parking is a pad, not a fuel station icon.")
		return
	if AirportBuildThumbnails._kind("cargo_parking_s", "Infrastructure") != "parking":
		_fail("Cargo parking is a pad, not a cargo warehouse.")
		return
	if AirportBuildThumbnails._detail_for_id("small_hangar") == AirportBuildThumbnails._detail_for_id("medium_hangar"):
		_fail("Small and medium hangars should have different silhouette badges.")
		return

	var hud = preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	var definitions: Array[Dictionary] = []
	for id in ids:
		definitions.append(BuildingCatalog.get_definition(id))
	hud.set_build_catalog(definitions)
	for id in ids:
		var button := hud.catalog_buttons.get(id) as Button
		if button == null or button.icon == null:
			_fail("Build cards need visible art: " + id)
			return
		if button.icon != seen[id]:
			_fail("Build cards should share the resolved thumbnail: " + id)
			return

	print("AIRPORT_THUMBNAILS_OK asset_first=true fallbacks=true catalog_consistent=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
