class_name AirsideRoutingRules
extends RefCounted

const TURN_PENALTY := 0.35
const UTURN_PENALTY := 1.25

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]


static func find_smooth_path(
	available: Dictionary,
	start: Vector2i,
	goals: Dictionary
) -> Array[Vector2i]:
	if not available.has(_cell_key(start)) or goals.is_empty():
		return []

	var frontier: Array[Dictionary] = [{
		"cell": start,
		"direction": -1,
		"cost": 0.0,
		"turns": 0,
	}]
	var best: Dictionary = {}
	var parent: Dictionary = {}
	var start_key := _state_key(start, -1)
	best[start_key] = 0.0
	parent[start_key] = ""

	var winning_key := ""
	while not frontier.is_empty():
		var best_index := _lowest_frontier_index(frontier)
		var state: Dictionary = frontier[best_index]
		frontier.remove_at(best_index)

		var cell: Vector2i = state["cell"]
		var incoming := int(state["direction"])
		var state_key := _state_key(cell, incoming)
		var cost := float(state["cost"])
		if cost > float(best.get(state_key, INF)) + 0.0001:
			continue

		if goals.has(_cell_key(cell)):
			winning_key = state_key
			break

		for direction_index in range(DIRECTIONS.size()):
			var neighbor := cell + DIRECTIONS[direction_index]
			if not available.has(_cell_key(neighbor)):
				continue

			var extra := 1.0
			var turns := int(state.get("turns", 0))
			if incoming >= 0 and incoming != direction_index:
				extra += TURN_PENALTY
				turns += 1
				if (incoming + 2) % 4 == direction_index:
					extra += UTURN_PENALTY

			var next_cost := cost + extra
			var next_key := _state_key(neighbor, direction_index)
			if next_cost >= float(best.get(next_key, INF)) - 0.0001:
				continue

			best[next_key] = next_cost
			parent[next_key] = state_key
			frontier.append({
				"cell": neighbor,
				"direction": direction_index,
				"cost": next_cost,
				"turns": turns,
			})

	if winning_key.is_empty():
		return []

	var reversed: Array[Vector2i] = []
	var cursor := winning_key
	while not cursor.is_empty():
		reversed.append(_cell_from_state_key(cursor))
		cursor = String(parent.get(cursor, ""))
	reversed.reverse()
	return reversed


static func turn_count(path: Array[Vector2i]) -> int:
	var result := 0
	if path.size() < 3:
		return result
	for index in range(1, path.size() - 1):
		var incoming := path[index] - path[index - 1]
		var outgoing := path[index + 1] - path[index]
		if incoming != outgoing:
			result += 1
	return result


static func connection_mask(
	cell: Vector2i,
	available: Dictionary
) -> int:
	var mask := 0
	if available.has(_cell_key(cell + Vector2i(0, -1))):
		mask |= AirsideGroundArt.NORTH
	if available.has(_cell_key(cell + Vector2i(1, 0))):
		mask |= AirsideGroundArt.EAST
	if available.has(_cell_key(cell + Vector2i(0, 1))):
		mask |= AirsideGroundArt.SOUTH
	if available.has(_cell_key(cell + Vector2i(-1, 0))):
		mask |= AirsideGroundArt.WEST
	return mask


static func _lowest_frontier_index(frontier: Array[Dictionary]) -> int:
	var selected := 0
	for index in range(1, frontier.size()):
		var candidate: Dictionary = frontier[index]
		var current: Dictionary = frontier[selected]
		var candidate_cost := float(candidate.get("cost", INF))
		var current_cost := float(current.get("cost", INF))
		if candidate_cost < current_cost - 0.0001:
			selected = index
		elif absf(candidate_cost - current_cost) <= 0.0001:
			if int(candidate.get("turns", 999)) < int(current.get("turns", 999)):
				selected = index
	return selected


static func _state_key(cell: Vector2i, direction: int) -> String:
	return "%d,%d|%d" % [cell.x, cell.y, direction]


static func _cell_from_state_key(key: String) -> Vector2i:
	var cell_text := key.get_slice("|", 0)
	return Vector2i(
		int(cell_text.get_slice(",", 0)),
		int(cell_text.get_slice(",", 1))
	)


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
