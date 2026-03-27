extends Node

## Autonomous debug controller.
## Activated by passing `-- --debug-play` on the command line.
## Simulates a full game session, takes labelled screenshots at each step,
## and prints a detailed log so Claude can debug without user interaction.

const PlayerData = preload("res://scripts/player/player.gd")
const DevCards   = preload("res://scripts/game/dev_cards.gd")
const AIPlayer   = preload("res://scripts/game/ai_player.gd")

# Phases as ints (mirrors GameState.Phase enum)
const PHASE_SETUP       := 0
const PHASE_ROLL        := 1
const PHASE_BUILD       := 2
const PHASE_ROBBER_MOVE := 3
const PHASE_GAME_OVER   := 4

var _main        # Node3D (main scene)
var _state       # GameState RefCounted
var _seq: int = 0
var _session_dir: String = ""   # set by _init_session(); all output goes here


func init(main_node: Node3D, game_state: RefCounted) -> void:
	_main  = main_node
	_state = game_state


# ---------------------------------------------------------------
# Main scripted play sequence
# ---------------------------------------------------------------

## Create a timestamped session directory and store it in _session_dir.
## All screenshots and logs for this run will be co-located there.
func _init_session(mode: String) -> void:
	# Both latest dirs are overwritten every run — no accumulation.
	Log.clear_dir(Log.LATEST_RUN_DIR)
	Log.clear_dir(Log.LATEST_SESSION_DIR)
	_session_dir = Log.LATEST_SESSION_DIR
	print("[SESSION] logs  → %s" % Log.LATEST_SESSION_DIR)
	print("[SESSION] shots → %s" % Log.LATEST_RUN_DIR)


