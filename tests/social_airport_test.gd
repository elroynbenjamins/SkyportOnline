extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var profile := ProfileStore.create_guest_airport(
		"Social Test",
		"SOC",
		"NL"
	)
	if profile.is_empty():
		_fail("Social test profile should be created.")
		return

	var service := SocialAirportService.new()
	root.add_child(service)
	service.configure(true)

	var snapshot := service.get_snapshot()
	var contacts: Array = snapshot.get("contacts", [])
	if contacts.size() != 6:
		_fail("Local social network should expose six test contacts.")
		return
	if not bool(snapshot.get("local_simulation", false)):
		_fail("Development contacts should be clearly marked as local simulation.")
		return
	if bool(snapshot.get("provider_connected", true)):
		_fail("Online provider should remain disconnected until a real backend is attached.")
		return

	var first: Dictionary = contacts[0]
	var first_id := String(first.get("id", ""))
	if not service.send_passenger_gift(first_id, "2026-10-05"):
		_fail("First passenger gift to a contact should succeed.")
		return
	if service.send_passenger_gift(first_id, "2026-10-05"):
		_fail("Only one outgoing passenger gift per contact/day should be allowed.")
		return

	var social_state := ProfileStore.get_social_state()
	var action_outbox: Array = social_state.get(
		"social_action_outbox",
		[]
	)
	if action_outbox.size() != 1:
		_fail("Outgoing passenger gift should be queued for future backend sync.")
		return
	if String(
		(action_outbox[0] as Dictionary).get("action", "")
	) != "passenger_gift":
		_fail("Social action outbox should identify passenger-gift actions.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	var economy := PassengerEconomy.new()
	root.add_child(economy)
	economy.configure(grid, 0.0)

	for index in range(3):
		var contact: Dictionary = contacts[index]
		var added := service.receive_passenger_gift(
			String(contact.get("id", "")),
			economy,
			"2026-10-05"
		)
		if added != 10:
			_fail("Each accepted incoming social gift should add +10 passengers.")
			return

	if economy.get_passengers() != 30:
		_fail("Three accepted friend gifts should add 30 passengers total.")
		return
	if service.receive_passenger_gift(
		String(contacts[3].get("id", "")),
		economy,
		"2026-10-05"
	) != 0:
		_fail("Fourth incoming passenger gift on one day should be blocked.")
		return

	var gift_status := ProfileStore.get_passenger_gift_status(
		"2026-10-05"
	)
	if int(gift_status.get("received", 0)) != 3:
		_fail("Incoming passenger gift ledger should remain capped at three.")
		return

	var request_a := service.request_visit(
		String(contacts[0].get("id", ""))
	)
	var request_b := service.request_visit(
		String(contacts[1].get("id", ""))
	)
	var request_c := service.request_visit(
		String(contacts[2].get("id", ""))
	)
	if request_a.is_empty() or request_b.is_empty() or request_c.is_empty():
		_fail("Three distinct social visits should fit the active visit cap.")
		return
	if not service.request_visit(
		String(contacts[0].get("id", ""))
	).is_empty():
		_fail("Same contact should not have two concurrent visiting flights.")
		return
	if not service.request_visit(
		String(contacts[3].get("id", ""))
	).is_empty():
		_fail("Fourth concurrent visitor should be blocked.")
		return

	var aircraft_profile := AircraftCatalog.get_profile(
		String(request_a.get("aircraft_type_id", ""))
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 123456
	var host_reward := SocialFlightRules.create_host_reward(
		aircraft_profile,
		request_a,
		rng
	)
	if int(host_reward.get("coins", 0)) <= 0:
		_fail("Servicing a friend flight should award host coins.")
		return
	if int(host_reward.get("xp", 0)) <= 0:
		_fail("Servicing a friend flight should award host XP.")
		return
	if absf(
		float(host_reward.get("resource_chance", 0.0)) - 0.40
	) > 0.001:
		_fail("Visitor-country resource chance should be 40% per resource.")
		return
	var rolls: Array = host_reward.get("resource_rolls", [])
	if rolls.size() != 3:
		_fail("Visitor-country reward should roll all three country resources.")
		return
	for roll_variant in rolls:
		var roll: Dictionary = roll_variant
		if absf(float(roll.get("chance", 0.0)) - 0.40) > 0.001:
			_fail("Every visitor resource roll should use the 40% social chance.")
			return

	var owner_reward := SocialFlightRules.create_owner_reward(
		aircraft_profile,
		request_a
	)
	if int(owner_reward.get("coins", 0)) <= 0:
		_fail("Visiting aircraft owner should receive a positive remote reward receipt.")
		return

	ProfileStore.record_social_service(
		String(request_a.get("contact_id", "")),
		String(request_a.get("relationship", "friend")),
		String(request_a.get("country_id", "")),
		int(host_reward.get("coins", 0)),
		int(host_reward.get("xp", 0)),
		(host_reward.get("resources_won", []) as Array).size()
	)
	ProfileStore.enqueue_social_reward_receipt(
		String(request_a.get("contact_id", "")),
		owner_reward,
		String(request_a.get("visit_id", ""))
	)
	service.complete_visit(
		String(request_a.get("visit_id", "")),
		host_reward,
		owner_reward
	)

	snapshot = service.get_snapshot()
	if (snapshot.get("active_visits", []) as Array).size() != 2:
		_fail("Completing one social visit should free one active slot.")
		return
	if (snapshot.get("recent_completed", []) as Array).size() != 1:
		_fail("Completed visitor should appear in recent social history.")
		return

	social_state = ProfileStore.get_social_state()
	if int(social_state.get("visits_serviced_total", 0)) != 1:
		_fail("Social service history should persist by account.")
		return
	if (social_state.get("reward_receipt_outbox", []) as Array).size() != 1:
		_fail("Remote owner reward should be queued for backend delivery.")
		return

	var screen := SocialAirportScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_screen(snapshot)
	if not screen.is_open():
		_fail("Social Airport screen should open from a service snapshot.")
		return
	if screen.contacts_list.get_child_count() != 6:
		_fail("Social screen should render all available contacts.")
		return
	if not screen.network_label.text.contains("LOCAL TEST NETWORK"):
		_fail("Prototype contacts must not masquerade as live online players.")
		return

	_cleanup_profile()
	print(
		"Social airport passed: contact network, daily passenger gifts, "
		+ "visit caps, 40% country imports, dual rewards and backend outboxes."
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
