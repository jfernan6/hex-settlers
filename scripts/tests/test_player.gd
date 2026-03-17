extends RefCounted

const PlayerData = preload("res://scripts/player/player.gd")

var _runner


func run() -> void:
	_test_init_defaults()
	_test_can_build_settlement_free()
	_test_can_build_settlement_resources()
	_test_can_build_settlement_piece_limit()
	_test_resource_summary_format()
	_test_debug_summary_ai_flag()


func _test_init_defaults() -> void:
	var p := PlayerData.new("Test", Color.RED)
	_runner.assert_eq(p.victory_points, 0,     "victory_points initializes to 0")
	_runner.assert_eq(p.knight_count, 0,       "knight_count initializes to 0")
	_runner.assert_eq(p.free_roads, 0,         "free_roads initializes to 0")
	_runner.assert_eq(p.dev_cards.size(), 0,   "dev_cards initializes empty")
	_runner.assert_eq(p.is_ai, false,          "is_ai defaults to false")
	_runner.assert_eq(p.free_placements_left, 2, "free_placements_left starts at 2")


func _test_can_build_settlement_free() -> void:
	var p := PlayerData.new("Test", Color.BLUE)
	# With 2 free placements and 0 resources, should be able to build
	_runner.assert_true(p.can_build_settlement(),
		"can_build_settlement is true with free placements")


func _test_can_build_settlement_resources() -> void:
	var p := PlayerData.new("Test", Color.BLUE)
	p.free_placements_left = 0

	# No resources → cannot build
	_runner.assert_false(p.can_build_settlement(),
		"can_build_settlement is false with no resources and no free placements")

	# Exact cost → can build (1 Lumber, 1 Brick, 1 Wool, 1 Grain)
	p.resources = {0: 1, 1: 1, 2: 1, 3: 1, 4: 0}
	_runner.assert_true(p.can_build_settlement(),
		"can_build_settlement is true with exact settlement cost")

	# Missing 1 resource → cannot build
	p.resources = {0: 1, 1: 1, 2: 0, 3: 1, 4: 0}
	_runner.assert_false(p.can_build_settlement(),
		"can_build_settlement is false when missing 1 resource")


func _test_can_build_settlement_piece_limit() -> void:
	var p := PlayerData.new("Test", Color.GREEN)
	p.free_placements_left = 0
	p.resources = {0: 5, 1: 5, 2: 5, 3: 5, 4: 5}

	# Simulate 5 settlements placed, 0 upgraded to cities
	for i in range(5):
		p.settlement_positions.append(Vector3(float(i) * 5.0, 0, 0))

	_runner.assert_false(p.can_build_settlement(),
		"can_build_settlement is false when 5 settlements already placed")

	# Upgrade 4 to cities → now 1 active settlement, can build again
	for i in range(4):
		p.city_positions.append(p.settlement_positions[i])

	_runner.assert_true(p.can_build_settlement(),
		"can_build_settlement is true after 4 cities (only 1 active settlement)")


func _test_resource_summary_format() -> void:
	var p := PlayerData.new("Test", Color.WHITE)
	p.resources = {0: 2, 1: 0, 2: 1, 3: 0, 4: 3}
	var summary := p.resource_summary()
	_runner.assert_true(summary.contains("Lumber: 2"), "resource_summary shows Lumber: 2")
	_runner.assert_true(summary.contains("Ore: 3"),    "resource_summary shows Ore: 3")


func _test_debug_summary_ai_flag() -> void:
	var p := PlayerData.new("Bot", Color.ORANGE)
	p.is_ai = true
	var summary := p.debug_summary()
	_runner.assert_true(summary.contains("(AI)"), "debug_summary includes (AI) for AI players")

	p.is_ai = false
	summary = p.debug_summary()
	_runner.assert_false(summary.contains("(AI)"), "debug_summary excludes (AI) for human players")
