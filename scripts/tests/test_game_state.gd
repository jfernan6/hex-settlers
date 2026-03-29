extends RefCounted

const GameState  = preload("res://scripts/game/game_state.gd")
const DevCards   = preload("res://scripts/game/dev_cards.gd")
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
	_test_resource_bank_starts_full()
	_test_resource_collection_draws_from_bank()
	_test_resource_collection_skips_when_bank_cannot_cover_type()
	_test_dev_purchase_returns_cost_to_bank()
	_test_year_of_plenty_fails_when_bank_is_short()
	_test_dev_supply_view_tracks_remaining_and_revealed_cards()
	_test_bank_trade()
	_test_piece_limits()
	_test_settlement_requires_connected_road()
	_test_city_requires_owned_settlement()
	_test_city_rejects_duplicate_upgrade()
	_test_duplicate_road_rejected()
	_test_longest_road()
	_test_largest_army()
	_test_longest_road_transfer()
	_test_largest_army_transfer()
	_test_resource_collection()
	_test_resource_payout_signal_tracks_exact_sources()
	_test_port_generic_rate()
	_test_port_specific_rate()
	_test_port_no_rate_without_settlement()
	_test_dev_card_timing_max_one_per_turn()
	_test_dev_card_timing_cannot_play_bought_same_turn()
	_test_player_trade_executes()
	_test_player_trade_rejects_when_insufficient()
	_test_get_robber_victims_returns_adjacent_opponents()
	_test_get_hand_cards_expands_resource_counts()
	_test_steal_specific_resource_transfers_exact_card()
	_test_move_robber_rejects_invalid_tile()
	_test_move_robber_rejects_same_tile()
	_test_scenario_setup_roll_robber_build_end_turn()
	_test_scenario_bonus_transfer_flow()


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
	_runner.assert_false(state.passes_distance_rule(adj_pos),
		"Distance rule: adjacent vertex (dist=HEX_SIZE) blocked")

	# Same position → blocked
	_runner.assert_false(state.passes_distance_rule(Vector3(0, 0.15, 0)),
		"Distance rule: same position blocked")

	# Vertex 2 edges away (dist ≈ 2.1) → allowed
	var far_pos := Vector3(HexGrid.HEX_SIZE * 2.0, 0.15, 0)
	_runner.assert_true(state.passes_distance_rule(far_pos),
		"Distance rule: vertex 2 edges away (dist≈2.1) allowed")

	# Fresh state with no settlements → always true
	var empty := _make_state()
	_runner.assert_true(empty.passes_distance_rule(Vector3(0, 0.15, 0)),
		"Distance rule: empty board always passes")


func _test_win_condition() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]

	p.victory_points = 9
	state.check_win()
	_runner.assert_false(state.phase == GameState.Phase.GAME_OVER,
		"9 VP does not trigger GAME_OVER")
	_runner.assert_eq(state.winner_index, -1, "winner_index stays -1 at 9 VP")

	p.victory_points = 10
	state.check_win()
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
	state.check_win()
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
	state.check_win()
	_runner.assert_eq(state.phase, GameState.Phase.GAME_OVER,
		"Largest Army bonus pushing VP to 10 triggers GAME_OVER")


## When player 1 (index 1) reaches 10 VP, winner_index must be 1, not 0.
func _test_win_correct_player() -> void:
	var state := _make_state()
	state.players[0].victory_points = 9
	state.players[1].victory_points = 10
	state.check_win()
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
	state.check_win()
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
	state.check_win()
	_runner.assert_eq(state.phase, GameState.Phase.GAME_OVER,
		"12 VP still triggers GAME_OVER (>= WIN_VP check)")
	_runner.assert_eq(state.winner_index, 0,
		"winner_index set correctly at 12 VP")


