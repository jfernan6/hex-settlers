class_name VertexSlot
extends Area3D

## Clickable vertex slot. Pre-creates all mesh children in _ready() to avoid
## add_child() calls during gameplay (which can trigger Godot's "busy" error).

signal slot_clicked(slot)

var is_occupied: bool = false
var is_city: bool = false
var owner_index: int = -1
var is_emphasized: bool = false

var _mat_disc: StandardMaterial3D
var _mat_body: StandardMaterial3D
var _mat_roof: StandardMaterial3D

var _disc:     MeshInstance3D  # empty slot indicator
var _body:     MeshInstance3D  # settlement / city body
var _roof:     MeshInstance3D  # settlement / city pyramid roof


func _ready() -> void:
	input_ray_pickable = true
	_build_all_meshes()
	_build_collision()
	connect("input_event", _on_input_event)
	connect("mouse_entered", _on_hover_start)
	connect("mouse_exited", _on_hover_end)


# ---------------------------------------------------------------
# Build — all add_child() calls happen once at scene load
# ---------------------------------------------------------------

func _build_all_meshes() -> void:
	# 1. Disc — visible when slot is empty
	_disc = MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius    = 0.26
	dm.bottom_radius = 0.26
	dm.height        = 0.06
	dm.radial_segments = 12
	dm.rings = 1
	_disc.mesh = dm
	_mat_disc = StandardMaterial3D.new()
	_mat_disc.albedo_color = Color(1.0, 0.98, 0.85)  # warm white — visible on dark table
	_mat_disc.roughness    = 0.3
	_mat_disc.emission_enabled = true
	_mat_disc.emission = Color(0.9, 0.85, 0.5)        # subtle golden glow
	_mat_disc.emission_energy_multiplier = 0.5
	_mat_disc.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_disc.material_override = _mat_disc
	add_child(_disc)

	# 2. Settlement / city body — hidden until occupied
	_body = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.32, 0.28)
	_body.mesh = bm
	_body.position = Vector3(0, 0.16, 0)
	_mat_body = StandardMaterial3D.new()
	_mat_body.roughness = 0.75
	_body.material_override = _mat_body
	_body.visible = false
	add_child(_body)

	# 3. Roof — 4-segment cone (square pyramid) — hidden until occupied
	_roof = MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius    = 0.0
	rm.bottom_radius = 0.24
	rm.height        = 0.20
	rm.radial_segments = 4
	rm.rings = 1
	_roof.mesh = rm
	_roof.position    = Vector3(0, 0.42, 0)
	_roof.rotation_degrees = Vector3(0, 45, 0)
	_mat_roof = StandardMaterial3D.new()
	_mat_roof.roughness = 0.85
	_roof.material_override = _mat_roof
	_roof.visible = false
	add_child(_roof)


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.32
	col.shape = shape
	add_child(col)


# ---------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------

func _on_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(self)


func _on_hover_start() -> void:
	if not is_occupied and is_emphasized:
		_mat_disc.albedo_color = Color(1.0, 0.95, 0.1)
		_mat_disc.emission = Color(1.0, 0.8, 0.0)
		_mat_disc.emission_energy_multiplier = 1.5


func _on_hover_end() -> void:
	if not is_occupied:
		set_affordance("legal" if is_emphasized else "neutral")


# ---------------------------------------------------------------
# Placement — no add_child / remove_child during gameplay
# ---------------------------------------------------------------

const SETTLEMENT_GLB := "res://assets/models/pieces/settlement.glb"
const CITY_GLB        := "res://assets/models/pieces/city.glb"


