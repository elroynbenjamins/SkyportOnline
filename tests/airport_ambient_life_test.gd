# Living-airport presentation regression: ambient visuals must stay bounded and
# NPC-only movement personality must not affect player-owned aircraft.
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var ambient := AirportAmbientLife.new()
	root.add_child(ambient)
	ambient.configure(grid)
	await process_frame

	var snapshot := ambient.get_ambient_snapshot()
	if int(snapshot.get("stands", 0)) < 2:
		_fail("Starter airport should expose both stand anchors to ambient life.")
		return
	if int(snapshot.get("terminals", 0)) < 1:
		_fail("Starter terminal should expose a terminal activity anchor.")
		return
	if int(snapshot.get("windsocks", 0)) < 1:
		_fail("At least one runway windsock anchor should be created.")
		return
	if int(snapshot.get("service_route_points", 0)) < 6:
		_fail("Starter service roads should form a useful ambient cart route.")
		return
	if int(snapshot.get("ambient_cart_cap", 0)) > 2:
		_fail("Ambient service traffic must stay tightly capped for mobile.")
		return
	if float(snapshot.get("draw_hz", 99.0)) > 15.0:
		_fail("Ambient drawing should remain throttled below 15 Hz.")
		return
	if not bool(snapshot.get("art_atlas_ready", false)):
		_fail("Ambient life should load the production ambient art atlas.")
		return
	if int(snapshot.get("baggage_train_cap", 99)) > 3:
		_fail("Baggage ambience should stay tightly capped for mobile.")
		return

	var art_profile: Dictionary = snapshot.get(
		"art_profile",
		{}
	)
	if String(art_profile.get("atlas_path", "")).is_empty():
		_fail("Ambient art profile should expose its production atlas path.")
		return
	if AirportAmbientLifeArt.texture() == null:
		_fail("Production ambient-life atlas should resolve as a texture.")
		return
	for key in [
		"crew_a",
		"crew_b",
		"marshaller_a",
		"marshaller_b",
		"civilian_a",
		"civilian_b",
		"utility_right",
		"utility_left",
		"baggage_right",
		"baggage_left",
		"windsock_a",
		"windsock_b",
		"flag_a",
		"flag_b"
	]:
		var source := AirportAmbientLifeArt.source_rect(
			String(key)
		)
		if source.size != Vector2(256, 256):
			_fail("%s should occupy one 256x256 ambient atlas cell." % key)
			return

	var s_activity := AirportAmbientLife.behavior_profile_for_size("S")
	var m_activity := AirportAmbientLife.behavior_profile_for_size("M")
	var xl_activity := AirportAmbientLife.behavior_profile_for_size("XL")
	if int(m_activity.get("crew_count", 0)) <= int(s_activity.get("crew_count", 0)):
		_fail("Medium aircraft should create more apron activity than small aircraft.")
		return
	if int(xl_activity.get("crew_count", 0)) <= int(m_activity.get("crew_count", 0)):
		_fail("Future XL aircraft should scale ambient crew activity above M.")
		return

	var medium_id := ""
	for contact in NpcTrafficDirector.catalog():
		if String(contact.get("size", "")) == "M":
			medium_id = String(contact.get("aircraft_type_id", ""))
			break
	if medium_id.is_empty():
		_fail("NPC catalog should retain at least one medium visitor.")
		return

	var hopper_profile := NpcTrafficDirector.behavior_profile_for_aircraft(
		"pico_p8"
	)
	var regional_profile := NpcTrafficDirector.behavior_profile_for_aircraft(
		medium_id
	)
	if String(hopper_profile.get("tier", "")) != "hopper":
		_fail("Starter Pico NPC should use the nimble hopper profile.")
		return
	if String(regional_profile.get("tier", "")) != "regional":
		_fail("Medium NPC should use the deliberate regional profile.")
		return
	if (
		float(hopper_profile.get("taxi_speed_scale", 1.0))
		<= float(regional_profile.get("taxi_speed_scale", 1.0))
	):
		_fail("Small hopper NPCs should taxi more briskly than medium visitors.")
		return
	if (
		float(hopper_profile.get("turn_rate_deg", 0.0))
		<= float(regional_profile.get("turn_rate_deg", 0.0))
	):
		_fail("Small hopper NPCs should turn more nimbly than medium visitors.")
		return

	var npc := CareerAircraft.new()
	npc.configure_aircraft_type("pico_p8")
	var base_taxi_speed := npc.taxi_speed
	var applied := NpcTrafficDirector.apply_behavior(npc)
	if applied.is_empty() or not npc.has_meta("npc_behavior"):
		_fail("NPC behavior application should publish its ambient profile.")
		return
	if npc.taxi_speed <= base_taxi_speed:
		_fail("Hopper NPC should receive the intended subtle taxi-speed lift.")
		return
	npc.state = "SERVICING"
	npc.position = Vector2(90, 320)
	root.add_child(npc)
	await process_frame

	var live_snapshot := ambient.get_ambient_snapshot()
	if int(live_snapshot.get("live_aircraft", 0)) < 1:
		_fail("Ambient controller should discover live sibling aircraft.")
		return
	if int(live_snapshot.get("crew_count", 0)) < 1:
		_fail("Servicing aircraft should create visible ground-crew activity.")
		return
	if int(live_snapshot.get("baggage_trains", 0)) != 0:
		_fail("Generic servicing should not create baggage trains outside load/unload.")
		return

	npc.state = "LOADING"
	var loading_snapshot := ambient.get_ambient_snapshot()
	if int(loading_snapshot.get("baggage_trains", 0)) < 1:
		_fail("Loading aircraft should create production-art baggage movement.")
		return
	if not ambient.has_method("_draw_baggage_activity"):
		_fail("Ambient controller should retain dedicated baggage activity rendering.")
		return
	if not ambient.has_method("_draw_atlas_sprite"):
		_fail("Ambient subjects should render through the shared production atlas.")
		return

	if int(live_snapshot.get("npc_aircraft", 0)) != 1:
		_fail("NPC aircraft should be identified from their behavior metadata.")
		return
	var npc_tiers: Dictionary = live_snapshot.get("npc_tiers", {})
	if int(npc_tiers.get("hopper", 0)) != 1:
		_fail("Live ambient snapshot should preserve the NPC traffic tier.")
		return

	print(
		(
			"AIRPORT_AMBIENT_LIFE_OK "
			+ "stands=%d route=%d windsocks=%d draw_hz=%.0f "
			+ "crew=%d baggage=%d atlas=true npc_tier=%s"
		) % [
			int(snapshot.get("stands", 0)),
			int(snapshot.get("service_route_points", 0)),
			int(snapshot.get("windsocks", 0)),
			float(snapshot.get("draw_hz", 0.0)),
			int(live_snapshot.get("crew_count", 0)),
			int(loading_snapshot.get("baggage_trains", 0)),
			String(applied.get("tier", ""))
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
