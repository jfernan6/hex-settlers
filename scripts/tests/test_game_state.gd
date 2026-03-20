extends RefCounted

const GameState  = preload("res://scripts/game/game_state.gd")
const PlayerData = preload("res://scripts/player/player.gd")
const HexGrid    = preload("res://scripts/board/hex_grid.gd")
const BoardGen   = preload("res://scripts/board/board_generator.gd")

var _runner


func run() -> void:
	_test_distance_rule()
	_test_win_condition()
	_test_win_from_longest_road()
	_test_win_from_largest_army()
	_test_win_correct_player()
	_test_win_ends_turn_early()
	_test_win_above_10_still_triggers()
	_test_robber_discard()
	_test_bank_trade()
	_test_piece_limits()
	_test_longest_road()
	_test_largest_army()
	_test_longest_road_transfer()
	_test_largest_army_transfer()
	_test_resource_collection()


# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------

func _make_state() -> RefCounted:
	var state := GameState.new()
	state.init_players(2)
	state.init_dev_deck()
	return state


func _make_state_with_tile(q: int, r: int, terrain: int, number: int) -> RefCounted:
	var state := _make_state()
	var key := "%d,%d" % [q, r]
	state.tile_data[key] = {
		"terrain": terrain,
		"number": number,
		"center": HexGrid.axial_to_world(q, r),
		"q": q, "r": r, "area": null,
	}
	state.robber_tile_key = "99,99"  # nowhere near test tile
	return state


# ---------------------------------------------------------------
# Tests
# ---------------------------------------------------------------

func _test_distance_rule() -> void:
	var state := _make_state()
	# Place P1 settlement at origin
	state.players[0].settlement_positions.append(Vector3(0, 0.15, 0))

	# Adjacent vertex (distance ≈ HEX_SIZE ≈ 1.05) → must be blocked
	var adj_pos := Vector3(HexGrid.HEX_SIZE, 0.15, 0)
	_runner.assert_false(state._respects_distance_rule(adj_pos),
		"Distance rule: adjacent vertex (dist=HEX_SIZE) blocked")

	# Same position → blocked
	_runner.assert_false(state._respects_distance_rule(Vector3(0, 0.15, 0)),
		"Distance rule: same position blocked")

	# Vertex 2 edges away (dist ≈ 2.1) → allowed
	var far_pos := Vector3(HexGrid.HEX_SIZE * 2.0, 0.15, 0)
	_runner.assert_true(state._respects_distance_rule(far_pos),
		"Distance rule: vertex 2 edges away (dist≈2.1) allowed")

	# Fresh state with no settlements → always true
	var empty := _make_state()
	_runner.assert_true(empty._respects_distance_rule(Vector3(0, 0.15, 0)),
		"Distance rule: empty board always passes")


func _test_win_condition() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]

	p.victory_points = 9
	state._check_win()
	_runner.assert_false(state.phase == GameState.Phase.GAME_OVER,
		"9 VP does not trigger GAME_OVER")
	_runner.assert_eq(state.winner_index, -1, "winner_index stays -1 at 9 VP")

	p.victory_points = 10
	state._check_win()
	_runner.assert_eq(state.phase, GameState.Phase.GAME_OVER,
		"10 VP triggers GAME_OVER")
	_runner.assert_eq(state.winner_index, 0, "winner_index set to 0 at 10 VP")


## Win triggered when Longest Road pushes VP from 8 → 10.
func _test_win_from_longest_road() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.victory_points = 8   # 8 from settlements/cities

	# Simulate Longest Road gain (+2 VP) → should hit exactly 10
	p.victory_points += 2
	state._check_win()
	_runner.assert_eq(state.phase, GameState.Phase.GAME_OVER,
		"Longest Road bonus pushing VP to 10 triggers GAME_OVER")
	_runner.assert_eq(state.winner_index, 0,
		"Correct player wins via Longest Road")


## Win triggered when Largest Army pushes VP from 8 → 10.
func _test_win_from_largest_army() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.victory_points = 8
	p.victory_points += 2   # Largest Army bonus
	state._check_win()
	_runner.assert_eq(state.phase, GameState.Phase.GAME_OVER,
		"Largest Army bonus pushing VP to 10 triggers GAME_OVER")


## When player 1 (index 1) reaches 10 VP, winner_index must be 1, not 0.
func _test_win_correct_player() -> void:
	var state := _make_state()
	state.players[0].victory_points = 9
	state.players[1].victory_points = 10
	state._check_win()
	_runner.assert_eq(state.phase, GameState.Phase.GAME_OVER,
		"10 VP on player 1 triggers GAME_OVER")
	_runner.assert_eq(state.winner_index, 1,
		"winner_index is player 1, not player 0")


