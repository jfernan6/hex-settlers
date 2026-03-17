extends Control

## Main menu — title screen shown at startup.
## Skipped automatically when running with any --debug-* flag.

const GAME_SCENE := "res://scenes/main.tscn"


func _ready() -> void:
	# Debug / test modes skip the menu entirely
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--debug") or arg.begins_with("--run-tests"):
			_start_game()
			return
	_build_ui()


func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centered content panel
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left   = -220.0
	panel.offset_right  = 220.0
	panel.offset_top    = -200.0
	panel.offset_bottom = 200.0
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 20)
	add_child(panel)

	# Title
	var title := _label("HEX SETTLERS", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.90, 0.20, 0.12)
	panel.add_child(title)

	# Subtitle
	var sub := _label("A Catan-inspired board game", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.65, 0.65, 0.65)
	panel.add_child(sub)

	panel.add_child(_spacer(24))

	# Play button
	var play_btn := _btn("Play vs AI", _start_game)
	panel.add_child(play_btn)

	panel.add_child(_spacer(8))

	# Quit button
	var quit_btn := _btn("Quit", func(): get_tree().quit())
	panel.add_child(quit_btn)

	panel.add_child(_spacer(32))

	# Version
	var ver := _label("v0.1.0  |  CC0 assets  |  Godot 4.6.1", 12)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.modulate = Color(0.35, 0.35, 0.35)
	panel.add_child(ver)

	# Keyboard hint
	var hint := _label("F11 — fullscreen   F12 — screenshot   Esc — quit", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.30, 0.30, 0.30)
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
	l.add_theme_font_size_override("font_size", size)
	return l


func _btn(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(callback)
	return b


func _spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s
