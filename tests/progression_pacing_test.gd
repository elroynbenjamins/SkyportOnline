extends SceneTree

var errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func _run() -> void:
	# Named airport stages make progression legible.
	check(
		String(
			AirportProgressionPacing.stage_for_level(1).get(
				"name",
				""
			)
		) == "Local Airfield",
		"Level 1 should begin in the Local Airfield stage."
	)
	check(
		String(
			AirportProgressionPacing.stage_for_level(8).get(
				"name",
				""
			)
		) == "Busy Regional Airport",
		"Level 8 should enter the Busy Regional Airport stage."
	)
	check(
		String(
			AirportProgressionPacing.stage_for_level(12).get(
				"name",
				""
			)
		) == "Regional Hub",
		"Level 12 should enter the Regional Hub stage."
	)
	check(
		String(
			AirportProgressionPacing.stage_for_level(22).get(
				"name",
				""
			)
		) == "Logistics Airport",
		"Level 22 should enter the Logistics Airport stage."
	)

	# Fleet capacity should grow steadily rather than being fully open at start.
	var expected_capacity := {
		1: 2,
		2: 3,
		4: 4,
		6: 5,
		8: 6,
		10: 7,
		12: 9,
		14: 10,
		15: 11,
		17: 12,
		19: 13,
		21: 14,
		24: 15,
		28: 16,
		30: 16
	}
	for level_variant in expected_capacity:
		var level := int(level_variant)
		check(
			AirportProgressionPacing.fleet_capacity_for_level(
				level
			) == int(expected_capacity[level]),
			"Unexpected fleet capacity at level %d." % level
		)

	var starter := AirportProgressionRules.new_state(
		"progression-cap-test",
		1
	)
	check(
		(starter.get("owned_aircraft", []) as Array).size() == 2,
		"Starter airport should fill its initial two-aircraft license."
	)
	check(
		AirportProgressionRules.purchase_aircraft(
			starter,
			"pico_p8",
			1
		).is_empty(),
		"Level 1 should not buy beyond the two-aircraft starter license."
	)
	var level_two := starter.duplicate(true)
	level_two["coins"] = 100000
	var swift_purchase := AirportProgressionRules.purchase_aircraft(
		level_two,
		"swift_s14",
		2
	)
	check(
		not swift_purchase.is_empty(),
		"Level 2 fleet-capacity increase should make room for the Swift."
	)
	check(
		(swift_purchase.get("owned_aircraft", []) as Array).size() == 3,
		"Swift purchase should fill the level-2 three-aircraft capacity."
	)

	# Route progression is derived from the selected home country.
	DestinationCatalog.configure_home_country("NL")
	var nl_starter := DestinationCatalog.starter_destination_for_home(
		"NL",
		AircraftCatalog.get_profile("pico_p8")
	)
	var jp_starter := DestinationCatalog.starter_destination_for_home(
		"JP",
		AircraftCatalog.get_profile("pico_p8")
	)
	var au_starter := DestinationCatalog.starter_destination_for_home(
		"AU",
		AircraftCatalog.get_profile("pico_p8")
	)
	check(
		String(nl_starter.get("country_code", "")) == "NL",
		"Netherlands airport should receive a domestic level-1 starter route."
	)
	check(
		String(jp_starter.get("country_code", "")) == "JP",
		"Japan airport should receive a domestic level-1 starter route."
	)
	check(
		String(au_starter.get("country_code", "")) == "AU",
		"Australia airport should receive a domestic level-1 starter route."
	)
	check(
		String(nl_starter.get("id", ""))
		!= String(jp_starter.get("id", "")),
		"Different home countries should produce different starter route IDs."
	)
	check(
		int(nl_starter.get("unlock_level", 0)) == 1
		and int(jp_starter.get("unlock_level", 0)) == 1
		and int(au_starter.get("unlock_level", 0)) == 1,
		"Every selectable home country needs a playable level-1 domestic route."
	)
	var japan_routes := DestinationCatalog.all_for_home("JP")
	var netherlands_routes := DestinationCatalog.all_for_home("NL")
	check(
		japan_routes.size() == netherlands_routes.size(),
		"Home country should reshape the same global route network, not remove destination countries."
	)
	check(
		japan_routes.size() >= CountryCatalog.get_countries().size(),
		"Generated network should retain at least one route for every country."
	)
	for code in ["IT", "ES", "TR", "JP", "AU", "BR"]:
		check(
			CountryResourceCatalog.resources_for_country(code).size() == 3,
			"Every route country must retain three-resource identity: %s" % code
		)
	var tokyo_from_nl := DestinationCatalog.get_destination_for_home(
		"NL",
		"tokyo"
	)
	var tokyo_from_kr := DestinationCatalog.get_destination_for_home(
		"KR",
		"tokyo"
	)
	check(
		float(tokyo_from_nl.get("distance_km", 0.0))
		> float(tokyo_from_kr.get("distance_km", 0.0)),
		"Tokyo should be geographically farther from the Netherlands than from South Korea."
	)
	check(
		float(tokyo_from_nl.get("effective_distance_km", 0.0))
		> float(tokyo_from_kr.get("effective_distance_km", 0.0)),
		"Gameplay travel distance should preserve geographic ordering."
	)
	var korea_from_japan := DestinationCatalog.get_destination_for_home(
		"JP",
		"seoul"
	)
	check(
		FlightRules.can_fly(
			AircraftCatalog.get_profile("comet_c22"),
			korea_from_japan
		),
		"Japan's nearby South Korea route should become reachable by early-growth aircraft."
	)


	# There should always be another visible milestone nearby.
	for level in range(1, AirportProgressionPacing.MAX_LEVEL):
		var next := AirportProgressionPacing.next_unlock(level)
		check(
			not next.is_empty(),
			"Every pre-cap level should have a future milestone."
		)
		if next.is_empty():
			continue
		check(
			int(next.get("level", level + 99)) - level <= 2,
			"Progression should never leave more than two levels without a new milestone after level %d." % level
		)

	var level_ten_unlocks := AirportProgressionPacing.unlock_names(10)
	check(
		level_ten_unlocks.has("Arrow A52"),
		"Level 10 should advertise Arrow A52."
	)
	check(
		level_ten_unlocks.has("Fleet capacity 7"),
		"Level 10 should advertise its fleet-license increase."
	)
	var level_twenty_two_unlocks := AirportProgressionPacing.unlock_names(22)
	check(
		level_twenty_two_unlocks.has("Cargo Charter"),
		"Level 22 should advertise Cargo Charter."
	)
	check(
		level_twenty_two_unlocks.has("Logistics District"),
		"Level 22 should advertise the Logistics District."
	)

	# Activities should accelerate progression, not replace normal airport economics.
	var dispatch_gold: Dictionary = DispatchChallengeRules.TIERS[2]
	check(
		int(dispatch_gold.get("coins", 0))
		< int(BuildingCatalog.get_definition("medium_stand").get("cost", 0)),
		"One Gold Dispatch reward must not buy a medium stand outright."
	)
	var challenge_coins := 0
	for row_variant in AirportChallengeRules.MILESTONES:
		var row: Dictionary = row_variant
		challenge_coins += int(row.get("coins", 0))
	check(
		challenge_coins
		< int(BuildingCatalog.get_definition("regional_runway").get("cost", 0)),
		"A full weekly challenge track must stay below a regional runway purchase."
	)
	var alliance_coins := 0
	for row_variant in AllianceOperationsRules.milestones():
		var row: Dictionary = row_variant
		alliance_coins += int(row.get("coins", 0))
	check(
		alliance_coins
		< int(BuildingCatalog.get_definition("atc_tower").get("cost", 0)),
		"A full Alliance weekly project must stay below the ATC Tower cost."
	)

	var charter_state := AirportProgressionRules.new_state(
		"charter-balance-test",
		22
	)
	CharterRules.ensure_state(
		charter_state,
		22,
		100.0 * CharterRules.DAY_SECONDS
	)
	var charter_snapshot := CharterRules.snapshot(
		charter_state,
		22,
		true,
		true,
		100.0 * CharterRules.DAY_SECONDS
	)
	var max_charter_coin := 0
	for offer_variant in charter_snapshot.get("offers", []):
		var offer: Dictionary = offer_variant
		max_charter_coin = maxi(
			max_charter_coin,
			int(offer.get("coin_reward", 0))
		)
	check(
		max_charter_coin
		< int(BuildingCatalog.get_definition("medium_stand").get("cost", 0)),
		"One Cargo Charter must remain a bonus, not a major-infrastructure skip."
	)

	# Career UI should explain current stage, capacity and next milestone.
	var career := AirportCareerScreen.new()
	root.add_child(career)
	await process_frame
	var career_state := AirportProgressionRules.new_state(
		"career-pacing-ui",
		10
	)
	career.open_screen({
		"state": career_state,
		"airport": {
			"buildings": [],
			"parcels": ["home"],
			"medium_ready": false
		},
		"level": 10,
		"active_owned": [],
		"npc_enabled": true,
		"activities": {}
	})
	check(
		career.header.text.contains("BUSY REGIONAL AIRPORT"),
		"Career header should show the current airport stage."
	)
	check(
		_find_text(career, "FLEET LICENSE • 2 / 7 AIRCRAFT"),
		"Career progression card should show the current fleet license."
	)
	check(
		_find_text(career, "NEXT MILESTONE"),
		"Career progression card should show the next unlock target."
	)
	career.close_screen()

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("PROGRESSION_PACING_OK: stages, fleet license, routes, milestone cadence and economy guardrails")
	quit(0)

func _find_text(node: Node, needle: String) -> bool:
	if node is Label and String((node as Label).text).contains(needle):
		return true
	for child in node.get_children():
		if _find_text(child, needle):
			return true
	return false
