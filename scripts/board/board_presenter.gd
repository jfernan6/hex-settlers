extends Node3D

const BoardGenerator = preload("res://scripts/board/board_generator.gd")
const HexGrid = preload("res://scripts/board/hex_grid.gd")
const HexVertices = preload("res://scripts/board/hex_vertices.gd")
const HexEdges = preload("res://scripts/board/hex_edges.gd")
const VertexSlot = preload("res://scripts/board/vertex_slot.gd")
const EdgeSlot = preload("res://scripts/board/edge_slot.gd")
const GameState = preload("res://scripts/game/game_state.gd")
const PlayerData = preload("res://scripts/player/player.gd")

signal vertex_clicked(slot)
signal edge_clicked(slot)
signal tile_clicked(tile_key)

var _state: RefCounted
var _camera: Camera3D
var _vertex_slots: Array = []
var _edge_slots: Array = []
var _anim_tokens: Array = []
var _anim_models: Array = []
var _robber: Node3D
var _robber_base_y: float = 0.45
var _time: float = 0.0
var _tile_picking_enabled: bool = false


func setup(state: RefCounted, camera: Camera3D) -> void:
	_state = state
	_camera = camera


func build_board() -> void:
	print("[BOARD] Generating board...")
	var generator := BoardGenerator.new()
	_state.tile_data = generator.generate(self)
	var refs: Dictionary = generator.get_anim_refs()
	_anim_tokens = refs.tokens
	_anim_models = refs.models
	Log.info("[BOARD] Anim refs: %d tokens, %d models" % [_anim_tokens.size(), _anim_models.size()])
	for key in _state.tile_data:
		var area: Area3D = _state.tile_data[key].area
		area.connect("input_event", _on_tile_input.bind(key))
	print("[BOARD] %d tiles ready" % _state.tile_data.size())
	_create_vertex_slots()
	_create_edge_slots()


func create_robber() -> void:
	if _robber != null and is_instance_valid(_robber):
		_robber.queue_free()
	var root := Node3D.new()
	root.name = "Robber"

	var coat := _robber_mat(Color(0.13, 0.11, 0.10), 0.88, 0.02)
	var skin := _robber_mat(Color(0.78, 0.62, 0.46), 0.90, 0.00)
	var hat := _robber_mat(Color(0.10, 0.08, 0.05), 0.92, 0.00)
	var bag := _robber_mat(Color(0.55, 0.40, 0.22), 0.95, 0.00)
	var belt := _robber_mat(Color(0.25, 0.15, 0.06), 0.88, 0.05)
	var mask := _robber_mat(Color(0.06, 0.05, 0.05), 0.82, 0.00)

	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.13
	bm.bottom_radius = 0.16
	bm.height = 0.07
	bm.radial_segments = 8
	base.mesh = bm
	base.position = Vector3(0, 0.035, 0)
	base.material_override = coat
	root.add_child(base)

	var body := MeshInstance3D.new()
	var bodm := CylinderMesh.new()
	bodm.top_radius = 0.09
	bodm.bottom_radius = 0.13
	bodm.height = 0.38
	bodm.radial_segments = 8
	body.mesh = bodm
	body.position = Vector3(0, 0.26, 0)
	body.material_override = coat
	root.add_child(body)

	var beltm := MeshInstance3D.new()
	var belm := CylinderMesh.new()
	belm.top_radius = 0.10
	belm.bottom_radius = 0.115
	belm.height = 0.034
	belm.radial_segments = 8
	beltm.mesh = belm
	beltm.position = Vector3(0, 0.135, 0)
	beltm.material_override = belt
	root.add_child(beltm)

	var shld := MeshInstance3D.new()
	var shm := CylinderMesh.new()
	shm.top_radius = 0.12
	shm.bottom_radius = 0.09
	shm.height = 0.055
	shm.radial_segments = 8
	shld.mesh = shm
	shld.position = Vector3(0, 0.47, 0)
	shld.material_override = coat
	root.add_child(shld)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.115
	hm.height = 0.23
	hm.radial_segments = 12
	head.mesh = hm
	head.position = Vector3(0, 0.585, 0)
	head.material_override = skin
	root.add_child(head)

	var maskm := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.15, 0.044, 0.05)
	maskm.mesh = mm
	maskm.position = Vector3(0, 0.595, -0.088)
	maskm.material_override = mask
	root.add_child(maskm)

	for ex: float in [-0.046, 0.046]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.015
		em.height = 0.022
		eye.mesh = em
		eye.position = Vector3(ex, 0.595, -0.098)
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(0.95, 0.82, 0.20)
		emat.emission_enabled = true
		emat.emission = Color(0.95, 0.82, 0.20)
		emat.emission_energy_multiplier = 3.5
		eye.material_override = emat
		root.add_child(eye)

	var crown := MeshInstance3D.new()
	var crm := CylinderMesh.new()
	crm.top_radius = 0.080
	crm.bottom_radius = 0.090
	crm.height = 0.145
	crm.radial_segments = 8
	crown.mesh = crm
	crown.position = Vector3(0, 0.777, 0)
	crown.material_override = hat
	root.add_child(crown)

	var brim := MeshInstance3D.new()
	var brimm := CylinderMesh.new()
	brimm.top_radius = 0.230
	brimm.bottom_radius = 0.230
	brimm.height = 0.022
	brimm.radial_segments = 16
	brim.mesh = brimm
	brim.position = Vector3(0, 0.700, 0)
	brim.material_override = hat
	root.add_child(brim)

	var band := MeshInstance3D.new()
	var bandm := CylinderMesh.new()
	bandm.top_radius = 0.092
	bandm.bottom_radius = 0.092
	bandm.height = 0.026
	bandm.radial_segments = 8
	band.mesh = bandm
	band.position = Vector3(0, 0.712, 0)
	band.material_override = _robber_mat(Color(0.45, 0.28, 0.10), 0.88, 0.0)
	root.add_child(band)

	var sack := MeshInstance3D.new()
	var sackm := SphereMesh.new()
	sackm.radius = 0.082
	sackm.radial_segments = 8
	sack.mesh = sackm
	sack.scale = Vector3(0.85, 1.0, 0.85)
	sack.position = Vector3(0.15, 0.29, 0.02)
	sack.material_override = bag
	root.add_child(sack)

	var tie := MeshInstance3D.new()
	var tiem := CylinderMesh.new()
	tiem.top_radius = 0.028
	tiem.bottom_radius = 0.033
	tiem.height = 0.020
	tiem.radial_segments = 6
	tie.mesh = tiem
	tie.position = Vector3(0.15, 0.375, 0.02)
	tie.material_override = belt
	root.add_child(tie)

	add_child(root)
	_robber = root
	update_robber_position()
	Log.info("[ROBBER] Bandit robber at %s" % _state.robber_tile_key)


