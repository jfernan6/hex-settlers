class_name BoardGenerator

## Generates the 19-tile Catan board with randomized terrain and number tokens.

const HexGrid = preload("res://scripts/board/hex_grid.gd")

enum TerrainType {
	FOREST,    # Lumber
	HILLS,     # Brick
	PASTURE,   # Wool
	FIELDS,    # Grain
	MOUNTAINS, # Ore
	DESERT
}

# Standard Catan tile distribution
const TERRAIN_COUNTS: Dictionary = {
	TerrainType.FOREST:    4,
	TerrainType.HILLS:     3,
	TerrainType.PASTURE:   4,
	TerrainType.FIELDS:    4,
	TerrainType.MOUNTAINS: 3,
	TerrainType.DESERT:    1,
}

const TERRAIN_COLORS: Dictionary = {
	TerrainType.FOREST:    Color(0.10, 0.42, 0.10),
	TerrainType.HILLS:     Color(0.72, 0.30, 0.10),
	TerrainType.PASTURE:   Color(0.45, 0.78, 0.20),
	TerrainType.FIELDS:    Color(0.92, 0.80, 0.10),
	TerrainType.MOUNTAINS: Color(0.50, 0.50, 0.52),
	TerrainType.DESERT:    Color(0.90, 0.82, 0.52),
}

const TERRAIN_NAMES: Dictionary = {
	TerrainType.FOREST:    "Forest",
	TerrainType.HILLS:     "Hills",
	TerrainType.PASTURE:   "Pasture",
	TerrainType.FIELDS:    "Fields",
	TerrainType.MOUNTAINS: "Mountains",
	TerrainType.DESERT:    "Desert",
}

# Standard Catan number token distribution (18 tokens for 18 non-desert tiles)
const NUMBER_TOKENS: Array = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]


## Spawns all 19 hex tiles as children of `parent`.
func generate(parent: Node3D) -> void:
	var positions := HexGrid.get_board_positions()
	var terrains := _build_shuffled_terrains()
	var tokens := NUMBER_TOKENS.duplicate()
	tokens.shuffle()

	var token_index := 0
	var terrain_tally: Dictionary = {}

	for i in positions.size():
		var q: int = positions[i].x
		var r: int = positions[i].y
		var terrain: int = terrains[i]

		var number := 0
		if terrain != TerrainType.DESERT:
			number = tokens[token_index]
			token_index += 1

		_spawn_tile(parent, q, r, terrain, number)
		terrain_tally[terrain] = terrain_tally.get(terrain, 0) + 1

		var token_str := "(%d)" % number if number > 0 else "(desert)"
		print("  Tile [q=%2d, r=%2d]  %-10s %s" % [q, r, TERRAIN_NAMES[terrain], token_str])

	# --- Validation summary ---
	print("[BOARD] --- Terrain summary ---")
	var all_ok := true
	for t in TERRAIN_COUNTS:
		var expected: int = TERRAIN_COUNTS[t]
		var actual: int = terrain_tally.get(t, 0)
		var status := "OK" if actual == expected else "ERROR — expected %d got %d" % [expected, actual]
		if actual != expected:
			all_ok = false
		print("  %-10s: %d  [%s]" % [TERRAIN_NAMES[t], actual, status])
	print("[BOARD] Tokens assigned : %d  %s" % [token_index, "OK" if token_index == 18 else "ERROR — expected 18"])
	print("[BOARD] Total tiles     : %d  %s" % [positions.size(), "OK" if positions.size() == 19 else "ERROR — expected 19"])
	print("[BOARD] Validation      : %s" % ("PASSED" if all_ok and token_index == 18 else "FAILED"))


func _build_shuffled_terrains() -> Array:
	var terrains: Array = []
	for terrain_type in TERRAIN_COUNTS:
		for _i in range(TERRAIN_COUNTS[terrain_type]):
			terrains.append(terrain_type)
	terrains.shuffle()
	return terrains


func _spawn_tile(parent: Node3D, q: int, r: int, terrain: int, number: int) -> void:
	var tile := MeshInstance3D.new()

	# Hexagonal prism — 6-sided cylinder
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.25
	mesh.radial_segments = 6
	mesh.rings = 1
	tile.mesh = mesh

	# Terrain colour
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TERRAIN_COLORS[terrain]
	mat.roughness = 0.9
	tile.material_override = mat

	tile.position = HexGrid.axial_to_world(q, r)
	tile.name = "Tile_%d_%d" % [q, r]
	parent.add_child(tile)
