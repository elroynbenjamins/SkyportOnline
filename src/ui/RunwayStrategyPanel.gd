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
var auto_button: Button
var arrival_button: Button
var departure_button: Button

var current_runway_uid := -1
var current_strategy := RunwayStrategyRules.AUTO
var specialization_available := false


func _ready() -> void:
	layer = 35
	_build_ui()
	root.visible = false


func open_runway(
	runway: Dictionary,
	strategy: String,
	runway_count: int
) -> void:
	current_runway_uid = int(
		runway.get("uid", -1)
	)
	current_strategy = RunwayStrategyRules.normalize(
		strategy
	)
	specialization_available = runway_count >= 2

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
	panel.offset_top = -195
	panel.offset_right = -35
	panel.offset_bottom = 195
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
