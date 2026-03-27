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
	_spawn_ocean_plane(parent)   # single unified surface: sand island + ocean
	_spawn_port_markers(parent)  # 9 harbor markers around the board edge
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

	# Procedural PBR hex tile (vivid terrain colors) + optional Kenney decoration on top.
	# Terrain color gives clarity; 3D decoration adds visual interest.
	var pbr: Dictionary = TERRAIN_PBR[terrain]
	var tile := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.40; mesh.bottom_radius = 1.40
	mesh.height = 0.25; mesh.radial_segments = 24; mesh.rings = 4
	tile.mesh = mesh
	tile.material_override = _make_tile_material(terrain)
	container.add_child(tile)

	# Kenney model on top of the shader surface
	_add_terrain_decoration(container, terrain)

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

	# Number token — sits flat on the tile surface, not floating.
	# Flat CylinderMesh disc + billboard label above it.
	if number > 0:
		var pips: int = 6 - abs(7 - number)
		var is_hot: bool = number in [6, 8]
		var token_color: Color = Color(0.85, 0.08, 0.08) if is_hot else Color(0.06, 0.06, 0.06)

		# Flat cream disc sitting on the tile (smooth circle, 32 segments)
		var disc := MeshInstance3D.new()
		var dm   := CylinderMesh.new()
		dm.top_radius = 0.46; dm.bottom_radius = 0.46
		dm.height = 0.018; dm.radial_segments = 32
		disc.mesh = dm
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color    = Color(0.94, 0.90, 0.74)
		dmat.roughness       = 0.82
		dmat.no_depth_test   = true   # always visible — rocks/models can't cover it
		dmat.render_priority = -1     # draws before the label so label composites on top
		disc.material_override = dmat
		disc.position = Vector3(0, 0.134, 0)
		container.add_child(disc)

		# Combined number + pips label — one block = guaranteed shared centre axis
		var tok_label := Label3D.new()
		tok_label.text                = str(number) + "\n" + "•".repeat(pips)
		tok_label.position            = Vector3(0, 0.20, 0)
		tok_label.billboard            = BaseMaterial3D.BILLBOARD_ENABLED
		tok_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tok_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		tok_label.font_size            = 82
		tok_label.pixel_size           = 0.003
		tok_label.outline_size         = 9
		tok_label.outline_modulate     = Color(0.93, 0.89, 0.72)
		tok_label.modulate             = token_color
		tok_label.render_priority      = 1
		tok_label.no_depth_test        = true
		container.add_child(tok_label)

	return [area, tile]


# ---------------------------------------------------------------
# Sprint B: visual elements
# ---------------------------------------------------------------

## Shared circular token texture — generated once, reused by every tile.
var _token_tex: ImageTexture = null
var _sheep_billboard_tex: ImageTexture = null

func _get_token_tex() -> ImageTexture:
	if _token_tex != null:
		return _token_tex
	var sz  := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))   # fully transparent
	var c := sz / 2.0
	var r := c - 2.0
	for y in range(sz):
		for x in range(sz):
			var d := Vector2(float(x) - c, float(y) - c).length()
			if d <= r - 3.0:
				# Interior — warm parchment, subtle centre highlight
				var glow := 1.0 - (d / r) * 0.10
				img.set_pixel(x, y, Color(0.95 * glow, 0.91 * glow, 0.74 * glow, 1.0))
			elif d <= r:
				# Dark border ring
				img.set_pixel(x, y, Color(0.60, 0.50, 0.32, 1.0))
	_token_tex = ImageTexture.create_from_image(img)
	return _token_tex


func _get_sheep_billboard_tex() -> ImageTexture:
	if _sheep_billboard_tex != null:
		return _sheep_billboard_tex
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var outline := Color(0.12, 0.10, 0.10, 1.0)
	var wool := Color(0.98, 0.97, 0.95, 1.0)
	var wool_shadow := Color(0.88, 0.85, 0.80, 1.0)
	var face := Color(0.13, 0.11, 0.12, 1.0)
	var muzzle := Color(0.72, 0.60, 0.58, 1.0)
	var ear := Color(0.20, 0.14, 0.15, 1.0)
	var hoof := Color(0.17, 0.12, 0.12, 1.0)
	var hoof_shadow := Color(0.0, 0.0, 0.0, 0.16)

	_paint_ellipse(img, Vector2(132, 220), Vector2(78, 18), hoof_shadow)

	var body_puffs := [
		{"center": Vector2(78, 100), "radius": Vector2(30, 27)},
		{"center": Vector2(106, 82), "radius": Vector2(34, 31)},
		{"center": Vector2(142, 86), "radius": Vector2(38, 33)},
		{"center": Vector2(168, 112), "radius": Vector2(33, 30)},
		{"center": Vector2(131, 125), "radius": Vector2(49, 36)},
		{"center": Vector2(86, 126), "radius": Vector2(33, 29)},
		{"center": Vector2(56, 122), "radius": Vector2(24, 22)},
	]
	for puff in body_puffs:
		_paint_ellipse(img, puff.center, puff.radius + Vector2(7, 7), outline)
	_paint_ellipse(img, Vector2(122, 138), Vector2(75, 34), outline)
	for puff in body_puffs:
		_paint_ellipse(img, puff.center + Vector2(0, 8), puff.radius, wool_shadow)
	for puff in body_puffs:
		_paint_ellipse(img, puff.center, puff.radius, wool)
	_paint_ellipse(img, Vector2(122, 134), Vector2(70, 29), wool)
	_paint_ellipse(img, Vector2(34, 122), Vector2(16, 15), outline)
	_paint_ellipse(img, Vector2(36, 120), Vector2(12, 11), wool)

	for leg_x in [92, 119, 147, 174]:
		_paint_rect(img, Rect2i(leg_x - 7, 152, 14, 48), outline)
		_paint_rect(img, Rect2i(leg_x - 5, 156, 10, 40), hoof)
		_paint_rect(img, Rect2i(leg_x - 8, 194, 16, 7), outline)

	_paint_rect(img, Rect2i(166, 112, 30, 28), outline)
	_paint_rect(img, Rect2i(171, 116, 20, 24), face)
	_paint_ellipse(img, Vector2(208, 124), Vector2(33, 29), outline)
	_paint_ellipse(img, Vector2(210, 125), Vector2(25, 22), face)
	_paint_ellipse(img, Vector2(236, 132), Vector2(18, 14), outline)
	_paint_ellipse(img, Vector2(237, 132), Vector2(13, 10), muzzle)
	_paint_ellipse(img, Vector2(215, 119), Vector2(4, 4), Color(1.0, 1.0, 1.0, 1.0))
	_paint_ellipse(img, Vector2(193, 96), Vector2(10, 18), outline)
	_paint_ellipse(img, Vector2(195, 96), Vector2(7, 13), ear)
	_paint_ellipse(img, Vector2(214, 97), Vector2(9, 17), outline)
	_paint_ellipse(img, Vector2(214, 97), Vector2(6, 12), ear)
	_paint_rect(img, Rect2i(98, 146, 30, 10), Color(0.92, 0.90, 0.86, 1.0))

	_sheep_billboard_tex = ImageTexture.create_from_image(img)
	return _sheep_billboard_tex


