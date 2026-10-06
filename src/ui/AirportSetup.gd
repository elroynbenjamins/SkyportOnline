class_name AirportSetup
extends CanvasLayer

signal airport_created(profile: Dictionary)

var overlay_root: Control
var airport_name_input: LineEdit
var airport_code_input: LineEdit
var name_status: Label
var country_map: CountryMap
var country_picker: OptionButton
var country_title: Label
var country_region: Label
var resource_labels: Array[Label] = []
var confirm_button: Button
var create_status: Label

var countries: Array[Dictionary] = []
var selected_country_id := "NL"
var code_manually_edited := false
var updating_code := false


func _ready() -> void:
	layer = 100
	countries = CountryCatalog.get_countries()
	_build_interface()
	_select_country(selected_country_id)
	close()


func open() -> void:
	if overlay_root == null:
		return
	overlay_root.visible = true
	_refresh_validation()
	airport_name_input.call_deferred("grab_focus")


func close() -> void:
	if overlay_root != null:
		overlay_root.visible = false


func _build_interface() -> void:
	overlay_root = Control.new()
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay_root)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = GameUIStyle.COLOR_BG
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.add_child(background)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 26)
	outer.add_theme_constant_override("margin_right", 26)
	outer.add_theme_constant_override("margin_top", 22)
	outer.add_theme_constant_override("margin_bottom", 22)
	overlay_root.add_child(outer)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	outer.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)

	var heading_box := VBoxContainer.new()
	heading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading_box)

	var heading := Label.new()
	heading.text = "ESTABLISH YOUR AIRPORT"
	GameUIStyle.heading(heading, 28)
	heading.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	heading_box.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Create locally now • link this same airport later without losing progress."
	subtitle.add_theme_font_size_override("font_size", 15)
	GameUIStyle.muted(subtitle)
	heading_box.add_child(subtitle)

	var guest_badge := Label.new()
	guest_badge.text = " GUEST ACCOUNT "
	guest_badge.add_theme_font_size_override("font_size", 15)
	guest_badge.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_ACCENT
	)
	header.add_child(guest_badge)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var identity_panel := PanelContainer.new()
	identity_panel.custom_minimum_size = Vector2(350, 0)
	GameUIStyle.apply_panel(identity_panel, "raised")
	body.add_child(identity_panel)

	var identity_margin := MarginContainer.new()
	identity_margin.add_theme_constant_override("margin_left", 18)
	identity_margin.add_theme_constant_override("margin_right", 18)
	identity_margin.add_theme_constant_override("margin_top", 16)
	identity_margin.add_theme_constant_override("margin_bottom", 16)
	identity_panel.add_child(identity_margin)

	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 10)
	identity_margin.add_child(identity)

	var identity_title := Label.new()
	identity_title.text = "AIRPORT IDENTITY"
	GameUIStyle.heading(identity_title, 20)
	identity.add_child(identity_title)

	var name_label := Label.new()
	name_label.text = "Airport name"
	identity.add_child(name_label)

	airport_name_input = LineEdit.new()
	airport_name_input.placeholder_text = "Skyhaven International"
	airport_name_input.max_length = 24
	airport_name_input.add_theme_font_size_override("font_size", 18)
	GameUIStyle.apply_input(airport_name_input)
	airport_name_input.text_changed.connect(_on_name_changed)
	identity.add_child(airport_name_input)

	name_status = Label.new()
	name_status.text = "3-24 characters"
	name_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_status.add_theme_font_size_override("font_size", 13)
	name_status.add_theme_color_override("font_color", Color("9fb7c0"))
	identity.add_child(name_status)

	var code_label := Label.new()
	code_label.text = "Airport code"
	identity.add_child(code_label)

	airport_code_input = LineEdit.new()
	airport_code_input.placeholder_text = "SKY"
	airport_code_input.max_length = 3
	airport_code_input.add_theme_font_size_override("font_size", 18)
	GameUIStyle.apply_input(airport_code_input)
	airport_code_input.text_changed.connect(_on_code_changed)
	identity.add_child(airport_code_input)

	var code_help := Label.new()
	code_help.text = "Three letters/numbers. Suggested automatically from the airport name."
	code_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_help.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(code_help)
	identity.add_child(code_help)

	var separator := HSeparator.new()
	identity.add_child(separator)

	var account_title := Label.new()
	account_title.text = "GUEST FIRST"
	account_title.add_theme_font_size_override("font_size", 16)
	identity.add_child(account_title)

	var account_text := Label.new()
	account_text.text = "Your airport starts locally and can be secured to an account later."
	account_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_text.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(account_text)
	identity.add_child(account_text)

	create_status = Label.new()
	create_status.text = ""
	create_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create_status.add_theme_font_size_override("font_size", 13)
	create_status.add_theme_color_override("font_color", Color("ffbd73"))
	identity.add_child(create_status)

	var map_panel := PanelContainer.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_panel(map_panel, "dark")
	body.add_child(map_panel)

	var map_margin := MarginContainer.new()
	map_margin.add_theme_constant_override("margin_left", 16)
	map_margin.add_theme_constant_override("margin_right", 16)
	map_margin.add_theme_constant_override("margin_top", 14)
	map_margin.add_theme_constant_override("margin_bottom", 14)
	map_panel.add_child(map_margin)

	var map_column := VBoxContainer.new()
	map_column.add_theme_constant_override("separation", 8)
	map_margin.add_child(map_column)

	var country_header := HBoxContainer.new()
	country_header.add_theme_constant_override("separation", 12)
	map_column.add_child(country_header)

	var country_text := VBoxContainer.new()
	country_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	country_header.add_child(country_text)

	country_title = Label.new()
	country_title.text = "Netherlands"
	GameUIStyle.heading(country_title, 22)
	country_text.add_child(country_title)

	country_region = Label.new()
	country_region.text = "Europe"
	country_region.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(country_region)
	country_text.add_child(country_region)

	country_picker = OptionButton.new()
	country_picker.custom_minimum_size = Vector2(260, 44)
	GameUIStyle.apply_button(country_picker, "secondary", true)
	for country in countries:
		country_picker.add_item("%s  %s" % [
			String(country.get("id", "")),
			String(country.get("name", "Country"))
		])
		var item_index := country_picker.item_count - 1
		country_picker.set_item_metadata(item_index, String(country.get("id", "")))
	country_picker.item_selected.connect(_on_country_picker_selected)
	country_header.add_child(country_picker)

	country_map = CountryMap.new()
	country_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	country_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	country_map.set_countries(countries)
	country_map.country_selected.connect(_on_map_country_selected)
	map_column.add_child(country_map)

	var resource_header := HBoxContainer.new()
	map_column.add_child(resource_header)

	var resource_title := Label.new()
	resource_title.text = "HOME COUNTRY RESOURCES"
	resource_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_title.add_theme_font_size_override("font_size", 15)
	resource_header.add_child(resource_title)

	var drop_badge := Label.new()
	drop_badge.text = " 40% BASE • PLANE / ROUTE MODIFIERS "
	drop_badge.add_theme_font_size_override("font_size", 13)
	drop_badge.add_theme_color_override("font_color", Color("f1d27a"))
	resource_header.add_child(drop_badge)

	var resources_row := HBoxContainer.new()
	resources_row.add_theme_constant_override("separation", 8)
	map_column.add_child(resources_row)

	for _index in range(3):
		var resource_panel := PanelContainer.new()
		resource_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		GameUIStyle.apply_panel(resource_panel, "raised")
		resources_row.add_child(resource_panel)

		var resource_label := Label.new()
		resource_label.custom_minimum_size = Vector2(0, 66)
		resource_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		resource_label.add_theme_font_size_override("font_size", 13)
		resource_panel.add_child(resource_label)
		resource_labels.append(resource_label)

	var probability_note := Label.new()
	probability_note.text = "These are this country's three materials. Every destination keeps its own three resources. At the 40% base chance: 21.6% none • 43.2% one • 28.8% two • 6.4% all three."
	probability_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	probability_note.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(probability_note)
	map_column.add_child(probability_note)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)

	var social_note := Label.new()
	social_note.text = "Home country sets your route origin and travel distances. It does NOT lock materials: every country's resources remain obtainable through flights, global resource crates, friends and Alliance play."
	social_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	social_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	social_note.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(social_note)
	footer.add_child(social_note)

	confirm_button = Button.new()
	confirm_button.custom_minimum_size = Vector2(260, 52)
	confirm_button.text = "CREATE GUEST AIRPORT"
	confirm_button.add_theme_font_size_override("font_size", 17)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_create_pressed)
	GameUIStyle.apply_button(confirm_button, "gold")
	footer.add_child(confirm_button)


