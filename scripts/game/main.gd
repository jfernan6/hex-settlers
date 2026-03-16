extends Node3D

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_spawn_hex_tile()
	print("=== Hex Settlers: Phase 1 loaded ===")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

# --- Setup functions ---

func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()

	# Sky-blue background
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.65, 0.85)

	# Ambient light so nothing is pitch black
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 1.0, 1.0)
	env.ambient_light_energy = 0.4

	world_env.environment = env
	add_child(world_env)

func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)

func _setup_camera() -> void:
	var camera := Camera3D.new()
	# Position above and in front of the tile, angled down
	camera.position = Vector3(0.0, 5.0, 5.0)
	camera.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	add_child(camera)

# --- Hex tile ---

func _spawn_hex_tile() -> void:
	var tile := MeshInstance3D.new()

	# CylinderMesh with 6 radial segments = hexagonal prism
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.25
	mesh.radial_segments = 6
	mesh.rings = 1
	tile.mesh = mesh

	# Forest green material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.55, 0.18)
	mat.roughness = 0.9
	tile.material_override = mat

	tile.name = "HexTile_Forest"
	add_child(tile)

	print("Hex tile spawned — terrain: Forest")
