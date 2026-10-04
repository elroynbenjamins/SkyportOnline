extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var profile := ProfileStore.create_guest_airport(
		"Cosmetic Test",
		"COS",
		"NL"
	)
	if profile.is_empty():
		_fail("Cosmetic test profile should be created.")
		return

	for event in EventCatalog.all():
		for item_variant in event.get("shop", []):
			var item: Dictionary = item_variant
			if String(item.get("type", "")) != "cosmetic":
				continue
			var cosmetic_id := String(item.get("cosmetic_id", ""))
			if CosmeticCatalog.get_cosmetic(cosmetic_id).is_empty():
				_fail(
					"Event shop cosmetic is missing CosmeticCatalog data: %s"
					% cosmetic_id
				)
				return

		var alliance: Dictionary = event.get("alliance", {})
		for milestone_variant in alliance.get("milestones", []):
			var milestone: Dictionary = milestone_variant
			if String(milestone.get("reward_type", "")) != "cosmetic":
				continue
			var cosmetic_id := String(
				milestone.get("cosmetic_id", "")
			)
			if CosmeticCatalog.get_cosmetic(cosmetic_id).is_empty():
				_fail(
					"Alliance cosmetic is missing CosmeticCatalog data: %s"
					% cosmetic_id
				)
				return

	var blocked := ProfileStore.equip_cosmetic(
		CosmeticCatalog.SLOT_AIRPORT_BORDER,
		"event_autumn_airport_border"
	)
	if not blocked.is_empty():
		_fail("Unowned cosmetics must not be equipable.")
		return

	profile = ProfileStore.add_owned_cosmetic(
		"event_autumn_airport_border"
	)
	profile = ProfileStore.add_owned_cosmetic(
		"event_autumn_terminal_skin"
	)
	profile = ProfileStore.add_owned_cosmetic(
		"event_autumn_pico_livery"
	)
	profile = ProfileStore.add_owned_cosmetic(
		"event_autumn_alliance_flag"
	)
	profile = ProfileStore.add_owned_cosmetic(
		"event_autumn_alliance_emblem"
	)
	if profile.is_empty():
		_fail("Owned event cosmetics should persist.")
		return

	var equipped_profile := ProfileStore.equip_cosmetic(
		CosmeticCatalog.SLOT_AIRPORT_BORDER,
		"event_autumn_airport_border"
	)
	if equipped_profile.is_empty():
		_fail("Owned border cosmetic should equip.")
		return

	var equipped: Dictionary = equipped_profile.get(
		"equipped_cosmetics",
		{}
	)
	if String(
		equipped.get(CosmeticCatalog.SLOT_AIRPORT_BORDER, "")
	) != "event_autumn_airport_border":
		_fail("Equipped border should persist in profile.")
		return

	var wrong_slot := ProfileStore.equip_cosmetic(
		CosmeticCatalog.SLOT_AIRPORT_BORDER,
		"event_autumn_pico_livery"
	)
	if not wrong_slot.is_empty():
		_fail("Cosmetics must not equip into the wrong slot.")
		return

	equipped_profile = ProfileStore.equip_cosmetic(
		CosmeticCatalog.SLOT_AIRCRAFT_LIVERY,
		"event_autumn_pico_livery"
	)
	if equipped_profile.is_empty():
		_fail("Owned Pico livery should equip.")
		return

	if not CosmeticCatalog.is_compatible_with_aircraft(
		"event_autumn_pico_livery",
		"pico_p8"
	):
		_fail("Autumn Pico livery should apply to Pico P8.")
		return
	if CosmeticCatalog.is_compatible_with_aircraft(
		"event_autumn_pico_livery",
		"swift_s14"
	):
		_fail("Pico-specific livery must not apply to Swift S14.")
		return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")
	plane.set_livery_cosmetic("event_autumn_pico_livery")
	if plane.get_livery_cosmetic() != "event_autumn_pico_livery":
		_fail("Aircraft should retain equipped livery ID.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.set_cosmetic_loadout(
		equipped_profile.get("equipped_cosmetics", {})
	)

	var unequipped := ProfileStore.equip_cosmetic(
		CosmeticCatalog.SLOT_AIRPORT_BORDER,
		""
	)
	if unequipped.is_empty():
		_fail("Player should be able to restore default slot style.")
		return
	if (
		unequipped.get("equipped_cosmetics", {}) as Dictionary
	).has(CosmeticCatalog.SLOT_AIRPORT_BORDER):
		_fail("Unequipping should remove the slot from persisted loadout.")
		return

	var reloaded := ProfileStore.load_profile()
	if String(
		(
			reloaded.get("equipped_cosmetics", {}) as Dictionary
		).get(CosmeticCatalog.SLOT_AIRCRAFT_LIVERY, "")
	) != "event_autumn_pico_livery":
		_fail("Equipped livery should survive profile reload.")
		return

	_cleanup_profile()
	print(
		"Cosmetic loadouts passed: event IDs mapped, ownership enforced, "
		+ "slots persisted, Pico livery compatibility works."
	)
	quit(0)


func _cleanup_profile() -> void:
	var path := ProjectSettings.globalize_path(ProfileStore.SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_cleanup_profile()
	push_error(message)
	quit(1)