func _paint_ellipse(img: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	var min_x := maxi(0, int(floor(center.x - radius.x)))
	var max_x := mini(img.get_width() - 1, int(ceil(center.x + radius.x)))
	var min_y := maxi(0, int(floor(center.y - radius.y)))
	var max_y := mini(img.get_height() - 1, int(ceil(center.y + radius.y)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var nx := (float(x) - center.x) / radius.x
			var ny := (float(y) - center.y) / radius.y
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, color)


func _paint_rect(img: Image, rect: Rect2i, color: Color) -> void:
	var min_x := maxi(0, rect.position.x)
	var max_x := mini(img.get_width(), rect.position.x + rect.size.x)
	var min_y := maxi(0, rect.position.y)
	var max_y := mini(img.get_height(), rect.position.y + rect.size.y)
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			img.set_pixel(x, y, color)

const KENNEY_TILE_PATHS: Dictionary = {
	TerrainType.FOREST:    "res://assets/models/tiles/forest.glb",
	TerrainType.HILLS:     "res://assets/models/tiles/hills.glb",
	TerrainType.PASTURE:   "res://assets/models/tiles/pasture.glb",
	TerrainType.FIELDS:    "res://assets/models/tiles/fields.glb",
	TerrainType.MOUNTAINS: "res://assets/models/tiles/mountains.glb",
	TerrainType.DESERT:    "res://assets/models/tiles/desert.glb",
}
const KENNEY_SEA_PATH := "res://assets/models/tiles/sea.glb"


## Animation refs — populated during generate(), fetched by main.gd for _process().
var _anim_tokens: Array = []   # {node:Node3D, base_y:float, offset:float}
var _anim_models: Array = []   # {node:Node3D, type:String, offset:float}

func get_anim_refs() -> Dictionary:
	return {"tokens": _anim_tokens, "models": _anim_models}


const _KEN := "res://assets/models/kenney/hexagon-kit/Models/GLB format/"

## Terrain decorations — fully self-contained in-repo props.
func _add_terrain_decoration(container: Node3D, terrain: int) -> void:
	match terrain:
		TerrainType.FOREST:
			_add_forest_cluster(container)
		TerrainType.MOUNTAINS:
			_add_mountain_cluster(container)
		TerrainType.HILLS:
			_add_hills_brick_scene(container)
		TerrainType.PASTURE:
			_add_sheep_herd(container)
		TerrainType.FIELDS:
			_add_windmill(container)
			_add_grain_field(container)
		TerrainType.DESERT:
			_add_desert_scene(container)


func _place_model(container: Node3D, path: String, pos: Vector3,
		scale_f: float, rot_y: float, anim_type: String) -> void:
	var node: Node3D
	if path.ends_with(".gltf"):
		node = _load_gltf_runtime(path)
	else:
		var scene = load(path)
		if scene == null or not (scene is PackedScene):
			return
		node = scene.instantiate()
	if node == null:
		return
	node.position           = pos
	node.scale              = Vector3(scale_f, scale_f, scale_f)
	node.rotation_degrees.y = rot_y
	container.add_child(node)
	if anim_type != "":
		_anim_models.append({"node": node, "type": anim_type, "offset": randf() * TAU})


## Load a .gltf file at runtime using GLTFDocument — works without editor pre-import.
func _load_gltf_runtime(path: String) -> Node3D:
	var doc   := GLTFDocument.new()
	var state := GLTFState.new()
	var err   := doc.append_from_file(path, state, 0, path.get_base_dir())
	if err != OK:
		push_warning("[GLTF] Failed to load %s (err %d)" % [path, err])
		return null
	var root: Node = doc.generate_scene(state)
	if root == null:
		return null
	if not (root is Node3D):
		root.free()
		return null
	return root as Node3D


## FIELDS — ring of wheat stalks, each swaying independently in the breeze.
## Positions are arranged at r≈0.55–0.65 so they clear the token disc (r=0.40).
func _add_grain_field(container: Node3D) -> void:
	var stem_col  := _solid_mat(Color(0.80, 0.68, 0.08), 0.93, 0.0)
	var head_col  := _solid_mat(Color(0.95, 0.83, 0.12), 0.88, 0.0)

	# 8 stalks at r≈0.70 — wide enough to clear the token disc (r=0.46) and avoid
	# projecting under the no_depth_test token from the camera at (0,10,9).
	var ring: Array[Vector3] = [
		Vector3( 0.70, 0,  0.00),
		Vector3( 0.54, 0,  0.46),
		Vector3( 0.20, 0,  0.67),
		Vector3(-0.45, 0,  0.54),
		Vector3(-0.70, 0,  0.00),
		Vector3(-0.54, 0, -0.46),
		Vector3( 0.00, 0, -0.70),
		Vector3( 0.54, 0, -0.46),
	]

	for base_pos in ring:
		# Each stalk is a pivot so the whole stalk+head sways as one unit
		var pivot := Node3D.new()
		pivot.position = Vector3(base_pos.x, 0.125, base_pos.z)
		# Slight random lean per stalk for a natural field look
		pivot.rotation_degrees.z = randf_range(-6.0, 6.0)
		container.add_child(pivot)

		# Stem — tapered thin cylinder
		var stalk := MeshInstance3D.new()
		var sm    := CylinderMesh.new()
		sm.top_radius    = 0.012
		sm.bottom_radius = 0.018
		sm.height        = 0.44
		sm.radial_segments = 5
		stalk.mesh = sm
		stalk.position = Vector3(0, 0.22, 0)
		stalk.material_override = stem_col
		pivot.add_child(stalk)

		# Grain head — elongated oval, bristly wheat appearance
		var head := MeshInstance3D.new()
		var hm   := SphereMesh.new()
		hm.radius        = 0.038
		hm.height        = 0.16
		hm.radial_segments = 6
		hm.rings         = 4
		head.mesh = hm
		head.scale    = Vector3(1.0, 2.6, 1.0)
		head.position = Vector3(0, 0.48, 0)
		head.material_override = head_col
		pivot.add_child(head)

		# Each stalk gets a unique offset so they don't all sway in sync
		_anim_models.append({"node": pivot, "type": "wheat_sway",
				"offset": randf() * TAU})


## FIELDS — animated windmill with spinning sail cross
func _add_windmill(container: Node3D) -> void:
	var stone  := _solid_mat(Color(0.72, 0.70, 0.65), 0.90, 0.05)
	var wood   := _solid_mat(Color(0.45, 0.35, 0.22), 0.88, 0.0)
	var canvas := _solid_mat(Color(0.88, 0.84, 0.70), 0.85, 0.0)

	# Root — 1.5× bigger than base design; token disc still clear at centre
	var root := Node3D.new()
	root.position      = Vector3(0.73, 0.125, 0.11)
	root.rotation_degrees.y = randf_range(-15.0, 15.0)
	root.scale         = Vector3(1.5, 1.5, 1.5)
	container.add_child(root)

	# Tapered stone tower (8-sided for faceted look)
	var tower := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.09; tm.bottom_radius = 0.14
	tm.height = 0.48; tm.radial_segments = 8
	tower.mesh = tm
	tower.position = Vector3(0, 0.24, 0)
	tower.material_override = stone
	root.add_child(tower)

	# Wooden conical cap
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0; cm.bottom_radius = 0.16
	cm.height = 0.15; cm.radial_segments = 8
	cap.mesh = cm
	cap.position = Vector3(0, 0.555, 0)
	cap.material_override = wood
	root.add_child(cap)

	# Small door at base
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.08, 0.11, 0.02)
	door.mesh = dm
	door.position = Vector3(0, 0.055, 0.14)   # front face toward camera (+Z)
	door.material_override = _solid_mat(Color(0.28, 0.18, 0.10), 0.95, 0)
	root.add_child(door)

	# Sail hub — offset in +Z so sails face the camera, not the back wall
	var hub := Node3D.new()
	hub.position = Vector3(0, 0.44, 0.16)   # sticks out toward camera (+Z direction)
	root.add_child(hub)
	_anim_models.append({"node": hub, "type": "windmill_sail", "offset": randf() * TAU})

	# 4 blade arms in + pattern (top / right / bottom / left)
	# Blades spread in X and Y — from the camera they appear as a spinning cross
	var b_offsets  := [Vector3(0, 0.12, 0), Vector3(0.12, 0, 0), Vector3(0, -0.12, 0), Vector3(-0.12, 0, 0)]
	var b_rotations := [0.0, 90.0, 0.0, 90.0]
	for i in 4:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.048, 0.24, 0.016)
		blade.mesh = bm
		blade.position = b_offsets[i]
		blade.rotation_degrees.z = b_rotations[i]
		blade.material_override = canvas
		hub.add_child(blade)


