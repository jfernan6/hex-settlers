class_name GameplayActionController
extends RefCounted

const AIPlayer = preload("res://scripts/game/ai_player.gd")
const DevCards = preload("res://scripts/game/dev_cards.gd")
const PlayerData = preload("res://scripts/player/player.gd")

var _state
var _hud
var _board_presenter
var _resource_feedback
var _refresh_hud: Callable
var _queue_ai_followup: Callable
var _forced_roll_provider: Callable


func setup(state, resource_feedback, callbacks: Dictionary) -> void:
	_state = state
	_resource_feedback = resource_feedback
	_refresh_hud = callbacks["refresh_hud"]
	_queue_ai_followup = callbacks["queue_ai_followup"]
	_forced_roll_provider = callbacks["forced_roll_provider"]


func update_bindings(hud, board_presenter) -> void:
	_hud = hud
	_board_presenter = board_presenter


func click_vertex_slot(slot: Object) -> void:
	var player = _state.current_player()
	var pidx: int = _state.current_player_index

	if _state.phase == _state.Phase.GAME_OVER:
		return

	if _state.phase == _state.Phase.SETUP:
		if _state.setup_sub_phase != _state.SetupSubPhase.PLACE_SETTLEMENT:
			_show_message("Place a road first!", "warn")
			return
		if slot.is_occupied:
			return
		if not _state.can_place_setup_settlement_at(slot.position):
			_show_message("Too close to another settlement!", "warn")
			return
		slot.occupy(player.color, pidx)
		_state.setup_settlement_placed(slot.position)
		_refresh_hud.call()
		_show_message("Opening settlement placed. Add a connecting road.", "success")
		return

	if slot.is_occupied and slot.owner_index == pidx and not slot.is_city:
		if _state.phase == _state.Phase.BUILD:
			if _state.try_place_city(player, slot.position):
				slot.upgrade_to_city(player.color)
				_refresh_hud.call()
				_show_message("City upgraded.", "success")
			elif player.city_positions.size() >= _state.MAX_CITIES:
				_show_message("City limit reached (max %d cities)." % _state.MAX_CITIES, "warn")
			else:
				_show_message("Need 2 Grain + 3 Ore to upgrade to a city (have Grain:%d Ore:%d)." % [
					player.resources.get(PlayerData.RES_GRAIN, 0),
					player.resources.get(PlayerData.RES_ORE, 0)], "warn")
		return

	if slot.is_occupied or _state.phase != _state.Phase.BUILD:
		return

	if _state.try_place_settlement(player, slot.position):
		slot.occupy(player.color, pidx)
		_refresh_hud.call()
		_show_message("Settlement built.", "success")
	elif not _state.passes_distance_rule(slot.position):
		_show_message("Too close to another settlement. Leave at least one road gap.", "warn")
	elif not _state.can_connect_settlement_at(pidx, slot.position):
		_show_message("Settlement must connect to one of your roads.", "warn")
	else:
		_show_message("Need 1 Lumber + 1 Brick + 1 Wool + 1 Grain to build a settlement.", "warn")


func click_edge_slot(slot: Object) -> void:
	var player = _state.current_player()
	var pidx: int = _state.current_player_index
	var is_setup_road: bool = (_state.phase == _state.Phase.SETUP and
		_state.setup_sub_phase == _state.SetupSubPhase.PLACE_ROAD)

	if not is_setup_road and _state.phase != _state.Phase.BUILD:
		if _state.phase == _state.Phase.SETUP:
			_show_message("Place your settlement first!", "warn")
		else:
			_show_message("Roads can only be placed during your turn.", "warn")
		return

	if _state.try_place_road(player, pidx, slot.v1, slot.v2):
		slot.occupy(player.color, pidx)
		if is_setup_road:
			_state.setup_road_placed()
		_refresh_hud.call()
		_show_message("Opening road placed." if is_setup_road else "Road built.", "success")
		return

	if is_setup_road:
		return

	var player_road_count: int = _state.roads.filter(func(r): return r.player_index == pidx).size()
	var connected_road: bool = _state.can_connect_road_at(pidx, slot.v1, slot.v2)
	if player_road_count >= _state.MAX_ROADS:
		_show_message("Road limit reached (max %d roads)." % _state.MAX_ROADS, "warn")
	elif not connected_road:
		_show_message("Road must connect to your existing settlements or roads.", "warn")
	else:
		_show_message("Need 1 Lumber + 1 Brick to build a road.", "warn")


