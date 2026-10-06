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

	# Preserve the original shortest-cell behavior first. Among routes with
	# the same number of cells, prefer fewer turns and avoid U-turns.
	var frontier: Array[Dictionary] = [{
		"cell": start,
		"direction": -1,
		"steps": 0,
		"turns": 0,
	}]
	var parent: Dictionary = {}
	var best: Dictionary = {}
	var start_key := _state_key(start, -1)
	parent[start_key] = ""
	best[start_key] = {"steps": 0, "turns": 0}

	var cursor := 0
	var winning_key := ""
	var best_goal_steps := 1 << 30
	var best_goal_turns := 1 << 30

	while cursor < frontier.size():
		var state: Dictionary = frontier[cursor]
		cursor += 1

		var cell: Vector2i = state["cell"]
		var incoming := int(state["direction"])
		var steps := int(state["steps"])
		var turns := int(state["turns"])
		var state_key := _state_key(cell, incoming)

		if steps > best_goal_steps:
			continue

		if goals.has(_cell_key(cell)):
			if (
				steps < best_goal_steps
				or (
					steps == best_goal_steps
					and turns < best_goal_turns
				)
			):
				best_goal_steps = steps
				best_goal_turns = turns
				winning_key = state_key
			continue

		for direction_index in range(DIRECTIONS.size()):
			var neighbor := cell + DIRECTIONS[direction_index]
			if not available.has(_cell_key(neighbor)):
				continue

			var next_steps := steps + 1
			if next_steps > best_goal_steps:
				continue

			var next_turns := turns
			if incoming >= 0 and incoming != direction_index:
				next_turns += 1
				if (incoming + 2) % 4 == direction_index:
					# Strongly disfavor reversing direction when an equal-length
					# non-U-turn path exists.
					next_turns += 2

			var next_key := _state_key(neighbor, direction_index)
			var previous: Dictionary = best.get(next_key, {})
			if not previous.is_empty():
				var previous_steps := int(previous.get("steps", 1 << 30))
				var previous_turns := int(previous.get("turns", 1 << 30))
				if (
					next_steps > previous_steps
					or (
						next_steps == previous_steps
						and next_turns >= previous_turns
					)
				):
					continue

			best[next_key] = {
				"steps": next_steps,
				"turns": next_turns,
			}
			parent[next_key] = state_key
			frontier.append({
				"cell": neighbor,
				"direction": direction_index,
				"steps": next_steps,
				"turns": next_turns,
			})

	if winning_key.is_empty():
		return []

	var reversed: Array[Vector2i] = []
	var route_cursor := winning_key
	while not route_cursor.is_empty():
		reversed.append(_cell_from_state_key(route_cursor))
		route_cursor = String(parent.get(route_cursor, ""))
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
