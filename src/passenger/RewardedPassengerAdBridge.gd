class_name RewardedPassengerAdBridge
extends Node

signal reward_granted
signal unavailable

var provider_connected := false


func set_provider_connected(value: bool) -> void:
	provider_connected = value


func request_ad() -> void:
	if not provider_connected:
		unavailable.emit()
		return

	# The real ad SDK should show a rewarded ad here and call
	# complete_reward_from_provider() only after the provider confirms reward.
	# This bridge deliberately does not auto-grant anything.


func complete_reward_from_provider() -> void:
	if not provider_connected:
		return
	reward_granted.emit()
