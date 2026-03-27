extends RefCounted

const AIPlayer   = preload("res://scripts/game/ai_player.gd")
const GameState  = preload("res://scripts/game/game_state.gd")
const PlayerData = preload("res://scripts/player/player.gd")
const HexGrid    = preload("res://scripts/board/hex_grid.gd")

var _runner


func run() -> void:
	_test_pick_setup_vertex_null_when_blocked()
	_test_pick_setup_vertex_highest_score()
	_test_pick_road_prefers_better_expansion()
	_test_decide_build_prefers_city_over_bank_trade()
	_test_decide_build_prefers_settlement_over_bank_trade()
	_test_decide_build_end_turn_when_nothing()


func _make_state() -> RefCounted:
	var state := GameState.new()
	state.init_players(2)
	state.init_dev_deck()
	state.robber_tile_key = "99,99"
	return state


## Stub vertex slot for testing (minimal duck-typed object)
class FakeSlot extends RefCounted:
	var position: Vector3
	var is_occupied: bool = false
	var is_city: bool = false
	var owner_index: int = -1

	func _init(pos: Vector3, occupied: bool = false) -> void:
		position = pos
		is_occupied = occupied


class FakeEdgeSlot extends RefCounted:
	var v1: Vector3
	var v2: Vector3
	var is_occupied: bool = false

	func _init(p_v1: Vector3, p_v2: Vector3, occupied: bool = false) -> void:
		v1 = p_v1
		v2 = p_v2
		is_occupied = occupied


func _test_pick_setup_vertex_null_when_blocked() -> void:
	var state := _make_state()
	# Place a settlement at origin to block distance rule
	state.players[0].settlement_positions.append(Vector3(0, 0.15, 0))

	# Create a slot that violates the distance rule
	var blocked_slot := FakeSlot.new(Vector3(HexGrid.HEX_SIZE, 0.15, 0))

	var result = AIPlayer.pick_setup_vertex([blocked_slot], {}, state)
	_runner.assert_true(result == null,
		"pick_setup_vertex returns null when all slots violate distance rule")


func _test_pick_setup_vertex_highest_score() -> void:
	var state := _make_state()
	# Two free slots far apart — one adjacent to a high-value tile, one to nothing
	var slot_low  := FakeSlot.new(Vector3(0, 0.15, 0))   # no adjacent tiles
	var slot_high := FakeSlot.new(Vector3(100, 0.15, 0))  # no adjacent tiles either

	# Add a tile at (0,0) with number 6 (5 pips) adjacent to slot_low
	var tile_center := HexGrid.axial_to_world(0, 0)
	slot_low.position = Vector3(tile_center.x + HexGrid.HEX_SIZE * 0.9, 0.15, 0)

	state.tile_data["0,0"] = {
		"terrain": 0, "number": 6,
		"center": tile_center, "q": 0, "r": 0, "area": null,
	}

	var result = AIPlayer.pick_setup_vertex([slot_low, slot_high], state.tile_data, state)
	_runner.assert_true(result == slot_low,
		"pick_setup_vertex returns slot adjacent to high-pip tile")


func _test_pick_road_prefers_better_expansion() -> void:
	var state := _make_state()
	state.current_player_index = 0
	var p: RefCounted = state.players[0]
	p.settlement_positions.append(Vector3(0, 0.15, 0))

	var weak_vertex := Vector3(2, 0.15, 0)
	var strong_vertex := Vector3(0, 0.15, 2)
	var tile_center := Vector3(0, 0, 3.0)
	state.tile_data["0,1"] = {
		"terrain": 0, "number": 6,
		"center": tile_center, "q": 0, "r": 1, "area": null,
	}

	var weak_road := FakeEdgeSlot.new(Vector3(0, 0.15, 0), weak_vertex)
	var strong_road := FakeEdgeSlot.new(Vector3(0, 0.15, 0), strong_vertex)

	var weak_vertex_slot := FakeSlot.new(weak_vertex)
	var strong_vertex_slot := FakeSlot.new(strong_vertex)
	var picked = AIPlayer.pick_road(
		[weak_road, strong_road],
		[weak_vertex_slot, strong_vertex_slot],
		p,
		state)
	_runner.assert_true(picked == strong_road,
		"pick_road prefers the road leading to the higher-value expansion vertex")


func _test_decide_build_prefers_city_over_bank_trade() -> void:
	var state := _make_state()
	state.current_player_index = 0
	var p: RefCounted = state.players[0]
	p.resources = {0: 4, 1: 0, 2: 0, 3: 2, 4: 3}
	var city_slot := FakeSlot.new(Vector3(0, 0.15, 0), true)
	city_slot.owner_index = 0
	city_slot.is_city = false

	var decision: Dictionary = AIPlayer.decide_build(p, state, [city_slot], [])
	_runner.assert_eq(decision.action, "city",
		"decide_build prefers a city upgrade over a surplus bank trade")


func _test_decide_build_prefers_settlement_over_bank_trade() -> void:
	var state := _make_state()
	state.current_player_index = 0
	var p: RefCounted = state.players[0]
	p.resources = {0: 4, 1: 1, 2: 1, 3: 1, 4: 0}
	state.roads.append({
		"player_index": 0,
		"v1": Vector3(0, 0.15, 0),
		"v2": Vector3(HexGrid.HEX_SIZE, 0.15, 0),
	})
	var settlement_slot := FakeSlot.new(Vector3(HexGrid.HEX_SIZE, 0.15, 0))

	var decision: Dictionary = AIPlayer.decide_build(p, state, [settlement_slot], [])
	_runner.assert_eq(decision.action, "settlement",
		"decide_build prefers a legal settlement over a surplus bank trade")


func _test_decide_build_end_turn_when_nothing() -> void:
	var state := _make_state()
	state.current_player_index = 0
	var p: RefCounted = state.players[0]

	# No resources, no free placements, no cards, no roads
	p.resources   = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	p.free_placements_left = 0
	p.dev_cards   = []
	p.free_roads  = 0
	state.dev_deck = []  # empty deck

	var decision: Dictionary = AIPlayer.decide_build(p, state, [], [])
	_runner.assert_eq(decision.action, "end_turn",
		"decide_build returns end_turn when nothing viable")