## Longest Road transfers correctly: losing player loses 2 VP, gaining player gains 2 VP.
func _test_longest_road_transfer() -> void:
	var state := _make_state()
	var p0: RefCounted = state.players[0]
	var p1: RefCounted = state.players[1]
	p0.settlement_positions.append(Vector3(0, 0.15, 0))
	p1.settlement_positions.append(Vector3(10, 0.15, 0))

	for i in range(5):
		state.roads.append({
			"player_index": 0,
			"v1": Vector3(i, 0.15, 0),
			"v2": Vector3(i + 1, 0.15, 0),
		})
	state.update_longest_road()
	_runner.assert_eq(state.longest_road_holder, 0, "P0 starts with Longest Road")
	_runner.assert_eq(p0.victory_points, 2, "P0 gains 2 VP for the initial Longest Road")

	for i in range(6):
		state.roads.append({
			"player_index": 1,
			"v1": Vector3(10 + i, 0.15, 0),
			"v2": Vector3(11 + i, 0.15, 0),
		})
	state.update_longest_road()
	_runner.assert_eq(state.longest_road_holder, 1, "Longest Road transfers to P1 with the longer path")
	_runner.assert_eq(p0.victory_points, 0, "P0 loses 2 VP when Longest Road transfers away")
	_runner.assert_eq(p1.victory_points, 2, "P1 gains 2 VP when taking Longest Road")


## Largest Army transfers correctly: losing player loses 2 VP, gaining player gains 2 VP.
func _test_largest_army_transfer() -> void:
	var state := _make_state()
	var p0: RefCounted = state.players[0]
	var p1: RefCounted = state.players[1]
	p0.dev_cards = [0, 0, 0]
	p1.dev_cards = [0, 0, 0, 0]
	state.robber_tile_key = "0,-1"

	for _i in range(3):
		state.phase = GameState.Phase.BUILD
		state.dev_cards_played_this_turn = 0
		state.play_knight(p0, 0)

	_runner.assert_eq(state.largest_army_holder, 0, "P0 starts with Largest Army")
	_runner.assert_eq(p0.victory_points, 2, "P0 gains 2 VP for the initial Largest Army")

	for _i in range(4):
		state.phase = GameState.Phase.BUILD
		state.dev_cards_played_this_turn = 0
		state.play_knight(p1, 1)

	_runner.assert_eq(state.largest_army_holder, 1, "Largest Army transfers to P1 with more knights played")
	_runner.assert_eq(p0.victory_points, 0, "P0 loses 2 VP when Largest Army transfers away")
	_runner.assert_eq(p1.victory_points, 2, "P1 gains 2 VP when taking Largest Army")


func _test_robber_discard() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]

	# 7 cards — no discard
	p.resources = {0: 2, 1: 2, 2: 1, 3: 1, 4: 1}  # sum = 7
	state.apply_robber_discard()
	var total_after: int = 0
	for r in p.resources: total_after += p.resources[r]
	_runner.assert_eq(total_after, 7, "7 cards: no discard (7 < 8 threshold)")

	# 8 cards → discard 4
	p.resources = {0: 2, 1: 2, 2: 2, 3: 1, 4: 1}  # sum = 8
	state.apply_robber_discard()
	total_after = 0
	for r in p.resources: total_after += p.resources[r]
	_runner.assert_eq(total_after, 4, "8 cards: discard 4, keep 4")

	# 9 cards → discard 4 (floor(9/2) = 4)
	var p2: RefCounted = state.players[1]
	p2.resources = {0: 2, 1: 2, 2: 2, 3: 2, 4: 1}  # sum = 9
	state.apply_robber_discard()
	total_after = 0
	for r in p2.resources: total_after += p2.resources[r]
	_runner.assert_eq(total_after, 5, "9 cards: discard 4, keep 5 (floor(9/2)=4)")


func _test_resource_bank_starts_full() -> void:
	var state := _make_state()
	var bank: Dictionary = state.get_resource_bank_view()
	for resource in [PlayerData.RES_LUMBER, PlayerData.RES_BRICK, PlayerData.RES_WOOL, PlayerData.RES_GRAIN, PlayerData.RES_ORE]:
		_runner.assert_eq(bank.get(resource, 0), 19,
			"Resource bank starts with 19 cards for %s" % PlayerData.RES_NAMES[resource])


