class_name BuildCatalogPresentation
extends RefCounted


static func availability(
	definition: Dictionary,
	player_level: int,
	player_coins: int,
	active_building_id: String = ""
) -> Dictionary:
	var id := String(definition.get("id", ""))
	var required_level := int(definition.get("level", 1))
	var cost := int(definition.get("cost", 0))
	var shortfall := maxi(cost - player_coins, 0)
	var status := "ready"

	if player_level < required_level:
		status = "locked"
	elif shortfall > 0:
		status = "shortfall"

	return {
		"status": status,
		"selected": id == active_building_id,
		"required_level": required_level,
		"cost": cost,
		"coin_shortfall": shortfall,
		"can_build": status == "ready",
		"inspectable": true
	}


static func card_text(
	definition: Dictionary,
	player_level: int,
	player_coins: int,
	active_building_id: String = ""
) -> String:
	var state := availability(
		definition,
		player_level,
		player_coins,
		active_building_id
	)
	var name := String(
		definition.get("menu_name", definition.get("name", "BUILDING"))
	)
	var footprint: Vector2i = definition.get(
		"footprint",
		Vector2i.ONE
	)
	var size_label := _size_label(definition)
	var footprint_label := "%dx%d" % [
		footprint.x,
		footprint.y
	]
	var second_line := ""

	match String(state["status"]):
		"locked":
			second_line = "🔒 LV %d  •  %s" % [
				int(state["required_level"]),
				footprint_label
			]
		"shortfall":
			second_line = "🪙 %s  •  NEED %s" % [
				_format_number(int(state["cost"])),
				_format_number(int(state["coin_shortfall"]))
			]
		_:
			second_line = "🪙 %s  •  %s" % [
				_format_number(int(state["cost"])),
				size_label if not size_label.is_empty() else footprint_label
			]

	return "%s\n%s" % [name, second_line]


static func detail_text(
	definition: Dictionary,
	player_level: int,
	player_coins: int
) -> String:
	var state := availability(
		definition,
		player_level,
		player_coins
	)
	var footprint: Vector2i = definition.get(
		"footprint",
		Vector2i.ONE
	)
	var parts: Array[String] = [
		String(definition.get("category", "Building")).to_upper(),
		"%dx%d TILES" % [footprint.x, footprint.y]
	]
	var size_label := _size_label(definition)
	if not size_label.is_empty():
		parts.append(size_label)

	var service_label := _service_label(definition)
	if not service_label.is_empty():
		parts.append(service_label)

	var availability_text := ""
	match String(state["status"]):
		"locked":
			availability_text = "Unlocks at airport Lv %d" % int(
				state["required_level"]
			)
		"shortfall":
			availability_text = "Need 🪙 %s more" % _format_number(
				int(state["coin_shortfall"])
			)
		_:
			availability_text = "Ready to place"

	return "%s\n%s  •  %s" % [
		"  •  ".join(parts),
		availability_text,
		String(definition.get("description", ""))
	]


static func visible_summary(
	definitions: Array[Dictionary],
	category: String,
	player_level: int,
	player_coins: int
) -> Dictionary:
	var visible := 0
	var ready := 0
	var locked := 0
	var shortfall := 0

	for definition in definitions:
		if (
			category != "ALL"
			and String(definition.get("category", "")) != category
		):
			continue

		visible += 1
		var state := availability(
			definition,
			player_level,
			player_coins
		)
		match String(state["status"]):
			"locked":
				locked += 1
			"shortfall":
				shortfall += 1
			_:
				ready += 1

	return {
		"visible": visible,
		"ready": ready,
		"locked": locked,
		"shortfall": shortfall
	}


static func _size_label(definition: Dictionary) -> String:
	var raw = definition.get("sizes", PackedStringArray())
	if not (raw is PackedStringArray):
		return ""
	var sizes: PackedStringArray = raw
	if sizes.is_empty():
		return ""
	return "/".join(Array(sizes))


static func _service_label(definition: Dictionary) -> String:
	var service_type := String(definition.get("service", ""))
	if service_type.is_empty():
		var services: Dictionary = definition.get("services", {})
		if services.is_empty():
			return ""
		var labels: Array[String] = []
		for key in services.keys():
			labels.append(_service_short_name(String(key)))
		labels.sort()
		return "/".join(labels)

	return _service_short_name(service_type)


static func _service_short_name(service_type: String) -> String:
	match service_type:
		"passenger":
			return "PAX"
		"cargo":
			return "BAG"
		"cleaning":
			return "CLEAN"
		"catering":
			return "CATER"
		"pushback":
			return "TOW"
		"fuel":
			return "FUEL"
		_:
			return service_type.to_upper()


static func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1
	return result
