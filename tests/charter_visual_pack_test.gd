extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not CharterVisualPack.pack_available():
		_fail(
			"Cargo Charter visual ZIP should be readable from res://."
		)
		return

	var files := CharterVisualPack.list_files()
	if files.size() < 8:
		_fail(
			"Cargo Charter visual pack should contain the authored logistics set."
		)
		return

	for asset_key_variant in CharterVisualCatalog.required_asset_keys():
		var asset_key := String(asset_key_variant)
		var resolved := CharterVisualPack.resolve_asset_file(
			asset_key,
			0
		)
		if resolved.is_empty():
			_fail(
				"Missing Charter visual '%s'. Pack files: %s"
				% [asset_key, str(files)]
			)
			return

		var texture := CharterVisualPack.texture(
			asset_key,
			0
		)
		if texture == null:
			_fail(
				"Charter visual '%s' resolves but does not decode as an image."
				% asset_key
			)
			return
		if texture.get_width() <= 1 or texture.get_height() <= 1:
			_fail(
				"Charter visual '%s' should have a valid authored image size."
				% asset_key
			)
			return

	for visual in CharterVisualCatalog.building_visuals():
		if String(
			visual.get("placement_zone", "")
		) != "LOGISTICS":
			_fail(
				"Charter buildings must remain restricted to the LOGISTICS zone."
			)
			return

		var paths := CharterVisualCatalog.world_sprite_paths(
			String(visual.get("asset_key", ""))
		)
		if paths.size() != 2:
			_fail(
				"Charter buildings should expose two rotation-facing visual URIs."
			)
			return
		for path in paths:
			if not CharterVisualPack.is_uri(String(path)):
				_fail(
					"Charter world art should use the pack-backed charter:// URI."
				)
				return

	var cargo_plane := CharterVisualPack.resolve_asset_file(
		"cargo_plane",
		0
	)
	if cargo_plane.is_empty():
		cargo_plane = CharterVisualPack.resolve_asset_file(
			"twin_prop",
			0
		)
	if cargo_plane.is_empty():
		_fail(
			"Cargo Charter pack should include the active charter aircraft visual."
		)
		return

	var pallet_asset := CharterVisualPack.resolve_asset_file(
		"pallet",
		0
	)
	if pallet_asset.is_empty():
		pallet_asset = CharterVisualPack.resolve_asset_file(
			"crate",
			0
		)
	if pallet_asset.is_empty():
		_fail(
			"Cargo Charter pack should include pallet/crate cargo visuals."
		)
		return

	var live_visual := CharterTurnaroundVisual.new()
	root.add_child(live_visual)
	live_visual.set_charter_visual_state({
		"active": true,
		"phase": "LOADING",
		"pallet_count": 3,
		"visual_variant": 1
	})
	var live_snapshot := live_visual.get_visual_snapshot()
	if int(live_snapshot.get("pallet_count", 0)) != 3:
		_fail(
			"Charter turnaround visuals should expose the 1-4 pallet fill state."
		)
		return
	live_visual.clear_charter_visuals()
	if bool(
		live_visual.get_visual_snapshot().get(
			"active",
			true
		)
	):
		_fail(
			"Charter aircraft and pallet state should clear after departure."
		)
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	var office_visual := CharterVisualCatalog.visual_for(
		"cargo_charter_office"
	)
	var office_paths: PackedStringArray = office_visual.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	var renderer_texture := grid._get_building_texture(
		office_paths[0]
	)
	if renderer_texture == null:
		_fail(
			"AirportGrid should resolve pack-backed Charter sprites."
		)
		return

	print(
		"Charter visual pack passed: %d images indexed; logistics buildings, "
		% files.size()
		+ "support surfaces and airport renderer bridge are ready while the "
		+ "district remains progression-gated."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
