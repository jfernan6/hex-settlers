extends Node3D

## Hex Settlers — main scene entry point.
## Sprint A+: dev cards, AI player, bank trade, longest road, largest army,
## logging (Log autoload), game event log (GameEvents autoload), unit tests.

const TestRunner = preload("res://scripts/tests/test_runner.gd")

const BoardPresenter    = preload("res://scripts/board/board_presenter.gd")
const GameState         = preload("res://scripts/game/game_state.gd")
const HUD               = preload("res://scripts/ui/hud.gd")
const DebugController   = preload("res://scripts/game/debug_controller.gd")
const AITurnController  = preload("res://scripts/game/ai_turn_controller.gd")
const GameplayActionController = preload("res://scripts/game/gameplay_action_controller.gd")
const GamePhaseMessaging = preload("res://scripts/game/game_phase_messaging.gd")
const GodModePanel      = preload("res://scripts/ui/god_mode_panel.gd")
const ResourceFeedbackController = preload("res://scripts/game/resource_feedback_controller.gd")
const GodModeController = preload("res://scripts/game/god_mode_controller.gd")

var _state: RefCounted
var _hud:   CanvasLayer
var _board_presenter: Node3D
var _god_panel: CanvasLayer  # God Mode overlay (F4 to toggle)
var _camera: Camera3D

var _vertex_slots: Array = []
var _edge_slots:   Array = []

const NUM_PLAYERS := 2

# AI turn safeguard — reset each turn, forces end_turn after >8 actions
var _ai_timer: Timer     # fires after short delay to let frame render before AI acts
const AI_DELAY := 0.5    # seconds between AI actions
var _ai_turn := AITurnController.new()
var _actions := GameplayActionController.new()
var _resource_feedback := ResourceFeedbackController.new()
var _god_mode := GodModeController.new()
var _phase_messaging := GamePhaseMessaging.new()

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

	# Procedural sky — the key DirectionalLight3D becomes the visible sun disc
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.15, 0.35, 0.72)  # deep blue zenith
	sky_mat.sky_horizon_color    = Color(0.60, 0.76, 0.92)  # pale horizon haze
	sky_mat.sky_curve            = 0.12
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.ground_bottom_color  = Color(0.08, 0.06, 0.05)  # dark earth below horizon
	sky_mat.ground_horizon_color = Color(0.38, 0.42, 0.46)
	sky_mat.ground_curve         = 0.02
	sky_mat.sun_angle_max        = 35.0   # how wide the sun glow spreads
	sky_mat.sun_curve            = 0.12   # lower = sharper/smaller sun disc

	var sky := Sky.new()
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# Let sky colour drive ambient — objects pick up natural blue-sky fill
	env.ambient_light_source          = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_energy          = 0.55

	# Atmospheric fog — matches sky haze rather than dark-room fog
	env.fog_enabled     = true
	env.fog_light_color = Color(0.52, 0.64, 0.82)
	env.fog_density     = 0.006   # light haze — horizon softened by shader edge-fade instead

	world_env.environment = env
	add_child(world_env)
	Log.info("[SETUP] Environment OK (procedural sky + sun)")


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

	# 4th light — warm amber glow from below (board ambiance)
	var board_glow := DirectionalLight3D.new()
	board_glow.rotation_degrees = Vector3(60.0, 0.0, 0.0)
	board_glow.light_energy = 0.18
	board_glow.light_color  = Color(0.95, 0.78, 0.55)
	board_glow.shadow_enabled = false
	add_child(board_glow)

	Log.info("[SETUP] Lighting OK (4-point)")


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 10.0, 9.0)  # zoomed out for larger board (1.40x scale)
	_camera.fov = 62.0                           # wider FOV for cinematic feel
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.0, 0.5), Vector3.UP)
	Log.info("[SETUP] Camera OK (fov=62, pos=%s)" % _camera.position)


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
	_state.resource_payouts_generated.connect(_on_resource_payouts_generated)
	_resource_feedback.setup(self, _state, null, null)
	_god_mode.setup(_state, Callable(self, "_refresh_hud"), null, _resource_feedback)
	_actions.setup(_state, _resource_feedback, {
		"refresh_hud": Callable(self, "_refresh_hud"),
		"queue_ai_followup": Callable(self, "_queue_ai_followup"),
		"forced_roll_provider": Callable(_god_mode, "forced_roll"),
	})
	Log.info("[SETUP] GameState OK  (AI players: %d)" % \
		_state.players.filter(func(p): return p.is_ai).size())


func _create_ai_timer() -> void:
	_ai_timer = Timer.new()
	_ai_timer.wait_time = AI_DELAY
	_ai_timer.one_shot = true
	_ai_timer.timeout.connect(_process_ai_turn)
	add_child(_ai_timer)
	_ai_turn.setup(_state, _ai_timer, {
		"click_vertex_slot": Callable(self, "_on_vertex_slot_clicked"),
		"click_edge_slot": Callable(self, "_on_edge_slot_clicked"),
		"find_setup_road_slot": Callable(self, "_find_setup_road_slot"),
		"roll_dice": Callable(self, "_on_roll_dice"),
		"set_tile_picking": Callable(self, "_set_tile_picking"),
		"update_robber_position": Callable(self, "_update_robber_position"),
		"refresh_hud": Callable(self, "_refresh_hud"),
		"try_buy_dev_card": Callable(self, "_try_buy_dev_card"),
		"try_play_dev_card": Callable(self, "_try_play_dev_card"),
		"end_turn": Callable(self, "_on_end_turn"),
	})
	print("[SETUP] AI timer OK")