func run_debug_play() -> void:
	_init_session("play")
	# Stop the AI timer — debug controller drives all actions manually
	_main._ai_timer.stop()
	print("[DBGPLAY] ============================================================")
	print("[DBGPLAY] Automated debug play starting")
	print("[DBGPLAY] Vertices: %d  Edges: %d  Tiles: %d" % [
		_main._vertex_slots.size(),
		_main._edge_slots.size(),
		_state.tile_data.size()])

	await _shot("00_initial_board")

	# --- SETUP: let the state machine drive (settlement + road per turn) ---
	print("[DBGPLAY] === SETUP PHASE ===")
	while _state.phase == PHASE_SETUP:
		if _state.setup_sub_phase == 0:  # PLACE_SETTLEMENT
			var slot = AIPlayer.pick_setup_vertex(_main._vertex_slots, _state.tile_data, _state)
			if slot:
				_main._on_vertex_slot_clicked(slot)
			else:
				print("[DBGPLAY] ERROR: no valid setup vertex")
				break
		else:  # PLACE_ROAD
			var road_slot: Object = _main._find_setup_road_slot()
			if road_slot:
				_main._on_edge_slot_clicked(road_slot)
			else:
				print("[DBGPLAY] ERROR: no adjacent road slot")
				break
		await get_tree().process_frame
	await _shot("01_setup_complete")
	_print_all_state()

	# --- Roll 6: verify resource collection ---
	print("[DBGPLAY] === ROLL 6 ===")
	_force_roll(6)
	await _shot("02_roll_6_resources")
	_print_all_state()
	_end_turn()

	# --- Roll 8 ---
	print("[DBGPLAY] === ROLL 8 ===")
	_force_roll(8)
	await _shot("03_roll_8_resources")
	_end_turn()

	# --- Roll 7: robber ---
	print("[DBGPLAY] === ROLL 7 (ROBBER) ===")
	_force_roll(7)
	print("[DBGPLAY] Phase after 7: %s" % _state.phase_name())
	_god_move_robber(2)  # move robber to tile index 2
	await _shot("04_robber_moved")
	_end_turn()

	# --- Verify robber blocks production ---
	print("[DBGPLAY] === ROLL (robber blocks tile) ===")
	_force_roll(4)  # if robber tile has 4, no resources from it
	await _shot("05_roll_with_robber")
	_end_turn()

	# --- GOD MODE: give P1 full resources ---
	print("[DBGPLAY] === GOD MODE: fill P1 resources ===")
	_give_resources(0, {0:5, 1:5, 2:5, 3:5, 4:5})
	await _shot("06_godmode_resources")

	# --- BUILD: road ---
	print("[DBGPLAY] === BUILD ROAD ===")
	_state.phase = PHASE_BUILD
	_state.current_player_index = 0
	_try_place_road(0, 0)   # first edge slot
	await _shot("07_road_built")

	# --- BUILD: new settlement ---
	print("[DBGPLAY] === BUILD SETTLEMENT ===")
	_give_resources(0, {0:1, 1:1, 2:1, 3:1})
	_try_place_settlement_paid(0, 8)
	await _shot("08_settlement_built")
	_print_all_state()

	# --- BUILD: city upgrade ---
	print("[DBGPLAY] === BUILD CITY ===")
	_give_resources(0, {3:2, 4:3})
	_try_upgrade_city(0, 5)
	await _shot("09_city_built")
	_print_all_state()

	# --- End turn P1, roll for P2 ---
	_end_turn()
	_force_roll(9)
	await _shot("10_p2_roll_9")
	_end_turn()

	# --- Sprint A: Buy dev card ---
	print("[DBGPLAY] === BUY DEV CARD ===")
	_give_resources(0, {2:1, 3:1, 4:1})  # Wool+Grain+Ore
	_state.current_player_index = 0
	_state.phase = PHASE_BUILD
	var bought: bool = _state.buy_dev_card(_state.players[0])
	print("[DBGPLAY] Dev card bought: %s  hand: %s" % [
		"OK" if bought else "FAILED",
		DevCards.hand_summary(_state.players[0].dev_cards)])
	await _shot("12_dev_card_bought")

	# --- Sprint A: Play Knight ---
	print("[DBGPLAY] === PLAY KNIGHT (add one if needed) ===")
	var p0 = _state.players[0]
	if DevCards.Type.KNIGHT not in p0.dev_cards:
		p0.dev_cards.append(DevCards.Type.KNIGHT)
	_state.current_player_index = 0
	_state.phase = PHASE_BUILD
	_main._try_play_dev_card(p0, DevCards.Type.KNIGHT, 0)
	print("[DBGPLAY] After Knight — phase: %s  knights: %d" % [_state.phase_name(), p0.knight_count])
	if _state.phase == PHASE_ROBBER_MOVE:
		_god_move_robber(3)
	await _shot("13_knight_played")

	# --- Sprint A: Year of Plenty ---
	print("[DBGPLAY] === PLAY YEAR OF PLENTY ===")
	p0.dev_cards.append(DevCards.Type.YEAR_OF_PLENTY)
	_state.phase = PHASE_BUILD
	_main._try_play_dev_card(p0, DevCards.Type.YEAR_OF_PLENTY, 0)
	print("[DBGPLAY] After YoP — Ore:%d Grain:%d" % [
		p0.resources.get(PlayerData.RES_ORE, 0),
		p0.resources.get(PlayerData.RES_GRAIN, 0)])
	await _shot("14_year_of_plenty")

	# --- Sprint A: Bank trade ---
	print("[DBGPLAY] === BANK TRADE 4:1 ===")
	_give_resources(0, {0:4})  # give 4 lumber
	var before_brick: int = p0.resources.get(PlayerData.RES_BRICK, 0)
	_state.bank_trade(p0, PlayerData.RES_LUMBER, PlayerData.RES_BRICK)
	var after_brick: int = p0.resources.get(PlayerData.RES_BRICK, 0)
	print("[DBGPLAY] Bank trade: brick %d → %d  [%s]" % [
		before_brick, after_brick, "OK" if after_brick > before_brick else "FAILED"])
	await _shot("15_bank_trade")

	# --- Sprint A: Longest Road (place 5 roads) ---
	print("[DBGPLAY] === LONGEST ROAD (place 5 roads) ===")
	_state.current_player_index = 0
	_state.phase = PHASE_BUILD
	var roads_placed := 0
	for _i in range(5):
		var slot = AIPlayer.pick_road(_main._edge_slots, _main._vertex_slots, p0, _state)
		if slot == null:
			print("[DBGPLAY] No more connected road slots available")
			break
		_ensure_road_resources(0)
		_main._on_edge_slot_clicked(slot)
		roads_placed += 1
	print("[DBGPLAY] Roads placed: %d  Longest Road holder: %s  P1 VP: %d" % [
		roads_placed,
		_state.players[_state.longest_road_holder].player_name if _state.longest_road_holder >= 0 else "none",
		p0.victory_points])
	await _shot("16_longest_road")

	# --- Sprint A: Largest Army (play 3 knights) ---
	print("[DBGPLAY] === LARGEST ARMY (3 knights) ===")
	_state.phase = PHASE_BUILD
	p0.knight_count = 0  # reset for clean test
	for _i in range(3):
		p0.dev_cards.append(DevCards.Type.KNIGHT)
		_main._try_play_dev_card(p0, DevCards.Type.KNIGHT, 0)
		if _state.phase == PHASE_ROBBER_MOVE:
			_god_move_robber(1)
		_state.phase = PHASE_BUILD
	print("[DBGPLAY] After 3 knights — Largest Army holder: %s  P1 VP: %d" % [
		_state.players[_state.largest_army_holder].player_name if _state.largest_army_holder >= 0 else "none",
		p0.victory_points])
	await _shot("17_largest_army")

	# --- Final state ---
	print("[DBGPLAY] === FINAL STATE ===")
	_print_all_state()
	await _shot("18_final_state")

	print("[DBGPLAY] ============================================================")
	print("[DBGPLAY] Debug play complete — quitting")
	get_tree().quit()


