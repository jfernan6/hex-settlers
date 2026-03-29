class_name BoardTerrainProps
extends RefCounted

const BoardMaterials = preload("res://scripts/board/board_materials.gd")

enum TerrainType {
	FOREST,
	HILLS,
	PASTURE,
	FIELDS,
	MOUNTAINS,
	DESERT
}

var _anim_models: Array = []
var _materials: BoardMaterials


func setup(anim_models: Array, materials: BoardMaterials) -> void:
	_anim_models = anim_models
	_materials = materials


func add_terrain_decoration(container: Node3D, terrain: int) -> void:
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


func _add_grain_field(container: Node3D) -> void:
	var stem_col := _solid_mat(Color(0.80, 0.68, 0.08), 0.93, 0.0)
	var head_col := _solid_mat(Color(0.95, 0.83, 0.12), 0.88, 0.0)
	var ring: Array[Vector3] = [
		Vector3(0.70, 0, 0.00), Vector3(0.54, 0, 0.46), Vector3(0.20, 0, 0.67),
		Vector3(-0.45, 0, 0.54), Vector3(-0.70, 0, 0.00), Vector3(-0.54, 0, -0.46),
		Vector3(0.00, 0, -0.70), Vector3(0.54, 0, -0.46),
	]
	for base_pos in ring:
		var pivot := Node3D.new()
		pivot.position = Vector3(base_pos.x, 0.125, base_pos.z)
		pivot.rotation_degrees.z = randf_range(-6.0, 6.0)
		container.add_child(pivot)

		var stalk := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.012
		sm.bottom_radius = 0.018
		sm.height = 0.44
		sm.radial_segments = 5
		stalk.mesh = sm
		stalk.position = Vector3(0, 0.22, 0)
		stalk.material_override = stem_col
		pivot.add_child(stalk)

		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.038
		hm.height = 0.16
		hm.radial_segments = 6
		hm.rings = 4
		head.mesh = hm
		head.scale = Vector3(1.0, 2.6, 1.0)
		head.position = Vector3(0, 0.48, 0)
		head.material_override = head_col
		pivot.add_child(head)
		_anim_models.append({"node": pivot, "type": "wheat_sway", "offset": randf() * TAU})


func _add_windmill(container: Node3D) -> void:
	var stone := _solid_mat(Color(0.72, 0.70, 0.65), 0.90, 0.05)
	var wood := _solid_mat(Color(0.45, 0.35, 0.22), 0.88, 0.0)
	var canvas := _solid_mat(Color(0.88, 0.84, 0.70), 0.85, 0.0)
	var root := Node3D.new()
	root.position = Vector3(0.73, 0.125, 0.11)
	root.rotation_degrees.y = randf_range(-15.0, 15.0)
	root.scale = Vector3(1.5, 1.5, 1.5)
	container.add_child(root)

	var tower := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.09
	tm.bottom_radius = 0.14
	tm.height = 0.48
	tm.radial_segments = 8
	tower.mesh = tm
	tower.position = Vector3(0, 0.24, 0)
	tower.material_override = stone
	root.add_child(tower)

	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.16
	cm.height = 0.15
	cm.radial_segments = 8
	cap.mesh = cm
	cap.position = Vector3(0, 0.555, 0)
	cap.material_override = wood
	root.add_child(cap)

	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.08, 0.11, 0.02)
	door.mesh = dm
	door.position = Vector3(0, 0.055, 0.14)
	door.material_override = _solid_mat(Color(0.28, 0.18, 0.10), 0.95, 0)
	root.add_child(door)

	var hub := Node3D.new()
	hub.position = Vector3(0, 0.44, 0.16)
	root.add_child(hub)
	_anim_models.append({"node": hub, "type": "windmill_sail", "offset": randf() * TAU})

	var b_offsets := [Vector3(0, 0.12, 0), Vector3(0.12, 0, 0), Vector3(0, -0.12, 0), Vector3(-0.12, 0, 0)]
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
	_anim_models.append({"node": actor, "type": "sheep_idle", "offset": idle_offset, "base_y": actor.position.y, "base_ry": actor.rotation_degrees.y, "amp_y": 0.018 if grazing else 0.014, "amp_roll": 2.0 if grazing else 2.4})
	head_pivot.rotation_degrees.z = -18.0 if grazing else 8.0
	_anim_models.append({"node": head_pivot, "type": "sheep_head_graze", "offset": idle_offset + 0.7, "base_z": -18.0 if grazing else 8.0, "amp": 16.0 if grazing else 7.0, "speed": 1.20 if grazing else 0.82})


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


