extends Node3D

## Hex Settlers — main scene entry point.
## Sprint A+: dev cards, AI player, bank trade, longest road, largest army,
## logging (Log autoload), game event log (GameEvents autoload), unit tests.

const TestRunner = preload("res://scripts/tests/test_runner.gd")

const BoardGenerator    = preload("res://scripts/board/board_generator.gd")
const HexGrid           = preload("res://scripts/board/hex_grid.gd")
const HexVertices       = preload("res://scripts/board/hex_vertices.gd")
const HexEdges          = preload("res://scripts/board/hex_edges.gd")
const VertexSlot        = preload("res://scripts/board/vertex_slot.gd")
const EdgeSlot          = preload("res://scripts/board/edge_slot.gd")
const GameState         = preload("res://scripts/game/game_state.gd")
const HUD               = preload("res://scripts/ui/hud.gd")
const DebugController   = preload("res://scripts/game/debug_controller.gd")
const DevCards          = preload("res://scripts/game/dev_cards.gd")
const AIPlayer          = preload("res://scripts/game/ai_player.gd")
const PlayerData        = preload("res://scripts/player/player.gd")
const GodModePanel      = preload("res://scripts/ui/god_mode_panel.gd")

var _state: RefCounted
var _hud:   CanvasLayer
var _robber: MeshInstance3D
var _god_panel: CanvasLayer  # God Mode overlay (F4 to toggle)

var _vertex_slots: Array = []
var _edge_slots:   Array = []

const NUM_PLAYERS := 2

# God mode
var _god_forced_roll: int = 0

# AI turn safeguard — reset each turn, forces end_turn after >8 actions
var _ai_turn_actions: int = 0

# AI
var _ai_timer: Timer     # fires after short delay to let frame render before AI acts
const AI_DELAY := 0.5    # seconds between AI actions


func _ready() -> void:
	var args := OS.get_cmdline_user_args()

	# Unit tests run before scene setup
	if "--run-tests" in args:
		var runner := TestRunner.new()
		add_child(runner)
		runner.run_all()
		await get_tree().process_frame
		_take_screenshot()
		get_tree().quit()
		return

	Log.info("=== [INIT] Hex Settlers starting ===")
	GameEvents.clear()
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_setup_game()
	_generate_board()
	_create_vertex_slots()
	_create_edge_slots()
	_create_robber()
	_create_ai_timer()
	_create_hud()
	_create_god_panel()
	_refresh_hud()
	Log.info("=== [DONE] Scene ready — children: %d ===" % get_child_count())

	if "--debug-screenshot" in args:
		await get_tree().process_frame
		await get_tree().process_frame
		_take_screenshot()
		get_tree().quit()

	if "--debug-play" in args:
		var dc := DebugController.new()
		dc.init(self, _state)
		add_child(dc)
		await dc.run_debug_play()

	if "--debug-fullgame" in args:
		var dc := DebugController.new()
		dc.init(self, _state)
		add_child(dc)
		await dc.run_full_game()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F4:  _toggle_god_panel()       # Open/close god mode UI
			KEY_F11: _toggle_fullscreen()
			KEY_F12: _take_screenshot()
			KEY_F1:  _god_fill_resources()     # Quick: give current player 5 of everything
			KEY_F2:  _god_cycle_forced_roll()  # Quick: cycle forced dice roll
			KEY_F3:  _god_instant_win()        # Quick: set current player to 10 VP
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
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.11, 0.15)  # dark table
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.82, 0.86, 1.0)
	env.ambient_light_energy = 0.22
	world_env.environment = env
	add_child(world_env)
	Log.info("[SETUP] Environment OK (dark table)")


func _setup_lighting() -> void:
	# Key light — warm, casts shadows
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	key.light_energy     = 1.7
	key.light_color      = Color(1.0, 0.94, 0.84)
	key.shadow_enabled   = true
	add_child(key)

	# Fill light — cool, no shadow
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28.0, -155.0, 0.0)
	fill.light_energy     = 0.38
	fill.light_color      = Color(0.75, 0.84, 1.0)
	fill.shadow_enabled   = false
	add_child(fill)

	# Rim light — from behind
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(12.0, 95.0, 0.0)
	rim.light_energy     = 0.28
	rim.shadow_enabled   = false
	add_child(rim)

	Log.info("[SETUP] Lighting OK (3-point)")


func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 8.5, 7.5)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 0.8), Vector3.UP)
	print("[SETUP] Camera OK")