# ---------------------------------------------------------------
# Full AI game (--debug-fullgame)
# ---------------------------------------------------------------

func run_full_game() -> void:
	_init_session("fullgame")
	# Stop the AI timer — debug controller drives all turns
	_main._ai_timer.stop()
	const TIMEOUT_SECS := 300.0  # 5 minute safety cutoff
	print("[FULLGAME] ============================================================")
	print("[FULLGAME] Full AI game starting  (timeout: %.0fs)" % TIMEOUT_SECS)

	# All players are already marked AI by main.gd — override P1 to be AI too
	for p in _state.players:
		p.is_ai = true
	print("[FULLGAME] All %d players set as AI" % _state.players.size())

	# --- SETUP: AI places settlement + road each turn (correct Catan setup) ---
	print("[FULLGAME] === SETUP ===")
	while _state.phase == PHASE_SETUP:
		if _state.setup_sub_phase == 0:  # PLACE_SETTLEMENT
			var slot = AIPlayer.pick_setup_vertex(_main._vertex_slots, _state.tile_data, _state)
			if slot == null:
				print("[FULLGAME] ERROR: no valid vertex for setup!")
				break
			_main._on_vertex_slot_clicked(slot)
		else:  # PLACE_ROAD
			var road_slot: Object = _main._find_setup_road_slot()
			if road_slot:
				_main._on_edge_slot_clicked(road_slot)
			else:
				print("[FULLGAME] ERROR: no adjacent road slot for setup!")
				break
		await get_tree().process_frame
	await _shot("fg_00_setup_complete")
	_print_all_state()

	# --- Main game loop ---
	var turn_count := 0
	var start_ms: float = Time.get_ticks_msec()

	while _state.phase != PHASE_GAME_OVER:
		var elapsed: float = (Time.get_ticks_msec() - start_ms) / 1000.0
		if elapsed > TIMEOUT_SECS:
			print("[FULLGAME] TIMEOUT after %.0fs — stopping" % elapsed)
			break

		turn_count += 1
		var player = _state.current_player()
		print("[FULLGAME] Turn %d — %s [%s]  VP:%d" % [
			turn_count, player.player_name, _state.phase_name(), player.victory_points])

		if _state.phase == PHASE_GAME_OVER:
			break

		match _state.phase:
			PHASE_ROLL:
				_state.roll_dice()
				if _state.phase == PHASE_ROBBER_MOVE:
					var robber_key: String = AIPlayer.pick_robber_tile(_state, _state.current_player_index)
					_main._set_tile_picking(false)
					_state.move_robber(robber_key)
					_main._update_robber_position()

			PHASE_BUILD:
				# AI takes up to 5 build actions per turn to avoid infinite loops
				var actions_this_turn := 0
				while _state.phase == PHASE_BUILD and actions_this_turn < 5:
					var pidx: int = _state.current_player_index
					var decision: Dictionary = AIPlayer.decide_build(
						player, _state, _main._vertex_slots, _main._edge_slots)
					if decision.action == "end_turn":
						break
					print("[FULLGAME]   AI action: %s" % decision.action)
					match decision.action:
						"city":
							_main._on_vertex_slot_clicked(decision.params.slot)
						"settlement":
							_main._on_vertex_slot_clicked(decision.params.slot)
						"road":
							_main._on_edge_slot_clicked(decision.params.slot)
						"dev_card":
							_state.buy_dev_card(player)
						"play_card":
							_ai_play_card(player, decision.params.card, pidx)
						"bank_trade":
							_state.bank_trade(player, decision.params.give, decision.params.recv)
					actions_this_turn += 1
					# Stop building immediately if game is over
					if _state.phase == PHASE_GAME_OVER:
						break

				# Only end turn if game is still running
				if _state.phase != PHASE_GAME_OVER:
					_state.end_turn()
					# end_turn emits turn_changed → _on_turn_changed restarts the
					# AI timer. Kill it — debug controller drives all turns.
					_main._ai_timer.stop()

		# Screenshot every 10 turns, yield every turn so screen updates
		if turn_count % 10 == 0:
			await _shot("fg_%02d_turn%d" % [_seq, turn_count])
		else:
			await get_tree().process_frame  # keep UI responsive
		_main._ai_timer.stop()  # kill any timer that fired during the await

	# --- Game over ---
	var elapsed_final: float = (Time.get_ticks_msec() - start_ms) / 1000.0
	print("[FULLGAME] ============================================================")
	print("[FULLGAME] Game ended after %d turns  (%.1fs)" % [turn_count, elapsed_final])
	_print_all_state()
	if _state.winner_index >= 0:
		var w = _state.players[_state.winner_index]
		print("[FULLGAME] WINNER: %s with %d VP!" % [w.player_name, w.victory_points])
	else:
		print("[FULLGAME] No winner — timeout or draw")

	# --- Event log: validate + dump to disk ---
	var issues: Array = GameEvents.validate()
	print("[EVENTS] %d total events recorded." % GameEvents.entries.size())
	if issues.is_empty():
		print("[EVENTS] ✓ Validation passed — no rule violations detected.")
	else:
		print("[EVENTS] ✗ %d VIOLATION(S) FOUND:" % issues.size())
		for issue in issues:
			print("[EVENTS]   ✗ " + issue)
	GameEvents.flush_to_file("fullgame")

	await _shot("fg_final_state")
	print("[FULLGAME] ============================================================")
	get_tree().quit()


