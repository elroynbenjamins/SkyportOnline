class_name CountryCatalog
extends RefCounted

const RESOURCE_DROP_CHANCE := 0.40

const COUNTRIES = [
	{"id":"NL","name":"Netherlands","region":"Europe","map_x":0.505,"map_y":0.215},
	{"id":"BE","name":"Belgium","region":"Europe","map_x":0.485,"map_y":0.235},
	{"id":"DE","name":"Germany","region":"Europe","map_x":0.535,"map_y":0.215},
	{"id":"DK","name":"Denmark","region":"Europe","map_x":0.535,"map_y":0.165},
	{"id":"GB","name":"United Kingdom","region":"Europe","map_x":0.450,"map_y":0.195},
	{"id":"FR","name":"France","region":"Europe","map_x":0.485,"map_y":0.275},
	{"id":"ES","name":"Spain","region":"Europe","map_x":0.445,"map_y":0.330},
	{"id":"IT","name":"Italy","region":"Europe","map_x":0.555,"map_y":0.310},
	{"id":"US","name":"United States","region":"North America","map_x":0.220,"map_y":0.300},
	{"id":"CA","name":"Canada","region":"North America","map_x":0.205,"map_y":0.190},
	{"id":"MX","name":"Mexico","region":"North America","map_x":0.205,"map_y":0.405},
	{"id":"BR","name":"Brazil","region":"South America","map_x":0.355,"map_y":0.575},
	{"id":"ZA","name":"South Africa","region":"Africa","map_x":0.565,"map_y":0.690},
	{"id":"EG","name":"Egypt","region":"Africa","map_x":0.590,"map_y":0.370},
	{"id":"AE","name":"United Arab Emirates","region":"Middle East","map_x":0.655,"map_y":0.390},
	{"id":"TR","name":"Turkey","region":"Europe / Asia","map_x":0.600,"map_y":0.315},
	{"id":"IN","name":"India","region":"Asia","map_x":0.725,"map_y":0.415},
	{"id":"CN","name":"China","region":"Asia","map_x":0.800,"map_y":0.330},
	{"id":"JP","name":"Japan","region":"Asia","map_x":0.900,"map_y":0.315},
	{"id":"KR","name":"South Korea","region":"Asia","map_x":0.865,"map_y":0.350},
	{"id":"ID","name":"Indonesia","region":"Asia","map_x":0.825,"map_y":0.545},
	{"id":"AU","name":"Australia","region":"Oceania","map_x":0.865,"map_y":0.685},
	{"id":"NZ","name":"New Zealand","region":"Oceania","map_x":0.955,"map_y":0.750}
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

	for country in get_countries():
		var country_id := String(country.get("id", ""))
		if country_id.is_empty():
			errors.append("Country is missing an ID.")
		elif country_ids.has(country_id):
			errors.append("Duplicate country ID: %s" % country_id)
		else:
			country_ids[country_id] = true

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
