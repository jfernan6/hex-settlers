extends RefCounted

const AIPlayer   = preload("res://scripts/game/ai_player.gd")
const GameState  = preload("res://scripts/game/game_state.gd")
const PlayerData = preload("res://scripts/player/player.gd")
const HexGrid    = preload("res://scripts/board/hex_grid.gd")

var _runner


func run() -> void:
	_test_pick_setup_vertex_null_when_blocked()
	_test_pick_setup_vertex_highest_score()
	_test_decide_build_bank_trade_first()
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


func _test_decide_build_bank_trade_first() -> void:
	var state := _make_state()
	state.current_player_index = 0
	var p: RefCounted = state.players[0]

	# Give player 4 Lumber and nothing else — should bank trade immediately
	p.resources = {0: 4, 1: 0, 2: 0, 3: 0, 4: 0}
	p.free_placements_left = 0

	var decision: Dictionary = AIPlayer.decide_build(p, state, [], [])
	_runner.assert_eq(decision.action, "bank_trade",
		"decide_build returns bank_trade when 4+ surplus exists")
	_runner.assert_eq(decision.params.give, PlayerData.RES_LUMBER,
		"Bank trade gives away Lumber surplus")


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
