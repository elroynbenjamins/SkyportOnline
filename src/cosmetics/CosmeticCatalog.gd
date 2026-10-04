class_name CosmeticCatalog
extends RefCounted

const SLOT_AIRPORT_BORDER := "airport_border"
const SLOT_TERMINAL_SKIN := "terminal_skin"
const SLOT_AIRCRAFT_LIVERY := "aircraft_livery"
const SLOT_ALLIANCE_FLAG := "alliance_flag"
const SLOT_ALLIANCE_EMBLEM := "alliance_emblem"


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "event_autumn_airport_border",
			"name": "Autumn Airport Border",
			"slot": SLOT_AIRPORT_BORDER,
			"theme": "autumn",
			"accent": Color("d77a32")
		},
		{
			"id": "event_autumn_terminal_skin",
			"name": "Autumn Terminal Skin",
			"slot": SLOT_TERMINAL_SKIN,
			"theme": "autumn",
			"accent": Color("c86f32")
		},
		{
			"id": "event_autumn_pico_livery",
			"name": "Harvest Pico Livery",
			"slot": SLOT_AIRCRAFT_LIVERY,
			"theme": "autumn",
			"accent": Color("d96f2b"),
			"secondary": Color("f0c25c"),
			"aircraft_types": PackedStringArray(["pico_p8"])
		},
		{
			"id": "event_autumn_alliance_flag",
			"name": "Autumn Alliance Flag",
			"slot": SLOT_ALLIANCE_FLAG,
			"theme": "autumn",
			"accent": Color("c6632d")
		},
		{
			"id": "event_autumn_alliance_emblem",
			"name": "Autumn Alliance Emblem",
			"slot": SLOT_ALLIANCE_EMBLEM,
			"theme": "autumn",
			"accent": Color("e5a74a")
		},
		{
			"id": "event_lantern_airport_border",
			"name": "Lantern Airport Border",
			"slot": SLOT_AIRPORT_BORDER,
			"theme": "lantern",
			"accent": Color("db536d")
		},
		{
			"id": "event_lantern_terminal_skin",
			"name": "Lantern Terminal Skin",
			"slot": SLOT_TERMINAL_SKIN,
			"theme": "lantern",
			"accent": Color("b84b78")
		},
		{
			"id": "event_lantern_pico_livery",
			"name": "Festival Pico Livery",
			"slot": SLOT_AIRCRAFT_LIVERY,
			"theme": "lantern",
			"accent": Color("e1537c"),
			"secondary": Color("f4c85d"),
			"aircraft_types": PackedStringArray(["pico_p8"])
		},
		{
			"id": "event_lantern_flag",
			"name": "Lantern Flag",
			"slot": SLOT_ALLIANCE_FLAG,
			"theme": "lantern",
			"accent": Color("ca4a74")
		},
		{
			"id": "event_lantern_alliance_emblem",
			"name": "Lantern Alliance Emblem",
			"slot": SLOT_ALLIANCE_EMBLEM,
			"theme": "lantern",
			"accent": Color("f0a64d")
		}
	]


static func slots() -> Array[String]:
	return [
		SLOT_AIRPORT_BORDER,
		SLOT_TERMINAL_SKIN,
		SLOT_AIRCRAFT_LIVERY,
		SLOT_ALLIANCE_FLAG,
		SLOT_ALLIANCE_EMBLEM
	]


static func slot_name(slot: String) -> String:
	match slot:
		SLOT_AIRPORT_BORDER:
			return "Airport Border"
		SLOT_TERMINAL_SKIN:
			return "Terminal Skin"
		SLOT_AIRCRAFT_LIVERY:
			return "Aircraft Livery"
		SLOT_ALLIANCE_FLAG:
			return "Alliance Flag"
		SLOT_ALLIANCE_EMBLEM:
			return "Alliance Emblem"
		_:
			return slot.capitalize()


static func get_cosmetic(cosmetic_id: String) -> Dictionary:
	for cosmetic in all():
		if String(cosmetic.get("id", "")) == cosmetic_id:
			return cosmetic.duplicate(true)
	return {}


static func for_slot(slot: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cosmetic in all():
		if String(cosmetic.get("slot", "")) == slot:
			result.append(cosmetic.duplicate(true))
	return result


static func visual_color(cosmetic_id: String) -> Color:
	var cosmetic := get_cosmetic(cosmetic_id)
	if cosmetic.is_empty():
		return Color.WHITE
	var color = cosmetic.get("accent", Color.WHITE)
	if color is Color:
		return color
	return Color.WHITE


static func secondary_color(cosmetic_id: String) -> Color:
	var cosmetic := get_cosmetic(cosmetic_id)
	if cosmetic.is_empty():
		return visual_color(cosmetic_id)
	var color = cosmetic.get("secondary", cosmetic.get("accent", Color.WHITE))
	if color is Color:
		return color
	return visual_color(cosmetic_id)


static func is_compatible_with_aircraft(
	cosmetic_id: String,
	aircraft_type_id: String
) -> bool:
	var cosmetic := get_cosmetic(cosmetic_id)
	if cosmetic.is_empty():
		return false
	if String(cosmetic.get("slot", "")) != SLOT_AIRCRAFT_LIVERY:
		return false
	var types: PackedStringArray = cosmetic.get(
		"aircraft_types",
		PackedStringArray()
	)
	return types.is_empty() or types.has(aircraft_type_id)