func _test_resource_collection_draws_from_bank() -> void:
	var state := _make_state_with_tile(0, 0, BoardGen.TerrainType.FOREST, 6)
	var player: RefCounted = state.players[0]
	player.settlement_positions.append(state.tile_data["0,0"].center + Vector3(0.0, 0.15, 0.0))

	state.collect_resources_for_roll(6)

	_runner.assert_eq(player.resources[PlayerData.RES_LUMBER], 1,
		"Matching roll adds one lumber to the adjacent settlement owner")
	_runner.assert_eq(state.get_resource_bank_view()[PlayerData.RES_LUMBER], 18,
		"Paid production removes the resource from the bank")


func _test_resource_collection_skips_when_bank_cannot_cover_type() -> void:
	var state := _make_state_with_tile(0, 0, BoardGen.TerrainType.HILLS, 8)
	var center: Vector3 = state.tile_data["0,0"].center
	var player: RefCounted = state.players[0]
	player.settlement_positions.append(center + Vector3(0.0, 0.15, 0.0))
	player.city_positions.append(center + Vector3(0.0, 0.15, 0.0))
	state.resource_bank[PlayerData.RES_BRICK] = 1

	state.collect_resources_for_roll(8)

	_runner.assert_eq(player.resources[PlayerData.RES_BRICK], 0,
		"When the bank cannot cover a resource type, no payout of that type is made")
	_runner.assert_eq(state.get_resource_bank_view()[PlayerData.RES_BRICK], 1,
		"Skipped payouts do not partially drain the bank")


func _test_dev_purchase_returns_cost_to_bank() -> void:
	var state := _make_state()
	state.phase = GameState.Phase.BUILD
	state.dev_deck = [DevCards.Type.KNIGHT]
	state.debug_adjust_resource(0, PlayerData.RES_WOOL, 1)
	state.debug_adjust_resource(0, PlayerData.RES_GRAIN, 1)
	state.debug_adjust_resource(0, PlayerData.RES_ORE, 1)

	var bought: bool = state.buy_dev_card(state.players[0])
	var bank: Dictionary = state.get_resource_bank_view()

	_runner.assert_true(bought, "Buying a dev card succeeds with the exact cost in hand")
	_runner.assert_eq(bank[PlayerData.RES_WOOL], 19,
		"Dev purchase returns spent Wool to the bank")
	_runner.assert_eq(bank[PlayerData.RES_GRAIN], 19,
		"Dev purchase returns spent Grain to the bank")
	_runner.assert_eq(bank[PlayerData.RES_ORE], 19,
		"Dev purchase returns spent Ore to the bank")


func _test_year_of_plenty_fails_when_bank_is_short() -> void:
	var state := _make_state()
	var player: RefCounted = state.players[0]
	player.dev_cards.append(DevCards.Type.YEAR_OF_PLENTY)
	state.phase = GameState.Phase.BUILD
	state.resource_bank[PlayerData.RES_ORE] = 1

	var played: bool = state.play_year_of_plenty(player, PlayerData.RES_ORE, PlayerData.RES_ORE)

	_runner.assert_false(played, "Year of Plenty fails if the bank cannot supply both chosen cards")
	_runner.assert_eq(player.resources[PlayerData.RES_ORE], 0,
		"Failed Year of Plenty does not grant a partial resource payout")


func _test_dev_supply_view_tracks_remaining_and_revealed_cards() -> void:
	var state := _make_state()
	state.dev_deck = [DevCards.Type.YEAR_OF_PLENTY, DevCards.Type.VP]
	state.debug_take_dev_card(0, DevCards.Type.VP)

	var view: Dictionary = state.get_dev_supply_view()
	var remaining: Dictionary = view.get("remaining_counts", {})
	var revealed: Dictionary = view.get("revealed_counts", {})

	_runner.assert_eq(view.get("remaining_total", -1), 1,
		"Dev supply view reports the remaining deck size")
	_runner.assert_eq(remaining.get(DevCards.Type.VP, -1), 0,
		"Dev supply view removes revealed VP cards from the remaining counts")
	_runner.assert_eq(revealed.get(DevCards.Type.VP, -1), 1,
		"Dev supply view tracks revealed dev cards by type")


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


