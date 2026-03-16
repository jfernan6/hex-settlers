extends Node3D

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_generate_board()
	print("=== Hex Settlers: Phase 2 loaded ===")

	# Debug mode: pass `-- --debug-screenshot` on the command line to auto-screenshot and quit
	if "--debug-screenshot" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		_take_screenshot()
		get_tree().quit()

func _input(event: InputEvent) -> void:
	# F12 = manual screenshot during normal play
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_take_screenshot()
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _take_screenshot() -> void:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var path := "res://debug-screenshots/run_%s.png" % timestamp
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Screenshot saved → debug-screenshots/run_%s.png" % timestamp)

# --- Setup ---

func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.65, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 1.0, 1.0)
	env.ambient_light_energy = 0.4
	world_env.environment = env
	add_child(world_env)

func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)

func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 8.5, 7.5)
	add_child(camera)
	# Shift look target slightly toward camera so the full board is centered
	camera.look_at(Vector3(0.0, 0.0, 0.8), Vector3.UP)

# --- Board ---

func _generate_board() -> void:
	var generator := BoardGenerator.new()
	generator.generate(self)
