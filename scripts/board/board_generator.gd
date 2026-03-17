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

## PBR properties per terrain: colour, roughness, metallic
const TERRAIN_PBR: Dictionary = {
	TerrainType.FOREST:    {c=Color(0.07, 0.30, 0.07), r=0.92, m=0.00},
	TerrainType.HILLS:     {c=Color(0.68, 0.20, 0.06), r=0.88, m=0.05},
	TerrainType.PASTURE:   {c=Color(0.35, 0.72, 0.14), r=0.94, m=0.00},
	TerrainType.FIELDS:    {c=Color(0.90, 0.76, 0.06), r=0.92, m=0.00},
	TerrainType.MOUNTAINS: {c=Color(0.40, 0.40, 0.44), r=0.62, m=0.22},
	TerrainType.DESERT:    {c=Color(0.92, 0.84, 0.54), r=0.97, m=0.00},
}

# Keep for backwards compat with any log/test that references TERRAIN_COLORS
const TERRAIN_COLORS: Dictionary = {
	TerrainType.FOREST:    Color(0.07, 0.30, 0.07),
	TerrainType.HILLS:     Color(0.68, 0.20, 0.06),
	TerrainType.PASTURE:   Color(0.35, 0.72, 0.14),
	TerrainType.FIELDS:    Color(0.90, 0.76, 0.06),
	TerrainType.MOUNTAINS: Color(0.40, 0.40, 0.44),
	TerrainType.DESERT:    Color(0.92, 0.84, 0.54),
}

const SEA_PBR: Dictionary = {c=Color(0.04, 0.28, 0.58), r=0.18, m=0.35}

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
## Returns a Dictionary mapping "q,r" -> {terrain, number, center, q, r}
## so game logic can look up which tiles a settlement is adjacent to.
func generate(parent: Node3D) -> Dictionary:
	_spawn_board_base(parent)
	_spawn_sea_frame(parent)
	var positions := HexGrid.get_board_positions()
	var terrains := _build_shuffled_terrains()
	var tokens := NUMBER_TOKENS.duplicate()
	tokens.shuffle()

	var token_index := 0
	var terrain_tally: Dictionary = {}
	var tile_data: Dictionary = {}  # "q,r" -> {terrain, number, center}

	for i in positions.size():
		var q: int = positions[i].x
		var r: int = positions[i].y
		var terrain: int = terrains[i]

		var number := 0
		if terrain != TerrainType.DESERT:
			number = tokens[token_index]
			token_index += 1

		var spawn_result: Array = _spawn_tile(parent, q, r, terrain, number)
		var area: Area3D = spawn_result[0]
		var tile_mesh: MeshInstance3D = spawn_result[1]
		terrain_tally[terrain] = terrain_tally.get(terrain, 0) + 1

		tile_data["%d,%d" % [q, r]] = {
			"terrain": terrain,
			"number":  number,
			"center":  HexGrid.axial_to_world(q, r),
			"q": q,
			"r": r,
			"area": area,      # Area3D (kept for legacy; robber uses ray casting now)
			"mesh": tile_mesh, # MeshInstance3D for visual highlighting
		}

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

	return tile_data


func _build_shuffled_terrains() -> Array:
	var terrains: Array = []
	for terrain_type in TERRAIN_COUNTS:
		for _i in range(TERRAIN_COUNTS[terrain_type]):
			terrains.append(terrain_type)
	terrains.shuffle()
	return terrains


## Spawns one tile. Returns [Area3D, MeshInstance3D].
func _spawn_tile(parent: Node3D, q: int, r: int, terrain: int, number: int) -> Array:
	# Container groups mesh + label + collision under one node
	var container := Node3D.new()
	container.name = "Tile_%d_%d" % [q, r]
	container.position = HexGrid.axial_to_world(q, r)
	parent.add_child(container)

	# Hexagonal prism mesh
	var tile := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.25
	mesh.radial_segments = 6
	mesh.rings = 1
	tile.mesh = mesh
	var pbr: Dictionary = TERRAIN_PBR[terrain]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = pbr.c
	mat.roughness    = pbr.r
	mat.metallic     = pbr.m
	tile.material_override = mat
	container.add_child(tile)

	# Clickable area (used for robber placement when phase=ROBBER_MOVE)
	var area := Area3D.new()
	area.name = "TileArea"
	area.input_ray_pickable = false  # enabled only during ROBBER_MOVE
	var col := CollisionShape3D.new()
	var cshape := CylinderShape3D.new()
	cshape.radius = 0.95
	cshape.height = 0.3
	col.shape = cshape
	area.add_child(col)
	container.add_child(area)

	# Number token label (skip desert)
	if number > 0:
		var num_label := Label3D.new()
		num_label.text = str(number)
		num_label.position = Vector3(0, 0.22, 0)
		num_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		num_label.font_size = 128
		num_label.pixel_size = 0.003
		num_label.outline_size = 10
		num_label.outline_modulate = Color(0.95, 0.92, 0.80)
		num_label.modulate = Color(0.85, 0.08, 0.08) if number in [6, 8] else Color(0.06, 0.06, 0.06)
		container.add_child(num_label)

		# Probability pips (•) below the number — more pips = better odds
		var pips: int = 6 - abs(7 - number)
		var pip_label := Label3D.new()
		pip_label.text = "•".repeat(pips)
		pip_label.position = Vector3(0, 0.13, 0)
		pip_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pip_label.font_size = 80
		pip_label.pixel_size = 0.003
		pip_label.outline_size = 6
		pip_label.outline_modulate = Color(0.95, 0.92, 0.80)
		pip_label.modulate = Color(0.85, 0.08, 0.08) if number in [6, 8] else Color(0.06, 0.06, 0.06)
		container.add_child(pip_label)

	return [area, tile]


# ---------------------------------------------------------------
# Sprint B: visual elements
# ---------------------------------------------------------------

func _spawn_board_base(parent: Node3D) -> void:
	var base := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius    = 5.8
	mesh.bottom_radius = 5.8
	mesh.height        = 0.10
	mesh.radial_segments = 24
	mesh.rings = 1
	base.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.09, 0.05)  # dark walnut wood
	mat.roughness    = 0.88
	mat.metallic     = 0.05
	base.position = Vector3(0, -0.18, 0)
	base.name = "BoardBase"
	parent.add_child(base)


func _spawn_sea_frame(parent: Node3D) -> void:
	# Ring 3 (18 tiles) forms the ocean border around the playfield
	var sea_positions := HexGrid._get_ring_positions(3)
	for pos in sea_positions:
		var container := Node3D.new()
		container.position = HexGrid.axial_to_world(pos.x, pos.y)
		container.name = "Sea_%d_%d" % [pos.x, pos.y]
		parent.add_child(container)

		var tile := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius    = 1.0
		mesh.bottom_radius = 1.0
		mesh.height        = 0.20
		mesh.radial_segments = 6
		mesh.rings = 1
		tile.mesh = mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = SEA_PBR.c
		mat.roughness    = SEA_PBR.r
		mat.metallic     = SEA_PBR.m
		tile.material_override = mat
		container.add_child(tile)
