class_name GodModeController
extends RefCounted

const AIPlayer = preload("res://scripts/game/ai_player.gd")
const DevCards = preload("res://scripts/game/dev_cards.gd")
const PlayerData = preload("res://scripts/player/player.gd")

var _state
var _hud
var _god_panel
var _resource_feedback
var _vertex_slots: Array = []
var _edge_slots: Array = []
var _refresh_hud: Callable
var _forced_roll: int = 0


func setup(state, refresh_hud: Callable, hud, resource_feedback) -> void:
	_state = state
	_refresh_hud = refresh_hud
	_hud = hud
	_resource_feedback = resource_feedback


func update_bindings(hud, god_panel, vertex_slots: Array, edge_slots: Array) -> void:
	_hud = hud
	_god_panel = god_panel
	_vertex_slots = vertex_slots
	_edge_slots = edge_slots


func toggle_panel() -> void:
	if _god_panel == null:
		return
	_god_panel.visible = not _god_panel.visible
	if _god_panel.visible:
		_sync_panel_player()


func give_resource(res: int, amount: int) -> void:
	var player = _state.current_player()
	var applied: int = _state.debug_adjust_resource(_state.current_player_index, res, amount)
	_refresh_hud.call()
	if applied > 0 and _resource_feedback != null:
		_resource_feedback.play_debug_resource_feedback(
			res,
			applied,
			"[GOD] +%d %s" % [applied, PlayerData.RES_NAMES[res]])
	Log.info("[GOD] %s: %s %+d (now %d)" % [
		player.player_name, PlayerData.RES_NAMES[res], applied, player.resources[res]])


func build_free(type: String) -> void:
	var player = _state.current_player()
	var pidx: int = _state.current_player_index
	match type:
		"settlement":
			var slot = AIPlayer.pick_setup_vertex(_vertex_slots, _state.tile_data, _state)
			if slot:
				slot.occupy(player.color, pidx)
				player.place_settlement_free(slot.position)
				_state.force_check_win()
				_refresh_hud.call()
				Log.info("[GOD] Free settlement at %s" % slot.position)
			else:
				_message("[GOD] No valid vertex for settlement")
		"road":
			var road_slot = AIPlayer.pick_road(_edge_slots, _vertex_slots, player, _state)
			if road_slot:
				road_slot.occupy(player.color, pidx)
				player.free_roads += 1
				_state.try_place_road(player, pidx, road_slot.v1, road_slot.v2)
				_refresh_hud.call()
				Log.info("[GOD] Free road placed")
			else:
				_message("[GOD] No connected road slot found")
		"city":
			for slot in _vertex_slots:
				if slot.is_occupied and slot.owner_index == pidx and not slot.is_city:
					slot.upgrade_to_city(player.color)
					_state.try_place_city(player, slot.position)
					_refresh_hud.call()
					Log.info("[GOD] Free city upgrade")
					return
			_message("[GOD] No settlement to upgrade")
		"dev_card":
			if _state.dev_deck.is_empty():
				_message("[GOD] Dev deck is empty!")
				return
			if _state.debug_draw_dev_card(pidx):
				_refresh_hud.call()
				_message("[GOD] Drew the top dev card for %s." % player.player_name)
			else:
				_message("[GOD] Could not draw a dev card.")


func give_dev_card(card_type: int) -> void:
	var player = _state.current_player()
	if not _state.debug_take_dev_card(_state.current_player_index, card_type):
		_message("[GOD] No %s card left in the dev deck." % DevCards.NAMES[card_type])
		return
	if card_type == DevCards.Type.VP:
		_message("[GOD] VP card — %s now has %d VP" % [player.player_name, player.victory_points])
	else:
		_message("[GOD] Gave %s a %s card" % [player.player_name, DevCards.NAMES[card_type]])
	_refresh_hud.call()
	Log.info("[GOD] Gave dev card type %d to %s" % [card_type, player.player_name])


func force_roll(number: int) -> void:
	_forced_roll = number
	_message("[GOD] Next dice roll forced to %d — press Roll Dice" % number)
	Log.info("[GOD] Forced roll set to %d" % number)


func switch_player(player_idx: int) -> void:
	if player_idx >= _state.players.size():
		_message("[GOD] Player %d doesn't exist" % (player_idx + 1))
		return
	_state.current_player_index = player_idx
	_sync_panel_player()
	_refresh_hud.call()
	Log.info("[GOD] Switched active player to %s" % _state.current_player().player_name)


func fill_resources() -> void:
	var player = _state.current_player()
	for r in [0, 1, 2, 3, 4]:
		_state.debug_adjust_resource(_state.current_player_index, r, 5)
	_refresh_hud.call()
	Log.info("[GOD] Gave 5 of each resource to %s" % player.player_name)


func cycle_forced_roll() -> void:
	if _forced_roll == 0:
		_forced_roll = 2
	elif _forced_roll < 12:
		_forced_roll += 1
	else:
		_forced_roll = 0

	if _forced_roll == 0:
		_message("[GOD] Forced roll cleared")
	else:
		_message("[GOD] Forced roll set to %d" % _forced_roll)
	Log.info("[GOD] Cycle forced roll -> %d" % _forced_roll)


func instant_win() -> void:
	var player = _state.current_player()
	player.victory_points = 10
	_state.force_check_win()
	_refresh_hud.call()
	_message("[GOD] %s instantly wins with 10 VP!" % player.player_name)
	Log.info("[GOD] Instant win for %s" % player.player_name)


func forced_roll() -> int:
	return _forced_roll


func _sync_panel_player() -> void:
	if _god_panel == null:
		return
	var player = _state.current_player()
	_god_panel.set_player_name(player.player_name, player.color)


func _message(text: String) -> void:
	if _hud != null:
		if _hud.has_method("push_activity"):
			_hud.push_activity(text, "info", true)
		else:
			_hud.set_message(text)
