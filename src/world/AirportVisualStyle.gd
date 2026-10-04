class_name AirportVisualStyle
extends RefCounted

const APRON_CONCRETE := Color("8b9495")
const APRON_CONCRETE_ALT := Color("929b9b")
const APRON_LINE := Color("c8d0cf", 0.45)

const TAXIWAY_ASPHALT := Color("555d61")
const TAXIWAY_EDGE := Color("80888b", 0.62)
const TAXIWAY_CENTER := Color("f0c94c")
const TAXIWAY_LIGHT := Color("79bfff")

const RUNWAY_ASPHALT := Color("30363b")
const RUNWAY_EDGE := Color("596166", 0.72)
const RUNWAY_MARKING := Color("f4f2df")
const RUNWAY_LIGHT := Color("d9edff")

const SERVICE_ROAD := Color("756f67")
const SERVICE_ROAD_ALT := Color("7c756d")
const SERVICE_ROAD_EDGE := Color("b4aea4", 0.45)
const SERVICE_ROAD_CENTER := Color("e7e1d3", 0.78)

const STAND_GUIDE := Color("f0c94c")
const STAND_BOX := Color("e6eceb", 0.72)
const STAND_STOP := Color("f2d35c")


static func is_airport_surface(building_id: String) -> bool:
	return (
		building_id.contains("runway")
		or building_id == "taxiway"
		or building_id == "service_road"
		or building_id.contains("stand")
	)


static func tile_fill(
	building_id: String,
	default_color: Color,
	checker: bool = false
) -> Color:
	if building_id.contains("runway"):
		return RUNWAY_ASPHALT
	if building_id == "taxiway":
		return TAXIWAY_ASPHALT
	if building_id == "service_road":
		return SERVICE_ROAD_ALT if checker else SERVICE_ROAD
	if building_id.contains("stand"):
		return APRON_CONCRETE_ALT if checker else APRON_CONCRETE
	return default_color


static func tile_outline(
	building_id: String,
	default_color: Color
) -> Color:
	if building_id.contains("runway"):
		return RUNWAY_EDGE
	if building_id == "taxiway":
		return TAXIWAY_EDGE
	if building_id == "service_road":
		return SERVICE_ROAD_EDGE
	if building_id.contains("stand"):
		return APRON_LINE
	return default_color


static func runway_number_for(building_id: String) -> String:
	if building_id == "short_runway":
		return "09"
	if building_id == "regional_runway":
		return "27"
	return ""