func find_setup_road_slot() -> Object:
	if _board_presenter != null:
		return _board_presenter.find_setup_road_slot(_state.last_setup_pos)
	return null


func set_tile_picking(enabled: bool) -> void:
	if _board_presenter != null:
		_board_presenter.set_tile_picking(enabled)


func update_robber_position() -> void:
	if _board_presenter != null:
		_board_presenter.update_robber_position()


func on_board_tile_clicked(key: String) -> void:
	if key == _state.robber_tile_key:
		_show_message("Robber is already on that tile. Choose a different one.", "warn")
		return
	set_tile_picking(false)
	if not _state.move_robber(key, false):
		set_tile_picking(true)
		_show_message("Robber move failed. Choose a different tile.", "warn")
		return
	update_robber_position()
	var victims: Array = []
	for victim_idx in _state.get_robber_victims(key):
		var hand_cards: Array = _state.get_hand_cards(victim_idx, false)
		if not hand_cards.is_empty():
			victims.append({
				"player_index": victim_idx,
				"player_name": _state.players[victim_idx].player_name,
				"card_count": hand_cards.size(),
			})
	if victims.is_empty():
		_state.complete_robber_phase()
		_refresh_hud.call()
		_show_message("Robber moved. No cards to steal. Build phase resumed.", "success")
		return
	_refresh_hud.call()
	if victims.size() == 1:
		var victim: Dictionary = victims[0]
		_show_robber_card_picker(int(victim["player_index"]), str(victim["player_name"]), 0.0)
		return
	if _hud != null and _hud.has_method("show_robber_victim_picker"):
		_hud.show_robber_victim_picker(victims)
	_show_message("Choose which player to rob.", "info", true, 0.0)


func on_robber_victim_chosen(victim_idx: int) -> void:
	if _state.phase != _state.Phase.ROBBER_MOVE:
		return
	var victim = _state.get_player(victim_idx)
	if victim == null:
		return
	_show_robber_card_picker(victim_idx, victim.player_name, 0.0)


func on_robber_card_chosen(victim_idx: int, resource: int) -> void:
	if _state.phase != _state.Phase.ROBBER_MOVE:
		return
	var victim = _state.get_player(victim_idx)
	if victim == null:
		return
	if _state.steal_specific_resource(victim_idx, resource):
		_state.complete_robber_phase()
		_refresh_hud.call()
		_show_message("Stole 1 %s from %s. Build phase resumed." % [
			PlayerData.RES_NAMES[resource], victim.player_name], "success")
	else:
		_state.complete_robber_phase()
		_refresh_hud.call()
		_show_message("%s had no %s left to steal. Build phase resumed." % [
			victim.player_name, PlayerData.RES_NAMES[resource]], "warn")


func roll_dice() -> void:
	if _state.phase != _state.Phase.ROLL:
		return

	var roller = _state.current_player()
	_resource_feedback.reset_roll_context()
	var forced_roll: int = int(_forced_roll_provider.call())

	if forced_roll > 0:
		_state.last_roll = forced_roll
		print("[GOD] Forced roll: %d" % forced_roll)
		if forced_roll == 7:
			_state.robber_pick_pending = false
			_state.phase = _state.Phase.ROBBER_MOVE
			set_tile_picking(true)
		else:
			_state.debug_collect(forced_roll)
			_state.phase = _state.Phase.BUILD
		_state.dice_rolled.emit(forced_roll)
	else:
		_state.roll_dice()

	_resource_feedback.show_roll_feedback(
		roller.player_name,
		_state.last_roll,
		_state.phase == _state.Phase.ROBBER_MOVE,
		not roller.is_ai
	)
	if _state.phase == _state.Phase.ROBBER_MOVE:
		set_tile_picking(true)
	_refresh_hud.call()


func end_turn() -> void:
	if _state.phase != _state.Phase.BUILD:
		return
	_state.end_turn()
	_refresh_hud.call()


func buy_dev_card() -> void:
	var player = _state.current_player()
	if _state.dev_deck.is_empty():
		_show_message("The development card deck is empty!", "warn")
		return
	if not _state.can_buy_dev_card_for(_state.current_player_index):
		_show_message("Need 1 Ore + 1 Grain + 1 Wool to buy a dev card (you have Ore:%d Grain:%d Wool:%d)." % [
			player.resources.get(PlayerData.RES_ORE, 0),
			player.resources.get(PlayerData.RES_GRAIN, 0),
			player.resources.get(PlayerData.RES_WOOL, 0)], "warn")
		return
	if _state.buy_dev_card(player):
		_refresh_hud.call()
		_show_message("Dev card purchased!", "success")


