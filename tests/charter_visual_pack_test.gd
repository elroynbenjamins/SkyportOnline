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

	var layout_validation := CharterDistrictLayout.layout_validation()
	if not bool(layout_validation.get("valid", false)):
		_fail(
			"Charter district layout is invalid: %s"
			% str(layout_validation.get("errors", []))
		)
		return
	if int(layout_validation.get("future_pads", 0)) != 3:
		_fail(
			"Charter district should preserve three future logistics pads."
		)
		return
	if int(layout_validation.get("future_cells", 0)) != 12:
		_fail(
			"Three future 2x2 logistics pads should preserve 12 cells."
		)
		return

	var fixed_stand_move := CharterDistrictLayout.placement_status(
		"cargo_aircraft_stand",
		Vector2i(1, 0),
		0
	)
	if bool(fixed_stand_move.get("valid", true)):
		_fail(
			"Cargo Charter aircraft stand must remain static."
		)
		return

	var outside_move := CharterDistrictLayout.placement_status(
		"cargo_warehouse",
		Vector2i(7, 7),
		0
	)
	if bool(outside_move.get("valid", true)):
		_fail(
			"Charter buildings must reject movement outside the Logistics District."
		)
		return

	var future_move := CharterDistrictLayout.placement_status(
		"cargo_charter_office",
		Vector2i(0, 6),
		0
	)
	if bool(future_move.get("valid", true)):
		_fail(
			"Existing Charter structures must not consume future Kitchen/Workshop/Packing pads."
		)
		return

	var overlap_move := CharterDistrictLayout.placement_status(
		"cargo_charter_office",
		Vector2i(0, 0),
		0
	)
	if bool(overlap_move.get("valid", true)):
		_fail(
			"Charter move rules must reject overlap with the cargo stand."
		)
		return

	for structure in CharterVisualCatalog.building_visuals():
		var structure_id := String(structure.get("id", ""))
		if structure_id == "cargo_aircraft_stand":
			continue
		if String(structure.get("anchor", "")) != "bottom_center":
			_fail(
				"%s should use a bottom-center transparent-sprite anchor."
				% structure_id
			)
			return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	grid.set_charter_visual_state({
		"unlocked": true,
		"turnaround_active": true,
		"phase": "LOADING",
		"pallet_count": 3
	})
	if bool(
		grid.get_charter_district_visual_snapshot().get(
			"active",
			true
		)
	):
		_fail(
			"Charter district must stay hidden until the Logistics parcel is owned."
		)
		return

	grid.parcels[CharterDistrictLayout.PARCEL_ID]["owned"] = true
	grid.set_charter_visual_state({
		"unlocked": true,
		"turnaround_active": true,
		"phase": "LOADING",
		"pallet_count": 3
	})
	var district_snapshot := grid.get_charter_district_visual_snapshot()
	if not bool(district_snapshot.get("active", false)):
		_fail(
			"Owned Logistics parcel + Charter unlock should activate the visual district."
		)
		return
	if int(district_snapshot.get("future_pads", 0)) != 3:
		_fail(
			"Active Charter district should still expose three future pads."
		)
		return
	if (
		grid.charter_turnaround_visual == null
		or not grid.charter_turnaround_visual.visible
	):
		_fail(
			"Active Charter turnaround should appear on the cargo stand."
		)
		return

	var base_tile := grid._charter_district_base_tile()
	var reserved_status := grid._get_placement_status(
		"ground_ops_depot",
		base_tile + Vector2i(3, 5),
		0
	)
	if bool(reserved_status.get("valid", true)):
		_fail(
			"Active Charter road/yard cells must reject normal building placement."
		)
		return
	if not bool(
		reserved_status.get(
			"charter_reserved",
			false
		)
	):
		_fail(
			"Reserved Charter placement rejection should identify the district reason."
		)
		return

	var future_status := grid._get_placement_status(
		"ground_ops_depot",
		base_tile + Vector2i(0, 6),
		0
	)
	if not bool(future_status.get("valid", false)):
		_fail(
			"Future Logistics pads must remain usable by later Charter buildings."
		)
		return

	grid.set_charter_visual_state({
		"unlocked": false
	})
	if bool(
		grid.get_charter_district_visual_snapshot().get(
			"active",
			true
		)
	):
		_fail(
			"Charter district must disappear again when progression says it is locked."
		)
		return

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
		"Charter visual pack passed: %d images indexed; fixed Logistics gate, "
		% files.size()
		+ "service-road spine, cargo apron, warehouse/office handling yard, "
		+ "three future logistics pads and live turnaround state are progression-gated."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