## Place a settlement — hides disc, shows building with pop-in tween.
func occupy(player_color: Color, p_owner_index: int) -> void:
	is_occupied  = true
	owner_index  = p_owner_index
	scale = Vector3.ZERO  # start invisible for pop-in
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.15, 1.15, 1.15), 0.18)
	tw.tween_property(self, "scale", Vector3.ONE, 0.10)
	_disc.visible = false

	# Try Kenney GLB model first
	var scene = load(SETTLEMENT_GLB)
	if scene != null and scene is PackedScene:
		var node: Node3D = scene.instantiate()
		node.scale    = Vector3(0.018, 0.018, 0.018)
		node.position = Vector3(0, 0, 0)
		# Tint the model using a shader parameter isn't straightforward for GLB,
		# so we overlay a small colored cylinder as a player indicator
		_body.visible   = false
		_roof.visible   = false
		add_child(node)
		_add_player_ring(player_color, 0.22)
	else:
		_apply_color(player_color, false)
		_body.visible = true
		_roof.visible = true

	Log.info("[VERTEX] Settlement at %s  owner=%d" % [position, p_owner_index])


## Upgrade settlement to city — Kenney mansion model or fallback tower.
func upgrade_to_city(player_color: Color) -> void:
	is_city = true
	# Remove old settlement GLB children (keep _body/_roof/_disc)
	for child in get_children():
		if child != _disc and child != _body and child != _roof and \
				not (child is CollisionShape3D):
			child.queue_free()

	_body.visible = false
	_roof.visible = false

	var scene = load(CITY_GLB)
	if scene != null and scene is PackedScene:
		var node: Node3D = scene.instantiate()
		node.scale    = Vector3(0.022, 0.022, 0.022)
		node.position = Vector3(0, 0, 0)
		add_child(node)
		_add_player_ring(player_color, 0.32)
	else:
		_body.scale = Vector3(1.4, 1.5, 1.4)
		_body.position = Vector3(0, 0.22, 0)
		_roof.scale    = Vector3(1.3, 1.25, 1.3)
		_roof.position = Vector3(0, 0.60, 0)
		_apply_color(player_color, true)
		_body.visible = true
		_roof.visible = true

	Log.info("[VERTEX] City at %s  owner=%d" % [position, owner_index])


## Small colored ring under the building to show player ownership.
func _add_player_ring(color: Color, radius: float) -> void:
	var ring := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius; m.bottom_radius = radius
	m.height = 0.05; m.radial_segments = 12
	ring.mesh = m
	ring.position = Vector3(0, 0.025, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.8
	ring.material_override = mat
	add_child(ring)


func _apply_color(color: Color, city: bool) -> void:
	_mat_body.albedo_color = color
	_mat_body.metallic     = 0.50 if city else 0.12
	_mat_roof.albedo_color = color.darkened(0.25)
	_mat_roof.metallic     = 0.30 if city else 0.05


func set_affordance(mode: String, accent: Color = Color.WHITE) -> void:
	is_emphasized = false
	_set_owner_highlight(false, accent)

	if is_occupied:
		match mode:
			"upgrade":
				is_emphasized = true
				_set_owner_highlight(true, accent)
			"owned":
				_set_owner_highlight(false, accent)
		return

	match mode:
		"legal":
			is_emphasized = true
			_mat_disc.albedo_color = Color(1.0, 0.92, 0.38)
			_mat_disc.emission = Color(0.98, 0.77, 0.18)
			_mat_disc.emission_energy_multiplier = 1.15
		"blocked":
			_mat_disc.albedo_color = Color(0.48, 0.32, 0.30)
			_mat_disc.emission = Color(0.30, 0.12, 0.10)
			_mat_disc.emission_energy_multiplier = 0.12
		_:
			_mat_disc.albedo_color = Color(1.0, 0.98, 0.85)
			_mat_disc.emission = Color(0.9, 0.85, 0.5)
			_mat_disc.emission_energy_multiplier = 0.5


func _set_owner_highlight(active: bool, accent: Color) -> void:
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mesh := child as MeshInstance3D
		if not (mesh.material_override is StandardMaterial3D):
			continue
		var mat := mesh.material_override as StandardMaterial3D
		mat.emission_enabled = true
		if active:
			mat.emission = accent.lightened(0.15)
			mat.emission_energy_multiplier = 1.2
		elif mesh == _body or mesh == _roof:
			mat.emission = Color.BLACK
			mat.emission_energy_multiplier = 0.0
