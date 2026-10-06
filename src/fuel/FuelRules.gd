class_name FuelRules
extends RefCounted

# Fuel is an airport operational resource. Values are intentionally abstract
# "fuel units" rather than litres so route balance can stay readable on mobile.
const DEFAULT_STARTING_FUEL := 180
const EMERGENCY_ORDER_AMOUNT := 120
const EMERGENCY_ORDER_COIN_COST := 750
const REWARDED_AD_FUEL_AMOUNT := 50


static func required_for_route(
	aircraft_profile: Dictionary,
	distance_km: float
) -> int:
	if aircraft_profile.is_empty():
		return 0

	var size := String(aircraft_profile.get("size", "S")).to_upper()
	var distance := maxf(distance_km, 0.0)
	var base := 6.0
	var per_km := 0.024

	match size:
		"M":
			base = 15.0
			per_km = 0.020
		"L":
			base = 30.0
			per_km = 0.018
		"XL":
			base = 48.0
			per_km = 0.016

	return maxi(int(ceil(base + distance * per_km)), 1)


static func required_for_plan(
	aircraft_profile: Dictionary,
	flight_plan: Dictionary
) -> int:
	if flight_plan.has("fuel_required"):
		return maxi(int(flight_plan.get("fuel_required", 0)), 0)
	return required_for_route(
		aircraft_profile,
		float(flight_plan.get("distance_km", 0.0))
	)
