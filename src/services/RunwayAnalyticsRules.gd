class_name RunwayAnalyticsRules
extends RefCounted

const MAX_ATC_MULTIPLIER := 0.68
const MIN_SAMPLE_SECONDS := 12.0
const MIN_SAMPLE_MOVEMENTS := 3


static func recommendation(
	summary: Dictionary
) -> Dictionary:
	var runway_count := maxi(
		int(summary.get("runway_count", 1)),
		1
	)
	var tracked_seconds := float(
		summary.get("tracked_seconds", 0.0)
	)
	var movements := int(
		summary.get("movements", 0)
	)
	var utilization := float(
		summary.get("average_utilization_pct", 0.0)
	)
	var max_utilization := float(
		summary.get("max_utilization_pct", utilization)
	)
	var min_utilization := float(
		summary.get("min_utilization_pct", utilization)
	)
	var average_wait := float(
		summary.get("average_wait_seconds", 0.0)
	)
	var separation_share := float(
		summary.get("separation_delay_pct", 0.0)
	)
	var override_rate := float(
		summary.get("strategy_override_pct", 0.0)
	)
	var atc_multiplier := float(
		summary.get("separation_multiplier", 1.0)
	)
	var atc_can_improve := (
		atc_multiplier > MAX_ATC_MULTIPLIER + 0.001
	)

	if (
		tracked_seconds < MIN_SAMPLE_SECONDS
		or movements < MIN_SAMPLE_MOVEMENTS
	):
		return {
			"id": "collect_data",
			"title": "Keep monitoring",
			"detail": (
				"More runway movements are needed before recommending "
				+ "a major capacity investment."
			),
			"tone": "normal"
		}

	if (
		separation_share >= 42.0
		and average_wait >= 1.25
		and atc_can_improve
	):
		return {
			"id": "upgrade_atc",
			"title": "Upgrade ATC first",
			"detail": (
				"Most runway delay is coming from mandatory separation, "
				+ "so faster ATC procedures should improve throughput "
				+ "before adding more pavement."
			),
			"tone": "warning"
		}

	if (
		max_utilization >= 72.0
		and average_wait >= 2.5
		and (
			not atc_can_improve
			or separation_share < 42.0
		)
	):
		return {
			"id": "add_runway",
			"title": "Add runway capacity",
			"detail": (
				"Runway occupancy is the main constraint. Another connected "
				+ "compatible runway should provide more value than further "
				+ "ATC tuning."
			),
			"tone": "warning"
		}

	if runway_count >= 2:
		var utilization_gap := (
			max_utilization - min_utilization
		)
		if (
			override_rate >= 28.0
			or (
				utilization_gap >= 30.0
				and average_wait >= 1.0
			)
		):
			return {
				"id": "rebalance_roles",
				"title": "Rebalance runway roles",
				"detail": (
					"Traffic is frequently overriding runway preferences "
					+ "or concentrating on one runway. Adjust ARR/DEP roles "
					+ "before buying more capacity."
				),
				"tone": "warning"
			}

	if (
		runway_count == 1
		and average_wait >= 2.0
		and atc_can_improve
	):
		return {
			"id": "upgrade_atc",
			"title": "Upgrade ATC first",
			"detail": (
				"The single runway is creating moderate delay and ATC still "
				+ "has headroom. Improve separation before committing to "
				+ "a second runway."
			),
			"tone": "warning"
		}

	return {
		"id": "healthy",
		"title": "Capacity healthy",
		"detail": (
			"Current runway capacity is keeping up with traffic. "
			+ "No major runway investment is needed yet."
		),
		"tone": "success"
	}


static func format_seconds(value: float) -> String:
	return "%.1fs" % maxf(value, 0.0)


static func format_percent(value: float) -> String:
	return "%.0f%%" % clampf(value, 0.0, 100.0)
