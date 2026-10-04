class_name AircraftMastery
extends RefCounted

const STAR_MILESTONES_HOURS := [
	10.0,
	50.0,
	150.0,
	400.0,
	1000.0
]


static func stars_for_hours(hours: float) -> int:
	var stars := 0
	for milestone in STAR_MILESTONES_HOURS:
		if hours >= milestone:
			stars += 1
	return stars


static func bonuses_for_stars(stars: int) -> Dictionary:
	var clamped := clampi(stars, 0, 5)
	match clamped:
		0:
			return {
				"passenger_reduction": 0.00,
				"xp_bonus": 0.00,
				"coin_bonus": 0.00
			}
		1:
			return {
				"passenger_reduction": 0.05,
				"xp_bonus": 0.00,
				"coin_bonus": 0.00
			}
		2:
			return {
				"passenger_reduction": 0.05,
				"xp_bonus": 0.05,
				"coin_bonus": 0.00
			}
		3:
			return {
				"passenger_reduction": 0.05,
				"xp_bonus": 0.05,
				"coin_bonus": 0.05
			}
		4:
			return {
				"passenger_reduction": 0.10,
				"xp_bonus": 0.10,
				"coin_bonus": 0.05
			}
		_:
			return {
				"passenger_reduction": 0.10,
				"xp_bonus": 0.10,
				"coin_bonus": 0.10
			}


static func status(hours: float) -> Dictionary:
	var stars := stars_for_hours(hours)
	var next_star := stars + 1
	var next_hours := 0.0
	if next_star <= 5:
		next_hours = float(STAR_MILESTONES_HOURS[next_star - 1])

	return {
		"hours": maxf(hours, 0.0),
		"stars": stars,
		"next_star": next_star if next_star <= 5 else 5,
		"next_hours": next_hours,
		"bonuses": bonuses_for_stars(stars)
	}


static func passenger_requirement(
	base_passengers: int,
	hours: float
) -> int:
	var bonuses := bonuses_for_stars(stars_for_hours(hours))
	var reduction := float(
		bonuses.get("passenger_reduction", 0.0)
	)
	if reduction <= 0.0 or base_passengers <= 0:
		return maxi(base_passengers, 0)

	var reduction_count := maxi(
		int(round(float(base_passengers) * reduction)),
		1
	)
	if reduction >= 0.10:
		reduction_count = maxi(reduction_count, 2)

	return maxi(base_passengers - reduction_count, 1)


static func apply_coin_bonus(base_coins: int, hours: float) -> int:
	var bonuses := bonuses_for_stars(stars_for_hours(hours))
	return maxi(
		int(round(
			float(base_coins)
			* (1.0 + float(bonuses.get("coin_bonus", 0.0)))
		)),
		0
	)


static func apply_xp_bonus(base_xp: int, hours: float) -> int:
	var bonuses := bonuses_for_stars(stars_for_hours(hours))
	return maxi(
		int(round(
			float(base_xp)
			* (1.0 + float(bonuses.get("xp_bonus", 0.0)))
		)),
		0
	)


static func format_stars(stars: int) -> String:
	var result := ""
	for index in range(5):
		result += "★" if index < stars else "☆"
	return result


static func current_benefit_text(stars: int) -> String:
	var bonuses := bonuses_for_stars(stars)
	var passenger_reduction := float(
		bonuses.get("passenger_reduction", 0.0)
	)
	var xp_bonus := float(bonuses.get("xp_bonus", 0.0))
	var coin_bonus := float(bonuses.get("coin_bonus", 0.0))

	if stars <= 0:
		return "No Mastery bonuses yet."

	var parts: Array[String] = []
	if passenger_reduction > 0.0:
		parts.append(
			"~%.0f%% fewer passengers"
			% (passenger_reduction * 100.0)
		)
	if xp_bonus > 0.0:
		parts.append("XP +%.0f%%" % (xp_bonus * 100.0))
	if coin_bonus > 0.0:
		parts.append("Coins +%.0f%%" % (coin_bonus * 100.0))
	return " • ".join(parts)


static func next_reward_text(stars: int) -> String:
	match clampi(stars, 0, 5):
		0:
			return "★  ~5% fewer passengers"
		1:
			return "★★  +5% flight XP"
		2:
			return "★★★  +5% flight coins"
		3:
			return "★★★★  Passenger reduction ~10% + XP +10%"
		4:
			return "★★★★★  Flight coins improve to +10%"
		_:
			return "Mastery complete"
