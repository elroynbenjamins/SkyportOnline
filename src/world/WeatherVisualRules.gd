class_name WeatherVisualRules
extends RefCounted

const CLEAR := "CLEAR"
const CLOUDY := "CLOUDY"
const RAIN := "RAIN"
const FOG := "FOG"
const SNOW := "SNOW"


static func normalized_condition(condition: String) -> String:
	var value := condition.to_upper()
	if value in [CLEAR, CLOUDY, RAIN, FOG, SNOW]:
		return value
	return CLEAR


static func daily_condition(month: int, day: int) -> String:
	var safe_month := clampi(month, 1, 12)
	var safe_day := clampi(day, 1, 31)
	var roll := posmod(
		safe_month * 37 + safe_day * 17,
		100
	)

	if safe_month in [12, 1, 2]:
		if roll < 18:
			return SNOW
		if roll < 42:
			return CLOUDY
		if roll < 48:
			return FOG
		if roll < 55:
			return RAIN
		return CLEAR

	if roll < 12:
		return RAIN
	if roll < 35:
		return CLOUDY
	if roll < 41:
		return FOG
	return CLEAR


static func profile_for_condition(condition: String) -> Dictionary:
	match normalized_condition(condition):
		CLOUDY:
			return {
				"condition": CLOUDY,
				"display_name": "Cloudy",
				"world_tint": Color(0.05, 0.07, 0.08, 0.10),
				"cloud_shadow_strength": 0.34,
				"wet_strength": 0.0,
				"fog_strength": 0.0,
				"rain_count": 0,
				"snow_count": 0,
				"motion_speed": 7.0
			}
		RAIN:
			return {
				"condition": RAIN,
				"display_name": "Light Rain",
				"world_tint": Color(0.04, 0.08, 0.12, 0.18),
				"cloud_shadow_strength": 0.46,
				"wet_strength": 0.64,
				"fog_strength": 0.08,
				"rain_count": 42,
				"snow_count": 0,
				"motion_speed": 68.0
			}
		FOG:
			return {
				"condition": FOG,
				"display_name": "Haze",
				"world_tint": Color(0.68, 0.73, 0.72, 0.10),
				"cloud_shadow_strength": 0.08,
				"wet_strength": 0.0,
				"fog_strength": 0.48,
				"rain_count": 0,
				"snow_count": 0,
				"motion_speed": 3.0
			}
		SNOW:
			return {
				"condition": SNOW,
				"display_name": "Light Snow",
				"world_tint": Color(0.66, 0.78, 0.86, 0.12),
				"cloud_shadow_strength": 0.26,
				"wet_strength": 0.12,
				"fog_strength": 0.18,
				"rain_count": 0,
				"snow_count": 34,
				"motion_speed": 18.0
			}
		_:
			return {
				"condition": CLEAR,
				"display_name": "Clear",
				"world_tint": Color(0.0, 0.0, 0.0, 0.0),
				"cloud_shadow_strength": 0.0,
				"wet_strength": 0.0,
				"fog_strength": 0.0,
				"rain_count": 0,
				"snow_count": 0,
				"motion_speed": 0.0
			}


static func is_precipitation(condition: String) -> bool:
	return normalized_condition(condition) in [RAIN, SNOW]


static func is_wet(condition: String) -> bool:
	return normalized_condition(condition) == RAIN


static func is_low_visibility(condition: String) -> bool:
	return normalized_condition(condition) in [FOG, RAIN, SNOW]
