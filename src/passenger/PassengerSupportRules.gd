class_name PassengerSupportRules
extends RefCounted

const REWARDED_AD_PASSENGERS := 25
const DAILY_REWARDED_AD_CAP := 3

# Friend gifts are free to send and intentionally small. Ten incoming gifts
# per day contribute at most 50 passengers, so social play helps without
# replacing airport passenger infrastructure.
const FRIEND_GIFT_PASSENGERS := 5
const DAILY_INCOMING_FRIEND_GIFT_CAP := 10


static func rewarded_ad_amount() -> int:
	return REWARDED_AD_PASSENGERS


static func rewarded_ad_daily_cap() -> int:
	return DAILY_REWARDED_AD_CAP


static func max_daily_rewarded_ad_passengers() -> int:
	return REWARDED_AD_PASSENGERS * DAILY_REWARDED_AD_CAP


static func friend_gift_amount() -> int:
	return FRIEND_GIFT_PASSENGERS


static func friend_gift_daily_cap() -> int:
	return DAILY_INCOMING_FRIEND_GIFT_CAP


static func max_daily_friend_passengers() -> int:
	return (
		FRIEND_GIFT_PASSENGERS
		* DAILY_INCOMING_FRIEND_GIFT_CAP
	)


static func grant_rewarded_ad_passengers(
	economy: PassengerEconomy
) -> int:
	if economy == null:
		return 0
	return economy.add_passengers(REWARDED_AD_PASSENGERS)


static func grant_friend_gift(
	economy: PassengerEconomy
) -> int:
	if economy == null:
		return 0
	return economy.add_passengers(FRIEND_GIFT_PASSENGERS)
