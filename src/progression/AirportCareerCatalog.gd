class_name AirportCareerCatalog
extends RefCounted

# Stable IDs are save keys. Rewards deliberately contain no coins, gems or materials.
# Flight objectives count completed OWNED-aircraft returns, not dispatches or visitors.
const ROUTE_RANK_BY_QUEST := {
	"first_circuit": 0,
	"german_business": 1,
	"channel_crossing": 2,
	"french_connection": 3,
	"berlin_schedule": 3,
	"nordic_connection": 4,
	"nimbus_france": 3,
	"arrow_london": 4,
	"atlas_denmark": 5,
	"falcon_germany": 6
}

static func all() -> Array[Dictionary]:
	return [
		_q("first_circuit", "First departures", "A first link to Belgium", "Captain Tess", 1, 80, 8,
			{"kind": "flight", "country": "BE", "aircraft": "pico_p8", "destination": "brussels", "target": 1},
			"Complete a return flight to Belgium with a Pico P8. Choose Brussels on the World Map; rewards count when your aircraft comes home."),
		_q("swift_purchase", "First departures", "A little more range", "Captain Tess", 2, 60, 0,
			{"kind": "own_aircraft", "aircraft": "swift_s14", "target": 1},
			"Buy a Swift S14 from Aircraft Orders. It reaches destinations that are beyond the Pico's range. Owned aircraft already count."),
		_q("german_business", "First departures", "German business connections", "Captain Tess", 2, 100, 10,
			{"kind": "flight", "country": "DE", "aircraft": "swift_s14", "destination": "frankfurt", "target": 2},
			"Complete two Germany returns using a Swift S14. Frankfurt is within its range; Berlin is not."),
		_q("channel_crossing", "First departures", "Across the Channel", "Captain Tess", 2, 100, 0,
			{"kind": "flight", "country": "GB", "aircraft": "swift_s14", "destination": "london", "target": 1},
			"Send your Swift to London and bring it home. Different countries supply different upgrade materials."),
		_q("passenger_foundation", "First departures", "More passengers, more possibilities", "Mara - Airport Planner", 3, 80, 0,
			{"kind": "building", "building": "travel_office", "target": 2, "upgrade_level": 1},
			"Own two placed Travel Offices. Place them near your terminal for a production bonus; the starter office counts."),
		_q("first_guest", "First departures", "Welcome a visiting pilot", "Captain Tess", 3, 120, 10,
			{"kind": "npc_service", "target": 1},
			"Keep a connected stand free and fully service one NPC visitor through departure. NPCs visit occasionally; they do not use your passenger stock."),
		_q("french_connection", "First departures", "Bonjour, Paris", "Captain Tess", 3, 150, 0,
			{"kind": "flight", "country": "FR", "aircraft": "swift_s14", "destination": "paris", "target": 2},
			"Complete two France returns with a Swift. Paris is at the edge of its range, so check aircraft fit before dispatch."),
		_q("comet_purchase", "Growing airport", "A Comet joins the fleet", "Captain Elise", 4, 120, 0,
			{"kind": "own_aircraft", "aircraft": "comet_c22", "target": 1},
			"Buy a Comet C22. More seats mean higher passenger demand: keep production and storage growing with your fleet."),
		_q("berlin_schedule", "Growing airport", "A Berlin schedule", "Captain Elise", 4, 180, 15,
			{"kind": "flight", "country": "DE", "aircraft": "comet_c22", "destination": "berlin", "target": 2},
			"Complete two Germany returns with a Comet C22. Try Berlin to use its longer range; other German airports also count."),
		_q("service_apron", "Growing airport", "Room to grow", "Mara - Airport Planner", 5, 200, 0,
			{"kind": "parcel", "parcel": "north", "target": 1},
			"Purchase the Service Apron north of your airport. Already-owned land counts; use the new space for supporting buildings."),
		_q("baggage_capacity", "Growing airport", "Keep the baggage moving", "Mara - Airport Planner", 5, 180, 0,
			{"kind": "building", "building": "baggage_depot", "target": 1, "upgrade_level": 1},
			"Place a Baggage Depot and connect its service road to your stands. A nearby position also improves local service speed."),
		_q("voyager_purchase", "Growing airport", "Beyond the short routes", "Captain Freja", 6, 220, 0,
			{"kind": "own_aircraft", "aircraft": "voyager_v32", "target": 1},
			"Buy a Voyager V32. Its range reaches Denmark, which neither the Pico nor Comet can reach from the current route hub."),
		_q("nordic_connection", "Growing airport", "The Nordic connection", "Captain Freja", 6, 240, 15,
			{"kind": "flight", "country": "DK", "aircraft": "voyager_v32", "destination": "copenhagen", "target": 2},
			"Complete two Denmark returns with your Voyager. Copenhagen brings another country's materials into your network."),
		_q("office_upgrade", "Growing airport", "Invest in passenger supply", "Mara - Airport Planner", 6, 250, 0,
			{"kind": "building", "building": "travel_office", "target": 1, "upgrade_level": 2},
			"Upgrade one Travel Office to level 2. Its material list points you back to useful countries. Higher upgrades already count."),
		_q("shuttle_support", "Growing airport", "A regular shuttle service", "Mara - Airport Planner", 7, 240, 0,
			{"kind": "building", "building": "shuttle_station", "target": 1, "upgrade_level": 1},
			"Place a Shuttle Station to support your larger fleet. Near a terminal it gains a stronger passenger-production bonus."),
		_q("traffic_control", "Regional ambitions", "Give the tower a view", "Mara - Airport Planner", 9, 350, 20,
			{"kind": "building", "building": "atc_tower", "target": 1, "upgrade_level": 1},
			"Place an ATC Tower to improve runway throughput. Between career milestones, ordinary flights continue earning XP and coins."),
		_q("regional_ready", "Regional ambitions", "Ready for medium aircraft", "Captain Nico", 12, 500, 0,
			{"kind": "regional_ready", "target": 1},
			"Build a Regional Runway, Medium Stand and Regional Fuel Depot. Connect taxiways AND service roads. The runway unlocks at level 12; a Nimbus ordered earlier remains in reserve until ready."),
		_q("nimbus_purchase", "Regional ambitions", "Your first regional aircraft", "Captain Nico", 12, 350, 0,
			{"kind": "own_aircraft", "aircraft": "nimbus_n40", "target": 1},
			"Own a Nimbus N40. Aircraft Orders retains it safely in reserve until a compatible connected stand is free."),
		_q("nimbus_france", "Regional ambitions", "Regional service to France", "Captain Nico", 12, 450, 20,
			{"kind": "flight", "country": "FR", "aircraft": "nimbus_n40", "destination": "paris", "target": 2},
			"Complete two France returns with your Nimbus. Medium aircraft need the correct runway, stand and fueling support."),
		_q("arrow_purchase", "Regional ambitions", "A faster regional option", "Captain Sofia", 12, 400, 0,
			{"kind": "own_aircraft", "aircraft": "arrow_a52", "target": 1},
			"Buy an Arrow A52. Compare its flight time and passenger needs with the Nimbus before assigning a route."),
		_q("arrow_london", "Regional ambitions", "An express connection", "Captain Sofia", 12, 500, 0,
			{"kind": "flight", "country": "GB", "aircraft": "arrow_a52", "destination": "london", "target": 2},
			"Complete two United Kingdom returns using your Arrow. Keep room for incoming aircraft while your own fleet is away."),
		_q("atlas_purchase", "Regional ambitions", "Capacity matters", "Captain Mateo", 12, 450, 0,
			{"kind": "own_aircraft", "aircraft": "atlas_a64", "target": 1},
			"Buy an Atlas A64. Its larger passenger load rewards a well-supported airport rather than simply owning more stands."),
		_q("atlas_denmark", "Regional ambitions", "A larger Nordic connection", "Captain Mateo", 12, 600, 25,
			{"kind": "flight", "country": "DK", "aircraft": "atlas_a64", "destination": "copenhagen", "target": 2},
			"Complete two Denmark returns using an Atlas. This revisits an earlier country with a new aircraft and larger demand."),
		_q("medium_visitors", "Regional ambitions", "A regional welcome", "Captain Nico", 12, 600, 0,
			{"kind": "npc_service", "size": "M", "target": 2},
			"Fully service two medium NPC visitors. Their arrival depends on your level and compatible free infrastructure, not just owning a medium plane."),
		_q("falcon_purchase", "A connected airport", "Step up to the Falcon", "Captain Keiko", 15, 650, 0,
			{"kind": "own_aircraft", "aircraft": "falcon_f72", "target": 1},
			"Own a Falcon F72. Keep making ordinary flights between career milestones; career rewards are bonuses, not the whole economy."),
		_q("falcon_germany", "A connected airport", "Reliable international service", "Captain Keiko", 15, 800, 25,
			{"kind": "flight", "country": "DE", "aircraft": "falcon_f72", "destination": "berlin", "target": 3},
			"Complete three Germany returns using a Falcon. Upgraded ground services help keep this larger aircraft moving."),
		_q("horizon_purchase", "A connected airport", "The V1 flagship", "Captain Amara", 17, 750, 0,
			{"kind": "own_aircraft", "aircraft": "horizon_h88", "target": 1},
			"Own a Horizon H88. This is the last V1 aircraft family; large and extra-large aircraft remain future content."),
		_q("horizon_tour", "A connected airport", "An airport without borders", "Captain Amara", 17, 1000, 30,
			{"kind": "countries", "aircraft": "horizon_h88", "target": 5},
			"After this mission unlocks, complete Horizon returns from five different countries: Belgium, the UK, Germany, France and Denmark. Repeating one country does not advance this tour.")
	]

