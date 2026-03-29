class_name ResourceFeedbackController
extends RefCounted

const PlayerData = preload("res://scripts/player/player.gd")
const BoardGenerator = preload("res://scripts/board/board_generator.gd")

const _RESOURCE_ORDER := [
	PlayerData.RES_LUMBER,
	PlayerData.RES_BRICK,
	PlayerData.RES_WOOL,
	PlayerData.RES_GRAIN,
	PlayerData.RES_ORE,
]
const _RESOURCE_TERRAIN := {
	PlayerData.RES_LUMBER: BoardGenerator.TerrainType.FOREST,
	PlayerData.RES_BRICK: BoardGenerator.TerrainType.HILLS,
	PlayerData.RES_WOOL: BoardGenerator.TerrainType.PASTURE,
	PlayerData.RES_GRAIN: BoardGenerator.TerrainType.FIELDS,
	PlayerData.RES_ORE: BoardGenerator.TerrainType.MOUNTAINS,
}

var _owner: Node
var _state
var _hud
var _board_presenter
var _last_resource_payouts: Array = []


func setup(owner: Node, state, hud, board_presenter) -> void:
	_owner = owner
	_state = state
	_hud = hud
	_board_presenter = board_presenter


func update_bindings(hud, board_presenter) -> void:
	_hud = hud
	_board_presenter = board_presenter


func reset_roll_context() -> void:
	_last_resource_payouts = []


func record_payouts(payouts: Array) -> void:
	_last_resource_payouts = payouts.duplicate(true)


func display_player_gains() -> Dictionary:
	var delta: Dictionary = {}
	var target_player_index: int = _display_player_index()
	for payout in _last_resource_payouts:
		if payout.player_index != target_player_index:
			continue
		var res: int = int(payout.resource)
		delta[res] = delta.get(res, 0) + int(payout.amount)
	return delta


func show_roll_feedback(player_name: String, roll: int, robber_triggered: bool, show_dice_anim: bool) -> void:
	if _hud == null:
		return
	var gains: Dictionary = display_player_gains()
	if show_dice_anim:
		_hud.show_dice_animation(roll)
	_hud.show_roll_feedback(player_name, roll, gains, robber_triggered)
	_hud.push_activity(_roll_activity_line(player_name, roll, gains, robber_triggered), "info", false)
	_schedule_gain_feedback(gains, show_dice_anim)


func play_debug_resource_feedback(res: int, amount: int, caption: String) -> void:
	_play_resource_gain_feedback(res, amount, _fallback_sources(res, amount), caption)


func play_debug_brick_feedback(amount: int, caption: String) -> void:
	play_debug_resource_feedback(PlayerData.RES_BRICK, amount, caption)


func _play_resource_gain_feedback(res: int, amount: int, source_world_points: Array, caption: String) -> void:
	if _hud == null or amount <= 0:
		return
	var source_points: Array = []
	for world_point in source_world_points:
		source_points.append(_project_world_to_screen(world_point))
	_hud.show_resource_chip_flight(res, source_points, amount, caption)


func _schedule_resource_gain_feedback(res: int, amount: int, source_world_points: Array, caption: String, delay: float) -> void:
	if _hud == null or amount <= 0 or _owner == null:
		return
	var timer := _owner.get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		_play_resource_gain_feedback(res, amount, source_world_points, caption)
	)


func _schedule_gain_feedback(gains: Dictionary, show_dice_anim: bool) -> void:
	if _hud == null:
		return
	var base_delay: float = _hud.get_roll_feedback_delay(show_dice_anim)
	var sequence_index: int = 0
	for res in _RESOURCE_ORDER:
		var amount: int = int(gains.get(res, 0))
		if amount <= 0:
			continue
		_schedule_resource_gain_feedback(
			res,
			amount,
			_sources_for_display_player(res, amount),
			"+%d %s" % [amount, PlayerData.RES_NAMES[res]],
			base_delay + sequence_index * 0.18
		)
		sequence_index += 1


func _sources_for_display_player(res: int, amount: int) -> Array:
	if _board_presenter != null:
		var sources: Array = _board_presenter.payout_source_points(res, _last_resource_payouts, _display_player_index())
		if not sources.is_empty():
			return sources
	return _fallback_sources(res, amount)


func _fallback_sources(res: int, amount: int) -> Array:
	if _board_presenter != null:
		return _board_presenter.fallback_tile_sources(
			_RESOURCE_TERRAIN.get(res, BoardGenerator.TerrainType.FOREST),
			amount)
	return [Vector3.ZERO]


func _project_world_to_screen(world_pos: Vector3) -> Vector2:
	if _board_presenter != null:
		return _board_presenter.project_world_to_screen(world_pos)
	return _owner.get_viewport().get_visible_rect().size * 0.5 if _owner != null else Vector2.ZERO


func _display_player_index() -> int:
	if _state == null:
		return 0
	for i in range(_state.players.size()):
		if not _state.players[i].is_ai:
			return i
	return _state.current_player_index


func _roll_activity_line(player_name: String, roll: int, gains: Dictionary, robber_triggered: bool) -> String:
	if robber_triggered:
		return "%s rolled %d. Robber triggered." % [player_name, roll]
	var parts: Array[String] = []
	for res in _RESOURCE_ORDER:
		var amount: int = int(gains.get(res, 0))
		if amount > 0:
			parts.append("+%d %s" % [amount, PlayerData.RES_NAMES[res]])
	if parts.is_empty():
		return "%s rolled %d. No resources gained." % [player_name, roll]
	return "%s rolled %d. You gained %s." % [player_name, roll, ", ".join(parts)]
