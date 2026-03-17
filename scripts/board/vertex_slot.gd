class_name VertexSlot
extends Area3D

## A clickable vertex slot on the board.
## Shows as a small white sphere. Highlights yellow on hover.
## Emits slot_clicked when the player clicks it.

signal slot_clicked(slot)

var is_occupied: bool = false
var is_city: bool = false
var owner_index: int = -1  # player index, -1 = empty

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
	# Empty slot = small semi-transparent disc (less obtrusive than a sphere)
	_mesh_instance = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius    = 0.19
	disc.bottom_radius = 0.19
	disc.height        = 0.04
	disc.radial_segments = 10
	disc.rings = 1
	_mesh_instance.mesh = disc

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.95, 0.95, 0.95, 0.75)
	_mat.roughness    = 0.4
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
		# Always emit — main.gd decides whether to place settlement or upgrade to city
		slot_clicked.emit(self)


func _on_hover_start() -> void:
	if not is_occupied:
		_mat.albedo_color = Color(1.0, 0.95, 0.2)  # yellow highlight


func _on_hover_end() -> void:
	if not is_occupied:
		_mat.albedo_color = Color(0.95, 0.95, 0.95)


## Called when a player places a settlement here — builds a house shape.
func occupy(player_color: Color, p_owner_index: int) -> void:
	is_occupied = true
	owner_index = p_owner_index
	_mesh_instance.visible = false  # hide the disc indicator
	_build_house(player_color, false)
	Log.info("[VERTEX] Settlement at %s  owner=%d" % [position, p_owner_index])


## Upgrade this settlement to a city — taller tower with metallic finish.
func upgrade_to_city(player_color: Color) -> void:
	is_city = true
	# Remove existing house children
	for child in get_children():
		if child != _mesh_instance and child is MeshInstance3D:
			child.queue_free()
	_build_house(player_color, true)
	Log.info("[VERTEX] City at %s  owner=%d" % [position, owner_index])


func _build_house(color: Color, city: bool) -> void:
	var body_h  := 0.44 if city else 0.32
	var body_w  := 0.36 if city else 0.27
	var roof_br := 0.30 if city else 0.24
	var roof_h  := 0.24 if city else 0.20
	var metallic := 0.50 if city else 0.15

	# Body
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(body_w, body_h, body_w)
	body.mesh = bm
	body.position = Vector3(0, body_h * 0.5, 0)
	body.material_override = _house_mat(color, metallic)
	add_child(body)

	# Roof (square pyramid via 4-segment cone)
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius    = 0.0
	rm.bottom_radius = roof_br
	rm.height        = roof_h
	rm.radial_segments = 4
	rm.rings = 1
	roof.mesh = rm
	roof.position = Vector3(0, body_h + roof_h * 0.5, 0)
	roof.rotation_degrees = Vector3(0, 45, 0)
	roof.material_override = _house_mat(color.darkened(0.25), metallic * 0.5)
	add_child(roof)


func _house_mat(color: Color, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.75
	mat.metallic     = metallic
	return mat
