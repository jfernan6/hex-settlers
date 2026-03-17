extends RefCounted

const DevCards   = preload("res://scripts/game/dev_cards.gd")
const GameState  = preload("res://scripts/game/game_state.gd")
const PlayerData = preload("res://scripts/player/player.gd")

var _runner


func run() -> void:
	_test_deck_composition()
	_test_hand_summary()
	_test_knight_play()
	_test_vp_card_instant()


func _test_deck_composition() -> void:
	var deck := DevCards.make_deck()
	_runner.assert_eq(deck.size(), 25, "Deck has 25 cards total")

	var counts: Dictionary = {}
	for card in deck:
		counts[card] = counts.get(card, 0) + 1

	_runner.assert_eq(counts.get(DevCards.Type.KNIGHT, 0), 14, "14 Knight cards")
	_runner.assert_eq(counts.get(DevCards.Type.VP, 0), 5,      "5 VP cards")
	_runner.assert_eq(counts.get(DevCards.Type.ROAD_BUILDING, 0), 2, "2 Road Building cards")
	_runner.assert_eq(counts.get(DevCards.Type.YEAR_OF_PLENTY, 0), 2, "2 Year of Plenty cards")
	_runner.assert_eq(counts.get(DevCards.Type.MONOPOLY, 0), 2, "2 Monopoly cards")


func _test_hand_summary() -> void:
	var empty_summary := DevCards.hand_summary([])
	_runner.assert_eq(empty_summary, "none", "Empty hand summary is 'none'")

	var hand := [DevCards.Type.KNIGHT, DevCards.Type.KNIGHT, DevCards.Type.MONOPOLY]
	var summary := DevCards.hand_summary(hand)
	_runner.assert_true(summary.contains("KN×2"), "Hand summary shows KN×2")
	_runner.assert_true(summary.contains("MO×1"), "Hand summary shows MO×1")


func _test_knight_play() -> void:
	var state := GameState.new()
	state.init_players(2)
	state.init_dev_deck()
	state.robber_tile_key = "0,0"  # minimal setup

	var player: RefCounted = state.players[0]
	player.dev_cards.append(DevCards.Type.KNIGHT)

	var before_count: int = player.knight_count
	var ok: bool = state.play_knight(player, 0)

	_runner.assert_true(ok, "play_knight returns true when knight in hand")
	_runner.assert_eq(player.knight_count, before_count + 1, "knight_count increments")
	_runner.assert_false(DevCards.Type.KNIGHT in player.dev_cards,
		"Knight removed from hand after playing")
	_runner.assert_eq(state.phase, GameState.Phase.ROBBER_MOVE,
		"Phase becomes ROBBER_MOVE after Knight")


func _test_vp_card_instant() -> void:
	# Force a VP card draw: put one at top of deck
	var state := GameState.new()
	state.init_players(2)
	state.dev_deck = [DevCards.Type.VP]  # single VP card

	var player: RefCounted = state.players[0]
	# Give player cost
	player.resources = {0: 1, 1: 1, 2: 1, 3: 1, 4: 1}

	var before_vp: int = player.victory_points
	state.buy_dev_card(player)

	_runner.assert_eq(player.victory_points, before_vp + 1,
		"VP card gives +1 VP immediately")
	_runner.assert_eq(player.dev_cards.size(), 0,
		"VP card is NOT added to hand (consumed immediately)")
	_runner.assert_true(state.dev_deck.is_empty(),
		"Deck empty after drawing last card")