func _setup_game() -> void:
	_state = GameState.new()
	_state.init_players(NUM_PLAYERS)
	_state.init_dev_deck()
	_state.init_setup()
	# Mark player 2+ as AI (player 1 = human by default)
	for i in range(1, _state.players.size()):
		_state.players[i].is_ai = true
	_state.turn_changed.connect(_on_turn_changed)
	_state.dice_rolled.connect(_on_dice_rolled)
	_state.game_won.connect(_on_game_won)
	_state.robber_moved.connect(_on_robber_moved)
	_state.bonuses_changed.connect(_refresh_hud)
	_state.setup_sub_phase_changed.connect(_on_setup_sub_phase_changed)
	Log.info("[SETUP] GameState OK  (AI players: %d)" % \
		_state.players.filter(func(p): return p.is_ai).size())


func _create_ai_timer() -> void:
	_ai_timer = Timer.new()
	_ai_timer.wait_time = AI_DELAY
	_ai_timer.one_shot = true
	_ai_timer.timeout.connect(_process_ai_turn)
	add_child(_ai_timer)
	print("[SETUP] AI timer OK")


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
		_vertex_slots.append(slot)   # store for debug controller
	print("[VERTEX] %d slots. Children: %d" % [positions.size(), get_child_count()])


func _create_edge_slots() -> void:
	print("[EDGE] Creating 72 edge slots...")
	var edges := HexEdges.get_all_edges(HexGrid.get_board_positions())
	for edge_data in edges:
		var slot := EdgeSlot.new()
		slot.position = edge_data.midpoint
		slot.v1 = edge_data.v1
		slot.v2 = edge_data.v2
		var dir: Vector3 = edge_data.direction
		slot.rotation.y = atan2(dir.x, dir.z)
		slot.slot_clicked.connect(_on_edge_slot_clicked)
		add_child(slot)
		_edge_slots.append(slot)     # store for debug controller
	print("[EDGE] %d road slots. Children: %d" % [_edge_slots.size(), get_child_count()])


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
	_hud.buy_dev_card_pressed.connect(_try_buy_dev_card)
	add_child(_hud)
	print("[HUD] Created")


func _create_god_panel() -> void:
	_god_panel = GodModePanel.new()
	_god_panel.visible = false
	_god_panel.give_resource.connect(_gm_give_resource)
	_god_panel.build_free.connect(_gm_build_free)
	_god_panel.give_dev_card.connect(_gm_give_dev_card)
	_god_panel.force_roll.connect(_gm_force_roll)
	_god_panel.switch_player.connect(_gm_switch_player)
	_god_panel.instant_win.connect(_god_instant_win)
	_god_panel.panel_closed.connect(_toggle_god_panel)
	add_child(_god_panel)
	Log.info("[GOD] God Mode panel created — press F4 to open")


func _toggle_god_panel() -> void:
	_god_panel.visible = not _god_panel.visible
	if _god_panel.visible:
		var p = _state.current_player()
		_god_panel.set_player_name(p.player_name, p.color)


# ---------------------------------------------------------------
# God Mode signal handlers
# ---------------------------------------------------------------

func _gm_give_resource(res: int, amount: int) -> void:
	var player = _state.current_player()
	if amount < 0:
		player.resources[res] = max(0, player.resources.get(res, 0) + amount)
	else:
		player.add_resource(res, amount)
	_refresh_hud()
	Log.info("[GOD] %s: %s %+d (now %d)" % [
		player.player_name, PlayerData.RES_NAMES[res], amount, player.resources[res]])


func _gm_build_free(type: String) -> void:
	var player = _state.current_player()
	var pidx: int = _state.current_player_index
	match type:
		"settlement":
			var slot = AIPlayer.pick_setup_vertex(_vertex_slots, _state.tile_data, _state)
			if slot:
				slot.occupy(player.color, pidx)
				player.place_settlement_free(slot.position)
				_state._check_win()
				_refresh_hud()
				Log.info("[GOD] Free settlement at %s" % slot.position)
			else:
				_hud.set_message("[GOD] No valid vertex for settlement")
		"road":
			var road_slot = AIPlayer.pick_road(_edge_slots, player, _state)
			if road_slot:
				road_slot.occupy(player.color, pidx)
				player.free_roads += 1  # give one free road
				_state.try_place_road(player, pidx, road_slot.v1, road_slot.v2)
				_refresh_hud()
				Log.info("[GOD] Free road placed")
			else:
				_hud.set_message("[GOD] No connected road slot found")
		"city":
			for slot in _vertex_slots:
				if slot.is_occupied and slot.owner_index == pidx and not slot.is_city:
					slot.upgrade_to_city(player.color)
					_state.try_place_city(player, slot.position)
					_refresh_hud()
					Log.info("[GOD] Free city upgrade")
					return
			_hud.set_message("[GOD] No settlement to upgrade")
		"dev_card":
			if not _state.dev_deck.is_empty():
				player.resources = {0:1, 1:1, 2:1, 3:1, 4:1}  # temp give cost
				_state.buy_dev_card(player)
				player.resources = {0:0, 1:0, 2:0, 3:0, 4:0}  # clear cost
				_refresh_hud()
			else:
				_hud.set_message("[GOD] Dev deck is empty!")