## PASTURE — readable 3D sheep with idle/grazing motion.
func _add_sheep_herd(container: Node3D) -> void:
	var pasture := Node3D.new()
	pasture.position = Vector3(0, 0.125, 0)
	container.add_child(pasture)

	_add_pasture_fence(pasture)
	_add_sheep_actor(pasture, Vector3(0.72, 0.0, -0.28), 1.18, 202.0, true)
	_add_sheep_actor(pasture, Vector3(-0.78, 0.0, 0.34), 0.68, 18.0, false)


func _add_sheep_actor(container: Node3D, pos: Vector3, scale_f: float, rot_y: float, grazing: bool) -> void:
	var actor := Node3D.new()
	actor.position = pos
	actor.rotation_degrees.y = rot_y
	actor.scale = Vector3(scale_f, scale_f, scale_f)
	container.add_child(actor)

	_add_sheep_shadow(actor)
	var head_pivot := _add_sheep(actor)

	var idle_offset := randf() * TAU
	_anim_models.append({
		"node": actor,
		"type": "sheep_idle",
		"offset": idle_offset,
		"base_y": actor.position.y,
		"base_ry": actor.rotation_degrees.y,
		"amp_y": 0.018 if grazing else 0.014,
		"amp_roll": 2.0 if grazing else 2.4,
	})
	head_pivot.rotation_degrees.z = -18.0 if grazing else 8.0
	_anim_models.append({
		"node": head_pivot,
		"type": "sheep_head_graze",
		"offset": idle_offset + 0.7,
		"base_z": -18.0 if grazing else 8.0,
		"amp": 16.0 if grazing else 7.0,
		"speed": 1.20 if grazing else 0.82,
	})


func _add_sheep_shadow(container: Node3D) -> void:
	var shadow := MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.20
	shadow_mesh.bottom_radius = 0.28
	shadow_mesh.height = 0.012
	shadow_mesh.radial_segments = 18
	shadow.mesh = shadow_mesh
	shadow.position = Vector3(-0.02, 0.01, 0.05)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.14)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.material_override = shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	container.add_child(shadow)


func _add_pasture_fence(container: Node3D) -> void:
	var wood := _solid_mat(Color(0.54, 0.36, 0.18), 0.94, 0.0)
	_add_fence_segment(container, Vector3(-0.16, 0.125, 0.80), 14.0, 0.68, wood)
	_add_fence_segment(container, Vector3(-0.56, 0.125, 0.52), 78.0, 0.52, wood)


func _add_fence_segment(container: Node3D, pos: Vector3, rot_y: float, span: float, wood: Material) -> void:
	var fence_root := Node3D.new()
	fence_root.position = pos
	fence_root.rotation_degrees.y = rot_y
	container.add_child(fence_root)

	for x in [-span * 0.5, -span * 0.15, span * 0.15, span * 0.5]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.04, 0.19, 0.04)
		post.mesh = pm
		post.position = Vector3(x, 0.095, 0)
		post.material_override = wood
		fence_root.add_child(post)

	for y in [0.08, 0.145]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(span, 0.026, 0.03)
		rail.mesh = rm
		rail.position = Vector3(0, y, 0)
		rail.material_override = wood
		fence_root.add_child(rail)