func _add_desert_scene(container: Node3D) -> void:
	var sandstone := _solid_mat(Color(0.78, 0.62, 0.36), 0.95, 0.0)
	var cactus_c := _solid_mat(Color(0.20, 0.48, 0.15), 0.90, 0.0)
	var mesa := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.20
	mm.bottom_radius = 0.24
	mm.height = 0.15
	mm.radial_segments = 12
	mesa.mesh = mm
	mesa.position = Vector3(-0.07, 0.20, 0.76)
	mesa.material_override = sandstone
	container.add_child(mesa)

	var band := MeshInstance3D.new()
	var bm2 := CylinderMesh.new()
	bm2.top_radius = 0.206
	bm2.bottom_radius = 0.226
	bm2.height = 0.025
	bm2.radial_segments = 12
	band.mesh = bm2
	band.position = Vector3(-0.07, 0.185, 0.76)
	band.material_override = _solid_mat(Color(0.60, 0.46, 0.26), 0.95, 0)
	container.add_child(band)

	var cac := Node3D.new()
	cac.position = Vector3(0.70, 0.125, 0.31)
	cac.rotation_degrees.y = randf_range(0, 360)
	container.add_child(cac)

	var trunk := MeshInstance3D.new()
	var trm := CylinderMesh.new()
	trm.top_radius = 0.055
	trm.bottom_radius = 0.065
	trm.height = 0.28
	trm.radial_segments = 8
	trunk.mesh = trm
	trunk.position = Vector3(0, 0.14, 0)
	trunk.material_override = cactus_c
	cac.add_child(trunk)

	for side: float in [-1.0, 1.0]:
		var h := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.038
		hm.bottom_radius = 0.042
		hm.height = 0.14
		hm.radial_segments = 7
		h.mesh = hm
		h.rotation_degrees.z = 90.0
		h.position = Vector3(side * (0.065 + 0.07), 0.17, 0)
		h.material_override = cactus_c
		cac.add_child(h)

		var v := MeshInstance3D.new()
		var vm := CylinderMesh.new()
		vm.top_radius = 0.038
		vm.bottom_radius = 0.042
		vm.height = 0.10
		vm.radial_segments = 7
		v.mesh = vm
		v.position = Vector3(side * (0.065 + 0.14), 0.22, 0)
		v.material_override = cactus_c
		cac.add_child(v)
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
	var heights := [0.55, 0.42, 0.48]
	for i in positions.size():
		var trunk := MeshInstance3D.new()
		var t_mesh := CylinderMesh.new()
		t_mesh.top_radius = 0.04
		t_mesh.bottom_radius = 0.06
		t_mesh.height = 0.18
		t_mesh.radial_segments = 6
		trunk.mesh = t_mesh
		trunk.position = positions[i] + Vector3(0, 0.22, 0)
		trunk.material_override = _solid_mat(Color(0.35, 0.22, 0.08), 0.9, 0)
		container.add_child(trunk)

		var canopy := MeshInstance3D.new()
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = 0.0
		c_mesh.bottom_radius = 0.22
		c_mesh.height = heights[i]
		c_mesh.radial_segments = 6
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
	for offset in [Vector3(0.15, 0, 0), Vector3(-0.12, 0, 0.08)]:
		var peak := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 0.32
		m.height = 0.65
		m.radial_segments = 5
		peak.mesh = m
		peak.position = offset + Vector3(0, 0.45, 0)
		peak.rotation_degrees = Vector3(0, randf_range(0, 72), 0)
		peak.material_override = _solid_mat(Color(0.55, 0.55, 0.58), 0.6, 0.18)
		container.add_child(peak)

		var snow := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.12
		sm.height = 0.18
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


func _solid_mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	return _materials.solid_mat(color, roughness, metallic)
