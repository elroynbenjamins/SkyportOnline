class_name AirportProgressionStore
extends RefCounted

# Separate, airport-scoped sidecar: legacy ProfileStore saves cannot discard these fields.
# This is LOCAL persistence, not an authoritative online wallet.
static func save_path(airport_id: String) -> String:
	return "user://skyport_progression_%s.cfg" % airport_id.sha256_text().left(24)

static func has_state(airport_id: String) -> bool:
	return not airport_id.is_empty() and FileAccess.file_exists(save_path(airport_id))

static func load_state(airport_id: String) -> Dictionary:
	if airport_id.is_empty():
		return {}
	for path in [save_path(airport_id), save_path(airport_id) + ".bak"]:
		var config := ConfigFile.new()
		if config.load(path) != OK:
			continue
		var value = config.get_value("progression", "state", {})
		if value is Dictionary and String(value.get("airport_id", "")) == airport_id:
			if int(value.get("version", 0)) == 1:
				return value.duplicate(true)
	return {}

static func save_state(state: Dictionary) -> bool:
	var airport_id := String(state.get("airport_id", ""))
	if airport_id.is_empty() or int(state.get("version", 0)) != 1:
		return false
	var path := save_path(airport_id)
	var temporary := path + ".tmp"
	var config := ConfigFile.new()
	config.set_value("progression", "state", state)
	if config.save(temporary) != OK:
		return false
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			return false
	# Rename only a successfully-written file; a failed write leaves the live save intact.
	return DirAccess.rename_absolute(temporary, path) == OK