## DESERT — flat-topped sandstone mesa + animated cactus
func _add_desert_scene(container: Node3D) -> void:
	var sandstone := _solid_mat(Color(0.78, 0.62, 0.36), 0.95, 0.0)
	var cactus_c  := _solid_mat(Color(0.20, 0.48, 0.15), 0.90, 0.0)

	# --- Mesa ---
	var mesa := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.20; mm.bottom_radius = 0.24
	mm.height = 0.15; mm.radial_segments = 12
	mesa.mesh = mm
	mesa.position = Vector3(-0.07, 0.20, 0.76)
	mesa.material_override = sandstone
	container.add_child(mesa)

	# Rock strata band (slightly darker ring at mid-height)
	var band := MeshInstance3D.new()
	var bm2 := CylinderMesh.new()
	bm2.top_radius = 0.206; bm2.bottom_radius = 0.226
	bm2.height = 0.025; bm2.radial_segments = 12
	band.mesh = bm2
	band.position = Vector3(-0.07, 0.185, 0.76)
	band.material_override = _solid_mat(Color(0.60, 0.46, 0.26), 0.95, 0)
	container.add_child(band)

	# --- Cactus ---
	var cac := Node3D.new()
	cac.position = Vector3(0.70, 0.125, 0.31)
	cac.rotation_degrees.y = randf_range(0, 360)
	container.add_child(cac)

	# Trunk
	var trunk := MeshInstance3D.new()
	var trm := CylinderMesh.new()
	trm.top_radius = 0.055; trm.bottom_radius = 0.065
	trm.height = 0.28; trm.radial_segments = 8
	trunk.mesh = trm
	trunk.position = Vector3(0, 0.14, 0)
	trunk.material_override = cactus_c
	cac.add_child(trunk)

	# Two arms (left and right)
	for side: float in [-1.0, 1.0]:
		# Horizontal segment
		var h := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.038; hm.bottom_radius = 0.042
		hm.height = 0.14; hm.radial_segments = 7
		h.mesh = hm
		h.rotation_degrees.z = 90.0
		h.position = Vector3(side * (0.065 + 0.07), 0.17, 0)
		h.material_override = cactus_c
		cac.add_child(h)

		# Vertical segment (arm tip pointing up)
		var v := MeshInstance3D.new()
		var vm := CylinderMesh.new()
		vm.top_radius = 0.038; vm.bottom_radius = 0.042
		vm.height = 0.10; vm.radial_segments = 7
		v.mesh = vm
		v.position = Vector3(side * (0.065 + 0.14), 0.22, 0)
		v.material_override = cactus_c
		cac.add_child(v)

	# Register cactus for slow sway animation
	_anim_models.append({"node": cac, "type": "cactus_sway", "offset": randf() * TAU})


func _add_forest_cluster(container: Node3D) -> void:
	var grove := Node3D.new()
	grove.position = Vector3(0, 0.125, 0)
	container.add_child(grove)

	_add_trees(grove)
	_add_log_stack(grove)
	_anim_models.append({"node": grove, "type": "tree", "offset": randf() * TAU})


func _add_trees(container: Node3D) -> void:
	var positions := [Vector3(0, 0, 0), Vector3(0.32, 0, 0.22), Vector3(-0.28, 0, 0.18)]
	var heights   := [0.55, 0.42, 0.48]
	for i in positions.size():
		var trunk := MeshInstance3D.new()
		var t_mesh := CylinderMesh.new()
		t_mesh.top_radius = 0.04; t_mesh.bottom_radius = 0.06
		t_mesh.height = 0.18; t_mesh.radial_segments = 6
		trunk.mesh = t_mesh
		trunk.position = positions[i] + Vector3(0, 0.22, 0)
		trunk.material_override = _solid_mat(Color(0.35, 0.22, 0.08), 0.9, 0)
		container.add_child(trunk)

		var canopy := MeshInstance3D.new()
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = 0.0; c_mesh.bottom_radius = 0.22
		c_mesh.height = heights[i]; c_mesh.radial_segments = 6
		canopy.mesh = c_mesh
		canopy.position = positions[i] + Vector3(0, 0.30 + heights[i] * 0.5, 0)
		canopy.material_override = _solid_mat(Color(0.05, 0.28, 0.05), 0.92, 0)
		container.add_child(canopy)


func _add_log_stack(container: Node3D) -> void:
	var bark := _solid_mat(Color(0.45, 0.28, 0.12), 0.93, 0.0)
	var cut_face := _solid_mat(Color(0.76, 0.60, 0.34), 0.88, 0.0)
	var anchor := Vector3(0.40, 0.12, -0.52)
	for row in range(2):
		for col in range(3 - row):
			var log := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.07
			mesh.bottom_radius = 0.07
			mesh.height = 0.32
			mesh.radial_segments = 10
			log.mesh = mesh
			log.rotation_degrees.z = 90.0
			log.position = anchor + Vector3(col * 0.16 - row * 0.06, row * 0.09, 0)
			log.material_override = bark
			container.add_child(log)

			var cap := MeshInstance3D.new()
			var face := CylinderMesh.new()
			face.top_radius = 0.072
			face.bottom_radius = 0.072
			face.height = 0.02
			face.radial_segments = 10
			cap.mesh = face
			cap.position = log.position + Vector3(-0.16, 0.0, 0.0)
			cap.rotation_degrees.z = 90.0
			cap.material_override = cut_face
			container.add_child(cap)


func _add_mountain_peak(container: Node3D) -> void:
	# Two jagged grey peaks
	for offset in [Vector3(0.15, 0, 0), Vector3(-0.12, 0, 0.08)]:
		var peak := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.0; m.bottom_radius = 0.32
		m.height = 0.65; m.radial_segments = 5
		peak.mesh = m
		peak.position = offset + Vector3(0, 0.45, 0)
		peak.rotation_degrees = Vector3(0, randf_range(0, 72), 0)
		peak.material_override = _solid_mat(Color(0.55, 0.55, 0.58), 0.6, 0.18)
		container.add_child(peak)
		# Snow cap
		var snow := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0; sm.bottom_radius = 0.12; sm.height = 0.18
		snow.mesh = sm
		snow.position = offset + Vector3(0, 0.72, 0)
		snow.material_override = _solid_mat(Color(0.95, 0.95, 0.97), 0.5, 0)
		container.add_child(snow)


func _add_mountain_cluster(container: Node3D) -> void:
	var massif := Node3D.new()
	massif.position = Vector3(0, 0.125, 0)
	container.add_child(massif)

	_add_mountain_peak(massif)
	_add_ore_cluster(massif)


func _add_ore_cluster(container: Node3D) -> void:
	var crystal_col := _solid_mat(Color(0.20, 0.42, 0.98), 0.22, 0.75)
	var dark_rock := _solid_mat(Color(0.20, 0.23, 0.30), 0.85, 0.06)
	var base_offsets := [Vector3(0.48, 0.12, -0.44), Vector3(0.62, 0.12, -0.30), Vector3(0.36, 0.12, -0.26)]
	for i in base_offsets.size():
		var crystal := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.02
		mesh.bottom_radius = 0.10 - i * 0.01
		mesh.height = 0.24 + i * 0.05
		mesh.radial_segments = 5
		crystal.mesh = mesh
		crystal.position = base_offsets[i] + Vector3(0, mesh.height * 0.5, 0)
		crystal.rotation_degrees = Vector3(randf_range(-6, 6), randf_range(0, 360), randf_range(-6, 6))
		crystal.material_override = crystal_col
		container.add_child(crystal)

	var ore_base := MeshInstance3D.new()
	var ore_mesh := CylinderMesh.new()
	ore_mesh.top_radius = 0.18
	ore_mesh.bottom_radius = 0.24
	ore_mesh.height = 0.12
	ore_mesh.radial_segments = 7
	ore_base.mesh = ore_mesh
	ore_base.position = Vector3(0.50, 0.18, -0.34)
	ore_base.rotation_degrees.y = 18.0
	ore_base.material_override = dark_rock
	container.add_child(ore_base)