func _test_settlement_requires_connected_road() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.resources = {0: 2, 1: 2, 2: 2, 3: 2, 4: 0}

	var blocked: bool = state.try_place_settlement(p, Vector3(5, 0.15, 0))
	_runner.assert_false(blocked,
		"Settlement rejected when not connected to the player's road network")

	state.roads.append({
		"player_index": 0,
		"v1": Vector3(0, 0.15, 0),
		"v2": Vector3(HexGrid.HEX_SIZE, 0.15, 0),
	})

	var ok: bool = state.try_place_settlement(p, Vector3(HexGrid.HEX_SIZE, 0.15, 0))
	_runner.assert_true(ok,
		"Settlement allowed when it connects to the player's road endpoint")


func _test_city_requires_owned_settlement() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.resources = {0: 0, 1: 0, 2: 0, 3: 2, 4: 3}

	var ok: bool = state.try_place_city(p, Vector3(0, 0.15, 0))
	_runner.assert_false(ok, "City rejected without an existing owned settlement")


func _test_city_rejects_duplicate_upgrade() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	var spot := Vector3(0, 0.15, 0)
	p.settlement_positions.append(spot)
	p.resources = {0: 0, 1: 0, 2: 0, 3: 4, 4: 6}

	var first_ok: bool = state.try_place_city(p, spot)
	_runner.assert_true(first_ok, "City upgrade succeeds on an owned settlement")

	var second_ok: bool = state.try_place_city(p, spot)
	_runner.assert_false(second_ok, "City rejected when the same settlement is already a city")


func _test_duplicate_road_rejected() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.resources = {0: 5, 1: 5, 2: 0, 3: 0, 4: 0}
	p.settlement_positions.append(Vector3(0, 0.15, 0))

	var v1 := Vector3(0, 0.15, 0)
	var v2 := Vector3(1, 0.15, 0)

	var first_ok: bool = state.try_place_road(p, 0, v1, v2)
	_runner.assert_true(first_ok, "First road placement succeeds")

	var lumber_after_first: int = p.resources[PlayerData.RES_LUMBER]
	var brick_after_first: int = p.resources[PlayerData.RES_BRICK]

	var second_ok: bool = state.try_place_road(p, 0, v2, v1)
	_runner.assert_false(second_ok, "Duplicate road rejected even in reverse direction")
	_runner.assert_eq(state.roads.size(), 1, "Duplicate road does not increase road count")
	_runner.assert_eq(p.resources[PlayerData.RES_LUMBER], lumber_after_first,
		"Duplicate road does not spend Lumber")
	_runner.assert_eq(p.resources[PlayerData.RES_BRICK], brick_after_first,
		"Duplicate road does not spend Brick")


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

	# Play 2 knights — no bonus yet (each on a simulated separate turn)
	state.play_knight(p, 0)
	state.phase = GameState.Phase.BUILD; state.dev_cards_played_this_turn = 0
	state.play_knight(p, 0)
	state.phase = GameState.Phase.BUILD; state.dev_cards_played_this_turn = 0
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
	state.collect_resources_for_roll(6)
	_runner.assert_eq(p.resources[PlayerData.RES_LUMBER], before + 1,
		"Roll 6 on Forest tile gives +1 Lumber")

	# Roll 5 → no production (Forest has token 6)
	state.collect_resources_for_roll(5)
	_runner.assert_eq(p.resources[PlayerData.RES_LUMBER], before + 1,
		"Roll 5 on Forest(6) tile gives no Lumber")