func _gm_give_dev_card(card_type: int) -> void:
	var player = _state.current_player()
	if card_type == DevCards.Type.VP:
		player.victory_points += 1
		_state._check_win()
		_hud.set_message("[GOD] VP card — %s now has %d VP" % [player.player_name, player.victory_points])
	else:
		player.dev_cards.append(card_type)
		_hud.set_message("[GOD] Gave %s a %s card" % [player.player_name, DevCards.NAMES[card_type]])
	_refresh_hud()
	Log.info("[GOD] Gave dev card type %d to %s" % [card_type, player.player_name])


func _gm_force_roll(number: int) -> void:
	_god_forced_roll = number
	_hud.set_message("[GOD] Next dice roll forced to %d — press Roll Dice" % number)
	Log.info("[GOD] Forced roll set to %d" % number)


func _gm_switch_player(player_idx: int) -> void:
	if player_idx >= _state.players.size():
		_hud.set_message("[GOD] Player %d doesn't exist" % (player_idx + 1))
		return
	_state.current_player_index = player_idx
	var p = _state.current_player()
	_god_panel.set_player_name(p.player_name, p.color)
	_refresh_hud()
	Log.info("[GOD] Switched active player to %s" % p.player_name)


func _refresh_hud() -> void:
	if _hud == null or _state.players.is_empty():
		return
	_hud.refresh(_state.current_player(), _state.phase_name(), _state.last_roll, _state)
	match _state.phase:
		GameState.Phase.SETUP:
			var p = _state.current_player()
			if _state.setup_sub_phase == GameState.SetupSubPhase.PLACE_SETTLEMENT:
				_hud.set_message("%s: place your settlement  (round %d of 2)" % [
					p.player_name, _state.setup_round])
			else:
				_hud.set_message("%s: place a road adjacent to your new settlement" % p.player_name)
		GameState.Phase.ROLL:
			_hud.set_message("%s: press Roll Dice to produce resources" % _state.current_player().player_name)
		GameState.Phase.BUILD:
			var roll_str := " (rolled %d)" % _state.last_roll if _state.last_roll > 0 else ""
			if _state.current_player().is_ai:
				_hud.set_message("%s (AI) is taking their turn%s..." % [
					_state.current_player().player_name, roll_str])
			else:
				_hud.set_message("%s%s — click gold dots to build settlements, blue bars for roads, or use the buttons" % [
					_state.current_player().player_name, roll_str])
		GameState.Phase.ROBBER_MOVE:
			var p_name: String = _state.current_player().player_name
			if _state.current_player().is_ai:
				_hud.set_message("%s (AI) is moving the robber..." % p_name)
			else:
				_hud.set_message("%s: click any tile to move the robber there" % p_name)
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

	# --- Setup: free settlement placement ---
	if _state.phase == GameState.Phase.SETUP:
		if _state.setup_sub_phase != GameState.SetupSubPhase.PLACE_SETTLEMENT:
			_hud.set_message("Place a road first!")
			return
		if slot.is_occupied:
			return
		if not _state._respects_distance_rule(slot.position):
			_hud.set_message("Too close to another settlement!")
			return
		slot.occupy(player.color, pidx)
		_state.setup_settlement_placed(slot.position)
		_refresh_hud()
		return

	# --- City upgrade ---
	if slot.is_occupied and slot.owner_index == pidx and not slot.is_city:
		if _state.phase == GameState.Phase.BUILD:
			if _state.try_place_city(player, slot.position):
				slot.upgrade_to_city(player.color)
				_refresh_hud()
			elif player.city_positions.size() >= _state.MAX_CITIES:
				_hud.set_message("City limit reached (max %d cities)" % _state.MAX_CITIES)
			else:
				_hud.set_message("Need 2 Grain + 3 Ore to upgrade to city  (have Grain:%d Ore:%d)" % [
					player.resources.get(PlayerData.RES_GRAIN, 0),
					player.resources.get(PlayerData.RES_ORE, 0)])
		return

	# --- Paid settlement (BUILD phase) ---
	if slot.is_occupied:
		return
	if _state.phase != GameState.Phase.BUILD:
		return
	if _state.try_place_settlement(player, slot.position):
		slot.occupy(player.color, pidx)
		_refresh_hud()
	elif not _state._respects_distance_rule(slot.position):
		_hud.set_message("Too close to another settlement — must leave at least 1 road gap")
	else:
		_hud.set_message("Need 1 Lumber + 1 Brick + 1 Wool + 1 Grain to build a settlement")