func _add_hills_brick_scene(container: Node3D) -> void:
	var kiln := Node3D.new()
	kiln.position = Vector3(0, 0.125, 0)
	container.add_child(kiln)

	_add_clay_kiln(kiln)
	_add_brick_pile(kiln)


func _add_clay_kiln(container: Node3D) -> void:
	var brick_mat := _solid_mat(Color(0.69, 0.27, 0.12), 0.95, 0.0)
	var dark_brick := _solid_mat(Color(0.46, 0.16, 0.07), 0.96, 0.0)
	var soot_mat := _solid_mat(Color(0.14, 0.08, 0.06), 0.96, 0.0)

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.54, 0.22, 0.42)
	base.mesh = base_mesh
	base.position = Vector3(0.58, 0.17, 0.48)
	base.rotation_degrees.y = -18.0
	base.material_override = brick_mat
	container.add_child(base)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(0.60, 0.06, 0.48)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.58, 0.32, 0.48)
	roof.rotation_degrees.y = -18.0
	roof.material_override = dark_brick
	container.add_child(roof)

	var chimney := MeshInstance3D.new()
	var chimney_mesh := BoxMesh.new()
	chimney_mesh.size = Vector3(0.12, 0.34, 0.12)
	chimney.mesh = chimney_mesh
	chimney.position = Vector3(0.76, 0.49, 0.36)
	chimney.rotation_degrees.y = -18.0
	chimney.material_override = dark_brick
	container.add_child(chimney)

	var arch := MeshInstance3D.new()
	var arch_mesh := BoxMesh.new()
	arch_mesh.size = Vector3(0.18, 0.12, 0.05)
	arch.mesh = arch_mesh
	arch.position = Vector3(0.44, 0.19, 0.27)
	arch.rotation_degrees.y = -18.0
	arch.material_override = soot_mat
	container.add_child(arch)

	for row_i in range(3):
		var row := MeshInstance3D.new()
		var row_mesh := BoxMesh.new()
		row_mesh.size = Vector3(0.56 - row_i * 0.03, 0.018, 0.44)
		row.mesh = row_mesh
		row.position = Vector3(0.58, 0.08 + row_i * 0.07, 0.48)
		row.rotation_degrees.y = -18.0
		row.material_override = _solid_mat(Color(0.78, 0.35, 0.16), 0.95, 0.0)
		container.add_child(row)


## Brick pile — stacked terracotta bricks in alternating rows
func _add_brick_pile(container: Node3D) -> void:
	var mat := _solid_mat(Color(0.74, 0.29, 0.12), 0.95, 0)
	var rows := [
		[Vector3(-0.24, 0, 0), Vector3(-0.08, 0, 0), Vector3(0.08, 0, 0), Vector3(0.24, 0, 0)],
		[Vector3(-0.16, 0, 0), Vector3(0.0, 0, 0), Vector3(0.16, 0, 0)],
		[Vector3(-0.08, 0, 0), Vector3(0.10, 0, 0)],
	]
	for row_i in rows.size():
		for pos in rows[row_i]:
			var brick := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.15, 0.08, 0.10)
			brick.mesh = bm
			brick.position = pos + Vector3(-0.54, 0.17 + row_i * 0.09, -0.52)
			brick.rotation_degrees = Vector3(0, randf_range(-8, 8), 0)
			brick.material_override = mat
			container.add_child(brick)


## Wheat stalks with grain heads — Fields/Grain resource
func _add_wheat(container: Node3D) -> void:
	var positions := [
		Vector3(0, 0, 0), Vector3(0.24, 0, 0.14), Vector3(-0.20, 0, 0.16),
		Vector3(0.08, 0, -0.22), Vector3(-0.16, 0, -0.16)
	]
	for pos in positions:
		var stalk := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.016; sm.bottom_radius = 0.022; sm.height = 0.36
		stalk.mesh = sm
		stalk.position = pos + Vector3(0, 0.31, 0)
		stalk.material_override = _solid_mat(Color(0.85, 0.72, 0.10), 0.92, 0)
		container.add_child(stalk)
		pass  # stalk sway removed (terrain shaders handle all animation)

		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.05; hm.height = 0.14; hm.radial_segments = 6
		head.mesh = hm
		head.scale    = Vector3(1, 2.2, 1)
		head.position = pos + Vector3(0, 0.52, 0)
		head.material_override = _solid_mat(Color(0.92, 0.80, 0.05), 0.88, 0)
		container.add_child(head)


## Fluffy sheep — Pasture/Wool resource.
## Built as exaggerated 3D forms so the sheep still read from the board camera.
func _add_sheep(container: Node3D) -> Node3D:
	var wool := _solid_mat(Color(0.97, 0.96, 0.94), 0.95, 0.0)
	var wool_shadow := _solid_mat(Color(0.86, 0.84, 0.80), 0.96, 0.0)
	var face := _solid_mat(Color(0.11, 0.09, 0.09), 0.93, 0.0)
	var muzzle := _solid_mat(Color(0.54, 0.40, 0.36), 0.93, 0.0)

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.18
	body_mesh.height = 0.28
	body_mesh.radial_segments = 12
	body.mesh = body_mesh
	body.scale = Vector3(1.72, 0.96, 1.10)
	body.position = Vector3(-0.02, 0.25, 0.0)
	body.material_override = wool_shadow
	container.add_child(body)

	for puff_data in [
		{"pos": Vector3(-0.20, 0.28, 0.0), "scale": Vector3(0.72, 0.64, 0.76)},
		{"pos": Vector3(-0.02, 0.33, 0.12), "scale": Vector3(0.68, 0.60, 0.68)},
		{"pos": Vector3(-0.02, 0.33, -0.12), "scale": Vector3(0.68, 0.60, 0.68)},
		{"pos": Vector3(0.17, 0.30, 0.0), "scale": Vector3(0.66, 0.60, 0.64)},
		{"pos": Vector3(0.03, 0.38, 0.0), "scale": Vector3(0.60, 0.54, 0.56)},
	]:
		var puff := MeshInstance3D.new()
		var puff_mesh := SphereMesh.new()
		puff_mesh.radius = 0.16
		puff_mesh.height = 0.22
		puff_mesh.radial_segments = 10
		puff.mesh = puff_mesh
		puff.position = puff_data.pos
		puff.scale = puff_data.scale
		puff.material_override = wool
		container.add_child(puff)

	var tail := MeshInstance3D.new()
	var tail_mesh := SphereMesh.new()
	tail_mesh.radius = 0.06
	tail.mesh = tail_mesh
	tail.scale = Vector3(0.85, 0.75, 0.85)
	tail.position = Vector3(-0.38, 0.31, 0.0)
	tail.material_override = wool
	container.add_child(tail)

	for leg_pos in [
		Vector3(-0.18, 0.10, 0.10), Vector3(-0.18, 0.10, -0.10),
		Vector3(0.11, 0.10, 0.11), Vector3(0.11, 0.10, -0.11),
	]:
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.024
		leg_mesh.bottom_radius = 0.028
		leg_mesh.height = 0.20
		leg_mesh.radial_segments = 6
		leg.mesh = leg_mesh
		leg.position = leg_pos
		leg.material_override = face
		container.add_child(leg)

	var head_pivot := Node3D.new()
	head_pivot.position = Vector3(0.26, 0.28, 0.0)
	container.add_child(head_pivot)

	var neck := MeshInstance3D.new()
	var neck_mesh := BoxMesh.new()
	neck_mesh.size = Vector3(0.18, 0.11, 0.12)
	neck.mesh = neck_mesh
	neck.position = Vector3(-0.02, -0.02, 0.0)
	neck.material_override = face
	head_pivot.add_child(neck)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.10
	head_mesh.height = 0.17
	head_mesh.radial_segments = 10
	head.mesh = head_mesh
	head.scale = Vector3(1.25, 0.94, 0.86)
	head.position = Vector3(0.12, 0.0, 0.0)
	head.material_override = face
	head_pivot.add_child(head)

	var muzzle_node := MeshInstance3D.new()
	var muzzle_mesh := SphereMesh.new()
	muzzle_mesh.radius = 0.055
	muzzle_mesh.height = 0.10
	muzzle_mesh.radial_segments = 8
	muzzle_node.mesh = muzzle_mesh
	muzzle_node.scale = Vector3(1.45, 0.78, 0.70)
	muzzle_node.position = Vector3(0.24, -0.03, 0.0)
	muzzle_node.material_override = muzzle
	head_pivot.add_child(muzzle_node)

	for ear_pos in [Vector3(0.10, 0.10, 0.07), Vector3(0.10, 0.10, -0.07)]:
		var ear := MeshInstance3D.new()
		var ear_mesh := BoxMesh.new()
		ear_mesh.size = Vector3(0.05, 0.02, 0.08)
		ear.mesh = ear_mesh
		ear.position = ear_pos
		ear.rotation_degrees.x = 18.0 if ear_pos.z > 0.0 else -18.0
		ear.rotation_degrees.z = 22.0
		ear.material_override = face
		head_pivot.add_child(ear)

	return head_pivot