func _test_resource_payout_signal_tracks_exact_sources() -> void:
	var state := _make_state()
	state.tile_data = {
		"0,0": {
			"terrain": BoardGen.TerrainType.HILLS,
			"number": 8,
			"center": HexGrid.axial_to_world(0, 0),
			"q": 0, "r": 0, "area": null,
		},
		"2,0": {
			"terrain": BoardGen.TerrainType.PASTURE,
			"number": 8,
			"center": HexGrid.axial_to_world(2, 0),
			"q": 2, "r": 0, "area": null,
		},
	}
	state.robber_tile_key = "9,9"

	var payouts_seen: Array = []
	state.resource_payouts_generated.connect(func(payouts: Array) -> void:
		payouts_seen.clear()
		payouts_seen.append_array(payouts.duplicate(true))
	)

	var p0: RefCounted = state.players[0]
	p0.settlement_positions.append(Vector3(
		state.tile_data["0,0"].center.x + HexGrid.HEX_SIZE, 0.15, state.tile_data["0,0"].center.z))
	var city_pos := Vector3(
		state.tile_data["2,0"].center.x + HexGrid.HEX_SIZE, 0.15, state.tile_data["2,0"].center.z)
	p0.settlement_positions.append(city_pos)
	p0.city_positions.append(city_pos)

	state.collect_resources_for_roll(8)

	_runner.assert_eq(payouts_seen.size(), 2,
		"Payout signal emits one entry per paying tile and player")
	_runner.assert_eq(payouts_seen[0].tile_key, "0,0",
		"Payout signal keeps the exact brick tile key")
	_runner.assert_eq(payouts_seen[0].resource, PlayerData.RES_BRICK,
		"Payout signal keeps the exact brick resource type")
	_runner.assert_eq(payouts_seen[0].amount, 1,
		"Payout signal records single-settlement payout amount")
	_runner.assert_eq(payouts_seen[1].tile_key, "2,0",
		"Payout signal keeps the exact wool tile key")
	_runner.assert_eq(payouts_seen[1].resource, PlayerData.RES_WOOL,
		"Payout signal keeps the exact wool resource type")
	_runner.assert_eq(payouts_seen[1].amount, 2,
		"Payout signal records city payout amount")
	_runner.assert_eq(payouts_seen[1].roll, 8,
		"Payout signal records the triggering dice roll")


# ---------------------------------------------------------------
# Sprint 2A — Port / harbour trade rate tests
# ---------------------------------------------------------------

## Player with settlement at a generic (3:1) harbour vertex gets rate=3.
func _test_port_generic_rate() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	# First harbour in HARBORS: type=-1 (generic), v1x=-5.145, v1z=3.819
	var harbor: Dictionary = HexGrid.HARBORS[0]
	p.settlement_positions.append(Vector3(harbor["v1x"], 0.15, harbor["v1z"]))
	p.resources[PlayerData.RES_LUMBER] = 3   # can now trade 3 Lumber
	var rate: int = state.get_trade_rate_for(p, PlayerData.RES_LUMBER)
	_runner.assert_eq(rate, 3, "Generic harbour gives 3:1 rate")


## Player with settlement at a specific (2:1 Grain) harbour vertex gets rate=2 for Grain.
func _test_port_specific_rate() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	# Harbour index 2: type=3 (Grain=RES_GRAIN), v1x=3.675, v1z=3.819
	var harbor: Dictionary = HexGrid.HARBORS[2]
	p.settlement_positions.append(Vector3(harbor["v1x"], 0.15, harbor["v1z"]))
	var grain_rate: int = state.get_trade_rate_for(p, PlayerData.RES_GRAIN)
	_runner.assert_eq(grain_rate, 2, "Specific Grain harbour gives 2:1 for Grain")
	# Other resources still at 4:1 (no generic port)
	var lumber_rate: int = state.get_trade_rate_for(p, PlayerData.RES_LUMBER)
	_runner.assert_eq(lumber_rate, 4, "Specific Grain harbour still 4:1 for Lumber")


## Player without any harbour settlement gets default 4:1 rate.
func _test_port_no_rate_without_settlement() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.settlement_positions.append(Vector3(0, 0.15, 0))   # board centre — no harbour
	var rate: int = state.get_trade_rate_for(p, PlayerData.RES_ORE)
	_runner.assert_eq(rate, 4, "No harbour settlement → default 4:1")


# ---------------------------------------------------------------
# Sprint 2B — Dev card timing rule tests
# ---------------------------------------------------------------

