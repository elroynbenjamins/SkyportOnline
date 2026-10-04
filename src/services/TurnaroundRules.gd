class_name TurnaroundRules
extends RefCounted

# Ground handling is grouped into parallel blocks:
# 1) passenger deboarding + cargo unloading
# 2) fueling + cleaning + catering
# 3) passenger boarding + cargo loading
# 4) pushback preparation
#
# This keeps larger aircraft meaningfully slower without simply summing every
# service timer. Facility bonuses can target their own category later.


static func timing_for_profile(profile: Dictionary) -> Dictionary:
	if profile.is_empty():
		return {}

	return {
		"deboard_seconds": maxf(float(profile.get("deboard_seconds", 0.0)), 0.0),
		"cargo_unload_seconds": maxf(float(profile.get("cargo_unload_seconds", 0.0)), 0.0),
		"fuel_seconds": maxf(float(profile.get("fuel_seconds", 0.0)), 0.0),
		"clean_seconds": maxf(float(profile.get("clean_seconds", 0.0)), 0.0),
		"catering_seconds": maxf(float(profile.get("catering_seconds", 0.0)), 0.0),
		"board_seconds": maxf(float(profile.get("board_seconds", 0.0)), 0.0),
		"cargo_load_seconds": maxf(float(profile.get("cargo_load_seconds", 0.0)), 0.0),
		"pushback_seconds": maxf(float(profile.get("pushback_seconds", 0.0)), 0.0)
	}


static func arrival_block_seconds(profile: Dictionary) -> float:
	var timing := timing_for_profile(profile)
	if timing.is_empty():
		return 0.0
	return maxf(
		float(timing.get("deboard_seconds", 0.0)),
		float(timing.get("cargo_unload_seconds", 0.0))
	)


static func service_block_seconds(
	profile: Dictionary,
	fuel_speed: float = 1.0
) -> float:
	var timing := timing_for_profile(profile)
	if timing.is_empty():
		return 0.0

	var adjusted_fuel := fuel_seconds(profile, fuel_speed)
	return maxf(
		adjusted_fuel,
		maxf(
			float(timing.get("clean_seconds", 0.0)),
			float(timing.get("catering_seconds", 0.0))
		)
	)


static func loading_block_seconds(profile: Dictionary) -> float:
	var timing := timing_for_profile(profile)
	if timing.is_empty():
		return 0.0
	return maxf(
		float(timing.get("board_seconds", 0.0)),
		float(timing.get("cargo_load_seconds", 0.0))
	)


static func fuel_seconds(
	profile: Dictionary,
	fuel_speed: float = 1.0
) -> float:
	var speed := maxf(fuel_speed, 0.1)
	return maxf(float(profile.get("fuel_seconds", 0.0)), 0.0) / speed


static func estimated_turnaround_seconds(
	profile: Dictionary,
	fuel_speed: float = 1.0,
	is_returning: bool = true
) -> float:
	if profile.is_empty():
		return 0.0

	var total := 0.0
	if is_returning:
		total += arrival_block_seconds(profile)
	total += service_block_seconds(profile, fuel_speed)
	total += loading_block_seconds(profile)
	total += maxf(float(profile.get("pushback_seconds", 0.0)), 0.0)
	return total


static func compact_summary(profile: Dictionary) -> String:
	if profile.is_empty():
		return "No turnaround profile"

	return (
		"Fuel %.0fs • Pax %.0f/%.0fs • Cargo %.0f/%.0fs • "
		+ "Clean %.0fs • Catering %.0fs • Push %.0fs"
	) % [
		float(profile.get("fuel_seconds", 0.0)),
		float(profile.get("deboard_seconds", 0.0)),
		float(profile.get("board_seconds", 0.0)),
		float(profile.get("cargo_unload_seconds", 0.0)),
		float(profile.get("cargo_load_seconds", 0.0)),
		float(profile.get("clean_seconds", 0.0)),
		float(profile.get("catering_seconds", 0.0)),
		float(profile.get("pushback_seconds", 0.0))
	]