func get_vertex_slots() -> Array:
	return _vertex_slots


func get_edge_slots() -> Array:
	return _edge_slots


func refresh_affordances() -> void:
	var player = _state.current_player()
	var pidx: int = _state.current_player_index
	var is_human_turn: bool = not player.is_ai
	var in_setup_settlement: bool = (
		_state.phase == GameState.Phase.SETUP and
		_state.setup_sub_phase == GameState.SetupSubPhase.PLACE_SETTLEMENT and
		is_human_turn
	)
	var in_setup_road: bool = (
		_state.phase == GameState.Phase.SETUP and
		_state.setup_sub_phase == GameState.SetupSubPhase.PLACE_ROAD and
		is_human_turn
	)
	var in_build: bool = (_state.phase == GameState.Phase.BUILD and is_human_turn)
	var can_afford_road: bool = (
		player.free_roads > 0 or
		(player.resources.get(PlayerData.RES_LUMBER, 0) >= 1 and
		player.resources.get(PlayerData.RES_BRICK, 0) >= 1)
	)

	for slot in _vertex_slots:
		if slot.is_occupied:
			var can_upgrade: bool = in_build and _state.can_upgrade_city_at(pidx, slot.position)
			slot.input_ray_pickable = can_upgrade
			if can_upgrade:
				slot.set_affordance("upgrade", player.color)
			elif slot.owner_index == pidx:
				slot.set_affordance("owned", player.color)
			else:
				slot.set_affordance("neutral")
			continue

		if in_setup_settlement:
			var legal_setup_vertex: bool = _state.can_place_setup_settlement_at(slot.position)
			slot.input_ray_pickable = legal_setup_vertex
			slot.set_affordance("setup_legal" if legal_setup_vertex else "blocked", player.color)
			continue

		if in_build:
			var legal_build_vertex: bool = _state.can_place_settlement_at(pidx, slot.position)
			slot.input_ray_pickable = legal_build_vertex
			slot.set_affordance("build_legal" if legal_build_vertex else "inactive", player.color)
			continue

		slot.input_ray_pickable = false
		slot.set_affordance("inactive")

	for slot in _edge_slots:
		if slot.is_occupied:
			slot.input_ray_pickable = false
			if slot.owner_index == pidx:
				slot.set_affordance("owned", player.color)
			else:
				slot.set_affordance("neutral")
			continue

		if in_setup_road:
			var legal_setup_road: bool = _state.can_place_setup_road_at(pidx, slot.v1, slot.v2)
			slot.input_ray_pickable = legal_setup_road
			slot.set_affordance("setup_legal" if legal_setup_road else "inactive")
			continue

		if in_build:
			var connected_road: bool = _state.can_connect_road_at(pidx, slot.v1, slot.v2)
			var legal_build_road: bool = connected_road and can_afford_road
			slot.input_ray_pickable = legal_build_road
			if legal_build_road:
				slot.set_affordance("build_legal")
			elif connected_road:
				slot.set_affordance("candidate")
			else:
				slot.set_affordance("inactive")
			continue

		slot.input_ray_pickable = false
		slot.set_affordance("inactive")


