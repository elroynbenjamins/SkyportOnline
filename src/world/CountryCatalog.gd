class_name CountryCatalog
extends RefCounted

const RESOURCE_DROP_CHANCE := 0.40

# map_x / map_y drive the stylized world-map marker placement.
# hub_lat / hub_lon are only used to calculate route geography.
# Each country has one representative hub for route generation; the player's
# actual airport can be anywhere inside the selected home country.
const COUNTRIES = [
	{"id":"NL","name":"Netherlands","region":"Europe","map_x":0.505,"map_y":0.215,"hub_city":"Amsterdam","route_id":"amsterdam","hub_lat":52.3676,"hub_lon":4.9041},
	{"id":"BE","name":"Belgium","region":"Europe","map_x":0.485,"map_y":0.235,"hub_city":"Brussels","route_id":"brussels","hub_lat":50.8503,"hub_lon":4.3517},
	{"id":"DE","name":"Germany","region":"Europe","map_x":0.535,"map_y":0.215,"hub_city":"Frankfurt","route_id":"frankfurt","hub_lat":50.1109,"hub_lon":8.6821},
	{"id":"DK","name":"Denmark","region":"Europe","map_x":0.535,"map_y":0.165,"hub_city":"Copenhagen","route_id":"copenhagen","hub_lat":55.6761,"hub_lon":12.5683},
	{"id":"GB","name":"United Kingdom","region":"Europe","map_x":0.450,"map_y":0.195,"hub_city":"London","route_id":"london","hub_lat":51.5074,"hub_lon":-0.1278},
	{"id":"FR","name":"France","region":"Europe","map_x":0.485,"map_y":0.275,"hub_city":"Paris","route_id":"paris","hub_lat":48.8566,"hub_lon":2.3522},
	{"id":"ES","name":"Spain","region":"Europe","map_x":0.445,"map_y":0.330,"hub_city":"Madrid","route_id":"madrid","hub_lat":40.4168,"hub_lon":-3.7038},
	{"id":"IT","name":"Italy","region":"Europe","map_x":0.555,"map_y":0.310,"hub_city":"Rome","route_id":"rome","hub_lat":41.9028,"hub_lon":12.4964},
	{"id":"US","name":"United States","region":"North America","map_x":0.220,"map_y":0.300,"hub_city":"New York","route_id":"new_york","hub_lat":40.7128,"hub_lon":-74.0060},
	{"id":"CA","name":"Canada","region":"North America","map_x":0.205,"map_y":0.190,"hub_city":"Toronto","route_id":"toronto","hub_lat":43.6532,"hub_lon":-79.3832},
	{"id":"MX","name":"Mexico","region":"North America","map_x":0.205,"map_y":0.405,"hub_city":"Mexico City","route_id":"mexico_city","hub_lat":19.4326,"hub_lon":-99.1332},
	{"id":"BR","name":"Brazil","region":"South America","map_x":0.355,"map_y":0.575,"hub_city":"Sao Paulo","route_id":"sao_paulo","hub_lat":-23.5505,"hub_lon":-46.6333},
	{"id":"ZA","name":"South Africa","region":"Africa","map_x":0.565,"map_y":0.690,"hub_city":"Johannesburg","route_id":"johannesburg","hub_lat":-26.2041,"hub_lon":28.0473},
	{"id":"EG","name":"Egypt","region":"Africa","map_x":0.590,"map_y":0.370,"hub_city":"Cairo","route_id":"cairo","hub_lat":30.0444,"hub_lon":31.2357},
	{"id":"AE","name":"United Arab Emirates","region":"Middle East","map_x":0.655,"map_y":0.390,"hub_city":"Dubai","route_id":"dubai","hub_lat":25.2048,"hub_lon":55.2708},
	{"id":"TR","name":"Turkey","region":"Europe / Asia","map_x":0.600,"map_y":0.315,"hub_city":"Istanbul","route_id":"istanbul","hub_lat":41.0082,"hub_lon":28.9784},
	{"id":"IN","name":"India","region":"Asia","map_x":0.725,"map_y":0.415,"hub_city":"Delhi","route_id":"delhi","hub_lat":28.6139,"hub_lon":77.2090},
	{"id":"CN","name":"China","region":"Asia","map_x":0.800,"map_y":0.330,"hub_city":"Beijing","route_id":"beijing","hub_lat":39.9042,"hub_lon":116.4074},
	{"id":"JP","name":"Japan","region":"Asia","map_x":0.900,"map_y":0.315,"hub_city":"Tokyo","route_id":"tokyo","hub_lat":35.6762,"hub_lon":139.6503},
	{"id":"KR","name":"South Korea","region":"Asia","map_x":0.865,"map_y":0.350,"hub_city":"Seoul","route_id":"seoul","hub_lat":37.5665,"hub_lon":126.9780},
	{"id":"ID","name":"Indonesia","region":"Asia","map_x":0.825,"map_y":0.545,"hub_city":"Jakarta","route_id":"jakarta","hub_lat":-6.2088,"hub_lon":106.8456},
	{"id":"AU","name":"Australia","region":"Oceania","map_x":0.865,"map_y":0.685,"hub_city":"Sydney","route_id":"sydney","hub_lat":-33.8688,"hub_lon":151.2093},
	{"id":"NZ","name":"New Zealand","region":"Oceania","map_x":0.955,"map_y":0.750,"hub_city":"Auckland","route_id":"auckland","hub_lat":-36.8509,"hub_lon":174.7645}
]


static func get_countries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for metadata in COUNTRIES:
		var country: Dictionary = metadata.duplicate(true)
		var country_id := String(country.get("id", ""))
		country["resources"] = CountryResourceCatalog.resources_for_country(
			country_id
		)
		result.append(country)
	return result


static func get_country(country_id: String) -> Dictionary:
	for metadata in COUNTRIES:
		if String(metadata.get("id", "")) != country_id:
			continue
		var country: Dictionary = metadata.duplicate(true)
		country["resources"] = CountryResourceCatalog.resources_for_country(
			country_id
		)
		return country
	return {}


static func validate_catalog() -> Dictionary:
	var errors: Array[String] = []
	var country_ids := {}
	var resource_ids := {}
	var route_ids := {}

	for country in get_countries():
		var country_id := String(country.get("id", ""))
		if country_id.is_empty():
			errors.append("Country is missing an ID.")
		elif country_ids.has(country_id):
			errors.append("Duplicate country ID: %s" % country_id)
		else:
			country_ids[country_id] = true

		var route_id := String(country.get("route_id", ""))
		if route_id.is_empty():
			errors.append("%s is missing a route ID." % country_id)
		elif route_ids.has(route_id):
			errors.append("Duplicate route ID: %s" % route_id)
		else:
			route_ids[route_id] = true

		if String(country.get("hub_city", "")).is_empty():
			errors.append("%s is missing a representative hub city." % country_id)
		if not country.has("hub_lat") or not country.has("hub_lon"):
			errors.append("%s is missing route coordinates." % country_id)

		var resources: Array = country.get("resources", [])
		if resources.size() != 3:
			errors.append("%s must define exactly three resources." % country_id)

		for resource in resources:
			var resource_id := String(resource.get("id", ""))
			if resource_id.is_empty():
				errors.append("%s contains a resource without an ID." % country_id)
			elif resource_ids.has(resource_id):
				errors.append("Duplicate country resource ID: %s" % resource_id)
			else:
				resource_ids[resource_id] = true

	return {"valid": errors.is_empty(), "errors": errors}
