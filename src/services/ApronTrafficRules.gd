class_name ApronTrafficRules
extends RefCounted

# Small visual lane offsets keep vehicles from perfectly overlapping while
# staying inside the same logical service-road route.
const SERVICE_LANE_OFFSETS := {
	"passenger": -5.0,
	"cleaning": -3.0,
	"pushback": -1.0,
	"fuel": 1.5,
	"catering": 3.5,
	"cargo": 5.5
}

const STAND_STAGGER_SECONDS := 0.45
const STATION_STAGGER_SECONDS := 0.30
const MAX_STAGGER_SECONDS := 1.80


static func lane_offset(service_type: String) -> float:
	return float(
		SERVICE_LANE_OFFSETS.get(service_type, 0.0)
	)


static func stagger_delay(active_approaches: int) -> float:
	return minf(
		maxi(active_approaches, 0)
		* STAND_STAGGER_SECONDS,
		MAX_STAGGER_SECONDS
	)


static func station_stagger_delay(active_dispatches: int) -> float:
	return minf(
		maxi(active_dispatches, 0)
		* STATION_STAGGER_SECONDS,
		MAX_STAGGER_SECONDS
	)


static func offset_route(
	points: PackedVector2Array,
	service_type: String
) -> PackedVector2Array:
	if points.size() < 3:
		return points.duplicate()

	var offset := lane_offset(service_type)
	if absf(offset) < 0.01:
		return points.duplicate()

	var result := PackedVector2Array()
	result.append(points[0])

	for index in range(1, points.size() - 1):
		var previous := points[index - 1]
		var current := points[index]
		var next := points[index + 1]

		var incoming := (current - previous).normalized()
		var outgoing := (next - current).normalized()
		var direction := incoming + outgoing
		if direction.length() < 0.01:
			direction = outgoing
		if direction.length() < 0.01:
			direction = incoming
		if direction.length() < 0.01:
			result.append(current)
			continue

		direction = direction.normalized()
		var normal := Vector2(-direction.y, direction.x)
		result.append(current + normal * offset)

	# Keep the aircraft docking point exact.
	result.append(points[points.size() - 1])
	return result


static func minimum_visual_spacing(
	service_type: String
) -> float:
	match service_type:
		"passenger":
			return 20.0
		"pushback":
			return 18.0
		_:
			return 16.0


const SERVICE_PRIORITY := {
	"pushback": 100,
	"passenger": 72,
	"fuel": 64,
	"catering": 56,
	"cargo": 50,
	"cleaning": 46,
}

const FOLLOW_LATERAL_TOLERANCE := 13.0
const CROSSING_CAUTION_RADIUS := 30.0
const ONCOMING_CAUTION_RADIUS := 34.0
const MIN_TRAFFIC_FACTOR := 0.18
const STAND_ENTRY_PROGRESS := 0.78
const STAND_EXIT_CLEAR_PROGRESS := 0.28


static func right_of_way_priority(
	service_type: String,
	phase: String = "OUTBOUND"
) -> int:
	var priority := int(
		SERVICE_PRIORITY.get(service_type, 50)
	)
	if phase == "OUTBOUND":
		priority += 4
	elif phase == "RETURNING":
		priority -= 4
	return priority


static func stand_throat_state(
	snapshot: Dictionary
) -> String:
	var stand_uid := int(snapshot.get("stand_uid", -1))
	if stand_uid < 0:
		return "road"
	var phase := String(snapshot.get("phase", ""))
	var progress := clampf(
		float(snapshot.get("route_progress", 0.0)),
		0.0,
		1.0
	)
	if phase == "OUTBOUND" and progress >= STAND_ENTRY_PROGRESS:
		return "entering"
	if phase == "RETURNING" and progress <= STAND_EXIT_CLEAR_PROGRESS:
		return "exiting"
	return "road"


static func _stand_throat_yield(
	self_snapshot: Dictionary,
	other_snapshot: Dictionary
) -> Dictionary:
	var self_stand := int(self_snapshot.get("stand_uid", -1))
	var other_stand := int(other_snapshot.get("stand_uid", -1))
	if self_stand < 0 or self_stand != other_stand:
		return {}

	var self_state := stand_throat_state(self_snapshot)
	var other_state := stand_throat_state(other_snapshot)
	if self_state == "road" or other_state == "road":
		return {}

	var self_id := int(self_snapshot.get("instance_id", -1))
	var other_id := int(other_snapshot.get("instance_id", -1))
	var self_sequence := int(
		self_snapshot.get("traffic_sequence", 999999)
	)
	var other_sequence := int(
		other_snapshot.get("traffic_sequence", 999999)
	)

	# A vehicle already leaving the stand clears the narrow apron throat first.
	if self_state == "entering" and other_state == "exiting":
		return {
			"yielding": true,
			"reason": "stand exit clearing",
			"blocker_id": other_id,
		}
	if self_state == "exiting" and other_state == "entering":
		return {}

	# Same-direction stand merges use stable dispatch order. This avoids two
	# vehicles visually entering/leaving the throat side-by-side.
	var self_yields := false
	if self_sequence != other_sequence:
		self_yields = self_sequence > other_sequence
	else:
		self_yields = self_id > other_id
	if not self_yields:
		return {}

	return {
		"yielding": true,
		"reason": (
			"stand approach queue"
			if self_state == "entering"
			else "stand exit queue"
		),
		"blocker_id": other_id,
	}


