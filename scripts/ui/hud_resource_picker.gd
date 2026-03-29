class_name HUDResourcePicker
extends PanelContainer

signal year_of_plenty_chosen(r1: int, r2: int)
signal monopoly_chosen(res: int)

var _font_size: int = 15
var _res_colors: Array = []
var _res_names: Array = []
var _mode: String = ""
var _selection: Array = []
var _title: Label


func setup(font_size: int, res_colors: Array, res_names: Array) -> void:
	_font_size = font_size
	_res_colors = res_colors
	_res_names = res_names
	visible = false
	anchor_left = 0.25
	anchor_right = 0.95
	anchor_top = 0.28
	anchor_bottom = 0.55
	z_index = 20
	_build_ui()


func open_picker(mode: String) -> void:
	_mode = mode
	_selection = []
	_title.text = "Year of Plenty — pick 2 resources:" if mode == "yop" else "Monopoly — pick 1 resource to claim from all:"
	visible = true


func _build_ui() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	_title = _lbl("Choose a resource:")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", _font_size + 2)
	vb.add_child(_title)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)

	for r in 5:
		var rv: int = r
		var btn := Button.new()
		btn.text = _res_names[r]
		btn.add_theme_font_size_override("font_size", _font_size)
		btn.custom_minimum_size = Vector2(maxi(60, _font_size * 4), maxi(36, _font_size * 2.5))
		var style := StyleBoxFlat.new()
		style.bg_color = _res_colors[r]
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.pressed.connect(func(): _on_resource_pressed(rv))
		hb.add_child(btn)

	vb.add_child(_btn("Cancel", func(): visible = false))


func _on_resource_pressed(res: int) -> void:
	if _mode == "mono":
		visible = false
		monopoly_chosen.emit(res)
		return

	_selection.append(res)
	if _selection.size() >= 2:
		visible = false
		year_of_plenty_chosen.emit(_selection[0], _selection[1])
		_selection = []
	else:
		_title.text = "Year of Plenty — pick 1 more resource:"


func _lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", _font_size)
	b.custom_minimum_size = Vector2(0, maxi(34, _font_size * 2.4))
	b.add_theme_stylebox_override("normal", _button_style(Color(0.18, 0.22, 0.28), Color(0.36, 0.43, 0.52)))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.29, 0.36), Color(0.52, 0.60, 0.72)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.12, 0.15, 0.20), Color(0.62, 0.69, 0.78)))
	b.add_theme_stylebox_override("disabled", _button_style(Color(0.11, 0.13, 0.16, 0.92), Color(0.20, 0.23, 0.27)))
	b.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	b.add_theme_color_override("font_disabled_color", Color(0.48, 0.52, 0.58))
	b.pressed.connect(callback)
	return b


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
