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
	mesh.top_radius = 1.0; mesh.bottom_radius = 1.0
	mesh.height = 0.25; mesh.radial_segments = 6; mesh.rings = 1
	tile.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = pbr.c; mat.roughness = pbr.r; mat.metallic = pbr.m
	tile.material_override = mat
	container.add_child(tile)

	# Add Kenney 3D decoration on top of the tile for visual depth
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

	# Number token label (skip desert)
	if number > 0:
		var num_label := Label3D.new()
		num_label.text = str(number)
		num_label.position = Vector3(0, 1.0, 0)   # above tallest decoration (~0.81)
		num_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		num_label.font_size = 128
		num_label.pixel_size = 0.003
		num_label.outline_size = 10
		num_label.outline_modulate = Color(0.95, 0.92, 0.80)
		num_label.modulate = Color(0.85, 0.08, 0.08) if number in [6, 8] else Color(0.06, 0.06, 0.06)
		container.add_child(num_label)
		# Register for floating animation
		_anim_tokens.append({"node": num_label, "base_y": 1.0, "offset": randf() * TAU})

		# Probability pips (•) below the number — more pips = better odds
		var pips: int = 6 - abs(7 - number)
		var pip_label := Label3D.new()
		pip_label.text = "•".repeat(pips)
		pip_label.position = Vector3(0, 0.84, 0)  # just below number token
		pip_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pip_label.font_size = 80
		pip_label.pixel_size = 0.003
		pip_label.outline_size = 6
		pip_label.outline_modulate = Color(0.95, 0.92, 0.80)
		pip_label.modulate = Color(0.85, 0.08, 0.08) if number in [6, 8] else Color(0.06, 0.06, 0.06)
		container.add_child(pip_label)

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
		res_lbl.position    = Vector3(0, 0.70, 0)  # below pips, above decorations
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
var _anim_tokens:   Array = []   # {node:Label3D, base_y:float, offset:float}
var _anim_canopies: Array = []   # {node:MeshInstance3D, offset:float}

func get_anim_refs() -> Dictionary:
	return {"tokens": _anim_tokens, "canopies": _anim_canopies}


## Adds procedural 3D terrain features on top of the PBR hex tile.
func _add_terrain_decoration(container: Node3D, terrain: int) -> void:
	match terrain:
		TerrainType.FOREST:
			_add_trees(container)
		TerrainType.MOUNTAINS:
			_add_mountain_peak(container)
		TerrainType.HILLS:
			_add_brick_pile(container)
		TerrainType.DESERT:
			_add_desert_rock(container)
		TerrainType.FIELDS:
			_add_wheat(container)
		TerrainType.PASTURE:
			_add_sheep(container)


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
		_anim_canopies.append({"node": canopy, "offset": randf() * TAU})


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
		_anim_canopies.append({"node": stalk, "offset": randf() * TAU})

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
uniform float u_dry_end    = 4.3;
uniform float u_shore_end  = 5.4;
uniform float u_ocean_full = 6.8;
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
	float edge_fade = smoothstep(18.0, 26.0, r);
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