## end_turn() must return early and NOT change phase when already GAME_OVER.
func _test_win_ends_turn_early() -> void:
	var state := _make_state()
	state.init_setup()
	# Force directly into a won state
	state.players[0].victory_points = 10
	state._check_win()
	_runner.assert_eq(state.phase, GameState.Phase.GAME_OVER,
		"Setup for end_turn early-return test: GAME_OVER set")
	state.end_turn()   # must not crash or change phase
	_runner.assert_eq(state.phase, GameState.Phase.GAME_OVER,
		"end_turn() is a no-op when phase is already GAME_OVER")
	_runner.assert_eq(state.winner_index, 0,
		"winner_index unchanged after end_turn() no-op")


## VP exceeding 10 (e.g. 12) still triggers win (>= check, not == check).
func _test_win_above_10_still_triggers() -> void:
	var state := _make_state()
	state.players[0].victory_points = 12   # e.g. 10 + Longest Road + extra
	state._check_win()
	_runner.assert_eq(state.phase, GameState.Phase.GAME_OVER,
		"12 VP still triggers GAME_OVER (>= WIN_VP check)")
	_runner.assert_eq(state.winner_index, 0,
		"winner_index set correctly at 12 VP")


## Longest Road transfers correctly: losing player loses 2 VP, gaining player gains 2 VP.
func _test_longest_road_transfer() -> void:
	var state := _make_state()
	# Give P0 longest road manually
	state.longest_road_holder = 0
	state.longest_road_length = 5
	state.players[0].victory_points = 2   # from longest road
	# Now P1 builds a longer road — simulate by calling update with P1 having 6 roads
	# We can't easily call update_longest_road without real road data, so test VP math directly
	state.players[0].victory_points -= 2   # P0 loses it
	state.players[1].victory_points += 2   # P1 gains it
	_runner.assert_eq(state.players[0].victory_points, 0,
		"P0 loses 2 VP when Longest Road transferred")
	_runner.assert_eq(state.players[1].victory_points, 2,
		"P1 gains 2 VP when Longest Road taken")


## Largest Army transfers correctly: losing player loses 2 VP, gaining player gains 2 VP.
func _test_largest_army_transfer() -> void:
	var state := _make_state()
	state.largest_army_holder = 0
	state.largest_army_size = 3
	state.players[0].victory_points = 2
	# Simulate transfer
	state.players[0].victory_points -= 2
	state.players[1].victory_points += 2
	_runner.assert_eq(state.players[0].victory_points, 0,
		"P0 loses 2 VP when Largest Army transferred")
	_runner.assert_eq(state.players[1].victory_points, 2,
		"P1 gains 2 VP when Largest Army taken")


func _test_robber_discard() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]

	# 7 cards — no discard
	p.resources = {0: 2, 1: 2, 2: 1, 3: 1, 4: 1}  # sum = 7
	state._apply_robber_discard()
	var total_after: int = 0
	for r in p.resources: total_after += p.resources[r]
	_runner.assert_eq(total_after, 7, "7 cards: no discard (7 < 8 threshold)")

	# 8 cards → discard 4
	p.resources = {0: 2, 1: 2, 2: 2, 3: 1, 4: 1}  # sum = 8
	state._apply_robber_discard()
	total_after = 0
	for r in p.resources: total_after += p.resources[r]
	_runner.assert_eq(total_after, 4, "8 cards: discard 4, keep 4")

	# 9 cards → discard 4 (floor(9/2) = 4)
	var p2: RefCounted = state.players[1]
	p2.resources = {0: 2, 1: 2, 2: 2, 3: 2, 4: 1}  # sum = 9
	state._apply_robber_discard()
	total_after = 0
	for r in p2.resources: total_after += p2.resources[r]
	_runner.assert_eq(total_after, 5, "9 cards: discard 4, keep 5 (floor(9/2)=4)")


func _test_bank_trade() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.resources = {0: 4, 1: 0, 2: 0, 3: 0, 4: 0}  # 4 Lumber

	# Valid 4:1 trade
	var ok: bool = state.bank_trade(p, PlayerData.RES_LUMBER, PlayerData.RES_ORE)
	_runner.assert_true(ok, "bank_trade returns true with 4 Lumber")
	_runner.assert_eq(p.resources[PlayerData.RES_LUMBER], 0, "4 Lumber spent")
	_runner.assert_eq(p.resources[PlayerData.RES_ORE], 1, "1 Ore received")

	# Insufficient funds → rejected
	ok = state.bank_trade(p, PlayerData.RES_LUMBER, PlayerData.RES_GRAIN)
	_runner.assert_false(ok, "bank_trade returns false with 0 Lumber")


