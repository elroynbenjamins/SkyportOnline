extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seen_resource_ids: Dictionary = {}
	var destination_countries: Dictionary = {}

	for route in RouteCatalog.all():
		var code := String(route.get("country_code", ""))
		if code.is_empty():
			_fail("Every V1 route should identify a destination country.")
			return
		destination_countries[code] = true

		if absf(float(route.get("resource_drop_chance", 0.0)) - 0.40) > 0.001:
			_fail("Every V1 route should keep the accepted 40% resource roll.")
			return

	for code_variant in destination_countries.keys():
		var code := String(code_variant)
		var country := CountryCatalog.get_country(code)
		if country.is_empty():
			_fail("Missing country catalog entry for route country %s." % code)
			return

		var resources := CountryCatalog.get_resources(code)
		if resources.size() != 3:
			_fail("%s should expose exactly three unique country resources." % code)
			return

		for resource in resources:
			var resource_id := String(resource.get("id", ""))
			if resource_id.is_empty():
				_fail("%s contains a resource without an ID." % code)
				return
			if seen_resource_ids.has(resource_id):
				_fail("Country resource IDs must be globally unique: %s." % resource_id)
				return
			seen_resource_ids[resource_id] = code

	var germany := CountryCatalog.get_resources("DE")
	if germany.size() != 3:
		_fail("Germany should expose three resource definitions.")
		return

	var mixed_drops := CountryCatalog.roll_resource_drops(
		"DE",
		0.40,
		[0.10, 0.60, 0.39]
	)
	if mixed_drops.size() != 2:
		_fail("Independent rolls should allow exactly two of three resources.")
		return
	if String(mixed_drops[0].get("id", "")) != String(germany[0].get("id", "")):
		_fail("First successful roll should award Germany resource 1.")
		return
	if String(mixed_drops[1].get("id", "")) != String(germany[2].get("id", "")):
		_fail("Third successful roll should award Germany resource 3.")
		return

	var all_drops := CountryCatalog.roll_resource_drops(
		"DE",
		0.40,
		[0.01, 0.20, 0.399]
	)
	if all_drops.size() != 3:
		_fail("Luck should allow all three country resources in one flight.")
		return

	var no_drops := CountryCatalog.roll_resource_drops(
		"DE",
		0.40,
		[0.40, 0.80, 0.99]
	)
	if not no_drops.is_empty():
		_fail("A 40% roll uses values below 0.40; bad luck should allow no drops.")
		return

	print("Country resource definitions and independent 40% drop rolls passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
