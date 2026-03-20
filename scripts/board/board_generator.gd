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
		dm.top_radius = 0.40; dm.bottom_radius = 0.40
		dm.height = 0.018; dm.radial_segments = 32
		disc.mesh = dm
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.94, 0.90, 0.74)
		dmat.roughness    = 0.82
		disc.material_override = dmat
		disc.position = Vector3(0, 0.134, 0)   # just above tile top (tile top = 0.125)
		container.add_child(disc)

		# Combined number + pips label — one block = guaranteed shared centre axis
		var tok_label := Label3D.new()
		tok_label.text                = str(number) + "\n" + "•".repeat(pips)
		tok_label.position            = Vector3(0, 0.20, 0)
		tok_label.billboard            = BaseMaterial3D.BILLBOARD_ENABLED
		tok_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tok_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		tok_label.font_size            = 64
		tok_label.pixel_size           = 0.003
		tok_label.outline_size         = 9
		tok_label.outline_modulate     = Color(0.93, 0.89, 0.72)
		tok_label.modulate             = token_color
		tok_label.render_priority      = 1
		tok_label.no_depth_test        = true
		container.add_child(tok_label)

	# Resource type overlay label — color-coded, always readable
	const RES_LABELS := {
		TerrainType.FOREST:    ["LUMBER", Color(0.30, 0.80, 0.25)],
		TerrainType.HILLS:     ["BRICK",  Color(0.90, 0.38, 0.10)],
		TerrainType.PASTURE:   ["WOOL",   Color(0.60, 0.92, 0.40)],
		TerrainType.FIELDS:    ["GRAIN",  Color(1.00, 0.88, 0.10)],
		TerrainType.MOUNTAINS: ["ORE",    Color(0.70, 0.70, 0.78)],
		TerrainType.DESERT:    ["",       Color(0, 0, 0)],
	}
	if terrain in RES_LABELS and RES_LABELS[terrain][0] != "":
		var res_lbl := Label3D.new()
		res_lbl.text        = RES_LABELS[terrain][0]
		res_lbl.position    = Vector3(0, 0.46, 0)  # below pips
		res_lbl.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
		res_lbl.font_size   = 52
		res_lbl.pixel_size  = 0.003
		res_lbl.outline_size = 5
		res_lbl.outline_modulate = Color(0.05, 0.05, 0.05)
		res_lbl.modulate    = RES_LABELS[terrain][1]
		container.add_child(res_lbl)

	return [area, tile]


# ---------------------------------------------------------------
# Sprint B: visual elements
# ---------------------------------------------------------------

## Shared circular token texture — generated once, reused by every tile.
var _token_tex: ImageTexture = null

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
const _QAT := "res://assets/models/quaternius/"

## Terrain decorations — Quaternius glTF for Forest/Mountains/Hills,
## procedural for Fields + Desert, none for Pasture (shader carries it).
func _add_terrain_decoration(container: Node3D, terrain: int) -> void:
	match terrain:
		TerrainType.FOREST:
			# 3 varied pines — positions and scales * 1.40 for larger tiles
			_place_model(container, _QAT + "Pine_1.gltf",
				Vector3( 0.63, 0.13,  0.35), 0.17, randf_range(0, 360), "tree")
			_place_model(container, _QAT + "Pine_2.gltf",
				Vector3(-0.56, 0.13,  0.49), 0.14, randf_range(0, 360), "tree")
			_place_model(container, _QAT + "Pine_3.gltf",
				Vector3( 0.35, 0.13, -0.63), 0.15, randf_range(0, 360), "tree")
		TerrainType.MOUNTAINS:
			# Rock cluster — varied sizes for natural arrangement
			_place_model(container, _QAT + "Rock_Medium_1.gltf",
				Vector3( 0.63, 0.13,  0.14), 0.31, randf_range(0, 360), "")
			_place_model(container, _QAT + "Rock_Medium_2.gltf",
				Vector3(-0.59, 0.13,  0.28), 0.25, randf_range(0, 360), "")
			_place_model(container, _QAT + "Rock_Medium_3.gltf",
				Vector3( 0.21, 0.13, -0.67), 0.28, randf_range(0, 360), "")
		TerrainType.HILLS:
			# Rock path + smaller accent rock
			_place_model(container, _QAT + "RockPath_Round_Wide.gltf",
				Vector3( 0.56, 0.13,  0.28), 0.28, randf_range(0, 360), "")
			_place_model(container, _QAT + "Rock_Medium_1.gltf",
				Vector3(-0.49, 0.13,  0.49), 0.21, randf_range(0, 360), "")
		TerrainType.PASTURE:
			pass   # animated grass shader carries the tile — sheep to be revisited
		TerrainType.FIELDS:
			_add_windmill(container)
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


## FIELDS — animated windmill with spinning sail cross
func _add_windmill(container: Node3D) -> void:
	var stone  := _solid_mat(Color(0.72, 0.70, 0.65), 0.90, 0.05)
	var wood   := _solid_mat(Color(0.45, 0.35, 0.22), 0.88, 0.0)
	var canvas := _solid_mat(Color(0.88, 0.84, 0.70), 0.85, 0.0)

	# Root — offset so token disc at centre stays clear
	var root := Node3D.new()
	root.position = Vector3(0.73, 0.125, 0.11)
	root.rotation_degrees.y = randf_range(-15.0, 15.0)
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