# ---------------------------------------------------------------
# Signal handlers — edge slots (roads)
# ---------------------------------------------------------------

func _on_edge_slot_clicked(slot: Object) -> void:
	var player = _state.current_player()
	var pidx: int = _state.current_player_index

	var is_setup_road: bool = (_state.phase == GameState.Phase.SETUP and
		_state.setup_sub_phase == GameState.SetupSubPhase.PLACE_ROAD)

	if not is_setup_road and _state.phase != GameState.Phase.BUILD:
		if _state.phase == GameState.Phase.SETUP:
			_hud.set_message("Place your settlement first!")
		else:
			_hud.set_message("Roads can only be placed during your turn.")
		return

	if _state.try_place_road(player, pidx, slot.v1, slot.v2):
		slot.occupy(player.color, pidx)
		if is_setup_road:
			_state.setup_road_placed()
		_refresh_hud()
	elif not is_setup_road:
		# Give specific reason for failure
		var player_road_count: int = _state.roads.filter(
			func(r): return r.player_index == pidx).size()
		if player_road_count >= _state.MAX_ROADS:
			_hud.set_message("Road limit reached (max %d roads)" % _state.MAX_ROADS)
		elif not _state._road_is_connected(player, pidx, slot.v1, slot.v2):
			_hud.set_message("Road must connect to your existing settlements or roads")
		else:
			_hud.set_message("Need 1 Lumber + 1 Brick to build a road")


## Called when setup sub-phase changes (settlement→road) to trigger AI road placement.
func _on_setup_sub_phase_changed() -> void:
	_refresh_hud()
	if _state.current_player().is_ai and _state.phase == GameState.Phase.SETUP:
		_ai_timer.start()


## Returns the edge slot adjacent to last_setup_pos (for AI road placement in setup).
func _find_setup_road_slot() -> Object:
	var target: Vector3 = _state.last_setup_pos
	for slot in _edge_slots:
		if slot.is_occupied:
			continue
		var d1: float = Vector2(slot.v1.x - target.x, slot.v1.z - target.z).length()
		var d2: float = Vector2(slot.v2.x - target.x, slot.v2.z - target.z).length()
		if d1 < 0.15 or d2 < 0.15:
			return slot
	return null


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
	# Disable vertex/edge slots during ROBBER_MOVE so they don't interfere.
	# Tile picking itself is now handled by _unhandled_input() ray casting.
	for slot in _vertex_slots:
		slot.input_ray_pickable = not enabled
	for slot in _edge_slots:
		slot.input_ray_pickable = not enabled
	# Visual: make tiles glow when robber mode is active
	_set_tile_robber_highlight(enabled)
	# Make robber sphere pulse red
	_set_robber_glow(enabled)


## Tile emissive highlight — warm glow on all tiles during ROBBER_MOVE.
func _set_tile_robber_highlight(active: bool) -> void:
	for key in _state.tile_data:
		var mesh: MeshInstance3D = _state.tile_data[key].get("mesh")
		if mesh == null or not (mesh.material_override is StandardMaterial3D):
			continue
		var mat: StandardMaterial3D = mesh.material_override
		mat.emission_enabled = active
		if active:
			mat.emission = Color(0.6, 0.5, 0.1)   # warm yellow "click me" glow
			mat.emission_energy_multiplier = 0.4


## Robber sphere pulses red during ROBBER_MOVE.
func _set_robber_glow(active: bool) -> void:
	if _robber == null:
		return
	var mat: StandardMaterial3D = _robber.material_override
	if mat == null:
		return
	mat.emission_enabled = active
	if active:
		mat.emission = Color(0.9, 0.1, 0.1)
		mat.emission_energy_multiplier = 2.0


