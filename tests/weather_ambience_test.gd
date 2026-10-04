extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for condition in [
		WeatherVisualRules.CLEAR,
		WeatherVisualRules.CLOUDY,
		WeatherVisualRules.RAIN,
		WeatherVisualRules.FOG,
		WeatherVisualRules.SNOW
	]:
		if WeatherVisualRules.normalized_condition(condition) != condition:
			_fail("Known weather condition should normalize unchanged: %s" % condition)
			return

	if WeatherVisualRules.normalized_condition("invalid") != WeatherVisualRules.CLEAR:
		_fail("Unknown weather should safely normalize to CLEAR.")
		return

	var known_daily := WeatherVisualRules.daily_condition(10, 4)
	if known_daily != WeatherVisualRules.FOG:
		_fail("October 4 ambient weather seed should remain stable for regression.")
		return

	for month in range(3, 12):
		for day in [1, 8, 15, 22, 29]:
			if WeatherVisualRules.daily_condition(month, day) == WeatherVisualRules.SNOW:
				_fail("Ambient snow should be restricted to winter months.")
				return

	var clear_profile := WeatherVisualRules.profile_for_condition(
		WeatherVisualRules.CLEAR
	)
	var rain_profile := WeatherVisualRules.profile_for_condition(
		WeatherVisualRules.RAIN
	)
	var fog_profile := WeatherVisualRules.profile_for_condition(
		WeatherVisualRules.FOG
	)
	var snow_profile := WeatherVisualRules.profile_for_condition(
		WeatherVisualRules.SNOW
	)

	var clear_tint: Color = clear_profile.get(
		"world_tint",
		Color.TRANSPARENT
	)
	if clear_tint.a != 0.0:
		_fail("CLEAR weather should not tint the airport.")
		return
	if float(rain_profile.get("wet_strength", 0.0)) <= 0.5:
		_fail("Rain should visibly enable wet pavement treatment.")
		return
	if int(rain_profile.get("rain_count", 0)) < 30:
		_fail("Rain should render a visible but lightweight streak set.")
		return
	if float(fog_profile.get("fog_strength", 0.0)) <= 0.4:
		_fail("Fog should have a strong haze layer.")
		return
	if int(snow_profile.get("snow_count", 0)) < 25:
		_fail("Snow should render a visible lightweight flurry.")
		return

	if not WeatherVisualRules.is_wet(WeatherVisualRules.RAIN):
		_fail("Rain should classify as wet weather.")
		return
	if WeatherVisualRules.is_wet(WeatherVisualRules.CLOUDY):
		_fail("Cloudy weather should not classify as wet.")
		return
	if not WeatherVisualRules.is_low_visibility(WeatherVisualRules.FOG):
		_fail("Fog should classify as low visibility.")
		return
	if not WeatherVisualRules.is_precipitation(WeatherVisualRules.SNOW):
		_fail("Snow should classify as precipitation.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	await process_frame

	if grid.weather_overlay == null:
		_fail("AirportGrid should create its weather overlay automatically.")
		return

	var before := grid.get_airside_status()

	grid.set_weather_override(WeatherVisualRules.RAIN)
	await process_frame
	var snapshot := grid.get_weather_snapshot()
	if String(snapshot.get("condition", "")) != WeatherVisualRules.RAIN:
		_fail("Manual rain override should immediately change airport weather.")
		return
	if String(snapshot.get("source", "")) != "manual":
		_fail("Manual weather should report manual source.")
		return
	if not bool(snapshot.get("precipitation", false)):
		_fail("Rain snapshot should report precipitation.")
		return

	grid.clear_weather_override()
	grid.set_event_visual_state(
		{
			"active": true,
			"theme": "winter"
		},
		{}
	)
	await process_frame
	snapshot = grid.get_weather_snapshot()
	if String(snapshot.get("condition", "")) != WeatherVisualRules.SNOW:
		_fail("Active Winter event should request snow ambience.")
		return
	if String(snapshot.get("source", "")) != "event":
		_fail("Winter weather should report event source.")
		return

	grid.set_weather_override(WeatherVisualRules.FOG)
	await process_frame
	snapshot = grid.get_weather_snapshot()
	if String(snapshot.get("condition", "")) != WeatherVisualRules.FOG:
		_fail("Manual override should take priority over Winter event snow.")
		return
	if String(snapshot.get("source", "")) != "manual":
		_fail("Manual override should remain the highest-priority source.")
		return

	grid.clear_weather_override()
	await process_frame
	snapshot = grid.get_weather_snapshot()
	if String(snapshot.get("condition", "")) != WeatherVisualRules.SNOW:
		_fail("Clearing manual override should reveal Winter event snow again.")
		return

	grid.set_event_visual_state(
		{
			"active": false,
			"theme": "winter"
		},
		{}
	)
	await process_frame
	snapshot = grid.get_weather_snapshot()
	if String(snapshot.get("source", "")) != "daily":
		_fail("Inactive Winter event should return weather control to daily ambience.")
		return

	var after := grid.get_airside_status()
	for key in [
		"runways",
		"taxiways",
		"stands_total",
		"stands_connected",
		"hangars_total",
		"hangars_connected"
	]:
		if int(before.get(key, -1)) != int(after.get(key, -2)):
			_fail(
				"Weather ambience must not change airside stat %s."
				% String(key)
			)
			return

	print(
		"Weather ambience passed: daily weather, rain/wet pavement, fog, "
		+ "Winter snow and override precedence stay visual-only."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