static func _q(id: String, chapter: String, title: String, mentor: String,
	level: int, xp: int, passengers: int, objective: Dictionary, guidance: String) -> Dictionary:
	return {"id": id, "chapter": chapter, "title": title, "mentor": mentor,
		"level": level, "xp": xp, "passengers": passengers,
		"objective": objective, "guidance": guidance}

static func all_for_home(
	home_country_id: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_variant in all():
		var quest: Dictionary = quest_variant
		result.append(
			resolve_for_home(
				quest,
				home_country_id
			)
		)
	return result


static func resolve_for_home(
	quest: Dictionary,
	home_country_id: String
) -> Dictionary:
	var resolved := quest.duplicate(true)
	var objective: Dictionary = (
		resolved.get("objective", {}) as Dictionary
	).duplicate(true)
	var kind := String(objective.get("kind", ""))
	if kind == "flight":
		var aircraft_id := String(
			objective.get("aircraft", "")
		)
		var rank := int(
			ROUTE_RANK_BY_QUEST.get(
				String(resolved.get("id", "")),
				0
			)
		)
		var destination := (
			DestinationCatalog.career_destination_for_home(
				home_country_id,
				aircraft_id,
				int(resolved.get("level", 1)),
				rank
			)
		)
		if not destination.is_empty():
			objective["country"] = String(
				destination.get("country_code", "")
			)
			objective["destination"] = String(
				destination.get("id", "")
			)
			resolved["title"] = "%s connection" % String(
				destination.get("city", "Route")
			)
			var target := maxi(
				int(objective.get("target", 1)),
				1
			)
			var aircraft := AircraftCatalog.get_profile(
				aircraft_id
			)
			resolved["guidance"] = (
				"Complete %d return%s to %s, %s with a %s. "
				+ "This route is selected from your %s home network; "
				+ "other countries keep their own resource drops."
			) % [
				target,
				"" if target == 1 else "s",
				String(destination.get("city", "destination")),
				String(destination.get("country", "")),
				String(aircraft.get("name", aircraft_id)),
				String(
					CountryCatalog.get_country(
						home_country_id
					).get("name", home_country_id)
				)
			]
			resolved["objective"] = objective
	elif kind == "countries":
		var aircraft := AircraftCatalog.get_profile(
			String(objective.get("aircraft", ""))
		)
		resolved["title"] = "An airport without borders"
		resolved["guidance"] = (
			"Complete returns from %d different destination countries "
			+ "with your %s. Repeating one country does not advance the tour."
		) % [
			maxi(int(objective.get("target", 1)), 1),
			String(aircraft.get("name", "aircraft"))
		]
	return resolved


static func current(
	claimed: Dictionary,
	home_country_id: String = DestinationCatalog.DEFAULT_HOME_COUNTRY_ID
) -> Dictionary:
	for quest in all_for_home(home_country_id):
		if not bool(claimed.get(quest["id"], false)):
			return quest.duplicate(true)
	return {}
