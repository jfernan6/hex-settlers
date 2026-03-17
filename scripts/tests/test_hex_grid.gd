extends RefCounted

const HexGrid     = preload("res://scripts/board/hex_grid.gd")
const HexVertices = preload("res://scripts/board/hex_vertices.gd")
const HexEdges    = preload("res://scripts/board/hex_edges.gd")

var _runner  # TestRunner reference


func run() -> void:
	_test_board_positions()
	_test_ring_sizes()
	_test_axial_to_world()
	_test_vertex_count()
	_test_edge_count()


func _test_board_positions() -> void:
	var positions := HexGrid.get_board_positions()
	_runner.assert_eq(positions.size(), 19, "get_board_positions returns 19 tiles")

	# Check all unique
	var seen: Dictionary = {}
	for p in positions:
		var key := "%d,%d" % [p.x, p.y]
		seen[key] = seen.get(key, 0) + 1
	_runner.assert_eq(seen.size(), 19, "All 19 board positions are unique")

	# Center tile must exist
	var has_center := false
	for p in positions:
		if p.x == 0 and p.y == 0:
			has_center = true
			break
	_runner.assert_true(has_center, "Center tile (0,0) present in board positions")


func _test_ring_sizes() -> void:
	# Ring 0 = 1 center, ring 1 = 6, ring 2 = 12
	var positions := HexGrid.get_board_positions()

	var ring0 := 0
	var ring1 := 0
	var ring2 := 0
	for p in positions:
		var dist: int = maxi(abs(p.x), maxi(abs(p.y), abs(p.x + p.y)))
		if dist == 0: ring0 += 1
		elif dist == 1: ring1 += 1
		elif dist == 2: ring2 += 1

	_runner.assert_eq(ring0, 1,  "Ring 0 has 1 tile (center)")
	_runner.assert_eq(ring1, 6,  "Ring 1 has 6 tiles")
	_runner.assert_eq(ring2, 12, "Ring 2 has 12 tiles")


func _test_axial_to_world() -> void:
	# Center tile must be at world origin
	var origin := HexGrid.axial_to_world(0, 0)
	_runner.assert_eq(origin, Vector3(0, 0, 0), "axial_to_world(0,0) = (0,0,0)")

	# (1,0) should be at x = HEX_SIZE * 1.5
	var p10 := HexGrid.axial_to_world(1, 0)
	var expected_x: float = HexGrid.HEX_SIZE * 1.5
	_runner.assert_true(abs(p10.x - expected_x) < 0.001,
		"axial_to_world(1,0).x ≈ HEX_SIZE * 1.5")
	_runner.assert_eq(p10.y, 0.0, "axial_to_world(1,0).y == 0 (on ground plane)")

	# Symmetry: (-1,0) should mirror (1,0) on x-axis
	var pm10 := HexGrid.axial_to_world(-1, 0)
	_runner.assert_true(abs(pm10.x + p10.x) < 0.001,
		"axial_to_world(-1,0).x mirrors (1,0).x")


func _test_vertex_count() -> void:
	var positions := HexGrid.get_board_positions()
	var vertices := HexVertices.get_all_positions(positions)
	_runner.assert_eq(vertices.size(), 54, "Standard Catan board has exactly 54 vertices")


func _test_edge_count() -> void:
	var positions := HexGrid.get_board_positions()
	var edges := HexEdges.get_all_edges(positions)
	_runner.assert_eq(edges.size(), 72, "Standard Catan board has exactly 72 edges")