func _add_desert_rock(container: Node3D) -> void:
	# Flat sandstone butte shape
	var rock := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.18; m.bottom_radius = 0.28; m.height = 0.22; m.radial_segments = 6
	rock.mesh = m
	rock.position = Vector3(0.1, 0.23, 0)
	rock.rotation_degrees = Vector3(0, 20, 0)
	rock.material_override = _solid_mat(Color(0.78, 0.60, 0.30), 0.9, 0)
	container.add_child(rock)


## Returns a live shader material for every terrain type.
func _make_tile_material(terrain: int) -> Material:
	match terrain:
		TerrainType.MOUNTAINS: return _mountains_shader()
		TerrainType.FIELDS:    return _fields_shader()
		TerrainType.FOREST:    return _forest_shader()
		TerrainType.HILLS:     return _hills_shader()
		TerrainType.PASTURE:   return _pasture_shader()
		TerrainType.DESERT:    return _desert_shader()
		_:
			var pbr: Dictionary = TERRAIN_PBR[terrain]
			var mat := StandardMaterial3D.new()
			mat.albedo_color = pbr.c; mat.roughness = pbr.r; mat.metallic = pbr.m
			return mat


## Mountains / Ore — rocky noise surface with pulsing blue ore veins.
func _mountains_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, specular_schlick_ggx;

varying vec2 v_pos;

float h21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p.yx + 19.19);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x),
	           mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y);
}

void vertex() { v_pos = VERTEX.xz; }

void fragment() {
	// Multi-scale rocky granite texture
	float n = vn(v_pos * 4.5)       * 0.55
	        + vn(v_pos * 9.0  + 2.3) * 0.30
	        + vn(v_pos * 18.0 + 5.1) * 0.15;

	vec3 rock = mix(vec3(0.24, 0.24, 0.28), vec3(0.56, 0.56, 0.61), n);

	// Ore veins — slow drift + pulse glow
	float vein_n = vn(v_pos * 6.5 + vec2(TIME * 0.08, TIME * 0.05)) * 0.6
	             + vn(v_pos * 13.0 + 3.7) * 0.4;
	float vein   = smoothstep(0.73, 0.77, vein_n);
	float pulse  = 0.5 + 0.5 * sin(TIME * 2.0 + vein_n * 9.0);

	vec3 ore = vec3(0.12, 0.25, 0.92);
	vec3 col = mix(rock, ore * 0.7, vein * 0.7);

	ALBEDO    = col;
	ROUGHNESS = mix(0.82, 0.28, vein);
	METALLIC  = mix(0.08, 0.55, vein);
	EMISSION  = ore * vein * pulse * 1.4;
	SPECULAR  = mix(0.30, 0.90, vein);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## Fields / Grain — animated grain-wave ripple, same spirit as the ocean.
func _fields_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

varying vec2 v_pos;

float h21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p.yx + 19.19);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x),
	           mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y);
}

void vertex() { v_pos = VERTEX.xz; }

void fragment() {
	// Wind ripple traveling diagonally — like looking down at a field from above
	float wave = sin(v_pos.x * 5.5 - v_pos.y * 2.0 + TIME * 1.4) * 0.5 + 0.5;
	wave = wave * 0.7 + vn(v_pos * 5.0 + TIME * 0.15) * 0.3;

	vec3 shadow = vec3(0.58, 0.44, 0.04);
	vec3 light  = vec3(0.95, 0.83, 0.12);
	vec3 col    = mix(shadow, light, wave);

	ALBEDO    = col;
	ROUGHNESS = 0.90;
	METALLIC  = 0.0;
	EMISSION  = light * wave * 0.07;  // warm golden shimmer at crest
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## Forest / Lumber — sunlight dappling through tree canopy onto the forest floor.
func _forest_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

varying vec2 v_pos;

float h21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p.yx + 19.19);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x),
	           mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y);
}

void vertex() { v_pos = VERTEX.xz; }

void fragment() {
	// Sunbeam patches drifting slowly — light filtering through canopy
	vec2 drift = vec2(TIME * 0.09, TIME * 0.06);
	float beam = vn(v_pos * 2.8 + drift) * 0.55
	           + vn(v_pos * 5.5 + drift * 1.4 + 1.7) * 0.30
	           + vn(v_pos * 11.0 + 3.3) * 0.15;

	// Undergrowth texture underneath the light
	float ground = vn(v_pos * 7.0 + 0.9) * 0.6 + vn(v_pos * 14.0 + 4.1) * 0.4;

	vec3 deep   = vec3(0.03, 0.16, 0.03);  // dense shadow
	vec3 mid    = vec3(0.07, 0.28, 0.05);  // undergrowth
	vec3 bright = vec3(0.22, 0.58, 0.08);  // sunlit patch

	vec3 col = mix(deep, mid, ground);
	col = mix(col, bright, smoothstep(0.48, 0.78, beam));

	ALBEDO    = col;
	ROUGHNESS = 0.94;
	EMISSION  = bright * smoothstep(0.62, 0.85, beam) * 0.08;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## Hills / Brick — terracotta clay with dried-earth crack lines.
func _hills_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

varying vec2 v_pos;

float h21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p.yx + 19.19);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x),
	           mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y);
}

