extends Node3D

## Phase 5: Roads, cities, robber, number tokens, full game loop.

const BoardGenerator = preload("res://scripts/board/board_generator.gd")
const HexGrid        = preload("res://scripts/board/hex_grid.gd")
const HexVertices    = preload("res://scripts/board/hex_vertices.gd")
const HexEdges       = preload("res://scripts/board/hex_edges.gd")
const VertexSlot     = preload("res://scripts/board/vertex_slot.gd")
const EdgeSlot       = preload("res://scripts/board/edge_slot.gd")
const GameState      = preload("res://scripts/game/game_state.gd")
const HUD            = preload("res://scripts/ui/hud.gd")

var _state: RefCounted
var _hud:   CanvasLayer
var _robber: MeshInstance3D  # single robber piece moved between tiles

const NUM_PLAYERS := 2


func _ready() -> void:
	print("=== [INIT] Hex Settlers — Phase 5 starting ===")
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_setup_game()
	_generate_board()
	_create_vertex_slots()
	_create_edge_slots()
	_create_robber()
	_create_hud()
	_refresh_hud()
	print("=== [DONE] Scene ready — children: %d ===" % get_child_count())

	if "--debug-screenshot" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		_take_screenshot()
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F11: _toggle_fullscreen()
			KEY_F12: _take_screenshot()
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---------------------------------------------------------------
# Setup
# ---------------------------------------------------------------

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
	print("[SETUP] Environment OK")


func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	print("[SETUP] Lighting OK")


func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 8.5, 7.5)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 0.8), Vector3.UP)
	print("[SETUP] Camera OK")


func _setup_game() -> void:
	_state = GameState.new()
	_state.init_players(NUM_PLAYERS)
	_state.turn_changed.connect(_on_turn_changed)
	_state.dice_rolled.connect(_on_dice_rolled)
	_state.game_won.connect(_on_game_won)
	_state.robber_moved.connect(_on_robber_moved)
	print("[SETUP] GameState OK")


# ---------------------------------------------------------------
# Board
# ---------------------------------------------------------------

func _generate_board() -> void:
	print("[BOARD] Generating board...")
	var generator := BoardGenerator.new()
	_state.tile_data = generator.generate(self)
	_state.init_robber()
	# Connect tile Area3D signals for robber (starts disabled)
	for key in _state.tile_data:
		var area: Area3D = _state.tile_data[key].area
		area.connect("input_event", _on_tile_input.bind(key))
	print("[BOARD] %d tiles, robber at '%s'. Children: %d" % [
		_state.tile_data.size(), _state.robber_tile_key, get_child_count()])


func _create_vertex_slots() -> void:
	print("[VERTEX] Creating 54 vertex slots...")
	var positions := HexVertices.get_all_positions(HexGrid.get_board_positions())
	for pos in positions:
		var slot := VertexSlot.new()
		slot.position = pos
		slot.slot_clicked.connect(_on_vertex_slot_clicked)
		add_child(slot)
	print("[VERTEX] %d slots. Children: %d" % [positions.size(), get_child_count()])


func _create_edge_slots() -> void:
	print("[EDGE] Creating 72 edge slots...")
	var edges := HexEdges.get_all_edges(HexGrid.get_board_positions())
	var added := 0
	for edge_data in edges:
		var slot := EdgeSlot.new()
		slot.position = edge_data.midpoint
		slot.v1 = edge_data.v1
		slot.v2 = edge_data.v2
		# Rotate bar to align with edge direction
		var dir: Vector3 = edge_data.direction
		slot.rotation.y = atan2(dir.x, dir.z)
		slot.slot_clicked.connect(_on_edge_slot_clicked)
		add_child(slot)
		added += 1
	print("[EDGE] %d road slots. Children: %d" % [added, get_child_count()])


func _create_robber() -> void:
	_robber = MeshInstance3D.new()
	_robber.name = "Robber"
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	_robber.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.10, 0.10)
	_robber.material_override = mat
	add_child(_robber)
	_update_robber_position()
	print("[ROBBER] Robber created at %s" % _state.robber_tile_key)


func _update_robber_position() -> void:
	if _state.robber_tile_key in _state.tile_data:
		var center: Vector3 = _state.tile_data[_state.robber_tile_key].center
		_robber.position = Vector3(center.x, 0.45, center.z)


# ---------------------------------------------------------------
# HUD
# ---------------------------------------------------------------

func _create_hud() -> void:
	_hud = HUD.new()
	_hud.roll_dice_pressed.connect(_on_roll_dice)
	_hud.end_turn_pressed.connect(_on_end_turn)
	add_child(_hud)
	print("[HUD] Created")


