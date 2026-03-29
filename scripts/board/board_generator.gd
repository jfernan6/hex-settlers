class_name BoardGenerator

## Generates the 19-tile Catan board with randomized terrain and number tokens.

const HexGrid = preload("res://scripts/board/hex_grid.gd")
const BoardVisuals = preload("res://scripts/board/board_visuals.gd")

enum TerrainType {
	FOREST,
	HILLS,
	PASTURE,
	FIELDS,
	MOUNTAINS,
	DESERT
}

const TERRAIN_COUNTS: Dictionary = {
	TerrainType.FOREST: 4,
	TerrainType.HILLS: 3,
	TerrainType.PASTURE: 4,
	TerrainType.FIELDS: 4,
	TerrainType.MOUNTAINS: 3,
	TerrainType.DESERT: 1,
}

const TERRAIN_NAMES: Dictionary = {
	TerrainType.FOREST: "Forest",
	TerrainType.HILLS: "Hills",
	TerrainType.PASTURE: "Pasture",
	TerrainType.FIELDS: "Fields",
	TerrainType.MOUNTAINS: "Mountains",
	TerrainType.DESERT: "Desert",
}

const NUMBER_TOKENS: Array = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]

var _anim_tokens: Array = []
var _anim_models: Array = []


## Spawns all 19 hex tiles as children of `parent`.
## Returns a Dictionary mapping "q,r" -> {terrain, number, center, q, r}
## so game logic can look up which tiles a settlement is adjacent to.
func generate(parent: Node3D) -> Dictionary:
	_anim_tokens = []
	_anim_models = []

	var visuals := BoardVisuals.new()
	visuals.setup(_anim_tokens, _anim_models)
	visuals.spawn_ocean_plane(parent)
	visuals.spawn_port_markers(parent)

	var positions := HexGrid.get_board_positions()
	var terrains := _build_shuffled_terrains()
	var tokens := NUMBER_TOKENS.duplicate()
	tokens.shuffle()

	var token_index := 0
	var terrain_tally: Dictionary = {}
	var tile_data: Dictionary = {}

	for i in positions.size():
		var q: int = positions[i].x
		var r: int = positions[i].y
		var terrain: int = terrains[i]
		var number := 0
		if terrain != TerrainType.DESERT:
			number = tokens[token_index]
			token_index += 1

		var spawn_result: Array = _spawn_tile(parent, q, r, terrain, number, visuals)
		var area: Area3D = spawn_result[0]
		var tile_mesh: MeshInstance3D = spawn_result[1]
		terrain_tally[terrain] = terrain_tally.get(terrain, 0) + 1

		tile_data["%d,%d" % [q, r]] = {
			"terrain": terrain,
			"number": number,
			"center": HexGrid.axial_to_world(q, r),
			"q": q,
			"r": r,
			"area": area,
			"mesh": tile_mesh,
		}

		var token_str := "(%d)" % number if number > 0 else "(desert)"
		print("  Tile [q=%2d, r=%2d]  %-10s %s" % [q, r, TERRAIN_NAMES[terrain], token_str])

	print("[BOARD] --- Terrain summary ---")
	var all_ok := true
	for terrain_type in TERRAIN_COUNTS:
		var expected: int = TERRAIN_COUNTS[terrain_type]
		var actual: int = terrain_tally.get(terrain_type, 0)
		var status := "OK" if actual == expected else "ERROR — expected %d got %d" % [expected, actual]
		if actual != expected:
			all_ok = false
		print("  %-10s: %d  [%s]" % [TERRAIN_NAMES[terrain_type], actual, status])
	print("[BOARD] Tokens assigned : %d  %s" % [token_index, "OK" if token_index == 18 else "ERROR — expected 18"])
	print("[BOARD] Total tiles     : %d  %s" % [positions.size(), "OK" if positions.size() == 19 else "ERROR — expected 19"])
	print("[BOARD] Validation      : %s" % ("PASSED" if all_ok and token_index == 18 else "FAILED"))

	return tile_data


func get_anim_refs() -> Dictionary:
	return {"tokens": _anim_tokens, "models": _anim_models}


func _build_shuffled_terrains() -> Array:
	var terrains: Array = []
	for terrain_type in TERRAIN_COUNTS:
		for _i in range(TERRAIN_COUNTS[terrain_type]):
			terrains.append(terrain_type)
	terrains.shuffle()
	return terrains


## Spawns one tile. Returns [Area3D, MeshInstance3D].
func _spawn_tile(parent: Node3D, q: int, r: int, terrain: int, number: int, visuals: BoardVisuals) -> Array:
	var container := Node3D.new()
	container.name = "Tile_%d_%d" % [q, r]
	container.position = HexGrid.axial_to_world(q, r)
	parent.add_child(container)

	var tile := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.40
	mesh.bottom_radius = 1.40
	mesh.height = 0.25
	mesh.radial_segments = 24
	mesh.rings = 4
	tile.mesh = mesh
	tile.material_override = visuals.make_tile_material(terrain)
	container.add_child(tile)

	visuals.add_terrain_decoration(container, terrain)

	var area := Area3D.new()
	area.name = "TileArea"
	area.input_ray_pickable = false
	var col := CollisionShape3D.new()
	var cshape := CylinderShape3D.new()
	cshape.radius = 0.95
	cshape.height = 0.3
	col.shape = cshape
	area.add_child(col)
	container.add_child(area)

	if number > 0:
		var pips: int = 6 - abs(7 - number)
		var is_hot: bool = number in [6, 8]
		var token_color: Color = Color(0.85, 0.08, 0.08) if is_hot else Color(0.06, 0.06, 0.06)

		var disc := MeshInstance3D.new()
		var disc_mesh := CylinderMesh.new()
		disc_mesh.top_radius = 0.46
		disc_mesh.bottom_radius = 0.46
		disc_mesh.height = 0.018
		disc_mesh.radial_segments = 32
		disc.mesh = disc_mesh
		var disc_mat := StandardMaterial3D.new()
		disc_mat.albedo_color = Color(0.94, 0.90, 0.74)
		disc_mat.roughness = 0.82
		disc_mat.no_depth_test = true
		disc_mat.render_priority = -1
		disc.material_override = disc_mat
		disc.position = Vector3(0, 0.134, 0)
		container.add_child(disc)

		var tok_label := Label3D.new()
		tok_label.text = str(number) + "\n" + "•".repeat(pips)
		tok_label.position = Vector3(0, 0.20, 0)
		tok_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tok_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tok_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tok_label.font_size = 82
		tok_label.pixel_size = 0.003
		tok_label.outline_size = 9
		tok_label.outline_modulate = Color(0.93, 0.89, 0.72)
		tok_label.modulate = token_color
		tok_label.render_priority = 1
		tok_label.no_depth_test = true
		container.add_child(tok_label)

	return [area, tile]
