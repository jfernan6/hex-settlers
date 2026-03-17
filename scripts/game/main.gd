extends Node3D

## Phase 4: Full game loop — setup, dice, resource collection, VP, win detection.

# --- Preloads (required for command-line / debug-loop runs) ---
const BoardGenerator = preload("res://scripts/board/board_generator.gd")
const HexGrid        = preload("res://scripts/board/hex_grid.gd")
const HexVertices    = preload("res://scripts/board/hex_vertices.gd")
const VertexSlot     = preload("res://scripts/board/vertex_slot.gd")
const GameState      = preload("res://scripts/game/game_state.gd")
const HUD            = preload("res://scripts/ui/hud.gd")

# --- Game references ---
var _state: RefCounted   # GameState instance
var _hud:   CanvasLayer  # HUD instance

const NUM_PLAYERS := 2   # Change to 3 or 4 to add more players


func _ready() -> void:
	print("=== [INIT] Hex Settlers — Phase 4 starting ===")
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_setup_game()
	_generate_board()
	_create_vertex_slots()
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
			KEY_F11:
				_toggle_fullscreen()
			KEY_F12:
				_take_screenshot()
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		print("[DISPLAY] Windowed (maximized)")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("[DISPLAY] Fullscreen")


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
	print("[SETUP] Camera OK  (pos=%s)" % camera.position)


func _setup_game() -> void:
	_state = GameState.new()
	_state.init_players(NUM_PLAYERS)
	_state.turn_changed.connect(_on_turn_changed)
	_state.dice_rolled.connect(_on_dice_rolled)
	_state.game_won.connect(_on_game_won)
	print("[SETUP] GameState OK  (%d players)" % NUM_PLAYERS)


# ---------------------------------------------------------------
# Board
# ---------------------------------------------------------------

func _generate_board() -> void:
	print("[BOARD] Generating board...")
	var generator := BoardGenerator.new()
	_state.tile_data = generator.generate(self)
	print("[BOARD] Tile data stored: %d tiles  Scene children: %d" % [
		_state.tile_data.size(), get_child_count()])


func _create_vertex_slots() -> void:
	print("[VERTEX] Creating 54 vertex slots...")
	var positions := HexVertices.get_all_positions(HexGrid.get_board_positions())
	for pos in positions:
		var slot := VertexSlot.new()
		slot.position = pos
		slot.slot_clicked.connect(_on_vertex_slot_clicked)
		add_child(slot)
	print("[VERTEX] %d slots added  Scene children: %d" % [
		positions.size(), get_child_count()])


# ---------------------------------------------------------------
# HUD
# ---------------------------------------------------------------

func _create_hud() -> void:
	_hud = HUD.new()
	_hud.roll_dice_pressed.connect(_on_roll_dice)
	_hud.end_turn_pressed.connect(_on_end_turn)
	add_child(_hud)
	print("[HUD] Created and connected")


func _refresh_hud() -> void:
	if _hud == null:
		return
	_hud.refresh(_state.current_player(), _state.phase_name(), _state.last_roll)

	match _state.phase:
		GameState.Phase.SETUP:
			var p = _state.current_player()
			_hud.set_message(
				"%s: click a white dot to place a free settlement  (%d left)" % [
				p.player_name, p.free_placements_left])
		GameState.Phase.ROLL:
			_hud.set_message("%s: press Roll Dice" % _state.current_player().player_name)
		GameState.Phase.BUILD:
			_hud.set_message(
				"%s: rolled %d — build settlements or End Turn" % [
				_state.current_player().player_name, _state.last_roll])
		GameState.Phase.GAME_OVER:
			var winner = _state.players[_state.winner_index]
			_hud.set_message("*** %s WINS with %d VP! ***" % [
				winner.player_name, winner.victory_points])


# ---------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------

func _on_vertex_slot_clicked(slot: Object) -> void:
	var player = _state.current_player()

	if _state.phase == GameState.Phase.GAME_OVER:
		return

	if not player.can_build_settlement():
		_hud.set_message(
			"%s: not enough resources to build (need 1 Lumber, Brick, Wool, Grain)" % player.player_name)
		print("[GAME] %s cannot afford settlement" % player.player_name)
		return

	# Valid placement
	slot.occupy(player.color)
	_state.try_place_settlement(player, slot.position)
	_refresh_hud()

	# Auto-advance turn in SETUP after each placement
	if _state.phase == GameState.Phase.SETUP:
		_state.end_turn()
		_refresh_hud()

	print("[GAME] Post-placement state: %s" % _state.phase_name())


func _on_roll_dice() -> void:
	if _state.phase != GameState.Phase.ROLL:
		return
	_state.roll_dice()
	_refresh_hud()
	print("[GAME] After roll: phase=%s  last_roll=%d" % [_state.phase_name(), _state.last_roll])


func _on_end_turn() -> void:
	if _state.phase != GameState.Phase.BUILD:
		return
	_state.end_turn()
	_refresh_hud()


func _on_turn_changed(_player: Object) -> void:
	_refresh_hud()


func _on_dice_rolled(roll: int) -> void:
	print("[GAME] Dice signal received: %d" % roll)
	_refresh_hud()


func _on_game_won(winner: Object) -> void:
	_refresh_hud()
	print("[GAME] Game over — winner: %s" % winner.player_name)


# ---------------------------------------------------------------
# Screenshot
# ---------------------------------------------------------------

func _take_screenshot() -> void:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://debug-screenshots/run_%s.png" % timestamp)
	img.save_png("res://debug-screenshots/latest_run.png")
	print("[SCREENSHOT] run_%s.png  +  latest_run.png" % timestamp)
