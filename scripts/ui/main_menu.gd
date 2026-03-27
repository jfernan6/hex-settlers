extends Control

## Main menu — title screen shown at startup.
## Skipped automatically when running with any --debug-* flag.

const GAME_SCENE := "res://scenes/main.tscn"


func _ready() -> void:
	# Debug / test modes skip the menu entirely
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--debug") or arg.begins_with("--run-tests"):
			_start_game.call_deferred()
			return
	_build_ui()


func _build_ui() -> void:
	var vp := get_viewport_rect().size

	# Full-screen dusk background
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(0.76, 0.33, 0.17, 0.12)
	glow.anchor_left = 0.0
	glow.anchor_right = 1.0
	glow.anchor_top = 0.0
	glow.anchor_bottom = 0.55
	add_child(glow)

	for i in range(3):
		var stripe := ColorRect.new()
		stripe.color = Color(0.92, 0.55, 0.22, 0.05 + 0.02 * i)
		stripe.position = Vector2(vp.x * (0.11 + 0.08 * i), -40 + 32 * i)
		stripe.size = Vector2(190 + 32 * i, vp.y * 0.78)
		stripe.rotation = deg_to_rad(18)
		add_child(stripe)

	var shell := MarginContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("margin_left", 32)
	shell.add_theme_constant_override("margin_right", 32)
	shell.add_theme_constant_override("margin_top", 28)
	shell.add_theme_constant_override("margin_bottom", 28)
	add_child(shell)

	var root := HBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 26)
	shell.add_child(root)

	var intro := VBoxContainer.new()
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.alignment = BoxContainer.ALIGNMENT_CENTER
	intro.add_theme_constant_override("separation", 12)
	root.add_child(intro)

	var eyebrow := _label("MAC BUILD LOCAL PROTOTYPE", 14)
	eyebrow.modulate = Color(0.96, 0.67, 0.34, 0.95)
	intro.add_child(eyebrow)

	# Title
	var title := _label("HEX SETTLERS", 52)
	title.add_theme_font_size_override("font_size", int(minf(74.0, maxf(52.0, vp.x * 0.042))))
	title.modulate = Color(0.97, 0.92, 0.84)
	intro.add_child(title)

	# Subtitle
	var sub := _label("A local-first Catan-inspired prototype built in Godot", 18)
	sub.custom_minimum_size = Vector2(minf(540.0, vp.x * 0.42), 0)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = Color(0.79, 0.79, 0.78)
	intro.add_child(sub)

	var flavor := _label("Hot-seat strategy, unfinished systems, and plenty of room to sharpen the board feel.", 15)
	flavor.custom_minimum_size = Vector2(minf(520.0, vp.x * 0.4), 0)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.modulate = Color(0.63, 0.66, 0.69)
	intro.add_child(flavor)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(clampf(vp.x * 0.26, 300.0, 360.0), 0)
	card.add_theme_stylebox_override("panel", _menu_panel_style())
	root.add_child(card)

	var panel := VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 16)
	card.add_child(panel)

	var panel_title := _label("Play Session", 22)
	panel_title.modulate = Color(0.95, 0.92, 0.86)
	panel.add_child(panel_title)

	var panel_sub := _label("Jump into the current local build and keep iterating.", 14)
	panel_sub.custom_minimum_size = Vector2(0, 0)
	panel_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_sub.modulate = Color(0.72, 0.74, 0.76)
	panel.add_child(panel_sub)

	var play_btn := _btn("Play vs AI", _start_game)
	play_btn.grab_focus()
	panel.add_child(play_btn)

	var quit_btn := _btn("Quit", func(): get_tree().quit())
	panel.add_child(quit_btn)

	var ver := _label("v0.1.0  |  CC0 assets  |  Godot 4.6.1", 12)
	ver.modulate = Color(0.50, 0.53, 0.57)
	panel.add_child(ver)

	var hint := _label("F11 — fullscreen   F12 — screenshot   Esc — quit", 12)
	hint.modulate = Color(0.44, 0.47, 0.50)
	panel.add_child(hint)


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l


func _btn(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", _button_style(Color(0.90, 0.42, 0.18), Color(0.98, 0.82, 0.62, 0.22)))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.96, 0.50, 0.20), Color(0.99, 0.86, 0.67, 0.30)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.73, 0.31, 0.12), Color(0.99, 0.88, 0.70, 0.18)))
	b.add_theme_stylebox_override("focus", _button_style(Color(0.96, 0.50, 0.20), Color(1.0, 0.90, 0.72, 0.38)))
	b.add_theme_color_override("font_color", Color(0.14, 0.08, 0.04))
	b.pressed.connect(callback)
	return b


func _spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


func _menu_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.16, 0.92)
	style.border_color = Color(0.94, 0.63, 0.35, 0.28)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.shadow_size = 24
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	return style


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
