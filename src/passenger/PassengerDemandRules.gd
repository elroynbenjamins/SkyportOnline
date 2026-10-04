class_name PassengerDemandRules
extends RefCounted

const MIN_LOAD_FACTOR := 0.45
const MAX_LOAD_FACTOR := 1.00


static func base_load_factor(destination: Dictionary) -> float:
	if destination.is_empty():
		return 1.0
	return clampf(
		float(destination.get("passenger_load_factor", 1.0)),
		MIN_LOAD_FACTOR,
		MAX_LOAD_FACTOR
	)


static func adjusted_load_factor(
	destination: Dictionary,
	demand_modifier: float = 1.0
) -> float:
	return clampf(
		base_load_factor(destination) * maxf(demand_modifier, 0.0),
		MIN_LOAD_FACTOR,
		MAX_LOAD_FACTOR
	)


static func base_route_requirement(
	aircraft_profile: Dictionary,
	destination: Dictionary,
	demand_modifier: float = 1.0
) -> int:
	if aircraft_profile.is_empty():
		return 0

	var seats := maxi(int(aircraft_profile.get("passengers", 0)), 0)
	if seats <= 0:
		return 0

	var load_factor := adjusted_load_factor(
		destination,
		demand_modifier
	)
	return clampi(
		int(ceil(float(seats) * load_factor)),
		1,
		seats
	)


static func required_passengers(
	aircraft_profile: Dictionary,
	destination: Dictionary,
	mastery_hours: float,
	demand_modifier: float = 1.0
) -> int:
	var route_requirement := base_route_requirement(
		aircraft_profile,
		destination,
		demand_modifier
	)
	return AircraftMastery.passenger_requirement(
		route_requirement,
		mastery_hours
	)


static func required_from_plan(
	aircraft_profile: Dictionary,
	flight_plan: Dictionary,
	mastery_hours: float
) -> int:
	if flight_plan.is_empty():
		return maxi(int(aircraft_profile.get("passengers", 0)), 0)

	var destination := {
		"passenger_load_factor": float(
			flight_plan.get("passenger_load_factor", 1.0)
		),
		"demand_label": String(
			flight_plan.get("passenger_demand_label", "Standard")
		)
	}
	var modifier := float(
		flight_plan.get("passenger_demand_modifier", 1.0)
	)
	return required_passengers(
		aircraft_profile,
		destination,
		mastery_hours,
		modifier
	)


static func preview(
	aircraft_profile: Dictionary,
	destination: Dictionary,
	mastery_hours: float,
	demand_modifier: float = 1.0
) -> Dictionary:
	var seats := maxi(int(aircraft_profile.get("passengers", 0)), 0)
	var route_requirement := base_route_requirement(
		aircraft_profile,
		destination,
		demand_modifier
	)
	var final_requirement := AircraftMastery.passenger_requirement(
		route_requirement,
		mastery_hours
	)
	return {
		"seats": seats,
		"base_load_factor": base_load_factor(destination),
		"adjusted_load_factor": adjusted_load_factor(
			destination,
			demand_modifier
		),
		"demand_label": String(
			destination.get("demand_label", "Standard")
		),
		"route_requirement": route_requirement,
		"mastery_requirement": final_requirement,
		"demand_modifier": demand_modifier
	}


static func preview_from_plan(
	aircraft_profile: Dictionary,
	flight_plan: Dictionary,
	mastery_hours: float
) -> Dictionary:
	if flight_plan.is_empty():
		return {}

	var destination := {
		"passenger_load_factor": float(
			flight_plan.get("passenger_load_factor", 1.0)
		),
		"demand_label": String(
			flight_plan.get("passenger_demand_label", "Standard")
		)
	}
	return preview(
		aircraft_profile,
		destination,
		mastery_hours,
		float(
			flight_plan.get("passenger_demand_modifier", 1.0)
		)
	)