## PASTURE — two procedural sheep, one grazing, one idling
## Only the head animates for grazing — body stays stable so it never looks broken.
func _add_sheep_herd(container: Node3D) -> void:
	var off1 := randf() * TAU

	# Sheep 1 — grazing: head tilts down/up independently
	var s1 := Node3D.new()
	s1.position = Vector3(0.70, 0.125, 0.22)
	s1.rotation_degrees.y = 40.0
	container.add_child(s1)
	var s1_head := _build_sheep(s1)
	_anim_models.append({"node": s1_head, "type": "sheep_head_graze", "offset": off1})
	_anim_models.append({"node": s1,      "type": "sheep_idle",        "offset": off1})

	# Sheep 2 — just idle body sway
	var s2 := Node3D.new()
	s2.position = Vector3(-0.67, 0.125, 0.31)
	s2.rotation_degrees.y = -75.0
	container.add_child(s2)
	_build_sheep(s2)
	_anim_models.append({"node": s2, "type": "sheep_idle", "offset": randf() * TAU})


## Clean minimal sheep: white oval body + black sphere head + dark legs.
## No neck, no rotations, no scaling on head — just spheres and cylinders.
func _build_sheep(parent: Node3D) -> Node3D:
	var wool  := _solid_mat(Color(0.96, 0.95, 0.93), 0.92, 0.0)
	var black := _solid_mat(Color(0.10, 0.08, 0.08), 0.90, 0.0)

	# Large white body
	var body := MeshInstance3D.new()
	var bm   := SphereMesh.new()
	bm.radius = 0.20; bm.radial_segments = 12
	body.mesh = bm
	body.scale    = Vector3(1.0, 0.85, 1.25)
	body.position = Vector3(0, 0.22, 0)
	body.material_override = wool
	parent.add_child(body)

	# Small black round head — pure sphere, no rotation, placed at front of body
	# body extends to z = -0.20*1.25 = -0.25 from centre; head sits right there
	var head_root := Node3D.new()
	head_root.position = Vector3(0, 0.26, -0.30)   # far enough that skull never clips into body
	parent.add_child(head_root)

	var skull := MeshInstance3D.new()
	var sm    := SphereMesh.new()
	sm.radius = 0.048; sm.radial_segments = 10      # smaller, proportional to body
	skull.mesh = sm
	skull.position = Vector3(0, 0, -0.08)           # arc point for grazing animation
	skull.material_override = black
	head_root.add_child(skull)

	# 4 dark legs
	for lp: Vector3 in [Vector3( 0.10, 0,  0.13), Vector3(-0.10, 0,  0.13),
	                     Vector3( 0.08, 0, -0.12), Vector3(-0.08, 0, -0.12)]:
		var leg := MeshInstance3D.new()
		var lm  := CylinderMesh.new()
		lm.top_radius = 0.030; lm.bottom_radius = 0.026; lm.height = 0.18
		leg.mesh = lm
		leg.position = Vector3(lp.x, 0.09, lp.z)
		leg.material_override = black
		parent.add_child(leg)

	return head_root


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
		# Register for sway animation
		pass  # canopy sway removed (terrain shaders handle all animation)


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


## Brick pile — stacked terracotta bricks in alternating rows
func _add_brick_pile(container: Node3D) -> void:
	var mat := _solid_mat(Color(0.72, 0.28, 0.12), 0.95, 0)
	var rows := [
		[Vector3(-0.18, 0, 0), Vector3(-0.06, 0, 0), Vector3(0.06, 0, 0), Vector3(0.18, 0, 0)],
		[Vector3(-0.12, 0, 0), Vector3(0.0, 0, 0), Vector3(0.12, 0, 0)],
		[Vector3(-0.06, 0, 0), Vector3(0.08, 0, 0)],
	]
	for row_i in rows.size():
		for pos in rows[row_i]:
			var brick := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.13, 0.07, 0.09)
			brick.mesh = bm
			brick.position = pos + Vector3(0, 0.16 + row_i * 0.078, 0.0)
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


## Fluffy sheep — Pasture/Wool resource
func _add_sheep(container: Node3D) -> void:
	var white := _solid_mat(Color(0.96, 0.96, 0.96), 0.95, 0)
	var dark  := _solid_mat(Color(0.14, 0.11, 0.09), 0.9, 0)

	# Woolly body
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.22; bm.height = 0.32; bm.radial_segments = 10
	body.mesh = bm
	body.scale    = Vector3(1.15, 0.78, 1.35)
	body.position = Vector3(0, 0.22, 0)
	body.material_override = white
	container.add_child(body)

	# Head
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.10; hm.radial_segments = 8
	head.mesh = hm
	head.position = Vector3(0, 0.30, -0.24)
	head.material_override = dark
	container.add_child(head)

	# 4 stubby legs
	for lp in [Vector3(0.10, 0, 0.12), Vector3(-0.10, 0, 0.12), Vector3(0.08, 0, -0.12), Vector3(-0.08, 0, -0.12)]:
		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.03; lm.bottom_radius = 0.03; lm.height = 0.14
		leg.mesh = lm
		leg.position = Vector3(0, 0.22, 0) + lp + Vector3(0, -0.18, 0)
		leg.material_override = dark
		container.add_child(leg)


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
