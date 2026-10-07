extends SceneTree

var errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func _run() -> void:
	var ids := {}
	var aircraft_quests := {}
	for quest in AirportCareerCatalog.all():
		check(not ids.has(quest["id"]), "Career IDs must be unique.")
		ids[quest["id"]] = true
		check(not quest.has("coins") and not quest.has("gems") and not quest.has("resources"), "Career rewards must be XP/passengers only.")
		check(int(quest["xp"]) > 0, "Every career mission should award positive XP.")
		var objective: Dictionary = quest["objective"]
		if objective.has("aircraft"):
			var profile := AircraftCatalog.get_profile(String(objective["aircraft"]))
			check(not profile.is_empty(), "Career references unknown aircraft.")
			check(int(quest["level"]) >= int(profile.get("unlock_level", 1)), "Quest requires a still-locked aircraft.")
			if objective["kind"] == "own_aircraft":
				aircraft_quests[objective["aircraft"]] = true
			if objective.has("destination"):
				var destination := DestinationCatalog.get_destination(String(objective["destination"]))
				check(FlightRules.can_fly(profile, destination), "Quest flight is out of range: " + String(quest["id"]))
				check(String(destination.get("country_code", "")) == String(objective.get("country", "")), "Quest hint points at the wrong country.")
			if profile.get("size", "S") == "M" and objective["kind"] == "flight":
				check(int(quest["level"]) >= int(BuildingCatalog.get_definition("regional_runway")["level"]), "Medium flight mission precedes the regional runway unlock.")
	check(aircraft_quests.size() == 8, "The career should introduce all eight purchasable upgrades beyond the Pico.")
	check(AirportCareerCatalog.all().size() == 28, "Expected 28 V1 career missions.")

	var state := AirportProgressionRules.new_state("rules-test")
	check(AirportProgressionRules.level_for_xp(99) == 1, "XP level boundary before level two.")
	check(AirportProgressionRules.level_for_xp(100) == 2, "XP level boundary at level two.")
	var event := {"id": "flight-1", "kind": "flight_return", "country": "DE", "aircraft": "pico_p8", "visitor": false}
	AirportProgressionRules.record_event(state, event, 1)
	check(int((state["progress"] as Dictionary).get("first_circuit", 0)) == 0, "Wrong country must not advance first flight mission.")
	event = {"id": "flight-2", "kind": "flight_return", "country": "BE", "aircraft": "swift_s14"}
	AirportProgressionRules.record_event(state, event, 1)
	check(int((state["progress"] as Dictionary).get("first_circuit", 0)) == 0, "Wrong model must not advance first flight mission.")
	event = {"id": "flight-3", "kind": "flight_return", "country": "BE", "aircraft": "pico_p8", "visitor": true}
	AirportProgressionRules.record_event(state, event, 1)
	check(int((state["progress"] as Dictionary).get("first_circuit", 0)) == 0, "Visitors must not count as owned flight returns.")
	event = {"id": "flight-4", "kind": "flight_return", "country": "BE", "aircraft": "pico_p8"}
	check(AirportProgressionRules.record_event(state, event, 1), "Correct return should be accepted.")
	check(not AirportProgressionRules.record_event(state, event, 1), "Replayed return event must be rejected.")
	var claimed := AirportProgressionRules.claim(state, "first_circuit", {}, 1)
	check(not claimed.is_empty(), "Completed mission should be claimable.")
	check(int(claimed.get("xp", 0)) == 80, "Claim should add exact XP reward.")
	check(int(claimed.get("pending_passengers", 0)) == 8, "Passenger reward must enter a retained reserve.")
	check(claimed.get("coins") == state.get("coins"), "Career claim must not grant coins.")
	check(AirportProgressionRules.claim(claimed, "first_circuit", {}, 2).is_empty(), "Double claim must not grant rewards again.")
	check(AirportProgressionRules.claim(state, "swift_purchase", {}, 2).is_empty(), "Cannot claim a future mission out of order.")
	check(AirportProgressionRules.purchase_aircraft(state, "swift_s14", 1).is_empty(), "Aircraft purchase respects level lock.")
	var purchase := AirportProgressionRules.purchase_aircraft(state, "swift_s14", 2)
	check(int(purchase.get("coins", 0)) == int(state["coins"]) - 3500, "Aircraft price should be deducted once.")
	check((purchase.get("owned_aircraft", []) as Array).size() == 3, "Purchased aircraft should be retained as owned.")
	var poor := state.duplicate(true)
	poor["coins"] = 1
	check(AirportProgressionRules.purchase_aircraft(poor, "pico_p8", 1).is_empty(), "Unaffordable purchase must be rejected.")

	var tour := AirportProgressionRules.new_state("tour")
	for quest in AirportCareerCatalog.all():
		if quest["id"] != "horizon_tour":
			tour["claimed"][quest["id"]] = true
	for index in range(4):
		AirportProgressionRules.record_event(tour, {"id": "tour-repeat-%d" % index, "kind": "flight_return", "aircraft": "horizon_h88", "country": "BE"}, 17)
	check(int(tour["progress"].get("horizon_tour", 0)) == 1, "Country tour must count unique countries, not flights.")
	for country in ["GB", "DE", "FR", "DK"]:
		AirportProgressionRules.record_event(tour, {"id": "tour-" + country, "kind": "flight_return", "aircraft": "horizon_h88", "country": country}, 17)
	check(bool(AirportProgressionRules.quest_status(tour, {}, 17).get("ready", false)), "Five unique country returns should complete the tour.")

	var ledger := {}
	for index in range(20):
		ledger = FriendshipRules.record_completion(ledger, {"contact_id": "friend-1", "visit_id": "visit-%d" % index, "relationship": "friend"}, "2026-10-05")
	check(int(ledger["friend-1"].get("points", 0)) == 5, "Only five friendship points per contact/day.")
	var npc_ledger := FriendshipRules.record_completion(ledger, {"contact_id": "npc-1", "visit_id": "npc-event", "relationship": "npc"}, "2026-10-05")
	check(not npc_ledger.has("npc-1"), "NPCs cannot earn friendship.")
	ledger = FriendshipRules.record_completion(ledger, {"contact_id": "friend-1", "visit_id": "clock-back", "relationship": "friend"}, "2026-10-04")
	check(int(ledger["friend-1"].get("points", 0)) == 5, "Clock rollback cannot refresh friendship allowance.")
	for index in range(5):
		ledger = FriendshipRules.record_completion(ledger, {"contact_id": "friend-1", "visit_id": "day-two-%d" % index, "relationship": "friend"}, "2026-10-06")
	check(int(FriendshipRules.status(ledger["friend-1"])["rank"]) == 2, "Ten visits should earn friendship rank two.")

	# Cached definitions remain isolated from caller mutations.
	var definition_copy := BuildingCatalog.get_definition("small_stand")
	definition_copy["cost"] = -1
	check(int(BuildingCatalog.get_definition("small_stand")["cost"]) == 3000, "Catalog cache must return independent definitions.")
	var styled_button := Button.new()
	GameUIStyle.apply_button(styled_button, "primary", true)
	var first_style := styled_button.get_theme_stylebox("normal")
	GameUIStyle.apply_button(styled_button, "primary", true)
	check(first_style == styled_button.get_theme_stylebox("normal"), "Unchanged button style must not allocate a fresh theme.")
	GameUIStyle.apply_button(styled_button, "gold", true)
	check(first_style != styled_button.get_theme_stylebox("normal"), "Changed button style must still apply.")
	styled_button.free()
	var traffic := TaxiTrafficController.new()
	root.add_child(traffic)
	var departing_visitor := AircraftPrototype.new()
	root.add_child(departing_visitor)
	departing_visitor.configure_taxi_traffic(traffic)
	var departed_id := departing_visitor.get_instance_id()
	departing_visitor.free()
	check(not traffic.registered.has(departed_id), "Removed visitors must unregister from taxi traffic.")
	var stale_plane := AircraftPrototype.new()
	traffic.register_aircraft(stale_plane)
	stale_plane.free()
	traffic._cleanup_invalid()
	check(traffic.registered.is_empty(), "Stale references must be checked before casting during taxi cleanup.")
	traffic.queue_free()

	var director := NpcTrafficDirector.new()
	director.rng.seed = 2026
	check(director.eligible(1, ["S"]).size() == 1, "Level one NPC pool should contain only the Pico pilot.")
	check(director.eligible(17, ["S"]).size() == 4, "Small-only airport must not admit medium NPCs.")
	check(director.eligible(17, ["S", "M"]).size() == 9, "All nine V1 NPC models should be available at level seventeen.")
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	check(NpcTrafficDirector.free_ready_stands(grid, "M", {}).is_empty(), "Starter infrastructure cannot support medium visitors.")
	director.remaining = 0.0
	var contact := director.advance(0.1, 1, grid, {}, false, false, 0)
	check(not contact.is_empty() and contact.get("relationship", "") == "npc", "Idle starter airport should admit one eligible NPC.")
	check(director.remaining >= 180.0 and director.remaining <= 360.0, "NPC opportunity should reset to 3–6 minute interval.")
	check(director.advance(86400.0, 17, grid, {}, false, false, 0).is_empty(), "Large offline-like delta must not create arrival catch-up.")
	director.remaining = 0.0
	check(director.advance(0.1, 17, grid, {}, true, false, 0).is_empty(), "Own pending returns take precedence over new NPCs.")
	director.remaining = 0.0
	check(director.advance(0.1, 17, grid, {}, false, true, 0).is_empty(), "At most one ambient NPC can be active.")
	for npc in NpcTrafficDirector.catalog():
		check(not CountryCatalog.get_country(String(npc["country_id"])).is_empty(), "NPC must use a valid country.")
		var plane := CareerAircraft.new()
		plane.configure_aircraft_type(String(npc["aircraft_type_id"]))
		check(plane.direction_textures.size() == 4, "Each NPC model needs all four committed sprite directions.")
		plane.free()
	grid.queue_free()
	await process_frame
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("PROGRESSION_TEST_OK: career rules, all model/range gates, claim replay, NPC cadence and friendship caps")
	quit(0)