func find_setup_road_slot(last_setup_pos: Vector3) -> Object:
	for slot in _edge_slots:
		if slot.is_occupied:
			continue
		var d1: float = Vector2(slot.v1.x - last_setup_pos.x, slot.v1.z - last_setup_pos.z).length()
		var d2: float = Vector2(slot.v2.x - last_setup_pos.x, slot.v2.z - last_setup_pos.z).length()
		if d1 < 0.15 or d2 < 0.15:
			return slot
	return null


func set_tile_picking(enabled: bool) -> void:
	_tile_picking_enabled = enabled
	for slot in _vertex_slots:
		slot.input_ray_pickable = not enabled
	for slot in _edge_slots:
		slot.input_ray_pickable = not enabled
	_set_tile_robber_highlight(enabled)
	_set_robber_glow(enabled)


func update_robber_position() -> void:
	if _robber == null or _state.robber_tile_key not in _state.tile_data:
		return
	var center: Vector3 = _state.tile_data[_state.robber_tile_key].center
	_robber.position = Vector3(center.x, _robber_base_y, center.z)


func project_world_to_screen(world_pos: Vector3) -> Vector2:
	if _camera == null:
		return get_viewport().get_visible_rect().size * 0.5
	if _camera.is_position_behind(world_pos):
		return get_viewport().get_visible_rect().size * 0.5
	return _camera.unproject_position(world_pos)


func payout_source_points(resource: int, payouts: Array, player_index: int, y_offset: float = 0.34) -> Array:
	var sources: Array = []
	for payout in payouts:
		if payout.player_index != player_index or payout.resource != resource:
			continue
		for _i in range(int(payout.amount)):
			sources.append(payout.center + Vector3(0, y_offset, 0))
	return sources


func fallback_tile_sources(terrain: int, amount: int, y_offset: float = 0.34) -> Array:
	var matches: Array = []
	for key in _state.tile_data:
		var tile: Dictionary = _state.tile_data[key]
		if tile.terrain == terrain:
			matches.append(tile.center + Vector3(0, y_offset, 0))
	if matches.is_empty():
		return [Vector3.ZERO]
	var sources: Array = []
	for i in range(maxi(1, amount)):
		sources.append(matches[i % matches.size()])
	return sources


func _process(delta: float) -> void:
	if _state == null or _state.players.is_empty():
		return
	_time += delta

	for entry in _anim_tokens:
		var node: Node3D = entry.node
		if is_instance_valid(node):
			node.position.y = entry.base_y + sin(_time * 1.4 + entry.offset) * 0.04

	for entry in _anim_models:
		var mdl: Node3D = entry.node
		if not is_instance_valid(mdl):
			continue
		match entry.type:
			"sheep_head_graze":
				var base_z: float = float(entry.get("base_z", -18.0))
				var amp: float = float(entry.get("amp", 16.0))
				var speed: float = float(entry.get("speed", 1.1))
				mdl.rotation_degrees.z = base_z + sin(_time * speed + entry.offset) * amp
				mdl.rotation_degrees.y = sin(_time * speed * 0.45 + entry.offset * 1.2) * minf(4.0, amp * 0.18)
			"sheep_idle", "sheep":
				var base_y: float = float(entry.get("base_y", mdl.position.y))
				var base_ry: float = float(entry.get("base_ry", mdl.rotation_degrees.y))
				var amp_y: float = float(entry.get("amp_y", 0.02))
				var amp_roll: float = float(entry.get("amp_roll", 1.8))
				mdl.position.y = base_y + sin(_time * 0.78 + entry.offset) * amp_y
				mdl.rotation_degrees.x = sin(_time * 0.54 + entry.offset * 1.3) * 1.2
				mdl.rotation_degrees.z = sin(_time * 0.42 + entry.offset) * amp_roll
				mdl.rotation_degrees.y = base_ry + sin(_time * 0.34 + entry.offset * 0.9) * 2.0
			"tree":
				mdl.rotation_degrees.z = sin(_time * 0.85 + entry.offset) * 3.5
			"mill":
				mdl.rotation_degrees.y = fmod(_time * 30.0 + rad_to_deg(entry.offset), 360.0)
			"windmill_sail":
				mdl.rotation_degrees.z = fmod(_time * 55.0 + rad_to_deg(entry.offset), 360.0)
			"cactus_sway":
				mdl.rotation_degrees.z = sin(_time * 0.30 + entry.offset) * 1.8
			"wheat_sway":
				mdl.rotation_degrees.z = sin(_time * 1.4 + entry.offset) * 7.0
				mdl.rotation_degrees.x = sin(_time * 0.9 + entry.offset * 1.3) * 4.0

	var in_active_phase: bool = (_state.phase == GameState.Phase.SETUP or _state.phase == GameState.Phase.BUILD)
	var pulse: float = 1.0 + sin(_time * 3.5) * 0.15
	for slot in _vertex_slots:
		if not slot.is_occupied and slot.is_emphasized:
			slot.scale = Vector3(pulse, 1.0, pulse) if in_active_phase else Vector3.ONE
		elif not slot.is_occupied:
			slot.scale = Vector3.ONE
	for slot in _edge_slots:
		if not slot.is_occupied and slot.is_emphasized:
			slot.scale = Vector3(1.0, 1.0, 1.0 + sin(_time * 3.2) * 0.12) if in_active_phase else Vector3.ONE
		elif not slot.is_occupied:
			slot.scale = Vector3.ONE

	if _robber != null and is_instance_valid(_robber):
		_robber.rotation_degrees.y += delta * 22.0
		_robber.position.y = _robber_base_y + sin(_time * 2.2) * 0.05


