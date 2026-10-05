class_name FriendshipRules
extends RefCounted

const THRESHOLDS := [0, 10, 30, 75, 150]
const NAMES := ["Acquaintance", "Regular Route", "Trusted Partner", "Close Connection", "Skyport Ally"]
const MAX_CREDIT_PER_CONTACT_DAY := 5

static func status(entry: Dictionary) -> Dictionary:
	var points := maxi(int(entry.get("points", 0)), 0)
	var rank := 1
	for index in range(THRESHOLDS.size()):
		if points >= int(THRESHOLDS[index]):
			rank = index + 1
	return {"rank": rank, "name": NAMES[rank - 1], "points": points,
		"next": int(THRESHOLDS[rank]) if rank < 5 else points,
		"coin_bonus": float(rank - 1) * 0.005}

static func record_completion(ledger: Dictionary, request: Dictionary, day: String) -> Dictionary:
	var relation := String(request.get("relationship", ""))
	var contact_id := String(request.get("contact_id", ""))
	var visit_id := String(request.get("visit_id", ""))
	if relation not in ["friend", "alliance"] or contact_id.is_empty() or visit_id.is_empty():
		return ledger.duplicate(true)
	var result := ledger.duplicate(true)
	var entry: Dictionary = result.get(contact_id, {})
	var receipts: Dictionary = entry.get("receipts", {})
	if receipts.has(visit_id):
		return result
	receipts[visit_id] = true
	while receipts.size() > 256:
		receipts.erase(receipts.keys()[0])
	entry["receipts"] = receipts
	# ISO dates compare chronologically; rolling the local clock back cannot refresh a day.
	var stored_day := String(entry.get("day", ""))
	if day > stored_day:
		entry["day"] = day
		entry["today"] = 0
	if day == String(entry.get("day", "")) and int(entry.get("today", 0)) < MAX_CREDIT_PER_CONTACT_DAY:
		entry["points"] = int(entry.get("points", 0)) + 1
		entry["today"] = int(entry.get("today", 0)) + 1
	entry["local_test"] = bool(request.get("system_contact", false))
	entry["name"] = String(request.get("display_name", contact_id))
	result[contact_id] = entry
	return result