void vertex() { v_pos = VERTEX.xz; }

void fragment() {
	// Base clay colour variation
	float clay_n = vn(v_pos * 3.5) * 0.55 + vn(v_pos * 7.0 + 1.8) * 0.45;
	vec3 dark_clay  = vec3(0.48, 0.14, 0.04);
	vec3 light_clay = vec3(0.78, 0.30, 0.10);
	vec3 col = mix(dark_clay, light_clay, clay_n);

	// Dried-earth cracks — thin dark lines at noise boundaries
	float crack_n = vn(v_pos * 4.8 + 2.2) * 0.6 + vn(v_pos * 9.5 + 5.0) * 0.4;
	float crack   = 1.0 - smoothstep(0.0, 0.06, abs(crack_n - 0.5));
	col = mix(col, vec3(0.20, 0.06, 0.01), crack * 0.65);

	// Faint warm inner glow — like kiln-fired brick still holding heat
	float glow = smoothstep(0.55, 0.85, clay_n);

	ALBEDO    = col;
	ROUGHNESS = 0.91;
	METALLIC  = 0.02;
	EMISSION  = vec3(0.55, 0.12, 0.01) * glow * 0.06;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## Pasture / Wool — multi-directional wind through wild meadow grass.
func _pasture_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

varying vec2 v_pos;

float h21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p.yx + 19.19);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x),
	           mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y);
}

void vertex() { v_pos = VERTEX.xz; }

void fragment() {
	// Two competing wind directions — creates irregular, natural grass motion
	float w1 = sin(v_pos.x * 5.5 + v_pos.y * 2.0  + TIME * 1.9) * 0.5 + 0.5;
	float w2 = sin(v_pos.x * 2.5 - v_pos.y * 5.0  - TIME * 1.3) * 0.5 + 0.5;
	float w3 = vn(v_pos * 4.0 + vec2(TIME * 0.12, TIME * 0.08)) * 0.4 + 0.3;

	float wave = w1 * 0.40 + w2 * 0.35 + w3 * 0.25;

	vec3 shadow = vec3(0.10, 0.34, 0.05);
	vec3 bright = vec3(0.42, 0.82, 0.14);
	vec3 col    = mix(shadow, bright, wave);

	ALBEDO    = col;
	ROUGHNESS = 0.93;
	EMISSION  = bright * smoothstep(0.65, 0.90, wave) * 0.06;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## Desert — concentric sand-dune ripples + heat-shimmer glow.
func _desert_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

varying vec2 v_pos;

float h21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p.yx + 19.19);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x),
	           mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y);
}

void vertex() { v_pos = VERTEX.xz; }

void fragment() {
	float r = length(v_pos);

	// Concentric dune ripples scrolling outward from centre
	float ripple = sin(r * 9.0 - TIME * 0.7) * 0.5 + 0.5;

	// Cross-wind noise breaks perfect symmetry for a natural dune look
	float noise  = vn(v_pos * 3.2 + vec2(TIME * 0.05, 0.0)) * 0.5
	             + vn(v_pos * 6.5 + 1.9) * 0.3;

	float dune = ripple * 0.65 + noise * 0.35;

	vec3 trough = vec3(0.68, 0.52, 0.24);  // valley between dunes
	vec3 crest  = vec3(0.97, 0.84, 0.52);  // wind-blown dune crest
	vec3 col    = mix(trough, crest, dune);

	// Heat shimmer — warm amber glow on dune crests
	float heat = smoothstep(0.62, 0.90, dune);

	ALBEDO    = col;
	ROUGHNESS = 0.96;
	EMISSION  = vec3(0.80, 0.45, 0.08) * heat * 0.10;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## Sprint 2A — 9 harbour markers around the board perimeter.
## Each marker is a small glowing post + billboard label (trade rate + resource).
func _spawn_port_markers(parent: Node3D) -> void:
	const RES_COLORS: Array = [
		Color(0.12, 0.42, 0.08),  # Lumber
		Color(0.65, 0.20, 0.06),  # Brick
		Color(0.28, 0.68, 0.12),  # Wool
		Color(0.85, 0.70, 0.04),  # Grain
		Color(0.38, 0.40, 0.50),  # Ore
	]
	const RES_SHORT: Array = ["LU", "BR", "WO", "GR", "OR"]

	# Harbour data: type (-1=generic 3:1, 0-4=specific 2:1), world-xz pos, two vertex xz pairs
	const HARBORS: Array = [
		{"type": -1, "px": -5.51, "pz":  3.18},
		{"type": -1, "px": -2.21, "pz":  5.73},
		{"type":  3, "px":  3.31, "pz":  4.46},
		{"type":  4, "px":  5.51, "pz":  3.18},
		{"type": -1, "px":  5.51, "pz": -3.18},
		{"type":  0, "px":  2.21, "pz": -5.73},
		{"type": -1, "px": -3.31, "pz": -4.46},
		{"type":  1, "px": -5.51, "pz": -3.18},
		{"type":  2, "px": -5.51, "pz":  0.64},
	]

	for h: Dictionary in HARBORS:
		var h_type: int = h["type"]
		var pos := Vector3(h["px"], 0.10, h["pz"])

		# Glowing beacon post
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.06; pm.bottom_radius = 0.08; pm.height = 0.28
		pm.radial_segments = 8
		post.mesh = pm
		post.position = pos + Vector3(0, 0.14, 0)
		var pier_col: Color
		if h_type == -1:
			pier_col = Color(0.80, 0.65, 0.30)  # tan wood for generic
		else:
			pier_col = RES_COLORS[h_type]
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = pier_col
		pmat.emission_enabled = true
		pmat.emission = pier_col * 0.6
		pmat.emission_energy_multiplier = 0.8
		post.material_override = pmat
		parent.add_child(post)

		# Billboard label (rate + resource abbreviation)
		var lbl := Label3D.new()
		if h_type == -1:
			lbl.text = "3:1"
			lbl.modulate = Color(1.0, 0.90, 0.55)
		else:
			lbl.text = "2:1\n%s" % RES_SHORT[h_type]
			lbl.modulate = RES_COLORS[h_type] * 1.8
		lbl.position = pos + Vector3(0, 0.55, 0)
		lbl.billboard      = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.pixel_size     = 0.004
		lbl.font_size      = 52
		lbl.outline_size   = 7
		lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
		lbl.no_depth_test  = true
		lbl.render_priority = 1
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(lbl)


func _solid_mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = roughness
	mat.metallic     = metallic
	return mat


## Try to load a Kenney hex tile GLB. Returns instantiated Node3D or null on failure.
func _try_load_kenney_tile(terrain: int) -> Node3D:
	var path: String = KENNEY_TILE_PATHS.get(terrain, "")
	if path == "":
		return null
	var scene = load(path)
	if scene == null or not (scene is PackedScene):
		return null
	return scene.instantiate()


func _spawn_ocean_plane(parent: Node3D) -> void:
	# One unified surface covers the whole scene: sandy island in the centre,
	# animated ocean at the edges.  Using a single PlaneMesh eliminates the
	# clipping that occurs when two separate meshes share the same Y range.
	# The shader transitions sand→wet-sand→shallow-water→deep-ocean purely
	# by distance from the board centre (world-space XZ radius).
	#
	# Zone radii (world units):
	#   r < 4.3   dry sand  (sits beneath the hex tile gaps — opaque tiles occlude it)
	#   4.3..5.4  wet sand / beach border
	#   5.4..6.4  shallow water / shoreline with foam
	#   r > 6.4   open ocean with Gerstner waves
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(54.0, 54.0)   # large enough that edges never appear on screen
	mesh.subdivide_width  = 120       # vertex spacing ~0.45 — smooth waves
	mesh.subdivide_depth  = 120
	plane.mesh = mesh
	# y = -0.10: sits just below hex tile bottoms (y = -0.125) so tiles appear
	# flush/embedded in sand; opaque tile cylinders occlude the plane beneath them.
	plane.position = Vector3(0.0, -0.10, 0.0)
	plane.name = "TerrainPlane"

	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4  u_sand_dry  : source_color = vec4(0.84, 0.72, 0.48, 1.0);
uniform vec4  u_sand_wet  : source_color = vec4(0.60, 0.50, 0.33, 1.0);
uniform vec4  u_shallow   : source_color = vec4(0.10, 0.46, 0.72, 1.0);
uniform vec4  u_deep      : source_color = vec4(0.01, 0.10, 0.30, 1.0);
uniform vec4  u_foam      : source_color = vec4(0.88, 0.95, 1.00, 1.0);
uniform float u_dry_end    = 6.0;
uniform float u_shore_end  = 7.6;
uniform float u_ocean_full = 9.5;
uniform float u_wave_h     = 0.14;
uniform float u_wave_scale = 1.6;

varying vec2  v_xz;
varying float v_ocean;

// Value noise — organic patches, no repeating grid
float h21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p.yx + 19.19);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x),
	           mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y);
}

