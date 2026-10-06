extends SceneTree

var errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func _run() -> void:
	var catalog_check := CountryCatalog.validate_catalog()
	check(
		bool(catalog_check.get("valid", false)),
		"Selectable-country catalog should include valid route geography."
	)

	for home_id in ["NL", "JP", "AU", "BR", "US"]:
		var starter := DestinationCatalog.starter_destination_for_home(
			home_id,
			AircraftCatalog.get_profile("pico_p8")
		)
		check(
			not starter.is_empty(),
			"Every selectable home country needs a Pico-compatible starter route: %s" % home_id
		)
		check(
			String(starter.get("country_code", "")) == home_id,
			"Starter route should be domestic for home country %s." % home_id
		)
		check(
			int(starter.get("unlock_level", 0)) == 1,
			"Domestic starter route should unlock at level 1."
		)
		check(
			FlightRules.can_fly(
				AircraftCatalog.get_profile("pico_p8"),
				starter
			),
			"Pico P8 must be able to fly the domestic starter route."
		)

	var netherlands_routes := DestinationCatalog.all_for_home("NL")
	var japan_routes := DestinationCatalog.all_for_home("JP")
	check(
		netherlands_routes.size() == japan_routes.size(),
		"Changing home country should reshape routes, not delete destinations."
	)
	check(
		netherlands_routes.size() >= CountryCatalog.get_countries().size(),
		"Generated network should retain at least one hub for every launch country."
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
		"True route distance should depend on the selected home country."
	)
	check(
		float(tokyo_from_nl.get("effective_distance_km", 0.0))
		> float(tokyo_from_kr.get("effective_distance_km", 0.0)),
		"Gameplay distance should preserve the same geographic ordering."
	)

	var london_from_nl := DestinationCatalog.get_destination_for_home(
		"NL",
		"london"
	)
	var london_from_au := DestinationCatalog.get_destination_for_home(
		"AU",
		"london"
	)
	check(
		int(london_from_nl.get("unlock_level", 99))
		< int(london_from_au.get("unlock_level", 0)),
		"Nearby London should unlock earlier from the Netherlands than from Australia."
	)

	var domestic_nl := DestinationCatalog.starter_destination_for_home(
		"NL",
		AircraftCatalog.get_profile("pico_p8")
	)
	var short_plan := FlightRules.create_flight_plan(
		AircraftCatalog.get_profile("pico_p8"),
		domestic_nl
	)
	var long_plan := FlightRules.create_flight_plan(
		AircraftCatalog.get_profile("horizon_h88"),
		tokyo_from_nl
	)
	check(
		not short_plan.is_empty(),
		"Domestic starter plan should be valid."
	)
	check(
		not long_plan.is_empty(),
		"Horizon should reach the compressed Netherlands-Tokyo gameplay route."
	)
	check(
		FlightRules.fuel_service_multiplier(short_plan) == 1.0,
		"Short domestic routes should use base fueling time."
	)
	check(
		FlightRules.fuel_service_multiplier(long_plan) > 1.0,
		"Long routes should increase fueling time mildly."
	)
	check(
		FlightRules.fuel_service_multiplier(long_plan) <= 1.25,
		"Distance-based fueling should stay capped at a mild 25% increase."
	)
	check(
		float(long_plan.get("duration_seconds", 0.0))
		> float(short_plan.get("duration_seconds", 0.0)),
		"Longer routes should take longer to fly."
	)

	var short_chance := ResourceDropRules.chance_for_flight(
		AircraftCatalog.get_profile("pico_p8"),
		short_plan
	)
	var long_chance := ResourceDropRules.chance_for_flight(
		AircraftCatalog.get_profile("horizon_h88"),
		long_plan
	)
	check(
		long_chance > short_chance,
		"Longer routes should retain a better country-resource chance."
	)

	var resource_codes := CountryResourceCatalog.country_codes()
	check(
		resource_codes.size() == CountryCatalog.get_countries().size(),
		"Global resource catalog should cover every selectable country."
	)
	for home_id in ["NL", "JP", "AU"]:
		for code in resource_codes:
			check(
				CountryResourceCatalog.resources_for_country(code).size() == 3,
				"Home %s must not remove %s resources from the global catalog." % [
					home_id,
					code
				]
			)

	var japan_state := AirportProgressionRules.new_state(
		"jp-career-route",
		1
	)
	japan_state["home_country_id"] = "JP"
	var japan_first := AirportProgressionRules.active_quest(japan_state)
	var japan_objective: Dictionary = japan_first.get("objective", {})
	check(
		String(japan_objective.get("country", "")) == "JP",
		"Japan Career should begin with its Japan domestic route, not Belgium."
	)
	check(
		String(japan_first.get("guidance", "")).contains("Japan"),
		"Resolved Career guidance should name the selected home market."
	)

	var australia_state := AirportProgressionRules.new_state(
		"au-career-route",
		1
	)
	australia_state["home_country_id"] = "AU"
	var australia_first := AirportProgressionRules.active_quest(
		australia_state
	)
	check(
		String(
			(australia_first.get("objective", {}) as Dictionary).get(
				"country",
				""
			)
		) == "AU",
		"Australia Career should begin with an Australian domestic route."
	)

	DestinationCatalog.configure_home_country("JP")
	check(
		DestinationCatalog.get_home_country_id() == "JP",
		"Configured route catalog should remember the current home country."
	)
	check(
		DestinationCatalog.home_hub_name() == "Tokyo",
		"Japan home route hub should display Tokyo."
	)
	DestinationCatalog.configure_home_country("NL")

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return

	print("HOME_COUNTRY_ROUTES_OK: home geography, global resources, distance timers, fueling and Career routes")
	quit(0)