# ---------------------------------------------------------------
# Board
# ---------------------------------------------------------------

func _generate_board() -> void:
	_board_presenter = BoardPresenter.new()
	_board_presenter.setup(_state, _camera)
	_board_presenter.vertex_clicked.connect(_on_vertex_slot_clicked)
	_board_presenter.edge_clicked.connect(_on_edge_slot_clicked)
	_board_presenter.tile_clicked.connect(_on_board_tile_clicked)
	add_child(_board_presenter)
	_board_presenter.build_board()
	_vertex_slots = _board_presenter.get_vertex_slots()
	_edge_slots = _board_presenter.get_edge_slots()
	_state.init_robber()
	_board_presenter.create_robber()
	_resource_feedback.update_bindings(_hud, _board_presenter)
	_actions.update_bindings(_hud, _board_presenter)
	_god_mode.update_bindings(_hud, _god_panel, _vertex_slots, _edge_slots)
	print("[BOARD] %d tiles, robber at '%s'. Children: %d" % [
		_state.tile_data.size(), _state.robber_tile_key, get_child_count()])


func stop_ai_turn_timer() -> void:
	if _ai_timer != null:
		_ai_timer.stop()


func _queue_ai_followup() -> void:
	if _ai_timer != null:
		_ai_timer.start()


func get_vertex_slots() -> Array:
	return _vertex_slots


func get_edge_slots() -> Array:
	return _edge_slots


func click_vertex_slot(slot: Object) -> void:
	_actions.click_vertex_slot(slot)


func click_edge_slot(slot: Object) -> void:
	_actions.click_edge_slot(slot)


func find_setup_road_slot() -> Object:
	return _actions.find_setup_road_slot()


func try_play_dev_card_for(player: RefCounted, card_type: int, pidx: int, target_res: int = -1) -> void:
	_actions.try_play_dev_card(player, card_type, pidx, target_res)


func set_tile_picking_enabled(enabled: bool) -> void:
	_actions.set_tile_picking(enabled)


func refresh_robber_position() -> void:
	_actions.update_robber_position()


func refresh_hud_view() -> void:
	_refresh_hud()


func end_current_turn() -> void:
	_actions.end_turn()


func _update_robber_position() -> void:
	_actions.update_robber_position()


# ---------------------------------------------------------------
# HUD
# ---------------------------------------------------------------

func _create_hud() -> void:
	_hud = HUD.new()
	_hud.roll_dice_pressed.connect(_on_roll_dice)
	_hud.end_turn_pressed.connect(_on_end_turn)
	_hud.buy_dev_card_pressed.connect(_try_buy_dev_card)
	# Sprint 1C: dev card hand signals
	_hud.play_dev_card_requested.connect(_on_play_dev_card_requested)
	_hud.year_of_plenty_chosen.connect(_on_year_of_plenty_chosen)
	_hud.monopoly_chosen.connect(_on_monopoly_chosen)
	# Sprint 2C: trade signal
	_hud.trade_proposed.connect(_on_trade_proposed)
	_hud.robber_victim_chosen.connect(_on_robber_victim_chosen)
	_hud.robber_card_chosen.connect(_on_robber_card_chosen)
	add_child(_hud)
	_resource_feedback.update_bindings(_hud, _board_presenter)
	_actions.update_bindings(_hud, _board_presenter)
	_god_mode.update_bindings(_hud, _god_panel, _vertex_slots, _edge_slots)
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
	_god_mode.update_bindings(_hud, _god_panel, _vertex_slots, _edge_slots)
	Log.info("[GOD] God Mode panel created — press F4 to open")


func _toggle_god_panel() -> void:
	_god_mode.toggle_panel()


# ---------------------------------------------------------------
# God Mode signal handlers
# ---------------------------------------------------------------

func _gm_give_resource(res: int, amount: int) -> void:
	_god_mode.give_resource(res, amount)


func _gm_build_free(type: String) -> void:
	_god_mode.build_free(type)


func _gm_give_dev_card(card_type: int) -> void:
	_god_mode.give_dev_card(card_type)


func _gm_force_roll(number: int) -> void:
	_god_mode.force_roll(number)


func _gm_switch_player(player_idx: int) -> void:
	_god_mode.switch_player(player_idx)


func _refresh_hud() -> void:
	if _hud == null or _state.players.is_empty():
		return
	_hud.refresh(_state.current_player(), _state.phase_name(), _state.last_roll, _state)
	_refresh_board_affordances()
	_hud.set_phase_prompt(_phase_messaging.hud_message_for(_state))


