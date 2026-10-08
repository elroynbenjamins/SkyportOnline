extends SceneTree

const TutorialScript := preload(
	"res://src/progression/StarterAirportTutorial.gd"
)

var rewards: Array[int] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := AirportProgressionRules.new_state("tutorial-test")
	if int(state.get("coins", 0)) != 20000:
		_fail("New airports should start with 20,000 coins.")
		return

	var expected_costs := {
		"short_runway": 7500,
		"small_hangar": 12000,
		"small_stand": 3000,
		"basic_fuel": 7500,
		"ground_ops_depot": 5500,
		"small_terminal": 8000,
		"taxiway": 125,
		"service_road": 75
	}
	for id_variant in expected_costs.keys():
		var id := String(id_variant)
		var definition := BuildingCatalog.get_definition(id)
		if int(definition.get("cost", -1)) != int(expected_costs[id_variant]):
			_fail("%s should keep its normal post-tutorial price." % id)
			return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	var layout := grid.export_airport_layout()
	if layout.size() != 1:
		_fail("New airport should begin with exactly one fixed building.")
		return
	var initial: Dictionary = layout[0]
	if String(initial.get("definition_id", "")) != "airport_office":
		_fail("Main Airport Building should be the only initial building.")
		return

	var tutorial = TutorialScript.new()
	root.add_child(tutorial)
	tutorial.coin_reward_earned.connect(_on_reward)
	tutorial.configure(grid, true)

	if not _expect_step(tutorial, "runway", "short_runway"):
		return
	if not _place(grid, "short_runway", Vector2i(0, 0)):
		return
	tutorial.refresh()

	if not _expect_step(tutorial, "stand", "small_stand"):
		return
	if not _place(grid, "small_stand", Vector2i(4, 6)):
		return
	tutorial.refresh()

	if not _expect_step(tutorial, "runway_taxi", "taxiway"):
		return
	for y in range(2, 6):
		if not _place(grid, "taxiway", Vector2i(4, y)):
			return
	tutorial.refresh()

	if not _expect_step(tutorial, "hangar", "small_hangar"):
		return
	if not _place(grid, "small_hangar", Vector2i(0, 10)):
		return
	tutorial.refresh()

	if not _expect_step(tutorial, "hangar_taxi_network", "taxiway"):
		return
	for y in range(5, 11):
		if not _place(grid, "taxiway", Vector2i(3, y)):
			return
	tutorial.refresh()

	if not _expect_step(tutorial, "fuel_station", "basic_fuel"):
		return
	if not _place(grid, "basic_fuel", Vector2i(8, 5)):
		return
	tutorial.refresh()

	if not _expect_step(tutorial, "ground_ops", "ground_ops_depot"):
		return
	if not _place(grid, "ground_ops_depot", Vector2i(5, 10)):
		return
	tutorial.refresh()

	if not _expect_step(tutorial, "service_road", "service_road"):
		return
	for cell in [
		# Fuel approach from the right side of the stand.
		Vector2i(7, 6),
		Vector2i(6, 6),
		# Ground Ops approach from below the stand.
		Vector2i(5, 9)
	]:
		if not _place(grid, "service_road", cell):
			return
	tutorial.refresh()

	if not _expect_step(tutorial, "terminal", "small_terminal"):
		return
	if not _place(grid, "small_terminal", Vector2i(9, 11)):
		return
	tutorial.refresh()

	if String(tutorial.get_snapshot().get("id", "")) != "hangar_taxi":
		_fail("Finished construction should start the aircraft tutorial.")
		return
	if not rewards.is_empty():
		_fail("Free construction grants should not also refund coins.")
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
		if String(tutorial.get_snapshot().get("id", "")) != String(row[1]):
			_fail(
				"%s should advance tutorial to %s."
				% [String(row[0]), String(row[1])]
			)
			return

	tutorial.notify_event("first_departure")
	if not bool(tutorial.get_snapshot().get("complete", false)):
		_fail("First takeoff should complete the starter tutorial.")
		return

	var total_rewards := 0
	for reward in rewards:
		total_rewards += reward
	if total_rewards != 2250:
		_fail("Operational tutorial should award 2,250 coins, got %d." % total_rewards)
		return

	print(
		"STARTER_AIRPORT_TUTORIAL_OK initial=office_only "
		+ "construction=9_guided_steps rewards=2250"
	)
	quit(0)


func _expect_step(tutorial, step_id: String, target: String) -> bool:
	var snapshot: Dictionary = tutorial.get_snapshot()
	if String(snapshot.get("id", "")) != step_id:
		_fail("Expected tutorial step %s." % step_id)
		return false
	if String(snapshot.get("target", "")) != target:
		_fail("Step %s should target %s." % [step_id, target])
		return false
	if not bool(snapshot.get("tutorial_grant", false)):
		_fail("Construction step %s should be a free tutorial grant." % step_id)
		return false
	var recommended: Vector2i = snapshot.get(
		"recommended_origin",
		Vector2i(-1, -1)
	)
	if recommended.x < 0 or recommended.y < 0:
		_fail("Construction step %s should provide a recommended grid origin." % step_id)
		return false
	return true


func _on_reward(amount: int, _reason: String) -> void:
	rewards.append(amount)


func _place(grid: AirportGrid, building_id: String, cell: Vector2i) -> bool:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(Vector2(cell.x, cell.y)),
		0
	)
	if not bool(preview.get("valid", false)):
		_fail(
			"Could not place %s at %s: %s"
			% [building_id, str(cell), String(preview.get("reason", "invalid"))]
		)
		return false
	if grid.confirm_build_preview().is_empty():
		_fail("Placement confirmation failed for %s." % building_id)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