void vertex() {
	v_xz   = VERTEX.xz;
	float r = length(v_xz);
	v_ocean = smoothstep(u_shore_end - 0.5, u_ocean_full, r);

	// Gerstner waves with ANALYTICAL normals (cos gradient, not -h approximation).
	// This gives smooth, physically correct specular highlights on the water.
	float h = 0.0, nx = 0.0, nz = 0.0;

	vec2 d1 = normalize(vec2( 1.0,  0.5)); float q1 = 0.9*u_wave_scale, a1 = u_wave_h;
	float p1 = dot(d1,v_xz)*q1 + TIME*1.1;
	h += a1*sin(p1); nx += a1*cos(p1)*q1*d1.x; nz += a1*cos(p1)*q1*d1.y;

	vec2 d2 = normalize(vec2(-0.6,  1.0)); float q2 = 1.3*u_wave_scale, a2 = u_wave_h*0.55;
	float p2 = dot(d2,v_xz)*q2 + TIME*0.9;
	h += a2*sin(p2); nx += a2*cos(p2)*q2*d2.x; nz += a2*cos(p2)*q2*d2.y;

	vec2 d3 = normalize(vec2( 0.4, -0.9)); float q3 = 2.1*u_wave_scale, a3 = u_wave_h*0.28;
	float p3 = dot(d3,v_xz)*q3 + TIME*1.4;
	h += a3*sin(p3); nx += a3*cos(p3)*q3*d3.x; nz += a3*cos(p3)*q3*d3.y;

	vec2 d4 = normalize(vec2(-1.0,  0.2)); float q4 = 3.2*u_wave_scale, a4 = u_wave_h*0.12;
	float p4 = dot(d4,v_xz)*q4 + TIME*1.7;
	h += a4*sin(p4); nx += a4*cos(p4)*q4*d4.x; nz += a4*cos(p4)*q4*d4.y;

	VERTEX.y += h * v_ocean;
	NORMAL    = normalize(vec3(-nx*v_ocean, 1.0, -nz*v_ocean));
}

void fragment() {
	float r = length(v_xz);

	float wet_t  = smoothstep(u_dry_end, u_shore_end, r);
	vec3  sand   = mix(u_sand_dry.rgb, u_sand_wet.rgb, wet_t);

	float deep_t = smoothstep(u_shore_end, u_ocean_full + 2.0, r);
	vec3  water  = mix(u_shallow.rgb, u_deep.rgb, deep_t);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);
	water = mix(water, u_shallow.rgb * 1.3, fresnel * 0.30 * v_ocean);

	// Large-scale value noise foam — only highlights the top ~20% of wave crests
	vec2  fc = v_xz * 0.55 + vec2(TIME * 0.045, TIME * 0.028);
	float fn = vn(fc) * 0.55 + vn(fc * 1.8 + 4.1) * 0.30 + vn(fc * 3.1 + 8.3) * 0.15;
	float foam_t = smoothstep(0.72, 0.92, fn) * v_ocean;
	water = mix(water, u_foam.rgb, foam_t * 0.22);

	// Soft shoreline fringe — subtle, not blinding white
	float shore_r = (u_shore_end + u_ocean_full) * 0.5;
	float shore_f = smoothstep(1.0, 0.0, abs(r - shore_r) / 0.9) * v_ocean;
	water = mix(water, u_foam.rgb, shore_f * 0.22);

	float water_t = smoothstep(u_shore_end - 0.4, u_shore_end + 0.6, r);
	vec3  col     = mix(sand, water, water_t);

	// Fade to deep ocean colour at the plane horizon — hides the carpet edge
	float edge_fade = smoothstep(25.0, 36.0, r);
	col = mix(col, u_deep.rgb * 0.6, edge_fade);

	ALBEDO    = col;
	EMISSION  = sand * (1.0 - water_t) * 0.10;
	ROUGHNESS = mix(0.97, mix(0.03, 0.15, 1.0 - fresnel), water_t);
	METALLIC  = mix(0.0,  0.60, water_t);
	SPECULAR  = mix(0.05, 0.95, water_t);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	plane.material_override = mat
	parent.add_child(plane)