## Ray-cast mouse click → nearest tile center. Replaces Area3D tile picking.
func _unhandled_input(event: InputEvent) -> void:
	if _state.phase != GameState.Phase.ROBBER_MOVE:
		return
	if _state.current_player().is_ai:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir:    Vector3 = camera.project_ray_normal(mouse_pos)

	# Intersect with ground plane y=0 (tiles sit at y=0..0.25)
	if abs(ray_dir.y) < 0.001:
		return
	var t: float = -ray_origin.y / ray_dir.y
	if t < 0.0:
		return
	var hit: Vector3 = ray_origin + ray_dir * t

	# Find closest tile center within 1.5×HEX_SIZE radius
	var best_key := ""
	var best_dist: float = HexGrid.HEX_SIZE * 1.5
	for key in _state.tile_data:
		var c: Vector3 = _state.tile_data[key].center
		var d: float   = Vector2(hit.x - c.x, hit.z - c.z).length()
		if d < best_dist:
			best_dist = d
			best_key  = key

	if best_key == "":
		_hud.set_message("Click directly on a tile to place the robber")
		return
	if best_key == _state.robber_tile_key:
		_hud.set_message("Robber is already on that tile — choose a different one")
		return

	_set_tile_picking(false)
	_state.move_robber(best_key)
	_update_robber_position()
	_refresh_hud()


# ---------------------------------------------------------------
# HUD button handlers
# ---------------------------------------------------------------

func _on_roll_dice() -> void:
	if _state.phase != GameState.Phase.ROLL:
		return
	# God mode: override with forced roll if set
	if _god_forced_roll > 0:
		_state.last_roll = _god_forced_roll
		print("[GOD] Forced roll: %d" % _god_forced_roll)
		if _god_forced_roll == 7:
			_state.phase = GameState.Phase.ROBBER_MOVE
			_set_tile_picking(true)
		else:
			_state.debug_collect(_god_forced_roll)
			_state.phase = GameState.Phase.BUILD
		_state.dice_rolled.emit(_god_forced_roll)
	else:
		_state.roll_dice()
	if _state.phase == GameState.Phase.ROBBER_MOVE:
		_set_tile_picking(true)
	_refresh_hud()


func _on_end_turn() -> void:
	if _state.phase != GameState.Phase.BUILD:
		return
	_state.end_turn()
	_refresh_hud()


func _on_turn_changed(_player: Object) -> void:
	_ai_turn_actions = 0   # reset per-turn action counter
	_refresh_hud()
	if _state.current_player().is_ai and _state.phase != GameState.Phase.GAME_OVER:
		_ai_timer.start()


# ---------------------------------------------------------------
# AI turn processing
# ---------------------------------------------------------------

func _process_ai_turn() -> void:
	var player = _state.current_player()
	if not player.is_ai or _state.phase == GameState.Phase.GAME_OVER:
		return

	match _state.phase:
		GameState.Phase.SETUP:
			if _state.setup_sub_phase == GameState.SetupSubPhase.PLACE_SETTLEMENT:
				var slot = AIPlayer.pick_setup_vertex(_vertex_slots, _state.tile_data, _state)
				if slot:
					_on_vertex_slot_clicked(slot)
			else:  # PLACE_ROAD
				var road_slot: Object = _find_setup_road_slot()
				if road_slot:
					_on_edge_slot_clicked(road_slot)
				else:
					Log.error("[AI] No setup road slot found adjacent to %s" % _state.last_setup_pos)
		GameState.Phase.ROLL:
			_on_roll_dice()
			# If 7 was rolled, AI needs another timer tick to handle ROBBER_MOVE
			if _state.phase == GameState.Phase.ROBBER_MOVE:
				_ai_timer.start()
		GameState.Phase.ROBBER_MOVE:
			var key: String = AIPlayer.pick_robber_tile(_state, _state.current_player_index)
			if key != "":
				_set_tile_picking(false)
				_state.move_robber(key)
				_update_robber_position()
				_refresh_hud()
			_ai_timer.start()  # re-enter BUILD phase
		GameState.Phase.BUILD:
			var pidx: int = _state.current_player_index
			var decision: Dictionary = AIPlayer.decide_build(player, _state, _vertex_slots, _edge_slots)
			print("[AI] %s → %s" % [player.player_name, decision.action])
			match decision.action:
				"city":
					_on_vertex_slot_clicked(decision.params.slot)
				"settlement":
					_on_vertex_slot_clicked(decision.params.slot)
				"road":
					_on_edge_slot_clicked(decision.params.slot)
				"dev_card":
					_try_buy_dev_card()
				"play_card":
					_try_play_dev_card(player, decision.params.card, pidx)
				"bank_trade":
					_state.bank_trade(player, decision.params.give, decision.params.recv)
					_refresh_hud()
					_ai_timer.start()   # keep building this turn
					return
				"end_turn":
					_ai_turn_actions = 0
					_on_end_turn()
					return
			_refresh_hud()
			_ai_turn_actions += 1
			if _ai_turn_actions > 8:  # safeguard against infinite build loops
				Log.warn("[AI] %s exceeded max actions - forcing end turn" % player.player_name)
				_ai_turn_actions = 0
				_on_end_turn()
			elif _state.phase == GameState.Phase.BUILD and player.is_ai:
				_ai_timer.start()
			elif _state.phase == GameState.Phase.ROBBER_MOVE and player.is_ai:
				_ai_timer.start()  # Knight card triggered ROBBER_MOVE mid-turn


