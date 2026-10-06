extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var atlas := load(CountryResourceVisuals.ATLAS_PATH)
	if not atlas is Texture2D:
		_fail("Country resource atlas must import as Texture2D.")
		return

	var count := 0
	for country_code_variant in CountryResourceCatalog.all().keys():
		var country_code := String(country_code_variant)
		var resources := CountryResourceCatalog.resources_for_country(country_code)
		if resources.size() != 3:
			_fail("%s should expose exactly three country resources." % country_code)
			return
		for resource in resources:
			var resource_id := String(resource.get("id", ""))
			if not CountryResourceVisuals.has_visual(resource_id):
				_fail("Missing country-resource visual for %s." % resource_id)
				return
			var region := CountryResourceVisuals.atlas_region(resource_id)
			if region.size != Vector2(96, 96):
				_fail("Unexpected atlas region for %s." % resource_id)
				return
			if CountryResourceVisuals.texture_for(resource_id) == null:
				_fail("Could not build AtlasTexture for %s." % resource_id)
				return
			count += 1

	if count != 69:
		_fail("Expected 69 country-resource visuals, got %d." % count)
		return

	print("COUNTRY_RESOURCE_VISUALS_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
