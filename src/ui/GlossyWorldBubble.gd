class_name GlossyWorldBubble
extends PanelContainer

signal action_pressed

var icon_rect: TextureRect
var title_label: Label
var value_label: Label
var detail_label: Label
var progress_bar: ProgressBar
var action_button: Button


func _ready() -> void:
	custom_minimum_size = Vector2(240, 92)
	GameUIStyle.apply_panel(self, "world_bubble")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(42, 42)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_rect)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)

	title_label = Label.new()
	GameUIStyle.heading(title_label, 13)
	text_box.add_child(title_label)

	value_label = Label.new()
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", Color("0d3760"))
	text_box.add_child(value_label)

	detail_label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 10)
	detail_label.add_theme_color_override("font_color", Color("3f6580"))
	text_box.add_child(detail_label)

	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(94, 12)
	GameUIStyle.apply_progress(progress_bar, false)
	text_box.add_child(progress_bar)

	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(54, 44)
	GameUIStyle.apply_button(action_button, "primary", true)
	action_button.pressed.connect(func(): action_pressed.emit())
	row.add_child(action_button)


func configure(
	title: String,
	value: String,
	detail: String,
	icon: Texture2D = null,
	action_text: String = "",
	progress: float = -1.0
) -> void:
	if title_label == null:
		return
	title_label.text = title
	value_label.text = value
	detail_label.text = detail
	detail_label.visible = not detail.is_empty()
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	action_button.text = action_text
	action_button.visible = not action_text.is_empty()
	progress_bar.visible = progress >= 0.0
	if progress >= 0.0:
		progress_bar.min_value = 0.0
		progress_bar.max_value = 1.0
		progress_bar.value = clampf(progress, 0.0, 1.0)
