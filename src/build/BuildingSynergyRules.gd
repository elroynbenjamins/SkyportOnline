class_name BuildingSynergyRules
extends RefCounted


const DEFAULT_PASSENGER_RADIUS_TILES := 5.0
const DEFAULT_PASSENGER_BONUS := 0.10
const DEFAULT_SERVICE_RADIUS_TILES := 6.0
const DEFAULT_SERVICE_BONUS := 0.08


static func passenger_multiplier(
	receiver_definition: Dictionary,
	provider_definition: Dictionary,
	distance_tiles: float
) -> float:
	if receiver_definition.is_empty() or provider_definition.is_empty():
		return 1.0
	if String(
		receiver_definition.get("synergy_receiver", "")
	) != "passenger_hub":
		return 1.0
	if String(
		provider_definition.get("synergy_provider", "")
	) != "passenger_hub":
		return 1.0

	var radius := maxf(
		float(
			provider_definition.get(
				"synergy_radius_tiles",
				DEFAULT_PASSENGER_RADIUS_TILES
			)
		),
		0.0
	)
	if distance_tiles > radius + 0.001:
		return 1.0

	var bonus := clampf(
		float(
			receiver_definition.get(
				"passenger_synergy_bonus",
				provider_definition.get(
					"synergy_bonus",
					DEFAULT_PASSENGER_BONUS
				)
			)
		),
		0.0,
		0.35
	)
	return 1.0 + bonus


static func service_multiplier(
	station_definition: Dictionary,
	distance_tiles: float
) -> float:
	if station_definition.is_empty():
		return 1.0

	var bonus := clampf(
		float(
			station_definition.get(
				"local_service_bonus",
				0.0
			)
		),
		0.0,
		0.30
	)
	if bonus <= 0.0:
		return 1.0

	var radius := maxf(
		float(
			station_definition.get(
				"local_service_radius_tiles",
				DEFAULT_SERVICE_RADIUS_TILES
			)
		),
		0.0
	)
	if distance_tiles > radius + 0.001:
		return 1.0
	return 1.0 + bonus


static func passenger_radius(
	provider_definition: Dictionary
) -> float:
	return maxf(
		float(
			provider_definition.get(
				"synergy_radius_tiles",
				DEFAULT_PASSENGER_RADIUS_TILES
			)
		),
		0.0
	)


static func service_radius(
	station_definition: Dictionary
) -> float:
	return maxf(
		float(
			station_definition.get(
				"local_service_radius_tiles",
				DEFAULT_SERVICE_RADIUS_TILES
			)
		),
		0.0
	)


static func bonus_percent(multiplier: float) -> int:
	return maxi(
		int(round((maxf(multiplier, 1.0) - 1.0) * 100.0)),
		0
	)


static func passenger_preview_text(
	multiplier: float,
	provider_name: String
) -> String:
	var bonus := bonus_percent(multiplier)
	if bonus <= 0:
		return "Outside terminal synergy range"
	return "+%d%% passenger production near %s" % [
		bonus,
		provider_name
	]


static func service_preview_text(
	bonus_multiplier: float,
	covered_stands: int
) -> String:
	var bonus := bonus_percent(bonus_multiplier)
	if bonus <= 0:
		return "No local service speed bonus"
	if covered_stands <= 0:
		return "+%d%% service speed when a stand is inside the zone" % bonus
	return "+%d%% service speed • %d stand%s covered" % [
		bonus,
		covered_stands,
		"" if covered_stands == 1 else "s"
	]
