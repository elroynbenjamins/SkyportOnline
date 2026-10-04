class_name OperationsAnalyticsRules
extends RefCounted

const SERVICE_LABELS := {
	"fuel": "Fuel",
	"passenger": "Passenger handling",
	"cargo": "Baggage",
	"cleaning": "Cleaning",
	"catering": "Catering",
	"pushback": "Pushback"
}


static func analyze(snapshot: Dictionary) -> Dictionary:
	var items: Array[Dictionary] = []

	var runway: Dictionary = snapshot.get(
		"runway",
		{}
	)
	var runway_recommendation: Dictionary = runway.get(
		"recommendation",
		{}
	)
	var runway_wait := float(
		runway.get("average_wait_seconds", 0.0)
	)
	var runway_util := float(
		runway.get("max_utilization_pct", 0.0)
	)
	var runway_score := (
		runway_wait * 14.0
		+ runway_util * 0.55
	)
	if String(
		runway_recommendation.get("tone", "normal")
	) == "warning":
		runway_score += 22.0
	items.append({
		"id": "runway",
		"name": "Runway / ATC",
		"score": runway_score,
		"detail": _runway_detail(runway),
		"action": String(
			runway_recommendation.get(
				"title",
				"Monitor runway capacity"
			)
		),
		"tone": String(
			runway_recommendation.get(
				"tone",
				"normal"
			)
		)
	})

	var services: Dictionary = snapshot.get(
		"services",
		{}
	)
	for service_type in services.keys():
		var stats: Dictionary = services[service_type]
		var utilization := float(
			stats.get("utilization_pct", 0.0)
		)
		var average_wait := float(
			stats.get("average_wait_seconds", 0.0)
		)
		var current_waiting := int(
			stats.get("current_waiting", 0)
		)
		var peak_waiting := int(
			stats.get("peak_waiting", 0)
		)
		var score := (
			utilization * 0.45
			+ average_wait * 13.0
			+ float(current_waiting) * 24.0
			+ float(peak_waiting) * 5.0
		)
		items.append({
			"id": String(service_type),
			"name": String(
				SERVICE_LABELS.get(
					service_type,
					String(service_type).capitalize()
				)
			),
			"score": score,
			"detail": "%s util • %s avg queue • %d waiting" % [
				_format_percent(utilization),
				_format_seconds(average_wait),
				current_waiting
			],
			"action": _service_action(
				String(service_type),
				stats
			),
			"tone": "warning" if score >= 50.0 else "normal"
		})

	var passenger: Dictionary = snapshot.get(
		"passengers",
		{}
	)
	var passenger_capacity := maxi(
		int(passenger.get("capacity", 0)),
		0
	)
	var passenger_stock := maxi(
		int(passenger.get("stock", 0)),
		0
	)
	var passenger_ratio := 1.0
	if passenger_capacity > 0:
		passenger_ratio = clampf(
			float(passenger_stock)
			/ float(passenger_capacity),
			0.0,
			1.0
		)
	var passenger_waiting := int(
		passenger.get("waiting_aircraft", 0)
	)
	var passenger_score := (
		float(passenger_waiting) * 35.0
		+ (1.0 - passenger_ratio) * 55.0
	)
	items.append({
		"id": "passenger_stock",
		"name": "Passenger supply",
		"score": passenger_score,
		"detail": "%d / %d stored • %.1f/min • %d aircraft waiting" % [
			passenger_stock,
			passenger_capacity,
			float(passenger.get("production_per_minute", 0.0)),
			passenger_waiting
		],
		"action": (
			"Upgrade passenger production/storage"
			if passenger_waiting > 0 or passenger_ratio < 0.25
			else "Passenger supply healthy"
		),
		"tone": "warning" if passenger_score >= 50.0 else "normal"
	})

	var stands: Dictionary = snapshot.get(
		"stands",
		{}
	)
	var stand_total := maxi(
		int(stands.get("total", 0)),
		0
	)
	var stand_occupied := maxi(
		int(stands.get("occupied", 0)),
		0
	)
	var pending_arrivals := maxi(
		int(stands.get("pending_arrivals", 0)),
		0
	)
	var stand_ratio := 0.0
	if stand_total > 0:
		stand_ratio = clampf(
			float(stand_occupied) / float(stand_total),
			0.0,
			1.0
		)
	var stand_score := (
		stand_ratio * 58.0
		+ float(pending_arrivals) * 40.0
	)
	items.append({
		"id": "stands",
		"name": "Aircraft stands",
		"score": stand_score,
		"detail": "%d / %d occupied • %d inbound holding" % [
			stand_occupied,
			stand_total,
			pending_arrivals
		],
		"action": (
			"Add another compatible stand"
			if pending_arrivals > 0 or stand_ratio >= 0.90
			else "Stand capacity healthy"
		),
		"tone": "warning" if stand_score >= 58.0 else "normal"
	})

	items.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("score", 0.0)) > float(
				b.get("score", 0.0)
			)
	)

	var primary: Dictionary = {}
	if not items.is_empty():
		primary = items[0].duplicate(true)

	var recommendation := {
		"id": String(primary.get("id", "healthy")),
		"title": String(
			primary.get(
				"action",
				"Operations healthy"
			)
		),
		"detail": String(
			primary.get(
				"detail",
				"No major bottleneck detected."
			)
		),
		"tone": (
			"warning"
			if float(primary.get("score", 0.0)) >= 50.0
			else "success"
		)
	}

	return {
		"ranked": items,
		"primary": primary,
		"recommendation": recommendation
	}


static func _service_action(
	service_type: String,
	stats: Dictionary
) -> String:
	var current_waiting := int(
		stats.get("current_waiting", 0)
	)
	var utilization := float(
		stats.get("utilization_pct", 0.0)
	)

	if current_waiting <= 0 and utilization < 65.0:
		return "%s capacity healthy" % String(
			SERVICE_LABELS.get(
				service_type,
				service_type.capitalize()
			)
		)

	match service_type:
		"fuel":
			return "Upgrade fuel capacity/speed"
		"passenger":
			return "Upgrade Passenger Service Hub"
		"cargo":
			return "Upgrade Baggage Depot"
		"cleaning":
			return "Upgrade Cleaning Center"
		"catering":
			return "Upgrade Catering Kitchen"
		"pushback":
			return "Upgrade Tow Operations"
		_:
			return "Upgrade service capacity"


static func _runway_detail(runway: Dictionary) -> String:
	return "%s util • %s avg wait • %s separation delay" % [
		_format_percent(
			float(
				runway.get(
					"average_utilization_pct",
					0.0
				)
			)
		),
		_format_seconds(
			float(
				runway.get(
					"average_wait_seconds",
					0.0
				)
			)
		),
		_format_percent(
			float(
				runway.get(
					"separation_delay_pct",
					0.0
				)
			)
		)
	]


static func _format_seconds(value: float) -> String:
	return "%.1fs" % maxf(value, 0.0)


static func _format_percent(value: float) -> String:
	return "%.0f%%" % clampf(value, 0.0, 100.0)