## Player may only play 1 dev card per turn.
func _test_dev_card_timing_max_one_per_turn() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	p.dev_cards = [0, 0]          # 2 Knights
	state.robber_tile_key = "0,0"
	state.phase = GameState.Phase.BUILD

	var ok1: bool = state.play_knight(p, 0)   # 1st Knight — should succeed
	state.phase = GameState.Phase.BUILD        # reset after robber move
	var ok2: bool = state.play_knight(p, 0)   # 2nd Knight same turn — must fail

	_runner.assert_true(ok1,  "Dev card timing: first Knight succeeds")
	_runner.assert_false(ok2, "Dev card timing: second Knight same turn blocked")


## Player cannot play a dev card they bought on the same turn.
func _test_dev_card_timing_cannot_play_bought_same_turn() -> void:
	var state := _make_state()
	var p: RefCounted = state.players[0]
	# Simulate: Knight was bought this turn
	p.dev_cards = [0]                          # 1 Knight in hand
	state.dev_cards_new_this_turn[0] = 1       # bought this turn
	state.robber_tile_key = "0,0"

	var ok: bool = state.play_knight(p, 0)
	_runner.assert_false(ok, "Dev card timing: cannot play card bought this turn")

	# Next turn: counter resets → should be playable
	state.dev_cards_new_this_turn = {}
	state.dev_cards_played_this_turn = 0
	state.phase = GameState.Phase.BUILD
	var ok2: bool = state.play_knight(p, 0)
	_runner.assert_true(ok2, "Dev card timing: same card playable next turn after reset")


# ---------------------------------------------------------------
# Sprint 2C — Player-to-player trade tests
# ---------------------------------------------------------------

## Valid trade executes: resources move between players correctly.
func _test_player_trade_executes() -> void:
	var state := _make_state()
	var p0: RefCounted = state.players[0]
	var p1: RefCounted = state.players[1]
	p0.resources[PlayerData.RES_LUMBER] = 3
	p1.resources[PlayerData.RES_BRICK]  = 2

	var ok: bool = state.player_trade(p0, p1,
		{PlayerData.RES_LUMBER: 2},   # offer 2 Lumber
		{PlayerData.RES_BRICK:  1})   # want 1 Brick
	_runner.assert_true(ok,  "Player trade: valid trade returns true")
	_runner.assert_eq(p0.resources[PlayerData.RES_LUMBER], 1, "Player trade: P0 gave 2 Lumber (3→1)")
	_runner.assert_eq(p0.resources[PlayerData.RES_BRICK],  1, "Player trade: P0 received 1 Brick")
	_runner.assert_eq(p1.resources[PlayerData.RES_LUMBER], 2, "Player trade: P1 received 2 Lumber")
	_runner.assert_eq(p1.resources[PlayerData.RES_BRICK],  1, "Player trade: P1 gave 1 Brick (2→1)")


## Trade fails if offering player lacks the offered resource.
func _test_player_trade_rejects_when_insufficient() -> void:
	var state := _make_state()
	var p0: RefCounted = state.players[0]
	var p1: RefCounted = state.players[1]
	p0.resources[PlayerData.RES_ORE] = 1   # has only 1 Ore
	p1.resources[PlayerData.RES_GRAIN] = 2

	var ok: bool = state.player_trade(p0, p1,
		{PlayerData.RES_ORE: 2},           # trying to offer 2 but only has 1
		{PlayerData.RES_GRAIN: 1})
	_runner.assert_false(ok, "Player trade: insufficient offer resource rejects trade")
	_runner.assert_eq(p0.resources[PlayerData.RES_ORE], 1, "Player trade: P0 resources unchanged on reject")


func _test_move_robber_rejects_invalid_tile() -> void:
	var state := _make_state_with_tile(0, 0, BoardGen.TerrainType.FOREST, 6)
	state.phase = GameState.Phase.ROBBER_MOVE
	state.robber_tile_key = "0,0"

	state.move_robber("9,9")
	_runner.assert_eq(state.robber_tile_key, "0,0",
		"Robber ignores invalid tile keys")
	_runner.assert_eq(state.phase, GameState.Phase.ROBBER_MOVE,
		"Invalid robber move keeps the game in ROBBER_MOVE phase")