func _ai_play_card(player: RefCounted, card_type: int, pidx: int) -> void:
	match card_type:
		DevCards.Type.KNIGHT:
			_state.play_knight(player, pidx)
			if _state.phase == PHASE_ROBBER_MOVE:
				var key := AIPlayer.pick_robber_tile(_state, pidx)
				_main._set_tile_picking(false)
				_state.move_robber(key)
				_main._update_robber_position()
		DevCards.Type.ROAD_BUILDING:
			_state.play_road_building(player)
		DevCards.Type.YEAR_OF_PLENTY:
			_state.play_year_of_plenty(player,
				AIPlayer.most_needed_resource(player), PlayerData.RES_GRAIN)
		DevCards.Type.MONOPOLY:
			_state.play_monopoly(player, PlayerData.RES_LUMBER)


# ---------------------------------------------------------------
# Settlement helpers
# ---------------------------------------------------------------

## Place settlement + road for whoever's current turn (correct Catan setup order).
func _auto_place_settlement(slot_idx: int) -> void:
	if slot_idx >= _main._vertex_slots.size():
		print("[DBGPLAY] WARN: vertex slot %d out of range" % slot_idx)
		return
	var p_name: String = _state.current_player().player_name

	# 1. Place settlement
	var slot = _main._vertex_slots[slot_idx]
	if slot.is_occupied or not _state._respects_distance_rule(slot.position):
		# Find best free slot respecting distance rule
		slot = AIPlayer.pick_setup_vertex(_main._vertex_slots, _state.tile_data, _state)
		if slot == null:
			print("[DBGPLAY] WARN: no valid setup vertex found")
			return
	_main._on_vertex_slot_clicked(slot)
	print("[DBGPLAY] %s settlement at %s  vp=%d" % [
		p_name, slot.position, _state.current_player().victory_points])

	# 2. Place road adjacent to that settlement (state is now PLACE_ROAD)
	if _state.setup_sub_phase == 1:  # PLACE_ROAD
		var road_slot: Object = _main._find_setup_road_slot()
		if road_slot:
			_main._on_edge_slot_clicked(road_slot)
			print("[DBGPLAY] %s road at %s" % [p_name, road_slot.position])
		else:
			print("[DBGPLAY] WARN: no adjacent road slot found for setup")


