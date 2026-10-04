class_name RunwayStrategyPanel
extends CanvasLayer

signal strategy_requested(
	runway_uid: int,
	strategy: String
)

var root: Control
var title_label: Label
var strategy_label: Label
var note_label: Label
var analytics_label: Label
var recommendation_label: Label
var auto_button: Button
var arrival_button: Button
var departure_button: Button

var current_runway_uid := -1
var current_strategy := RunwayStrategyRules.AUTO
var specialization_available := false
var current_analytics: Dictionary = {}
var current_recommendation: Dictionary = {}


func _ready() -> void:
	layer = 35
	_build_ui()
	root.visible = false


func open_runway(
	runway: Dictionary,
	strategy: String,
	runway_count: int,
	analytics: Dictionary = {},
	recommendation: Dictionary = {}
) -> void:
	current_runway_uid = int(
		runway.get("uid", -1)
	)
	current_strategy = RunwayStrategyRules.normalize(
		strategy
	)
	specialization_available = runway_count >= 2
	current_analytics = analytics.duplicate(true)
	current_recommendation = recommendation.duplicate(true)

	var definition := BuildingCatalog.get_definition(
		String(
			runway.get(
				"definition_id",
				""
			)
		)
	)
	title_label.text = "%s • RWY %d" % [
		String(
			definition.get(
				"name",
				"Runway"
			)
		).to_upper(),
		current_runway_uid
	]

	_refresh_controls()
	_refresh_analytics()
	root.visible = true


func close_panel() -> void:
	root.visible = false
	current_runway_uid = -1


func _refresh_controls() -> void:
	strategy_label.text = "Current strategy: %s" % (
		RunwayStrategyRules.display_name(
			current_strategy
		)
	)

	auto_button.disabled = (
		not specialization_available
		or current_strategy == RunwayStrategyRules.AUTO
	)
	arrival_button.disabled = (
		not specialization_available
		or current_strategy == RunwayStrategyRules.ARRIVALS
	)
	departure_button.disabled = (
		not specialization_available
		or current_strategy == RunwayStrategyRules.DEPARTURES
	)

	if specialization_available:
		note_label.text = (
			"Preferences influence runway assignment but are not hard locks. "
			+ "ATC can override them when another runway is clearly less congested."
		)
	else:
		note_label.text = (
			"Build and connect a second compatible runway to unlock "
			+ "arrival/departure specialization."
		)


func _refresh_analytics() -> void:
	if analytics_label == null or recommendation_label == null:
		return

	if current_analytics.is_empty():
		analytics_label.text = (
			"SESSION ANALYTICS\nCollecting runway data..."
		)
	else:
		analytics_label.text = (
			"SESSION ANALYTICS\n"
			+ "Utilization %s • Avg wait %s\n"
			+ "Separation delay %s • %d movements\n"
			+ "Role overrides %d • Diversions in %d"
		) % [
			RunwayAnalyticsRules.format_percent(
				float(
					current_analytics.get(
						"utilization_pct",
						0.0
					)
				)
			),
			RunwayAnalyticsRules.format_seconds(
				float(
					current_analytics.get(
						"average_wait_seconds",
						0.0
					)
				)
			),
			RunwayAnalyticsRules.format_percent(
				float(
					current_analytics.get(
						"separation_delay_pct",
						0.0
					)
				)
			),
			int(
				current_analytics.get(
					"movements",
					0
				)
			),
			int(
				current_analytics.get(
					"strategy_overrides",
					0
				)
			),
			int(
				current_analytics.get(
					"diversions_in",
					0
				)
			)
		]

	if current_recommendation.is_empty():
		recommendation_label.text = (
			"CAPACITY ADVICE\nKeep monitoring current traffic."
		)
		recommendation_label.add_theme_color_override(
			"font_color",
			Color("9fb9c2")
		)
		return

	recommendation_label.text = "CAPACITY ADVICE • %s\n%s" % [
		String(
			current_recommendation.get(
				"title",
				"Keep monitoring"
			)
		),
		String(
			current_recommendation.get(
				"detail",
				""
			)
		)
	]

	match String(
		current_recommendation.get(
			"tone",
			"normal"
		)
	):
		"warning":
			recommendation_label.add_theme_color_override(
				"font_color",
				Color("ffc266")
			)
		"success":
			recommendation_label.add_theme_color_override(
				"font_color",
				Color("9fe3b7")
			)
		_:
			recommendation_label.add_theme_color_override(
				"font_color",
				Color("9fb9c2")
			)


func _request_strategy(strategy: String) -> void:
	if (
		current_runway_uid < 0
		or not specialization_available
	):
		return

	var normalized := RunwayStrategyRules.normalize(
		strategy
	)
	current_strategy = normalized
	_refresh_controls()
	_refresh_analytics()
	strategy_requested.emit(
		current_runway_uid,
		normalized
	)


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(
		Control.PRESET_CENTER_RIGHT
	)
	panel.offset_left = -430
	panel.offset_top = -265
	panel.offset_right = -35
	panel.offset_bottom = 265
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		18
	)
	margin.add_theme_constant_override(
		"margin_right",
		18
	)
	margin.add_theme_constant_override(
		"margin_top",
		16
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		16
	)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(
		"separation",
		12
	)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)

	title_label = Label.new()
	title_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title_label.add_theme_font_size_override(
		"font_size",
		20
	)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(
		46,
		42
	)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)

	strategy_label = Label.new()
	strategy_label.add_theme_font_size_override(
		"font_size",
		15
	)
	column.add_child(strategy_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override(
		"separation",
		8
	)
	column.add_child(button_row)

	auto_button = Button.new()
	auto_button.text = "AUTO"
	auto_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	auto_button.custom_minimum_size = Vector2(
		0,
		48
	)
	auto_button.pressed.connect(
		_request_strategy.bind(
			RunwayStrategyRules.AUTO
		)
	)
	button_row.add_child(auto_button)

	arrival_button = Button.new()
	arrival_button.text = "ARRIVALS"
	arrival_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	arrival_button.custom_minimum_size = Vector2(
		0,
		48
	)
	arrival_button.pressed.connect(
		_request_strategy.bind(
			RunwayStrategyRules.ARRIVALS
		)
	)
	button_row.add_child(arrival_button)

	departure_button = Button.new()
	departure_button.text = "DEPARTURES"
	departure_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	departure_button.custom_minimum_size = Vector2(
		0,
		48
	)
	departure_button.pressed.connect(
		_request_strategy.bind(
			RunwayStrategyRules.DEPARTURES
		)
	)
	button_row.add_child(departure_button)

	note_label = Label.new()
	note_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	note_label.add_theme_font_size_override(
		"font_size",
		13
	)
	note_label.add_theme_color_override(
		"font_color",
		Color("a9c6cf")
	)
	column.add_child(note_label)

	analytics_label = Label.new()
	analytics_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	analytics_label.add_theme_font_size_override(
		"font_size",
		13
	)
	analytics_label.add_theme_color_override(
		"font_color",
		Color("d7e8ec")
	)
	column.add_child(analytics_label)

	recommendation_label = Label.new()
	recommendation_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	recommendation_label.add_theme_font_size_override(
		"font_size",
		13
	)
	column.add_child(recommendation_label)

	var priority_note := Label.new()
	priority_note.text = (
		"Traffic safety still wins: active runway use, arrival priority, "
		+ "ATC separation and severe congestion always override preference."
	)
	priority_note.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	priority_note.add_theme_font_size_override(
		"font_size",
		12
	)
	priority_note.add_theme_color_override(
		"font_color",
		Color("7fa5b1")
	)
	column.add_child(priority_note)
