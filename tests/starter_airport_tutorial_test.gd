extends SceneTree

const TutorialScript := preload(
	"res://src/progression/StarterAirportTutorial.gd"
)

var rewards: Array[int] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := AirportProgressionRules.new_state(
		"tutorial-test"
	)
	if int(state.get("coins", 0)) != 20000:
		_fail("New airports should start with 20,000 coins.")
		return

	var expected_costs := {
		"short_runway": 7500,
		"small_stand": 3000,
		"taxiway": 125,
		"service_road": 75
	}
	for id_variant in expected_costs.keys():
		var id := String(id_variant)
		var definition := BuildingCatalog.get_definition(id)
		if int(definition.get("cost", -1)) != int(
			expected_costs[id_variant]
		):
			_fail(
				"%s should cost %d coins during onboarding."
				% [id, int(expected_costs[id_variant])]
			)
			return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	var tutorial = TutorialScript.new()
	root.add_child(tutorial)
	tutorial.coin_reward_earned.connect(
		_on_reward
	)
	tutorial.configure(grid, true)

	if String(
		tutorial.get_snapshot().get("id", "")
	) != "runway":
		_fail("Tutorial should start by asking for a runway.")
		return

	if not _place(grid, "short_runway", Vector2i(0, 0)):
		return
	tutorial.refresh()
	if String(
		tutorial.get_snapshot().get("id", "")
	) != "stand":
		_fail("Runway placement should advance to the stand step.")
		return

	if not _place(grid, "small_stand", Vector2i(4, 5)):
		return
	tutorial.refresh()
	if String(
		tutorial.get_snapshot().get("id", "")
	) != "taxi_network":
		_fail("Stand placement should advance to taxiway guidance.")
		return

	for y in range(2, 8):
		if not _place(grid, "taxiway", Vector2i(3, y)):
			return
	tutorial.refresh()
	if String(
		tutorial.get_snapshot().get("id", "")
	) != "service_road":
		_fail(
			"Connected hangar/stand/runway should advance to service roads."
		)
		return

	for cell in [
		Vector2i(7, 7),
		Vector2i(7, 6),
		Vector2i(6, 6)
	]:
		if not _place(grid, "service_road", cell):
			return
	tutorial.refresh()
	if String(
		tutorial.get_snapshot().get("id", "")
	) != "hangar_taxi":
		_fail("Service-road connection should start the plane tutorial.")
		return

	var construction_rewards := 0
	for reward in rewards:
		construction_rewards += reward
	if construction_rewards != 5000:
		_fail(
			"Construction tutorial should refund 5,000 coins, got %d."
			% construction_rewards
		)
		return

	var construction_cost := (
		7500
		+ 3000
		+ 6 * 125
		+ 3 * 75
	)
	var remaining := (
		20000
		- construction_cost
		+ construction_rewards
	)
	if remaining < 13000:
		_fail(
			"Onboarding should leave a healthy cash buffer, got %d."
			% remaining
		)
		return

	var event_steps := [
		["hangar_taxi_complete", "service"],
		["service_started", "destination"],
		["destination_selected", "load"],
		["load_started", "send"],
		["send_started", "takeoff"]
	]
	for row_variant in event_steps:
		var row: Array = row_variant
		tutorial.notify_event(String(row[0]))
		if String(
			tutorial.get_snapshot().get("id", "")
		) != String(row[1]):
			_fail(
				"%s should advance tutorial to %s."
				% [String(row[0]), String(row[1])]
			)
			return

	tutorial.notify_event("first_departure")
	var done := tutorial.get_snapshot()
	if not bool(done.get("complete", false)):
		_fail("First takeoff should complete the starter tutorial.")
		return

	var total_rewards := 0
	for reward in rewards:
		total_rewards += reward
	if total_rewards != 8750:
		_fail(
			"Full starter tutorial should award 8,750 coins, got %d."
			% total_rewards
		)
		return

	print(
		"STARTER_AIRPORT_TUTORIAL_OK start_coins=20000 "
		+ "runway=7500 stand=3000 taxiway=125 road=75 "
		+ "tutorial_rewards=8750"
	)
	quit(0)


func _on_reward(
	amount: int,
	_reason: String
) -> void:
	rewards.append(amount)


func _place(
	grid: AirportGrid,
	building_id: String,
	cell: Vector2i
) -> bool:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(
			Vector2(cell.x, cell.y)
		),
		0
	)
	if not bool(preview.get("valid", false)):
		_fail(
			"Could not place %s at %s: %s"
			% [
				building_id,
				str(cell),
				String(preview.get("reason", "invalid"))
			]
		)
		return false
	if grid.confirm_build_preview().is_empty():
		_fail(
			"Placement confirmation failed for %s."
			% building_id
		)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
