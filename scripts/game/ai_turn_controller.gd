class_name AITurnController
extends RefCounted

const AIPlayer = preload("res://scripts/game/ai_player.gd")

var _state
var _timer: Timer
var _action_count: int = 0

var _click_vertex_slot: Callable
var _click_edge_slot: Callable
var _find_setup_road_slot: Callable
var _roll_dice: Callable
var _set_tile_picking: Callable
var _update_robber_position: Callable
var _refresh_hud: Callable
var _try_buy_dev_card: Callable
var _try_play_dev_card: Callable
var _end_turn: Callable


func setup(state, timer: Timer, callbacks: Dictionary) -> void:
	_state = state
	_timer = timer
	_click_vertex_slot = callbacks["click_vertex_slot"]
	_click_edge_slot = callbacks["click_edge_slot"]
	_find_setup_road_slot = callbacks["find_setup_road_slot"]
	_roll_dice = callbacks["roll_dice"]
	_set_tile_picking = callbacks["set_tile_picking"]
	_update_robber_position = callbacks["update_robber_position"]
	_refresh_hud = callbacks["refresh_hud"]
	_try_buy_dev_card = callbacks["try_buy_dev_card"]
	_try_play_dev_card = callbacks["try_play_dev_card"]
	_end_turn = callbacks["end_turn"]


func on_turn_changed() -> void:
	_action_count = 0


func process_turn(vertex_slots: Array, edge_slots: Array) -> void:
	var player = _state.current_player()
	if not player.is_ai or _state.phase == _state.Phase.GAME_OVER:
		return

	match _state.phase:
		_state.Phase.SETUP:
			_process_setup(vertex_slots)
		_state.Phase.ROLL:
			_process_roll()
		_state.Phase.ROBBER_MOVE:
			_process_robber()
		_state.Phase.BUILD:
			_process_build(player, vertex_slots, edge_slots)


func _process_setup(vertex_slots: Array) -> void:
	if _state.setup_sub_phase == _state.SetupSubPhase.PLACE_SETTLEMENT:
		var slot = AIPlayer.pick_setup_vertex(vertex_slots, _state.tile_data, _state)
		if slot:
			_click_vertex_slot.call(slot)
		return

	var road_slot: Object = _find_setup_road_slot.call()
	if road_slot:
		_click_edge_slot.call(road_slot)
	else:
		Log.error("[AI] No setup road slot found adjacent to %s" % _state.last_setup_pos)


func _process_roll() -> void:
	_roll_dice.call()
	if _state.phase == _state.Phase.ROBBER_MOVE:
		_timer.start()


func _process_robber() -> void:
	var key: String = AIPlayer.pick_robber_tile(_state, _state.current_player_index)
	if key != "":
		_set_tile_picking.call(false)
		_state.move_robber(key)
		_update_robber_position.call()
		_refresh_hud.call()
	_timer.start()


func _process_build(player, vertex_slots: Array, edge_slots: Array) -> void:
	var pidx: int = _state.current_player_index
	var decision: Dictionary = AIPlayer.decide_build(player, _state, vertex_slots, edge_slots)
	print("[AI] %s → %s" % [player.player_name, decision.action])

	match decision.action:
		"city", "settlement":
			_click_vertex_slot.call(decision.params.slot)
		"road":
			_click_edge_slot.call(decision.params.slot)
		"dev_card":
			_try_buy_dev_card.call()
		"play_card":
			_try_play_dev_card.call(player, decision.params.card, pidx)
		"bank_trade":
			_state.bank_trade(player, decision.params.give, decision.params.recv)
			_refresh_hud.call()
			_timer.start()
			return
		"end_turn":
			_action_count = 0
			_end_turn.call()
			return

	_refresh_hud.call()
	_action_count += 1
	if _action_count > 8:
		Log.warn("[AI] %s exceeded max actions - forcing end turn" % player.player_name)
		_action_count = 0
		_end_turn.call()
	elif _state.phase == _state.Phase.BUILD and player.is_ai:
		_timer.start()
	elif _state.phase == _state.Phase.ROBBER_MOVE and player.is_ai:
		_timer.start()
