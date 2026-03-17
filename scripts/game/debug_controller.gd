extends Node

## Autonomous debug controller.
## Activated by passing `-- --debug-play` on the command line.
## Simulates a full game session, takes labelled screenshots at each step,
## and prints a detailed log so Claude can debug without user interaction.

const PlayerData = preload("res://scripts/player/player.gd")

# Phases as ints (mirrors GameState.Phase enum)
const PHASE_SETUP       := 0
const PHASE_ROLL        := 1
const PHASE_BUILD       := 2
const PHASE_ROBBER_MOVE := 3
const PHASE_GAME_OVER   := 4

var _main   # Node3D (main scene)
var _state  # GameState RefCounted
var _seq: int = 0


func init(main_node: Node3D, game_state: RefCounted) -> void:
	_main  = main_node
	_state = game_state


# ---------------------------------------------------------------
# Main scripted play sequence
# ---------------------------------------------------------------

func run_debug_play() -> void:
	print("[DBGPLAY] ============================================================")
	print("[DBGPLAY] Automated debug play starting")
	print("[DBGPLAY] Vertices: %d  Edges: %d  Tiles: %d" % [
		_main._vertex_slots.size(),
		_main._edge_slots.size(),
		_state.tile_data.size()])

	await _shot("00_initial_board")

	# --- SETUP: 4 settlements in natural turn order ---
	print("[DBGPLAY] === SETUP PHASE ===")
	_auto_place_settlement(5)   # P1 turn
	_auto_place_settlement(20)  # P2 turn (auto-cycled)
	_auto_place_settlement(15)  # P1 turn
	_auto_place_settlement(40)  # P2 turn
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

	# --- Final state ---
	print("[DBGPLAY] === FINAL STATE ===")
	_print_all_state()
	await _shot("11_final_state")

	print("[DBGPLAY] ============================================================")
	print("[DBGPLAY] Debug play complete — quitting")
	get_tree().quit()


# ---------------------------------------------------------------
# Settlement helpers
# ---------------------------------------------------------------

## Place settlement for whoever's current turn (SETUP mode, auto-cycles)
func _auto_place_settlement(slot_idx: int) -> void:
	if slot_idx >= _main._vertex_slots.size():
		print("[DBGPLAY] WARN: vertex slot %d out of range" % slot_idx)
		return
	var p_name: String = _state.current_player().player_name
	var slot = _main._vertex_slots[slot_idx]
	if slot.is_occupied:
		# Find next free slot
		for i in _main._vertex_slots.size():
			if not _main._vertex_slots[i].is_occupied:
				slot = _main._vertex_slots[i]
				break
	_main._on_vertex_slot_clicked(slot)
	print("[DBGPLAY] %s settlement at vertex idx ~%d  pos=%s  vp=%d" % [
		p_name, slot_idx, slot.position, _state.players[_state.current_player_index].victory_points])


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
	var img := get_viewport().get_texture().get_image()
	var fname := "dbg_%02d_%s.png" % [_seq, label]
	img.save_png("res://debug-screenshots/" + fname)
	img.save_png("res://debug-screenshots/latest_run.png")
	print("[DBGPLAY] Screenshot: %s" % fname)
	_seq += 1
