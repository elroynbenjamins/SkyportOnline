extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var north := grid.get_parcel("north")
	if String(north.get("name", "")) != "Service Apron":
		_fail("North expansion should be the named Service Apron district.")
		return
	if int(north.get("level", 0)) != 5 or int(north.get("cost", 0)) != 25000:
		_fail("Service Apron should preserve the Lv5 / 25,000 early expansion gate.")
		return
	if String(north.get("tag", "")) != "FIRST EXPANSION":
		_fail("Service Apron should expose its progression role.")
		return

	var north_visual := grid.get_parcel_visual_state("north")
	if not bool(north_visual.get("show_boundary", false)):
		_fail("Unowned connected land should render an expansion boundary.")
		return
	if not bool(north_visual.get("show_construction_marker", false)):
		_fail("Available land should render a construction/purchase marker.")
		return
	if bool(north_visual.get("show_lock_marker", true)):
		_fail("Connected purchasable land should not render as future-locked.")
		return

	var north_west := grid.get_parcel("north_west")
	var north_west_visual := grid.get_parcel_visual_state("north_west")
	if String(north_west.get("progression_state", "")) != "future":
		_fail("International Reserve should begin disconnected.")
		return
	if not bool(north_west_visual.get("show_lock_marker", false)):
		_fail("Disconnected future land should render a lock marker.")
		return
	if String(north_west_visual.get("zone_name", "")) != "International Reserve":
		_fail("Visual state should expose the district identity.")
		return

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
		_fail("Purchased non-home districts should hide the large sale label.")
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
	if hud.purchase_button.disabled:
		_fail("Eligible affordable Regional Apron should be purchasable in the HUD.")
		return

	hud.show_parcel(north_west, 30, 2000000)
	if hud.parcel_title.text != "INTERNATIONAL RESERVE":
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
		"Airport expansion districts passed: named progression, regional runway "
		+ "path, world visual states, district HUD and milestone celebration."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
