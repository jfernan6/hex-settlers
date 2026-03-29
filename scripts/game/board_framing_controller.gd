extends RefCounted

const HexGrid = preload("res://scripts/board/hex_grid.gd")

const _BASE_CAMERA_OFFSET := Vector3(0.0, 10.0, 9.0)
const _BASE_TARGET_OFFSET := Vector3(0.0, 0.0, 0.5)
const _TARGET_FILL_X := 0.90
const _TARGET_FILL_Y := 0.84
const _FRAME_MARGIN := 18.0
const _TARGET_STEP := 0.35

var _camera: Camera3D
var _state
var _tile_centers: Array = []
var _sample_points: Array = []
var _look_offset: Vector3 = _BASE_TARGET_OFFSET
var _distance_scale: float = 1.0


func setup(camera: Camera3D, state) -> void:
	_camera = camera
	_state = state


func refresh_board_samples() -> void:
	_tile_centers.clear()
	_sample_points.clear()
	if _state == null or _state.tile_data.is_empty():
		return

	var edge_radius := HexGrid.HEX_SIZE * 1.02
	for key in _state.tile_data:
		var center: Vector3 = _state.tile_data[key].center
		_tile_centers.append(center)
		_sample_points.append(center)
		for i in range(6):
			var angle := (TAU / 6.0) * float(i)
			_sample_points.append(center + Vector3(cos(angle) * edge_radius, 0.0, sin(angle) * edge_radius))


func apply_framing(safe_insets: Dictionary) -> void:
	if _camera == null:
		return
	if _sample_points.is_empty():
		refresh_board_samples()
	if _sample_points.is_empty():
		return

	var vp := _camera.get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return

	var safe_rect := _safe_rect(vp, safe_insets)
	if safe_rect.size.x < 260.0 or safe_rect.size.y < 220.0:
		return

	var board_center := _board_center()
	var target_offset := _look_offset
	var distance_scale := _distance_scale

	for _i in range(4):
		_apply_camera_transform(board_center, target_offset, distance_scale)
		var bounds := _project_board_bounds()
		if bounds.size == Vector2.ZERO:
			break

		var center_delta := safe_rect.get_center() - bounds.get_center()
		var shifted_x := _projected_center(board_center, target_offset + Vector3(_TARGET_STEP, 0.0, 0.0), distance_scale)
		var shifted_z := _projected_center(board_center, target_offset + Vector3(0.0, 0.0, _TARGET_STEP), distance_scale)
		var shift_x := shifted_x.x - bounds.get_center().x
		var shift_y := shifted_z.y - bounds.get_center().y

		if absf(shift_x) > 0.001:
			target_offset.x += (center_delta.x / shift_x) * _TARGET_STEP * 0.92
		if absf(shift_y) > 0.001:
			target_offset.z += (center_delta.y / shift_y) * _TARGET_STEP * 0.92

		target_offset.x = clampf(target_offset.x, -2.8, 2.8)
		target_offset.z = clampf(target_offset.z, -3.0, 2.2)

		_apply_camera_transform(board_center, target_offset, distance_scale)
		bounds = _project_board_bounds()
		if bounds.size == Vector2.ZERO:
			break

		var width_budget := maxf(1.0, safe_rect.size.x - _FRAME_MARGIN * 2.0)
		var height_budget := maxf(1.0, safe_rect.size.y - _FRAME_MARGIN * 2.0)
		var width_ratio := bounds.size.x / maxf(1.0, width_budget * _TARGET_FILL_X)
		var height_ratio := bounds.size.y / maxf(1.0, height_budget * _TARGET_FILL_Y)
		var overflow := maxf(width_ratio, height_ratio)
		if overflow > 1.01:
			distance_scale = minf(1.18, distance_scale * minf(overflow, 1.10))

	_look_offset = target_offset
	_distance_scale = distance_scale
	_apply_camera_transform(board_center, _look_offset, _distance_scale)


func _safe_rect(vp: Vector2, safe_insets: Dictionary) -> Rect2:
	var left := clampf(float(safe_insets.get("left", 0.0)), 0.0, vp.x * 0.45)
	var top := clampf(float(safe_insets.get("top", 0.0)), 0.0, vp.y * 0.28)
	var right := clampf(float(safe_insets.get("right", 0.0)), 0.0, vp.x * 0.18)
	var bottom := clampf(float(safe_insets.get("bottom", 0.0)), 0.0, vp.y * 0.42)
	return Rect2(
		Vector2(left, top),
		Vector2(maxf(1.0, vp.x - left - right), maxf(1.0, vp.y - top - bottom))
	)


func _board_center() -> Vector3:
	if _tile_centers.is_empty():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for point in _tile_centers:
		total += point
	return total / float(_tile_centers.size())


func _projected_center(board_center: Vector3, target_offset: Vector3, distance_scale: float) -> Vector2:
	_apply_camera_transform(board_center, target_offset, distance_scale)
	return _project_board_bounds().get_center()


func _project_board_bounds() -> Rect2:
	var min_x := 1.0e20
	var min_y := 1.0e20
	var max_x := -1.0e20
	var max_y := -1.0e20
	var found := false

	for point in _sample_points:
		if _camera.is_position_behind(point):
			continue
		var screen_pos := _camera.unproject_position(point)
		min_x = minf(min_x, screen_pos.x)
		min_y = minf(min_y, screen_pos.y)
		max_x = maxf(max_x, screen_pos.x)
		max_y = maxf(max_y, screen_pos.y)
		found = true

	if not found:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _apply_camera_transform(board_center: Vector3, target_offset: Vector3, distance_scale: float) -> void:
	var position_offset := _BASE_CAMERA_OFFSET * distance_scale
	_camera.position = board_center + position_offset
	_camera.look_at(board_center + target_offset, Vector3.UP)