# ---------------------------------------------------------------
# Dev card handlers (human and AI)
# ---------------------------------------------------------------

func _try_buy_dev_card() -> void:
	var player = _state.current_player()
	if _state.dev_deck.is_empty():
		_hud.set_message("The development card deck is empty!")
		return
	if not _state._has_resources(player, _state.DEV_COST):
		_hud.set_message("Need 1 Ore + 1 Grain + 1 Wool to buy a dev card  (you have Ore:%d Grain:%d Wool:%d)" % [
			player.resources.get(PlayerData.RES_ORE, 0),
			player.resources.get(PlayerData.RES_GRAIN, 0),
			player.resources.get(PlayerData.RES_WOOL, 0)])
		return
	if _state.buy_dev_card(player):
		_hud.set_message("Dev card purchased!")
		_refresh_hud()


func _try_play_dev_card(player: RefCounted, card_type: int, pidx: int) -> void:
	match card_type:
		DevCards.Type.KNIGHT:
			if _state.play_knight(player, pidx):
				if player.is_ai:
					_ai_timer.start()   # process ROBBER_MOVE on next tick
				else:
					_set_tile_picking(true)
				_refresh_hud()
		DevCards.Type.ROAD_BUILDING:
			_state.play_road_building(player)
			_refresh_hud()
		DevCards.Type.YEAR_OF_PLENTY:
			# AI picks 2 most-needed resources; human gets ore+grain as default
			var r1 := AIPlayer.most_needed_resource(player) if player.is_ai else PlayerData.RES_ORE
			var r2 := PlayerData.RES_GRAIN
			_state.play_year_of_plenty(player, r1, r2)
			_refresh_hud()
		DevCards.Type.MONOPOLY:
			# AI monopolizes the resource opponents have most of
			var best_res := 0
			var best_amt := -1
			for r in [0, 1, 2, 3, 4]:
				var total := 0
				for i in _state.players.size():
					if i != _state.current_player_index:
						total += _state.players[i].resources.get(r, 0)
				if total > best_amt:
					best_amt = total
					best_res = r
			_state.play_monopoly(player, best_res)
			_refresh_hud()


func _on_dice_rolled(_roll: int) -> void:
	_refresh_hud()


func _on_game_won(_winner: Object) -> void:
	_refresh_hud()


func _on_robber_moved(_key: String) -> void:
	_refresh_hud()


# ---------------------------------------------------------------
# God mode (F1/F2/F3 during normal play)
# ---------------------------------------------------------------

func _god_fill_resources() -> void:
	var p = _state.current_player()
	for r in [0, 1, 2, 3, 4]:
		p.add_resource(r, 5)
	_refresh_hud()
	print("[GOD] Gave 5 of each resource to %s" % p.player_name)


func _god_cycle_forced_roll() -> void:
	# Cycles forced roll: off → 2 → 3 → … → 12 → off
	if _god_forced_roll == 0:
		_god_forced_roll = 2
	elif _god_forced_roll >= 12:
		_god_forced_roll = 0
	else:
		_god_forced_roll += 1
	var msg := "God roll OFF" if _god_forced_roll == 0 else "God roll LOCKED to %d" % _god_forced_roll
	_hud.set_message("[GOD] %s  (F2 to change)" % msg)
	print("[GOD] %s" % msg)


func _god_instant_win() -> void:
	var p = _state.current_player()
	var needed: int = 10 - p.victory_points
	if needed > 0:
		p.victory_points = 10
		_hud.set_message("[GOD] %s instant win!" % p.player_name)
		print("[GOD] Set %s to 10 VP" % p.player_name)
		_state._check_win()
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