func _test_move_robber_rejects_same_tile() -> void:
	var state := _make_state_with_tile(0, 0, BoardGen.TerrainType.FOREST, 6)
	state.tile_data["1,0"] = {
		"terrain": BoardGen.TerrainType.HILLS,
		"number": 8,
		"center": HexGrid.axial_to_world(1, 0),
		"q": 1, "r": 0, "area": null,
	}
	state.phase = GameState.Phase.ROBBER_MOVE
	state.robber_tile_key = "0,0"

	state.move_robber("0,0")
	_runner.assert_eq(state.robber_tile_key, "0,0",
		"Robber cannot stay on the same tile")
	_runner.assert_eq(state.phase, GameState.Phase.ROBBER_MOVE,
		"Same-tile robber move keeps the game in ROBBER_MOVE phase")


func _test_get_robber_victims_returns_adjacent_opponents() -> void:
	var state := _make_state_with_tile(0, 0, BoardGen.TerrainType.HILLS, 8)
	state.current_player_index = 0
	state.players[1].settlement_positions.append(Vector3(0.0, 0.15, 0.0))
	state.players[0].settlement_positions.append(Vector3(4.0, 0.15, 0.0))

	var victims: Array = state.get_robber_victims("0,0")
	_runner.assert_eq(victims, [1],
		"Robber victim query returns adjacent opponents only")


func _test_get_hand_cards_expands_resource_counts() -> void:
	var state := _make_state()
	state.players[1].resources = {
		PlayerData.RES_LUMBER: 2,
		PlayerData.RES_BRICK: 1,
		PlayerData.RES_WOOL: 0,
		PlayerData.RES_GRAIN: 1,
		PlayerData.RES_ORE: 0,
	}

	var cards: Array = state.get_hand_cards(1, false)
	_runner.assert_eq(cards.size(), 4,
		"Hand-card expansion returns one card per resource unit")
	_runner.assert_eq(int(cards[0]["resource"]), PlayerData.RES_LUMBER,
		"Hand-card expansion preserves resource identity")

	var shuffled: Array = state.get_hand_cards(1, true)
	_runner.assert_eq(shuffled.size(), 4,
		"Shuffled hand-card expansion keeps the same total count")


func _test_steal_specific_resource_transfers_exact_card() -> void:
	var state := _make_state()
	state.current_player_index = 0
	state.players[1].resources[PlayerData.RES_WOOL] = 2

	var stolen: bool = state.steal_specific_resource(1, PlayerData.RES_WOOL)

	_runner.assert_true(stolen,
		"Specific robber steal succeeds when the victim has that resource")
	_runner.assert_eq(state.players[1].resources[PlayerData.RES_WOOL], 1,
		"Specific robber steal removes exactly one matching card from the victim")
	_runner.assert_eq(state.players[0].resources[PlayerData.RES_WOOL], 1,
		"Specific robber steal transfers the exact resource to the current player")