## God-mode: place settlement for specific player ignoring costs/turn
func _try_place_settlement_paid(player_idx: int, slot_idx: int) -> void:
	if slot_idx >= _main._vertex_slots.size():
		return
	var old_idx: int = _state.current_player_index
	_state.current_player_index = player_idx
	_state.phase = PHASE_BUILD
	var slot = _main._vertex_slots[slot_idx]
	if slot.is_occupied:
		# find nearest free
		for i in _main._vertex_slots.size():
			if not _main._vertex_slots[i].is_occupied:
				slot = _main._vertex_slots[i]
				break
	_main._on_vertex_slot_clicked(slot)
	print("[DBGPLAY] Paid settlement for P%d: %s" % [player_idx + 1, "OK" if slot.is_occupied else "FAILED"])
	_state.current_player_index = old_idx


## God-mode: try to upgrade a settlement to a city
func _try_upgrade_city(player_idx: int, slot_idx: int) -> void:
	if slot_idx >= _main._vertex_slots.size():
		return
	var old_idx: int = _state.current_player_index
	_state.current_player_index = player_idx
	_state.phase = PHASE_BUILD
	var slot = _main._vertex_slots[slot_idx]
	# Find a slot owned by this player that isn't a city
	if not (slot.is_occupied and slot.owner_index == player_idx and not slot.is_city):
		for s in _main._vertex_slots:
			if s.is_occupied and s.owner_index == player_idx and not s.is_city:
				slot = s
				break
	_main._on_vertex_slot_clicked(slot)
	print("[DBGPLAY] City for P%d: %s" % [player_idx + 1, "OK" if slot.is_city else "FAILED (resources or slot?)"])
	_state.current_player_index = old_idx


# ---------------------------------------------------------------
# Road helpers
# ---------------------------------------------------------------