func _create_vertex_slots() -> void:
	print("[VERTEX] Creating 54 vertex slots...")
	var positions := HexVertices.get_all_positions(HexGrid.get_board_positions())
	for pos in positions:
		var slot := VertexSlot.new()
		slot.position = pos
		slot.slot_clicked.connect(func(clicked_slot: Object) -> void:
			vertex_clicked.emit(clicked_slot)
		)
		add_child(slot)
		_vertex_slots.append(slot)
	print("[VERTEX] %d slots. Children: %d" % [positions.size(), get_child_count()])


func _create_edge_slots() -> void:
	print("[EDGE] Creating 72 edge slots...")
	var edges := HexEdges.get_all_edges(HexGrid.get_board_positions())
	for edge_data in edges:
		var slot := EdgeSlot.new()
		slot.position = edge_data.midpoint
		slot.v1 = edge_data.v1
		slot.v2 = edge_data.v2
		var dir: Vector3 = edge_data.direction
		slot.rotation.y = atan2(dir.x, dir.z)
		slot.slot_clicked.connect(func(clicked_slot: Object) -> void:
			edge_clicked.emit(clicked_slot)
		)
		add_child(slot)
		_edge_slots.append(slot)
	print("[EDGE] %d road slots. Children: %d" % [_edge_slots.size(), get_child_count()])


func _on_tile_input(key: String, _cam: Object, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if not _tile_picking_enabled or _state.phase != GameState.Phase.ROBBER_MOVE:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _state.can_move_robber_to(key):
		tile_clicked.emit(key)


func _unhandled_input(event: InputEvent) -> void:
	if not _tile_picking_enabled or _state.phase != GameState.Phase.ROBBER_MOVE:
		return
	if _state.current_player().is_ai:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _camera == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = _camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = _camera.project_ray_normal(mouse_pos)
	if abs(ray_dir.y) < 0.001:
		return
	var t: float = -ray_origin.y / ray_dir.y
	if t < 0.0:
		return
	var hit: Vector3 = ray_origin + ray_dir * t

	var best_key := ""
	var best_dist: float = HexGrid.HEX_SIZE * 1.5
	for key in _state.tile_data:
		var c: Vector3 = _state.tile_data[key].center
		var d: float = Vector2(hit.x - c.x, hit.z - c.z).length()
		if d < best_dist:
			best_dist = d
			best_key = key

	if best_key != "" and _state.can_move_robber_to(best_key):
		tile_clicked.emit(best_key)


func _set_tile_robber_highlight(active: bool) -> void:
	for key in _state.tile_data:
		var mesh: MeshInstance3D = _state.tile_data[key].get("mesh")
		if mesh == null or not (mesh.material_override is StandardMaterial3D):
			continue
		var mat: StandardMaterial3D = mesh.material_override
		mat.emission_enabled = active
		if active:
			mat.emission = Color(0.6, 0.5, 0.1)
			mat.emission_energy_multiplier = 0.4


func _set_robber_glow(active: bool) -> void:
	if _robber == null:
		return
	_set_node_emission(_robber, active)


func _set_node_emission(node: Node, active: bool) -> void:
	if node is MeshInstance3D and node.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = node.material_override
		if mat.emission_energy_multiplier < 3.0:
			mat.emission_enabled = active
			if active:
				mat.emission = Color(0.9, 0.1, 0.1)
				mat.emission_energy_multiplier = 1.2
	for child in node.get_children():
		_set_node_emission(child, active)


func _robber_mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