func _test_scenario_setup_roll_robber_build_end_turn() -> void:
	var state := _make_state()
	state.tile_data = {
		"0,0": {
			"terrain": BoardGen.TerrainType.HILLS,
			"number": 4,
			"center": HexGrid.axial_to_world(0, 0),
			"q": 0, "r": 0, "area": null,
		},
		"1,0": {
			"terrain": BoardGen.TerrainType.DESERT,
			"number": 0,
			"center": HexGrid.axial_to_world(1, 0),
			"q": 1, "r": 0, "area": null,
		},
	}
	state.robber_tile_key = "1,0"
	state.init_setup()

	var p0_spot := Vector3(0, 0.15, 0)
	var p1_spot := Vector3(5, 0.15, 0)
	var p0_road_end := Vector3(HexGrid.HEX_SIZE, 0.15, 0)
	var p1_road_end := Vector3(5 + HexGrid.HEX_SIZE, 0.15, 0)

	_runner.assert_true(state.can_place_setup_settlement_at(p0_spot),
		"Scenario: setup starts with a legal settlement vertex")
	state.setup_settlement_placed(p0_spot)
	_runner.assert_true(state.can_place_setup_road_at(0, p0_spot, p0_road_end),
		"Scenario: setup road becomes legal after placing the settlement")
	state.try_place_road(state.players[0], 0, p0_spot, p0_road_end)
	state.setup_road_placed()

	state.setup_settlement_placed(p1_spot)
	state.try_place_road(state.players[1], 1, p1_spot, p1_road_end)
	state.setup_road_placed()

	state.setup_settlement_placed(Vector3(-5, 0.15, 0))
	state.try_place_road(state.players[1], 1, Vector3(-5, 0.15, 0), Vector3(-5 - HexGrid.HEX_SIZE, 0.15, 0))
	state.setup_road_placed()

	state.setup_settlement_placed(Vector3(10, 0.15, 0))
	state.try_place_road(state.players[0], 0, Vector3(10, 0.15, 0), Vector3(10 + HexGrid.HEX_SIZE, 0.15, 0))
	state.setup_road_placed()

	_runner.assert_eq(state.phase, GameState.Phase.ROLL,
		"Scenario: setup completes into the roll phase")
	_runner.assert_eq(state.current_player_index, 0,
		"Scenario: Player 1 starts the main game after setup")

	state.debug_collect(4)
	_runner.assert_eq(state.players[0].resources.get(PlayerData.RES_BRICK, 0), 1,
		"Scenario: matching roll pays the adjacent brick settlement")

	state.phase = GameState.Phase.ROBBER_MOVE
	_runner.assert_true(state.can_move_robber_to("0,0"),
		"Scenario: robber can move onto a different valid tile")
	state.move_robber("0,0")
	_runner.assert_eq(state.phase, GameState.Phase.BUILD,
		"Scenario: robber move returns the turn to build phase")

	var build_pos := Vector3(HexGrid.HEX_SIZE * 2.0, 0.15, 0)
	var p0: RefCounted = state.players[0]
	state.roads.append({
		"player_index": 0,
		"v1": p0_road_end,
		"v2": build_pos,
	})
	p0.resources = {0: 1, 1: 1, 2: 1, 3: 1, 4: 0}
	_runner.assert_true(state.can_place_settlement_at(0, build_pos),
		"Scenario: connected settlement location is legal in build phase")
	_runner.assert_true(state.try_place_settlement(p0, build_pos),
		"Scenario: build phase accepts the connected settlement")
	state.end_turn()
	_runner.assert_eq(state.phase, GameState.Phase.ROLL,
		"Scenario: ending the turn returns the next player to roll phase")
	_runner.assert_eq(state.current_player_index, 1,
		"Scenario: turn passes to Player 2 after end_turn")


func _test_scenario_bonus_transfer_flow() -> void:
	var state := _make_state()
	var p0: RefCounted = state.players[0]
	var p1: RefCounted = state.players[1]

	p0.settlement_positions.append(Vector3(0, 0.15, 0))
	p1.settlement_positions.append(Vector3(10, 0.15, 0))
	for i in range(5):
		state.roads.append({
			"player_index": 0,
			"v1": Vector3(i, 0.15, 0),
			"v2": Vector3(i + 1, 0.15, 0),
		})
	state.update_longest_road()
	_runner.assert_eq(state.longest_road_holder, 0,
		"Scenario: Player 1 takes Longest Road first")

	for i in range(6):
		state.roads.append({
			"player_index": 1,
			"v1": Vector3(10 + i, 0.15, 0),
			"v2": Vector3(11 + i, 0.15, 0),
		})
	state.update_longest_road()
	_runner.assert_eq(state.longest_road_holder, 1,
		"Scenario: Longest Road transfers when Player 2 exceeds the path length")

	p0.dev_cards = [0, 0, 0]
	p1.dev_cards = [0, 0, 0, 0]
	state.robber_tile_key = "0,0"
	for _i in range(3):
		state.phase = GameState.Phase.BUILD
		state.dev_cards_played_this_turn = 0
		state.play_knight(p0, 0)
	_runner.assert_eq(state.largest_army_holder, 0,
		"Scenario: Player 1 takes Largest Army at three knights")

	for _i in range(4):
		state.phase = GameState.Phase.BUILD
		state.dev_cards_played_this_turn = 0
		state.play_knight(p1, 1)
	_runner.assert_eq(state.largest_army_holder, 1,
		"Scenario: Largest Army transfers when Player 2 plays the fourth knight")
