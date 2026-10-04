extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if StandVisualRules.canonical_state("WAITING_FUEL") != "TURNAROUND":
		_fail("WAITING_FUEL should use the turnaround stand visual.")
		return
	if StandVisualRules.canonical_state("UNLOADING") != "TURNAROUND":
		_fail("UNLOADING should use the turnaround stand visual.")
		return
	if StandVisualRules.canonical_state("APPROACH") != "INBOUND_RESERVED":
		_fail("Approach should keep the inbound-reserved stand visual.")
		return
	if StandVisualRules.canonical_state("TAXIING_OUT") != "IDLE":
		_fail("Taxi-out should no longer read as an occupied stand.")
		return
	if not StandVisualRules.should_draw_entry_chevron(
		"INBOUND_RESERVED"
	):
		_fail("Inbound-reserved stands should draw an entry chevron.")
		return
	if not StandVisualRules.should_draw_departure_chevron(
		"READY_FOR_DEPARTURE"
	):
		_fail("Ready departure stands should draw a departure chevron.")
		return
	if StandVisualRules.is_occupied("IDLE"):
		_fail("Idle stand visual must not count as occupied.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var routes := grid.get_departure_routes("S")
	if routes.is_empty():
		_fail("Starter airport should expose at least one Small stand.")
		return

	var stand_uid := int(routes[0].get("stand_uid", -1))
	if stand_uid < 0:
		_fail("Starter route should expose a stand UID.")
		return

	var before := grid.get_airside_status()
	var initial := grid.get_stand_visual_state(stand_uid)
	if String(initial.get("canonical_state", "")) != "IDLE":
		_fail("Unassigned stand should default to IDLE visual state.")
		return
	if bool(initial.get("occupied", true)):
		_fail("Unassigned stand should report visual occupied=false.")
		return

	if not grid.set_stand_visual_state(
		stand_uid,
		"INBOUND_RESERVED",
		"S"
	):
		_fail("Valid stand should accept inbound visual reservation.")
		return

	var inbound := grid.get_stand_visual_state(stand_uid)
	if String(inbound.get("canonical_state", "")) != "INBOUND_RESERVED":
		_fail("Inbound reservation should persist on the stand.")
		return
	if not bool(inbound.get("occupied", false)):
		_fail("Inbound-reserved stand should visually count as occupied.")
		return

	if not grid.set_stand_visual_state(
		stand_uid,
		"UNLOADING",
		"S"
	):
		_fail("Valid stand should accept service visual state.")
		return
	var service := grid.get_stand_visual_state(stand_uid)
	if String(service.get("canonical_state", "")) != "TURNAROUND":
		_fail("Unloading visual should canonicalize to TURNAROUND.")
		return

	if not grid.set_stand_visual_state(
		stand_uid,
		"WAITING_PASSENGERS",
		"S"
	):
		_fail("Valid stand should accept passenger-wait visual state.")
		return
	var pax := grid.get_stand_visual_state(stand_uid)
	if String(pax.get("canonical_state", "")) != "WAITING_PASSENGERS":
		_fail("Passenger-wait visual state should be preserved.")
		return

	if not grid.set_stand_visual_state(
		stand_uid,
		"READY_FOR_DEPARTURE",
		"S"
	):
		_fail("Valid stand should accept ready-departure visual state.")
		return
	var ready := grid.get_stand_visual_state(stand_uid)
	if String(ready.get("canonical_state", "")) != "READY_FOR_DEPARTURE":
		_fail("Ready-departure visual state should be preserved.")
		return

	grid.clear_stand_visual_state(stand_uid)
	var cleared := grid.get_stand_visual_state(stand_uid)
	if String(cleared.get("canonical_state", "")) != "IDLE":
		_fail("Cleared stand should return to IDLE visual state.")
		return

	var runway_uid := int(routes[0].get("runway_uid", -1))
	if runway_uid >= 0 and grid.set_stand_visual_state(
		runway_uid,
		"SERVICING",
		"S"
	):
		_fail("Runway UID must never accept stand visual state.")
		return

	var after := grid.get_airside_status()
	for key in [
		"runways",
		"taxiways",
		"stands_total",
		"stands_connected",
		"hangars_total",
		"hangars_connected"
	]:
		if int(before.get(key, -1)) != int(after.get(key, -2)):
			_fail(
				"Stand visual state must not change airside stat %s."
				% String(key)
			)
			return

	print(
		"Stand activity visuals passed: idle, inbound, turnaround, "
		+ "passenger and departure cues remain visual-only."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