func _panel_style(background: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _on_name_changed(value: String) -> void:
	if not code_manually_edited:
		_set_code_text(ProfileStore.suggest_airport_code(value))
	_refresh_validation()


func _on_code_changed(value: String) -> void:
	if updating_code:
		return
	var cleaned := _sanitize_code(value)
	if cleaned != value:
		_set_code_text(cleaned)
	else:
		code_manually_edited = not value.is_empty()
	_refresh_validation()


func _sanitize_code(value: String) -> String:
	var upper := value.to_upper()
	var matcher := RegEx.new()
	matcher.compile("[A-Z0-9]")
	var cleaned := ""
	var offset := 0
	while cleaned.length() < 3:
		var result := matcher.search(upper, offset)
		if result == null:
			break
		cleaned += result.get_string()
		offset = result.get_end()
	return cleaned


func _set_code_text(value: String) -> void:
	updating_code = true
	airport_code_input.text = value
	airport_code_input.caret_column = value.length()
	updating_code = false


func _on_map_country_selected(country_id: String) -> void:
	_select_country(country_id)


func _on_country_picker_selected(index: int) -> void:
	_select_country(String(country_picker.get_item_metadata(index)))


func _select_country(country_id: String) -> void:
	var country := CountryCatalog.get_country(country_id)
	if country.is_empty():
		return

	selected_country_id = country_id
	country_map.set_selected_country(country_id)
	country_title.text = String(country.get("name", country_id))
	country_region.text = String(country.get("region", ""))

	for index in range(country_picker.item_count):
		if String(country_picker.get_item_metadata(index)) == country_id:
			country_picker.select(index)
			break

	var resources: Array = country.get("resources", [])
	for index in range(resource_labels.size()):
		if index >= resources.size():
			resource_labels[index].text = ""
			continue
		var resource: Dictionary = resources[index]
		resource_labels[index].text = "%s\n40%% base chance\n%s" % [
			String(resource.get("name", "Resource")),
			String(resource.get("use", ""))
		]

	_refresh_validation()


func _refresh_validation() -> void:
	if airport_name_input == null or airport_code_input == null:
		return

	var name_check := ProfileStore.validate_airport_name(airport_name_input.text)
	var code_check := ProfileStore.validate_airport_code(airport_code_input.text)
	var country_valid := not CountryCatalog.get_country(selected_country_id).is_empty()

	if bool(name_check.get("valid", false)):
		name_status.text = "✓ %s" % String(name_check.get("message", "Airport name ready."))
		name_status.add_theme_color_override("font_color", Color("8de3ad"))
	else:
		name_status.text = String(name_check.get("message", "Enter an airport name."))
		name_status.add_theme_color_override("font_color", Color("ffbd73"))

	confirm_button.disabled = not (
		bool(name_check.get("valid", false))
		and bool(code_check.get("valid", false))
		and country_valid
	)


func _on_create_pressed() -> void:
	var profile := ProfileStore.create_guest_airport(
		airport_name_input.text,
		airport_code_input.text,
		selected_country_id
	)
	if profile.is_empty():
		create_status.text = "Could not create the local guest airport profile."
		return

	create_status.text = ""
	close()
	airport_created.emit(profile)
