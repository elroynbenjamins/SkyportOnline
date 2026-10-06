extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var north := grid.get_parcel("north")
	if String(north.get("name", "")) != "Service Apron":
		_fail("North starter parcel should retain the Service Apron identity.")
		return
	if int(north.get("level", 0)) != 5 or int(north.get("cost", 0)) != 25000:
		_fail("Service Apron metadata should preserve the Lv5 / 25,000 expansion value.")
		return
	if not bool(north.get("owned", false)):
		_fail("Service Apron is now granted as part of the 16x16 starter airfield.")
		return
	var north_visual := grid.get_parcel_visual_state("north")
	if bool(north_visual.get("show_boundary", true)):
		_fail("Starter-owned Service Apron should not show a sale boundary.")
		return

	var future_runway := grid.get_parcel("south_east")
	var future_visual := grid.get_parcel_visual_state("south_east")
	if String(future_runway.get("progression_state", "")) != "future":
		_fail("Regional Runway Reserve should begin disconnected.")
		return
	if not bool(future_visual.get("show_lock_marker", false)):
		_fail("Disconnected runway reserve should render a lock marker.")
		return
	if String(future_visual.get("zone_name", "")) != "Regional Runway Reserve":
		_fail("Visual state should expose the runway-reserve identity.")
		return

	var future_snapshot := future_runway.duplicate(true)

	var east := grid.get_parcel("east")
	if String(east.get("name", "")) != "Regional Apron":
		_fail("East expansion should be the Regional Apron.")
		return
	if int(east.get("level", 0)) != 8:
		_fail("Regional Apron should open at airport Lv8.")
		return
	var east_unlocks: Array = east.get("unlock_names", [])
	if not east_unlocks.has("Medium Aircraft Stand"):
		_fail("Regional Apron should advertise the Medium Aircraft Stand.")
		return
	if not east_unlocks.has("Regional Fuel Depot"):
		_fail("Regional Apron should advertise regional fuel support.")
		return

	if not grid.purchase_parcel("east"):
		_fail("Connected Regional Apron should be purchasable.")
		return

	var runway_reserve := grid.get_parcel("south_east")
	if String(runway_reserve.get("progression_state", "")) != "available":
		_fail("Buying Regional Apron should connect the Regional Runway Reserve.")
		return
	if int(runway_reserve.get("level", 0)) != 12:
		_fail("Regional Runway Reserve should align with the Lv12 regional runway.")
		return
	if int(runway_reserve.get("cost", 0)) != 150000:
		_fail("Regional Runway Reserve should use the intended midgame land cost.")
		return
	var runway_unlocks: Array = runway_reserve.get("unlock_names", [])
	if not runway_unlocks.has("Regional Runway"):
		_fail("Runway Reserve should explicitly advertise the Regional Runway.")
		return

	var runway_visual := grid.get_parcel_visual_state("south_east")
	if not bool(runway_visual.get("show_construction_marker", false)):
		_fail("Connected runway reserve should show purchasable construction visuals.")
		return

	if not grid.purchase_parcel("south_east"):
		_fail("Connected Runway Reserve should be purchasable.")
		return
	if not grid.is_parcel_unlock_animation_active("south_east"):
		_fail("District purchase should trigger the world unlock effect.")
		return

	runway_visual = grid.get_parcel_visual_state("south_east")
	if bool(runway_visual.get("show_boundary", true)):
		_fail("Purchased district should remove its expansion perimeter.")
		return
	var label: Label = grid.parcel_labels.get("south_east")
	if label == null or label.visible:
		_fail("Purchased non-starter districts should hide the large sale label.")
		return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame

	hud.show_parcel(east, 8, 50000)
	if hud.parcel_title.text != "REGIONAL APRON":
		_fail("Expansion HUD should use the district name, not a generic title.")
		return
	if not hud.parcel_requirements.text.contains("MEDIUM AIRCRAFT"):
		_fail("Expansion HUD should show the district role.")
		return
	if not hud.parcel_requirements.text.contains("Medium Aircraft Stand"):
		_fail("Expansion HUD should preview suitable/unlocked infrastructure.")
		return

	hud.show_parcel(future_snapshot, 30, 2000000)
	if hud.parcel_title.text != "REGIONAL RUNWAY RESERVE":
		_fail("Future expansion HUD should retain the district identity.")
		return
	if not hud.parcel_requirements.text.contains("Connect adjacent airport land"):
		_fail("Future district should explain its connection requirement.")
		return
	if not hud.purchase_button.disabled:
		_fail("Disconnected future district must remain unpurchasable.")
		return

	hud.show_airport_expanded(
		"Regional Runway Reserve",
		64,
		"Creates the first clean two-runway expansion path."
	)
	if not hud.expansion_banner_detail.text.contains("two-runway"):
		_fail("Expansion celebration should communicate the new capability.")
		return

	print(
		"Airport expansion districts passed: starter 16x16 land, regional "
		+ "runway path, world visual states and district HUD."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
