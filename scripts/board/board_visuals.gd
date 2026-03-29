class_name BoardVisuals
extends RefCounted

const HexGrid = preload("res://scripts/board/hex_grid.gd")
const BoardEnvironment = preload("res://scripts/board/board_environment.gd")
const BoardMaterials = preload("res://scripts/board/board_materials.gd")
const BoardTerrainProps = preload("res://scripts/board/board_terrain_props.gd")

enum TerrainType {
	FOREST,
	HILLS,
	PASTURE,
	FIELDS,
	MOUNTAINS,
	DESERT
}

var _anim_tokens: Array = []
var _anim_models: Array = []
var _environment := BoardEnvironment.new()
var _materials := BoardMaterials.new()
var _terrain_props := BoardTerrainProps.new()


func setup(anim_tokens: Array, anim_models: Array) -> void:
	_anim_tokens = anim_tokens
	_anim_models = anim_models
	_terrain_props.setup(_anim_models, _materials)


func add_terrain_decoration(container: Node3D, terrain: int) -> void:
	_terrain_props.add_terrain_decoration(container, terrain)


func make_tile_material(terrain: int) -> Material:
	return _materials.make_tile_material(terrain)


func spawn_port_markers(parent: Node3D) -> void:
	_environment.spawn_port_markers(parent)


func spawn_ocean_plane(parent: Node3D) -> void:
	_environment.spawn_ocean_plane(parent)