func try_play_dev_card(player: RefCounted, card_type: int, pidx: int, r1: int = -1, r2: int = -1) -> void:
	match card_type:
		DevCards.Type.KNIGHT:
			if _state.play_knight(player, pidx):
				if player.is_ai:
					_queue_ai_followup.call()
				else:
					set_tile_picking(true)
				_refresh_hud.call()
				_show_message(
					"Knight played. Move the robber." if not player.is_ai else "%s played Knight." % player.player_name,
					"success",
					not player.is_ai)
			else:
				_show_message("Cannot play Knight right now (max 1 per turn, or bought this turn).", "warn")
		DevCards.Type.ROAD_BUILDING:
			if _state.play_road_building(player):
				_refresh_hud.call()
				_show_message("Road Building played. Two free roads ready.", "success", not player.is_ai)
			else:
				_show_message("Cannot play Road Building right now.", "warn")
		DevCards.Type.YEAR_OF_PLENTY:
			var res1: int = r1 if r1 >= 0 else AIPlayer.most_needed_resource(player)
			var res2: int = r2 if r2 >= 0 else PlayerData.RES_GRAIN
			if _state.play_year_of_plenty(player, res1, res2):
				_refresh_hud.call()
				_show_message("Year of Plenty added resources to your hand.", "success", not player.is_ai)
			else:
				_show_message("Cannot play Year of Plenty right now.", "warn")
		DevCards.Type.MONOPOLY:
			var mono_res: int = r1 if r1 >= 0 else AIPlayer.pick_monopoly_resource(_state, _state.current_player_index)
			if _state.play_monopoly(player, mono_res):
				_refresh_hud.call()
				_show_message("Monopoly claimed all %s." % PlayerData.RES_NAMES[mono_res], "success", not player.is_ai)
			else:
				_show_message("Cannot play Monopoly right now.", "warn")


func on_play_dev_card_requested(card_type: int) -> void:
	var player = _state.current_player()
	if player.is_ai:
		return
	if _state.phase != _state.Phase.BUILD:
		_show_message("Dev cards can only be played during your build phase.", "warn")
		return
	var pidx: int = _state.current_player_index
	match card_type:
		DevCards.Type.YEAR_OF_PLENTY:
			_hud.show_resource_picker("yop")
		DevCards.Type.MONOPOLY:
			_hud.show_resource_picker("mono")
		_:
			try_play_dev_card(player, card_type, pidx)


func on_year_of_plenty_chosen(r1: int, r2: int) -> void:
	var player = _state.current_player()
	try_play_dev_card(player, DevCards.Type.YEAR_OF_PLENTY, _state.current_player_index, r1, r2)


func on_monopoly_chosen(res: int) -> void:
	var player = _state.current_player()
	try_play_dev_card(player, DevCards.Type.MONOPOLY, _state.current_player_index, res, -1)


func on_trade_proposed(offer: Dictionary, want: Dictionary, to_player_idx: int) -> void:
	if to_player_idx < 0 or to_player_idx >= _state.players.size():
		return

	var from_player = _state.current_player()
	var to_player = _state.players[to_player_idx]
	var accepted := true
	if to_player.is_ai:
		accepted = AIPlayer.accepts_trade(to_player, offer, want)

	if not accepted:
		_show_message("%s declined the trade offer." % to_player.player_name, "warn")
		return

	if _state.player_trade(from_player, to_player, offer, want):
		_refresh_hud.call()
		_show_message("Trade accepted by %s!" % to_player.player_name, "success")
	else:
		_show_message("Trade failed. Check both players' resources.", "warn")


func _show_robber_card_picker(victim_idx: int, victim_name: String, duration: float) -> void:
	var cards: Array = _state.get_hand_cards(victim_idx, true)
	if cards.is_empty():
		_state.complete_robber_phase()
		_refresh_hud.call()
		_show_message("%s has no cards to steal. Build phase resumed." % victim_name, "info")
		return
	if _hud != null and _hud.has_method("show_robber_card_picker"):
		_hud.show_robber_card_picker(victim_idx, victim_name, cards, true)
	_show_message("Choose an exact card from %s's visible hand." % victim_name, "info", true, duration)


func _show_message(message: String, tone: String = "info", pin_to_message: bool = true, duration: float = 2.8) -> void:
	if _hud != null:
		if _hud.has_method("push_activity"):
			_hud.push_activity(message, tone, pin_to_message, duration)
		else:
			_hud.set_message(message)