static func traffic_decision(
	self_snapshot: Dictionary,
	other_snapshots: Array
) -> Dictionary:
	var result := {
		"factor": 1.0,
		"yielding": false,
		"reason": "",
		"blocker_id": -1,
	}
	var self_position: Vector2 = self_snapshot.get(
		"position",
		Vector2.ZERO
	)
	var self_heading := float(
		self_snapshot.get("heading", 0.0)
	)
	var self_forward := Vector2.RIGHT.rotated(
		self_heading
	)
	var self_normal := Vector2(
		-self_forward.y,
		self_forward.x
	)
	var self_type := String(
		self_snapshot.get("service_type", "")
	)
	var self_phase := String(
		self_snapshot.get("phase", "")
	)
	var self_priority := right_of_way_priority(
		self_type,
		self_phase
	)
	var self_sequence := int(
		self_snapshot.get("traffic_sequence", 999999)
	)
	var self_id := int(
		self_snapshot.get("instance_id", -1)
	)
	var self_spacing := minimum_visual_spacing(
		self_type
	)

	for other_variant in other_snapshots:
		var other: Dictionary = other_variant
		var other_id := int(
			other.get("instance_id", -1)
		)
		if other_id < 0 or other_id == self_id:
			continue
		var other_phase := String(
			other.get("phase", "")
		)
		if other_phase not in ["OUTBOUND", "RETURNING"]:
			continue

		var stand_yield := _stand_throat_yield(
			self_snapshot,
			other
		)
		if bool(stand_yield.get("yielding", false)):
			_apply_stronger_yield(
				result,
				0.0,
				String(stand_yield.get("reason", "stand queue")),
				int(stand_yield.get("blocker_id", other_id))
			)
			continue

		var other_position: Vector2 = other.get(
			"position",
			Vector2.ZERO
		)
		var relative := other_position - self_position
		var distance := relative.length()
		if distance > 54.0:
			continue

		var other_heading := float(
			other.get("heading", 0.0)
		)
		var other_forward := Vector2.RIGHT.rotated(
			other_heading
		)
		var heading_dot := self_forward.dot(
			other_forward
		)
		var forward_distance := relative.dot(
			self_forward
		)
		var lateral_distance := absf(
			relative.dot(self_normal)
		)
		var other_type := String(
			other.get("service_type", "")
		)
		var required_spacing := maxf(
			self_spacing,
			minimum_visual_spacing(other_type)
		)

		# Same-direction traffic: only the following vehicle yields.
		if heading_dot > 0.55:
			if (
				forward_distance > 0.0
				and lateral_distance
				<= FOLLOW_LATERAL_TOLERANCE
				and forward_distance
				< required_spacing * 1.65
			):
				var factor := clampf(
					(
						forward_distance
						- required_spacing * 0.72
					)
					/ maxf(
						required_spacing * 0.93,
						1.0
					),
					MIN_TRAFFIC_FACTOR,
					1.0
				)
				_apply_stronger_yield(
					result,
					factor,
					"vehicle ahead",
					other_id
				)
			continue

		# Crossing/oncoming traffic uses deterministic right-of-way. Outbound
		# traffic wins ties over returning traffic; otherwise service priority,
		# dispatch sequence, then instance id break ties.
		var caution_radius := (
			ONCOMING_CAUTION_RADIUS
			if heading_dot < -0.35
			else CROSSING_CAUTION_RADIUS
		)
		if distance > caution_radius:
			continue

		var other_priority := right_of_way_priority(
			other_type,
			other_phase
		)
		var other_sequence := int(
			other.get("traffic_sequence", 999999)
		)
		var self_yields := false
		if self_priority != other_priority:
			self_yields = self_priority < other_priority
		elif self_sequence != other_sequence:
			self_yields = self_sequence > other_sequence
		else:
			self_yields = self_id > other_id

		if self_yields:
			_apply_stronger_yield(
				result,
				0.0,
				(
					"oncoming vehicle"
					if heading_dot < -0.35
					else "crossing vehicle"
				),
				other_id
			)

	return result


static func _apply_stronger_yield(
	result: Dictionary,
	factor: float,
	reason: String,
	blocker_id: int
) -> void:
	var normalized := clampf(factor, 0.0, 1.0)
	if normalized >= float(result.get("factor", 1.0)):
		return
	result["factor"] = normalized
	result["yielding"] = normalized < 0.999
	result["reason"] = reason
	result["blocker_id"] = blocker_id
