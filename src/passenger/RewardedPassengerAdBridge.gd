class_name RewardedPassengerAdBridge
extends Node

signal reward_granted
signal unavailable
signal action_reward_granted(action_id: String)
signal action_unavailable(action_id: String)

var provider_connected := false
var pending_action := ""


func set_provider_connected(value: bool) -> void:
	provider_connected = value
	if not value:
		pending_action = ""


func request_ad() -> void:
	request_ad_for("passenger_boost")


func request_ad_for(action_id: String) -> void:
	if action_id.is_empty():
		return
	if not provider_connected:
		action_unavailable.emit(action_id)
		if action_id == "passenger_boost":
			unavailable.emit()
		return
	pending_action = action_id

	# The real ad SDK should show a rewarded ad here and call
	# complete_reward_from_provider() only after the provider confirms reward.
	# This bridge deliberately does not auto-grant anything.


func complete_reward_from_provider() -> void:
	if not provider_connected or pending_action.is_empty():
		return
	var completed_action := pending_action
	pending_action = ""
	if completed_action == "passenger_boost":
		reward_granted.emit()
	action_reward_granted.emit(completed_action)


func cancel_pending_ad() -> void:
	pending_action = ""