func _refresh_hud() -> void:
	if _hud == null or _state.players.is_empty():
		return
	_hud.refresh(_state.current_player(), _state.phase_name(), _state.last_roll)
	match _state.phase:
		GameState.Phase.SETUP:
			var p = _state.current_player()
			_hud.set_message("%s: place a free settlement  (%d remaining)" % [
				p.player_name, p.free_placements_left])
		GameState.Phase.ROLL:
			_hud.set_message("%s: press Roll Dice" % _state.current_player().player_name)
		GameState.Phase.BUILD:
			_hud.set_message(
				"%s rolled %d — place settlement/road/city or End Turn" % [
				_state.current_player().player_name, _state.last_roll])
		GameState.Phase.ROBBER_MOVE:
			_hud.set_message("%s: rolled 7 — click a tile to move the robber!" % [
				_state.current_player().player_name])
		GameState.Phase.GAME_OVER:
			var w = _state.players[_state.winner_index]
			_hud.set_message("*** %s WINS with %d VP! ***" % [w.player_name, w.victory_points])


# ---------------------------------------------------------------
# Signal handlers — vertex slots (settlements / cities)
# ---------------------------------------------------------------

func _on_vertex_slot_clicked(slot: Object) -> void:
	var player = _state.current_player()
	var pidx: int = _state.current_player_index

	if _state.phase == GameState.Phase.GAME_OVER:
		return

	# --- City upgrade: slot occupied by current player ---
	if slot.is_occupied and slot.owner_index == pidx and not slot.is_city:
		if _state.phase == GameState.Phase.BUILD:
			if _state.try_place_city(player, slot.position):
				slot.upgrade_to_city(player.color)
				_refresh_hud()
		return

	# --- New settlement: slot must be empty ---
	if slot.is_occupied:
		return

	if _state.phase != GameState.Phase.SETUP and _state.phase != GameState.Phase.BUILD:
		return

	if _state.try_place_settlement(player, slot.position):
		slot.occupy(player.color, pidx)
		_refresh_hud()
		if _state.phase == GameState.Phase.SETUP:
			_state.end_turn()
			_refresh_hud()

	print("[GAME] Post-placement phase: %s" % _state.phase_name())


# ---------------------------------------------------------------
# Signal handlers — edge slots (roads)
# ---------------------------------------------------------------

func _on_edge_slot_clicked(slot: Object) -> void:
	var player = _state.current_player()
	var pidx: int = _state.current_player_index

	if _state.phase != GameState.Phase.BUILD:
		_hud.set_message("You can only build roads during the BUILD phase.")
		return

	if _state.try_place_road(player, pidx, slot.v1, slot.v2):
		slot.occupy(player.color, pidx)
		_refresh_hud()
	else:
		_refresh_hud()


# ---------------------------------------------------------------
# Signal handlers — tile input (robber)
# ---------------------------------------------------------------

func _on_tile_input(key: String, _cam: Object, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if _state.phase != GameState.Phase.ROBBER_MOVE:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if key == _state.robber_tile_key:
			_hud.set_message("Robber is already here — pick a different tile.")
			return
		_set_tile_picking(false)
		_state.move_robber(key)
		_update_robber_position()
		_refresh_hud()


func _set_tile_picking(enabled: bool) -> void:
	for key in _state.tile_data:
		_state.tile_data[key].area.input_ray_pickable = enabled


# ---------------------------------------------------------------
# HUD button handlers
# ---------------------------------------------------------------

func _on_roll_dice() -> void:
	if _state.phase != GameState.Phase.ROLL:
		return
	_state.roll_dice()
	if _state.phase == GameState.Phase.ROBBER_MOVE:
		_set_tile_picking(true)  # enable tile clicks for robber placement
	_refresh_hud()


func _on_end_turn() -> void:
	if _state.phase != GameState.Phase.BUILD:
		return
	_state.end_turn()
	_refresh_hud()


func _on_turn_changed(_player: Object) -> void:
	_refresh_hud()


func _on_dice_rolled(_roll: int) -> void:
	_refresh_hud()


func _on_game_won(_winner: Object) -> void:
	_refresh_hud()


func _on_robber_moved(_key: String) -> void:
	_refresh_hud()


# ---------------------------------------------------------------
# Screenshot
# ---------------------------------------------------------------

func _take_screenshot() -> void:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://debug-screenshots/run_%s.png" % timestamp)
	img.save_png("res://debug-screenshots/latest_run.png")
	print("[SCREENSHOT] run_%s.png  +  latest_run.png" % timestamp)