func _refresh_board_affordances() -> void:
	if _board_presenter != null:
		_board_presenter.refresh_affordances()


# ---------------------------------------------------------------
# Signal handlers — vertex slots (settlements / cities)
# ---------------------------------------------------------------

func _on_vertex_slot_clicked(slot: Object) -> void:
	_actions.click_vertex_slot(slot)


# ---------------------------------------------------------------
# Signal handlers — edge slots (roads)
# ---------------------------------------------------------------

func _on_edge_slot_clicked(slot: Object) -> void:
	_actions.click_edge_slot(slot)


## Called when setup sub-phase changes (settlement→road) to trigger AI road placement.
func _on_setup_sub_phase_changed() -> void:
	_refresh_hud()
	if _state.current_player().is_ai and _state.phase == GameState.Phase.SETUP:
		_ai_timer.start()


## Returns the edge slot adjacent to last_setup_pos (for AI road placement in setup).
func _find_setup_road_slot() -> Object:
	return _actions.find_setup_road_slot()


func _set_tile_picking(enabled: bool) -> void:
	_actions.set_tile_picking(enabled)


func _on_board_tile_clicked(key: String) -> void:
	_actions.on_board_tile_clicked(key)


# ---------------------------------------------------------------
# HUD button handlers
# ---------------------------------------------------------------

func _on_roll_dice() -> void:
	_actions.roll_dice()


func _on_end_turn() -> void:
	_actions.end_turn()


func _on_turn_changed(_player: Object) -> void:
	_ai_turn.on_turn_changed()
	_refresh_hud()
	if _hud != null and _state.phase != GameState.Phase.GAME_OVER:
		var line := "%s begins %s." % [_state.current_player().player_name, _state.phase_name().to_lower()]
		_hud.push_activity(line, "info", false)
	if _state.current_player().is_ai and _state.phase != GameState.Phase.GAME_OVER:
		_ai_timer.start()


# ---------------------------------------------------------------
# AI turn processing
# ---------------------------------------------------------------

func _process_ai_turn() -> void:
	_ai_turn.process_turn(_vertex_slots, _edge_slots)


# ---------------------------------------------------------------
# Dev card handlers (human and AI)
# ---------------------------------------------------------------

func _try_buy_dev_card() -> void:
	_actions.buy_dev_card()


## Sprint 1C: r1/r2 are set by human via picker (>= 0) or -1 to use AI defaults.
func _try_play_dev_card(player: RefCounted, card_type: int, pidx: int,
		r1: int = -1, r2: int = -1) -> void:
	_actions.try_play_dev_card(player, card_type, pidx, r1, r2)


# Sprint 1C: human pressed a dev card button in the hand display
func _on_play_dev_card_requested(card_type: int) -> void:
	_actions.on_play_dev_card_requested(card_type)


func _on_year_of_plenty_chosen(r1: int, r2: int) -> void:
	_actions.on_year_of_plenty_chosen(r1, r2)


func _on_monopoly_chosen(res: int) -> void:
	_actions.on_monopoly_chosen(res)


# Sprint 2C: trade proposal from human player
func _on_trade_proposed(offer: Dictionary, want: Dictionary, to_player_idx: int) -> void:
	_actions.on_trade_proposed(offer, want, to_player_idx)


func _on_robber_victim_chosen(victim_idx: int) -> void:
	_actions.on_robber_victim_chosen(victim_idx)


func _on_robber_card_chosen(victim_idx: int, resource: int) -> void:
	_actions.on_robber_card_chosen(victim_idx, resource)


func _on_dice_rolled(_roll: int) -> void:
	_refresh_hud()


func _on_resource_payouts_generated(payouts: Array) -> void:
	_resource_feedback.record_payouts(payouts)


func _on_game_won(_winner: Object) -> void:
	_refresh_hud()
	if _hud != null:
		var winner = _state.players[_state.winner_index] if _state.winner_index >= 0 else _state.current_player()
		_hud.push_activity("%s wins with %d VP!" % [winner.player_name, winner.victory_points], "success")


func _on_robber_moved(_key: String) -> void:
	_refresh_hud()


# ---------------------------------------------------------------
# God mode (F1/F2/F3 during normal play)
# ---------------------------------------------------------------

func _god_fill_resources() -> void:
	_god_mode.fill_resources()


func _god_cycle_forced_roll() -> void:
	_god_mode.cycle_forced_roll()


func _god_instant_win() -> void:
	_god_mode.instant_win()


# ---------------------------------------------------------------
# Screenshot
# ---------------------------------------------------------------

func _take_screenshot() -> void:
	var dt  := Time.get_datetime_dict_from_system()
	var ts  := "%04d%02d%02d_%02d%02d%02d" % [
		dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	var img := get_viewport().get_texture().get_image()
	# Manual F12 shots and startup test shots go to the flat screenshots dir.
	img.save_png(Log.SCREENSHOT_DIR + "manual_%s.png" % ts)
	img.save_png(Log.SCREENSHOT_DIR + "latest.png")   # always-current for quick inspection
	print("[SCREENSHOT] debug/screenshots/manual_%s.png  +  latest.png" % ts)