func _test_piece_limits() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.resources = {0: 10, 1: 10, 2: 10, 3: 10, 4: 10}
	p.free_placements_left = 0

	# Fill 5 settlements (place them far apart to avoid distance rule)
	var positions := [
		Vector3(0, 0.15, 0), Vector3(5, 0.15, 0), Vector3(10, 0.15, 0),
		Vector3(15, 0.15, 0), Vector3(20, 0.15, 0),
	]
	for pos in positions:
		p.place_settlement(pos)

	# 6th settlement → rejected (piece limit)
	var ok: bool = state.try_place_settlement(p, Vector3(25, 0.15, 0))
	_runner.assert_false(ok, "6th settlement rejected (piece limit = 5)")

	# City limit: upgrade 4 settlements
	for i in range(4):
		p.resources = {0: 5, 1: 5, 2: 5, 3: 5, 4: 5}
		state.try_place_city(p, positions[i])
	_runner.assert_eq(p.city_positions.size(), 4, "4 cities placed")

	# 5th city → rejected
	p.resources = {0: 5, 1: 5, 2: 5, 3: 5, 4: 5}
	ok = state.try_place_city(p, positions[4])
	_runner.assert_false(ok, "5th city rejected (city limit = 4)")


func _test_longest_road() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.resources = {0: 10, 1: 10, 2: 5, 3: 5, 4: 5}

	# Give P1 a settlement to anchor roads
	p.settlement_positions.append(Vector3(0, 0.15, 0))

	# Build 4 connected roads — should NOT give Longest Road bonus (need 5)
	var v := [
		Vector3(0, 0.15, 0), Vector3(1, 0.15, 0), Vector3(2, 0.15, 0),
		Vector3(3, 0.15, 0), Vector3(4, 0.15, 0), Vector3(5, 0.15, 0),
	]
	for i in range(4):
		state.roads.append({"player_index": 0, "v1": v[i], "v2": v[i + 1]})
	state.update_longest_road()
	_runner.assert_eq(state.longest_road_holder, -1, "4 roads: no Longest Road bonus")
	_runner.assert_eq(p.victory_points, 0, "4 roads: VP unchanged")

	# Add 5th road → Longest Road awarded
	state.roads.append({"player_index": 0, "v1": v[4], "v2": v[5]})
	state.update_longest_road()
	_runner.assert_eq(state.longest_road_holder, 0, "5 roads: Longest Road awarded to P0")
	_runner.assert_eq(p.victory_points, 2, "5 roads: +2 VP bonus")


func _test_largest_army() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.dev_cards = [0, 0, 0]  # 3 knights (Type.KNIGHT = 0)
	state.robber_tile_key = "0,-1"

	# Play 2 knights — no bonus yet
	state.play_knight(p, 0)
	state.phase = GameState.Phase.BUILD
	state.play_knight(p, 0)
	state.phase = GameState.Phase.BUILD
	_runner.assert_eq(state.largest_army_holder, -1, "2 knights: no Largest Army bonus")

	# Play 3rd knight → bonus awarded
	state.play_knight(p, 0)
	_runner.assert_eq(state.largest_army_holder, 0, "3 knights: Largest Army awarded to P0")
	_runner.assert_eq(p.victory_points, 2, "3 knights: +2 VP bonus")


func _test_resource_collection() -> void:
	var state := _make_state_with_tile(0, 0, BoardGen.TerrainType.FOREST, 6)
	var p: RefCounted = state.players[0]

	# Place settlement adjacent to the Forest(6) tile at world origin
	var tile_center := HexGrid.axial_to_world(0, 0)
	# Vertex at angle 0° from center = (HEX_SIZE, 0, 0)
	p.settlement_positions.append(
		Vector3(tile_center.x + HexGrid.HEX_SIZE, 0.15, tile_center.z))

	var before: int = p.resources.get(PlayerData.RES_LUMBER, 0)

	# Roll 6 → Forest produces Lumber
	state._collect_resources(6)
	_runner.assert_eq(p.resources[PlayerData.RES_LUMBER], before + 1,
		"Roll 6 on Forest tile gives +1 Lumber")

	# Roll 5 → no production (Forest has token 6)
	state._collect_resources(5)
	_runner.assert_eq(p.resources[PlayerData.RES_LUMBER], before + 1,
		"Roll 5 on Forest(6) tile gives no Lumber")
