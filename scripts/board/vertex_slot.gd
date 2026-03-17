class_name VertexSlot
extends Area3D

## A clickable vertex slot on the board.
## Shows as a small white sphere. Highlights yellow on hover.
## Emits slot_clicked when the player clicks it.

signal slot_clicked(slot)

var is_occupied: bool = false

var _mat: StandardMaterial3D
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	input_ray_pickable = true
	_build_visuals()
	_build_collision()
	connect("input_event", _on_input_event)
	connect("mouse_entered", _on_hover_start)
	connect("mouse_exited", _on_hover_end)


# --- Build ---

func _build_visuals() -> void:
	_mesh_instance = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	sphere.radial_segments = 8
	sphere.rings = 4
	_mesh_instance.mesh = sphere

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.95, 0.95, 0.95)
	_mat.roughness = 0.5
	_mesh_instance.material_override = _mat
	add_child(_mesh_instance)


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.32
	col.shape = shape
	add_child(col)


# --- Interaction ---

func _on_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_occupied:
			slot_clicked.emit(self)


func _on_hover_start() -> void:
	if not is_occupied:
		_mat.albedo_color = Color(1.0, 0.95, 0.2)  # yellow highlight


func _on_hover_end() -> void:
	if not is_occupied:
		_mat.albedo_color = Color(0.95, 0.95, 0.95)


## Called when a player places a settlement here.
func occupy(player_color: Color) -> void:
	is_occupied = true
	_mat.albedo_color = player_color
	_mesh_instance.scale = Vector3(1.8, 2.2, 1.8)  # taller = settlement shape
	print("[VERTEX] Settlement placed at world pos %s" % position)
