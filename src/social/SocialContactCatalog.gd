class_name SocialContactCatalog
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "system_brussels",
			"display_name": "Aero Jules",
			"airport_name": "Brussels Link",
			"airport_code": "BRU",
			"country_id": "BE",
			"relationship": "friend",
			"aircraft_type_id": "pico_p8",
			"system_contact": true
		},
		{
			"id": "system_hamburg",
			"display_name": "Mira Hahn",
			"airport_name": "Hanseatic Airfield",
			"airport_code": "HAM",
			"country_id": "DE",
			"relationship": "friend",
			"aircraft_type_id": "swift_s14",
			"system_contact": true
		},
		{
			"id": "system_london",
			"display_name": "Avery Cole",
			"airport_name": "Thames Skyport",
			"airport_code": "LON",
			"country_id": "GB",
			"relationship": "friend",
			"aircraft_type_id": "comet_c22",
			"system_contact": true
		},
		{
			"id": "system_copenhagen",
			"display_name": "Freja Lund",
			"airport_name": "Nordic Gateway",
			"airport_code": "CPH",
			"country_id": "DK",
			"relationship": "friend",
			"aircraft_type_id": "pico_p8",
			"system_contact": true
		},
		{
			"id": "system_paris_alliance",
			"display_name": "Camille Roux",
			"airport_name": "Alliance Paris",
			"airport_code": "PAR",
			"country_id": "FR",
			"relationship": "alliance",
			"aircraft_type_id": "swift_s14",
			"alliance_tag": "AIR",
			"system_contact": true
		},
		{
			"id": "system_madrid_alliance",
			"display_name": "Nora Vega",
			"airport_name": "Iberia Alliance Hub",
			"airport_code": "MAD",
			"country_id": "ES",
			"relationship": "alliance",
			"aircraft_type_id": "comet_c22",
			"alliance_tag": "AIR",
			"system_contact": true
		}
	]


static func get_contact(contact_id: String) -> Dictionary:
	for contact in all():
		if String(contact.get("id", "")) == contact_id:
			return contact.duplicate(true)
	return {}


static func development_contacts() -> Array[Dictionary]:
	return all()
