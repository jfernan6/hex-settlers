extends Node3D

# Preload all scripts — class_name global registry only works in editor mode,
# so command-line / debug runs require explicit preload() for cross-script references.
const BoardGenerator = preload("res://scripts/board/board_generator.gd")
const HexGrid        = preload("res://scripts/board/hex_grid.gd")
const HexVertices    = preload("res://scripts/board/hex_vertices.gd")
const VertexSlot     = preload("res://scripts/board/vertex_slot.gd")

func _ready() -> void:
	print("=== [INIT] Hex Settlers — Phase 3 starting ===")
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_generate_board()
	_create_vertex_slots()
	print("=== [DONE] Scene ready — total children: %d ===" % get_child_count())

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
	var img := get_viewport().get_texture().get_image()
	# Timestamped copy for history
	img.save_png("res://debug-screenshots/run_%s.png" % timestamp)
	# Fixed filename so Claude can always read res://debug-screenshots/latest_run.png directly
	img.save_png("res://debug-screenshots/latest_run.png")
	print("[SCREENSHOT] run_%s.png  +  latest_run.png" % timestamp)

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
	print("[SETUP] Environment OK  (bg=sky-blue, ambient=0.4)")

func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	print("[SETUP] Lighting OK     (DirectionalLight3D energy=1.5, shadows=true)")

func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 8.5, 7.5)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 0.8), Vector3.UP)
	print("[SETUP] Camera OK       (pos=%s  look_at=(0,0,0.8))" % camera.position)

# --- Board ---

func _generate_board() -> void:
	print("[BOARD] Starting board generation...")
	var generator := BoardGenerator.new()
	generator.generate(self)
	print("[BOARD] Tiles spawned. Scene children: %d" % get_child_count())


func _create_vertex_slots() -> void:
	print("[VERTEX] Creating vertex slots...")
	var positions := HexVertices.get_all_positions(HexGrid.get_board_positions())
	for pos in positions:
		var slot := VertexSlot.new()
		slot.position = pos
		slot.slot_clicked.connect(_on_vertex_slot_clicked)
		add_child(slot)
	print("[VERTEX] %d vertex slots added. Scene children: %d" % [positions.size(), get_child_count()])


# --- Player interaction ---

func _on_vertex_slot_clicked(slot) -> void:
	slot.occupy(Color(0.85, 0.12, 0.12))  # Player 1 = red for now
	print("[GAME] Settlement placed → total children: %d" % get_child_count())
