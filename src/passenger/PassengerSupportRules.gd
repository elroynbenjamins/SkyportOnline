class_name PassengerSupportRules
extends RefCounted

const REWARDED_AD_PASSENGERS := 25

# Social values are groundwork for the later Friends / Alliance layer.
# They are deliberately conservative to avoid turning alt accounts into
# the best passenger source.
const FRIEND_GIFT_PASSENGERS := 10
const DAILY_INCOMING_FRIEND_GIFT_CAP := 3


static func rewarded_ad_amount() -> int:
	return REWARDED_AD_PASSENGERS


static func friend_gift_amount() -> int:
	return FRIEND_GIFT_PASSENGERS


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