func _try_place_road(player_idx: int, _hint_idx: int = 0) -> void:
	var old_idx: int = _state.current_player_index
	_state.current_player_index = player_idx
	_state.phase = PHASE_BUILD
	_ensure_road_resources(player_idx)
	# Try every edge slot until one connects to player's network
	var placed := false
	for i in _main._edge_slots.size():
		var slot = _main._edge_slots[i]
		if slot.is_occupied:
			continue
		_main._on_edge_slot_clicked(slot)
		if slot.is_occupied:
			print("[DBGPLAY] Road for P%d at edge %d: OK" % [player_idx + 1, i])
			placed = true
			break
	if not placed:
		print("[DBGPLAY] Road for P%d: FAILED — no connected edge found" % (player_idx + 1))
	_state.current_player_index = old_idx


func _ensure_road_resources(player_idx: int) -> void:
	var p = _state.players[player_idx]
	if p.resources.get(PlayerData.RES_LUMBER, 0) < 1:
		p.add_resource(PlayerData.RES_LUMBER, 1)
	if p.resources.get(PlayerData.RES_BRICK, 0) < 1:
		p.add_resource(PlayerData.RES_BRICK, 1)


# ---------------------------------------------------------------
# Dice / robber helpers
# ---------------------------------------------------------------

func _force_roll(number: int) -> void:
	if _state.phase != PHASE_ROLL:
		print("[DBGPLAY] WARN: forcing roll while in phase '%s'" % _state.phase_name())
	_state.last_roll = number
	print("[DBGPLAY] Force roll: %d" % number)
	if number == 7:
		_state.phase = PHASE_ROBBER_MOVE
		_main._set_tile_picking(true)
	else:
		_state.debug_collect(number)
		_state.phase = PHASE_BUILD
	_main._refresh_hud()


func _god_move_robber(tile_index: int) -> void:
	var keys: Array = _state.tile_data.keys()
	if tile_index >= keys.size():
		tile_index = 0
	var key: String = keys[tile_index]
	if key == _state.robber_tile_key:
		key = keys[(tile_index + 1) % keys.size()]
	_main._set_tile_picking(false)
	_state.move_robber(key)
	_main._update_robber_position()
	_main._refresh_hud()
	print("[DBGPLAY] Robber moved to tile %s" % key)


func _end_turn() -> void:
	if _state.phase == PHASE_ROBBER_MOVE:
		_god_move_robber(0)
	_state.phase = PHASE_BUILD
	_main._on_end_turn()
	print("[DBGPLAY] Turn ended → %s [%s]" % [_state.current_player().player_name, _state.phase_name()])


# ---------------------------------------------------------------
# God mode helpers
# ---------------------------------------------------------------

func _give_resources(player_idx: int, amounts: Dictionary) -> void:
	var p = _state.players[player_idx]
	for r in amounts:
		p.add_resource(r, amounts[r])
	print("[DBGPLAY] God mode → P%d: %s" % [player_idx + 1, p.resource_summary()])


# ---------------------------------------------------------------
# Logging
# ---------------------------------------------------------------

func _print_all_state() -> void:
	print("[DBGPLAY] --- State snapshot ---")
	for p in _state.players:
		print("[DBGPLAY]   %s" % p.debug_summary())
	print("[DBGPLAY]   Phase: %s  Last roll: %d  Robber: %s" % [
		_state.phase_name(), _state.last_roll, _state.robber_tile_key])


# ---------------------------------------------------------------
# Screenshot
# ---------------------------------------------------------------

func _shot(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img   := get_viewport().get_texture().get_image()
	var fname := "dbg_%02d_%s.png" % [_seq, label]
	# Always write to latest_run/ — overwritten each run, no storage accumulation.
	# Session folders only contain event logs (small text files).
	img.save_png(Log.LATEST_RUN_DIR + fname)
	print("[DBGPLAY] Screenshot → latest_run/%s" % fname)
	_seq += 1
