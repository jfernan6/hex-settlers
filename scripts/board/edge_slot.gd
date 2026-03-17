class_name EdgeSlot
extends Area3D

## A clickable road slot on the board (sits on a hex edge).
## Shows as a thin grey bar. Turns green on hover when buildable.
## Stores v1 and v2 (the two endpoint vertex world positions).

signal slot_clicked(slot)

var v1: Vector3  # first endpoint vertex position
var v2: Vector3  # second endpoint vertex position
var is_occupied: bool = false
var owner_index: int = -1

var _mat: StandardMaterial3D
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	input_ray_pickable = true
	_build_visuals()
	_build_collision()
	connect("input_event", _on_input_event)
	connect("mouse_entered", _on_hover_start)
	connect("mouse_exited", _on_hover_end)


func _build_visuals() -> void:
	_mesh_instance = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.07, 0.75)  # thin flat bar along Z (road direction)
	_mesh_instance.mesh = box

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.7, 0.75, 0.85)   # light blue-grey, fully visible
	_mat.roughness    = 0.6
	_mat.emission_enabled = true
	_mat.emission = Color(0.3, 0.35, 0.5)         # subtle blue glow
	_mat.emission_energy_multiplier = 0.4
	_mesh_instance.material_override = _mat
	add_child(_mesh_instance)


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.25, 0.15, 0.9)
	col.shape = shape
	add_child(col)


func _on_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_occupied:
			slot_clicked.emit(self)


func _on_hover_start() -> void:
	if not is_occupied:
		_mat.albedo_color = Color(0.2, 1.0, 0.3)
		_mat.emission = Color(0.1, 0.8, 0.2)
		_mat.emission_energy_multiplier = 1.2


func _on_hover_end() -> void:
	if not is_occupied:
		_mat.albedo_color = Color(0.7, 0.75, 0.85)
		_mat.emission = Color(0.3, 0.35, 0.5)
		_mat.emission_energy_multiplier = 0.4


## Place a road here for a player.
func occupy(player_color: Color, p_owner_index: int) -> void:
	is_occupied = true
	owner_index = p_owner_index
	_mat.albedo_color = player_color
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_mesh_instance.scale = Vector3(1.0, 1.4, 1.0)
	print("[EDGE] Road placed at midpoint %s" % position)
