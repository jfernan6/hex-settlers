class_name VertexSlot
extends Area3D

## Clickable vertex slot. Pre-creates all mesh children in _ready() to avoid
## add_child() calls during gameplay (which can trigger Godot's "busy" error).

signal slot_clicked(slot)

var is_occupied: bool = false
var is_city: bool = false
var owner_index: int = -1

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
	if not is_occupied:
		_mat_disc.albedo_color = Color(1.0, 0.95, 0.1)
		_mat_disc.emission = Color(1.0, 0.8, 0.0)
		_mat_disc.emission_energy_multiplier = 1.5


func _on_hover_end() -> void:
	if not is_occupied:
		_mat_disc.albedo_color = Color(1.0, 0.98, 0.85)
		_mat_disc.emission = Color(0.9, 0.85, 0.5)
		_mat_disc.emission_energy_multiplier = 0.5


# ---------------------------------------------------------------
# Placement — no add_child / remove_child during gameplay
# ---------------------------------------------------------------

## Place a settlement — hides disc, shows house shape in player colour.
func occupy(player_color: Color, p_owner_index: int) -> void:
	is_occupied  = true
	owner_index  = p_owner_index
	_disc.visible = false
	_apply_color(player_color, false)
	_body.visible = true
	_roof.visible = true
	Log.info("[VERTEX] Settlement at %s  owner=%d" % [position, p_owner_index])


## Upgrade settlement to city — taller, more metallic.
func upgrade_to_city(player_color: Color) -> void:
	is_city = true
	_body.scale = Vector3(1.4, 1.5, 1.4)
	_body.position = Vector3(0, 0.22, 0)
	_roof.scale    = Vector3(1.3, 1.25, 1.3)
	_roof.position = Vector3(0, 0.60, 0)
	_apply_color(player_color, true)
	Log.info("[VERTEX] City at %s  owner=%d" % [position, owner_index])


func _apply_color(color: Color, city: bool) -> void:
	_mat_body.albedo_color = color
	_mat_body.metallic     = 0.50 if city else 0.12
	_mat_roof.albedo_color = color.darkened(0.25)
	_mat_roof.metallic     = 0.30 if city else 0.05
