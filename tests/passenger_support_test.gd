extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	if PassengerSupportRules.REWARDED_AD_PASSENGERS != 25:
		_fail("Rewarded passenger ad should grant 25 passengers.")
		return
	if PassengerSupportRules.DAILY_REWARDED_AD_CAP != 3:
		_fail("Rewarded passenger ads should be capped at 3 per day.")
		return
	if PassengerSupportRules.FRIEND_GIFT_PASSENGERS != 5:
		_fail("Friend passenger gifts should grant 5 passengers.")
		return
	if PassengerSupportRules.DAILY_INCOMING_FRIEND_GIFT_CAP != 10:
		_fail("Players should be able to receive 10 friend gifts per day.")
		return
	if PassengerSupportRules.max_daily_friend_passengers() != 50:
		_fail("Friend gifts should cap at 50 passengers per day.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Support Test",
		"SUP",
		"NL"
	)
	if profile.is_empty():
		_fail("Passenger support test profile should be created.")
		return

	var day := "2026-10-04"
	var ad_status := ProfileStore.get_passenger_ad_status(day)
	if int(ad_status.get("remaining", -1)) != 3:
		_fail("A fresh day should start with 3 rewarded passenger ads.")
		return

	for index in range(3):
		profile = ProfileStore.record_rewarded_passenger_ad(day)
		if profile.is_empty():
			_fail("Rewarded passenger ad %d should be accepted." % (index + 1))
			return

	ad_status = ProfileStore.get_passenger_ad_status(day)
	if bool(ad_status.get("can_claim", true)):
		_fail("A fourth rewarded passenger ad must be blocked.")
		return
	if int(ad_status.get("claimed", -1)) != 3:
		_fail("Rewarded passenger ad ledger should persist 3 claims.")
		return
	if not ProfileStore.record_rewarded_passenger_ad(day).is_empty():
		_fail("Rewarded passenger ad cap must reject the fourth claim.")
		return

	var gift_status := ProfileStore.get_passenger_gift_status(day)
	if int(gift_status.get("max_passengers", -1)) != 50:
		_fail("Gift status should expose the 50 passenger daily ceiling.")
		return

	for index in range(10):
		profile = ProfileStore.record_friend_passenger_gift(day)
		if profile.is_empty():
			_fail("Friend passenger gift %d should be accepted." % (index + 1))
			return

	gift_status = ProfileStore.get_passenger_gift_status(day)
	if bool(gift_status.get("can_receive", true)):
		_fail("An eleventh incoming friend gift must be blocked.")
		return
	if int(gift_status.get("passengers_received", -1)) != 50:
		_fail("Ten incoming gifts should represent 50 passengers.")
		return
	if not ProfileStore.record_friend_passenger_gift(day).is_empty():
		_fail("Friend gift cap must reject the eleventh gift.")
		return

	var next_day_status := ProfileStore.get_passenger_ad_status("2026-10-05")
	if int(next_day_status.get("claimed", -1)) != 0:
		_fail("Rewarded passenger ad allowance should reset on a new day.")
		return
	var next_day_gifts := ProfileStore.get_passenger_gift_status("2026-10-05")
	if int(next_day_gifts.get("received", -1)) != 0:
		_fail("Friend gift allowance should reset on a new day.")
		return

	_cleanup_profile()
	print(
		"Passenger support passed: +25 ads (3/day) and +5 friend gifts "
		+ "(10/day, 50 passengers) persist and reset correctly."
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
