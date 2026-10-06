extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var atlas := ApronDetailArt.texture()
	if atlas == null:
		_fail("Apron-detail v2 atlas should load.")
		return
	if (
		atlas.get_width() != ApronDetailArt.ATLAS_SIZE.x
		or atlas.get_height() != ApronDetailArt.ATLAS_SIZE.y
	):
		_fail("Apron-detail v2 atlas should import at exactly 1024x1280.")
		return
	if ApronDetailArt.CELLS.size() != 20:
		_fail("Apron-detail v2 should expose exactly twenty authored cells.")
		return

	for key_variant in ApronDetailArt.CELLS.keys():
		var key := String(key_variant)
		var source := ApronDetailArt.source_rect(key)
		if source.size != Vector2(256, 256):
			_fail("%s should occupy one 256x256 atlas cell." % key)
			return
		if (
			source.position.x < 0.0
			or source.position.y < 0.0
			or source.end.x > 1024.0
			or source.end.y > 1280.0
		):
			_fail("%s should remain inside the apron-detail atlas." % key)
			return

	for kind in [
		"crew",
		"marshaller",
		"stairs",
		"belt",
		"gpu",
		"cargo_loader",
		"baggage",
		"utility",
		"cargo_pallet",
		"uld",
		"cones",
		"chocks"
	]:
		var size := ApronDetailArt.world_size(String(kind))
		if size.x <= 0.0 or size.y <= 0.0:
			_fail("%s should expose a valid tuned world size." % kind)
			return

	if ApronDetailArt.crew_key(false, 0) != "crew_a":
		_fail("Crew frame zero should map to crew_a.")
		return
	if ApronDetailArt.crew_key(false, 1) != "crew_b":
		_fail("Crew frame one should map to crew_b.")
		return
	if ApronDetailArt.crew_key(true, 0) != "marshaller_a":
		_fail("Marshaller frame zero should map to marshaller_a.")
		return
	if ApronDetailArt.directional_key("stairs", 0.0) != "stairs_right":
		_fail("Positive apron heading should use the right-facing stairs.")
		return
	if ApronDetailArt.directional_key("stairs", PI) != "stairs_left":
		_fail("Negative apron heading should use the left-facing stairs.")
		return

	var service_atlas := GroundServiceVehicleArt.texture()
	if service_atlas == null:
		_fail("Existing high-detail service-vehicle atlas should remain available.")
		return
	if (
		service_atlas.get_width() != 1024
		or service_atlas.get_height() != 1536
	):
		_fail("Service-vehicle atlas should retain its full directional production coverage.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var ambient := AirportAmbientLife.new()
	root.add_child(ambient)
	ambient.configure(grid)
	await process_frame

	if not ambient.has_method("_draw_apron_detail_sprite"):
		_fail("Ambient airport should render dedicated apron-detail sprites.")
		return
	if not ambient.has_method("_draw_apron_staging_props"):
		_fail("Ambient airport should stage v2 equipment around active aircraft.")
		return
	if not ambient.has_method("_apron_prop_count_for_aircraft"):
		_fail("Ambient airport should expose bounded apron-prop counts.")
		return

	var snapshot := ambient.get_ambient_snapshot()
	if not bool(snapshot.get("apron_detail_ready", false)):
		_fail("Ambient snapshot should report the apron-detail v2 atlas ready.")
		return
	if int(snapshot.get("apron_prop_cap", 99)) > 22:
		_fail("Apron prop count must remain bounded for mobile rendering.")
		return
	var profile: Dictionary = snapshot.get(
		"apron_detail_profile",
		{}
	)
	if String(profile.get("atlas_path", "")) != ApronDetailArt.ATLAS_PATH:
		_fail("Ambient snapshot should expose the apron-detail v2 atlas path.")
		return
	if int(profile.get("cell_count", 0)) != 20:
		_fail("Ambient snapshot should expose all twenty apron-detail cells.")
		return

	var aircraft := CareerAircraft.new()
	aircraft.configure_aircraft_type("pico_p8")
	aircraft.assign_flight_plan({
		"city": "Apron Art Test",
		"duration_seconds": 60.0
	})
	aircraft.record_boarded_passengers(12)
	aircraft.state = "LOADING"
	aircraft.position = Vector2(90, 320)
	root.add_child(aircraft)
	await process_frame

	var loading_snapshot := ambient.get_ambient_snapshot()
	if int(loading_snapshot.get("apron_prop_count", 0)) < 5:
		_fail("Loading aircraft should stage stairs, cargo handling and safety props.")
		return
	if int(loading_snapshot.get("baggage_trains", 0)) < 1:
		_fail("Loading aircraft should retain visible v2 baggage movement.")
		return

	aircraft.state = "SERVICING"
	var servicing_snapshot := ambient.get_ambient_snapshot()
	if int(servicing_snapshot.get("apron_prop_count", 0)) < 3:
		_fail("Servicing aircraft should stage safety equipment and a GPU.")
		return

	aircraft.state = "PUSHBACK_PREP"
	var pushback_snapshot := ambient.get_ambient_snapshot()
	if int(pushback_snapshot.get("apron_prop_count", 0)) != 2:
		_fail("Pushback preparation should keep only the compact safety kit.")
		return

	print(
		"APRON_DETAIL_V2_OK cells=20 vehicles=retained crew=v2 baggage=v2 "
		+ "stairs=true belt=true gpu=true loader=true props_bounded=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
