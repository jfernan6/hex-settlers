extends Control

var _font_size: int = 15
var _res_colors: Array = []
var _res_short: Array = []
var _res_names: Array = []
var _card_center_getter: Callable
var _card_pulse: Callable

var _resource_fx_layer: Control
var _dice_overlay: Control
var _dice_anim_label: Label
var _dice_anim_timer: Timer
var _dice_final: int = 0
var _dice_frame: int = 0
var _roll_feedback_panel: PanelContainer
var _roll_feedback_label: Label
var _roll_feedback_timer: Timer

const _DICE_FRAMES := 18
const _DICE_FRAME_T := 0.045


func setup(font_size: int, res_colors: Array, res_short: Array, res_names: Array,
		card_center_getter: Callable, card_pulse: Callable) -> void:
	_font_size = font_size
	_res_colors = res_colors
	_res_short = res_short
	_res_names = res_names
	_card_center_getter = card_center_getter
	_card_pulse = card_pulse
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_dice_overlay()
	_build_roll_feedback()
	_build_resource_fx_layer()


func show_dice_animation(result: int) -> void:
	_dice_final = result
	_dice_frame = 0
	_dice_anim_label.text = "?"
	_dice_anim_label.modulate = Color(1, 1, 1, 1)
	_dice_overlay.visible = true
	_dice_anim_timer.start()


func get_roll_feedback_delay(show_dice_anim: bool) -> float:
	if not show_dice_anim:
		return 0.40
	return (_DICE_FRAMES * _DICE_FRAME_T) + 1.45


func show_roll_feedback(player_name: String, roll: int, gains: Dictionary, robber_triggered: bool) -> void:
	var lines: Array[String] = []
	lines.append("%s rolled %d" % [player_name, roll])
	if robber_triggered:
		lines.append("Robber triggered. Move the bandit.")
	else:
		var parts: Array[String] = []
		for res in [0, 1, 2, 3, 4]:
			var amount: int = gains.get(res, 0)
			if amount > 0:
				parts.append("+%d %s" % [amount, _res_names[res]])
		lines.append(", ".join(parts) if not parts.is_empty() else "No resources gained on that roll.")
	_roll_feedback_label.text = "\n".join(lines)
	_roll_feedback_panel.visible = true
	_roll_feedback_timer.start(1.8)


func show_resource_chip_flight(res: int, source_points: Array, amount: int, caption: String = "") -> void:
	if amount <= 0:
		return
	var target: Vector2 = _card_center_getter.call(res)
	var total: int = maxi(amount, source_points.size())
	for source_point in source_points:
		_spawn_source_pulse(source_point, res)
	for i in range(total):
		var source: Vector2 = source_points[i % maxi(1, source_points.size())] if not source_points.is_empty() else get_viewport().get_visible_rect().size * 0.5
		_spawn_resource_chip(source, target, res, i)
	if caption != "":
		_spawn_resource_caption(target, caption)
	var pulse_timer := get_tree().create_timer(1.48 + total * 0.12)
	pulse_timer.timeout.connect(func() -> void:
		_card_pulse.call(res)
	)


func _build_dice_overlay() -> void:
	_dice_overlay = Control.new()
	_dice_overlay.visible = false
	_dice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_overlay.anchor_right = 1.0
	_dice_overlay.anchor_bottom = 1.0

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_dice_overlay.add_child(center)

	var inner := VBoxContainer.new()
	inner.custom_minimum_size = Vector2(200, 150)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(inner)

	_dice_anim_label = Label.new()
	_dice_anim_label.text = "?"
	_dice_anim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_anim_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dice_anim_label.add_theme_font_size_override("font_size", 96)
	_dice_anim_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
	_dice_anim_label.add_theme_color_override("font_shadow_color", Color(0.12, 0.08, 0.05, 0.55))
	_dice_anim_label.add_theme_constant_override("shadow_offset_x", 0)
	_dice_anim_label.add_theme_constant_override("shadow_offset_y", 8)
	inner.add_child(_dice_anim_label)
	add_child(_dice_overlay)

	_dice_anim_timer = Timer.new()
	_dice_anim_timer.wait_time = _DICE_FRAME_T
	_dice_anim_timer.one_shot = true
	_dice_anim_timer.timeout.connect(_on_dice_anim_tick)
	add_child(_dice_anim_timer)


func _on_dice_anim_tick() -> void:
	_dice_frame += 1
	if _dice_frame >= _DICE_FRAMES:
		_dice_anim_label.text = str(_dice_final)
		_dice_anim_label.modulate = Color(1.0, 0.88, 0.18)
		await get_tree().create_timer(0.80).timeout
		_dice_overlay.visible = false
	else:
		_dice_anim_label.text = str(randi_range(2, 12))
		_dice_anim_label.modulate = Color(1, 1, 1, 1)
		_dice_anim_timer.start()


func _build_roll_feedback() -> void:
	_roll_feedback_panel = PanelContainer.new()
	_roll_feedback_panel.visible = false
	_roll_feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll_feedback_panel.anchor_left = 0.5
	_roll_feedback_panel.anchor_right = 0.5
	_roll_feedback_panel.offset_left = -190.0
	_roll_feedback_panel.offset_right = 190.0
	_roll_feedback_panel.offset_top = 24.0
	_roll_feedback_panel.offset_bottom = 108.0
	_roll_feedback_panel.add_theme_stylebox_override("panel", _roll_feedback_style())
	add_child(_roll_feedback_panel)

	_roll_feedback_label = Label.new()
	_roll_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roll_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_roll_feedback_label.add_theme_font_size_override("font_size", _font_size + 2)
	_roll_feedback_panel.add_child(_roll_feedback_label)

	_roll_feedback_timer = Timer.new()
	_roll_feedback_timer.one_shot = true
	_roll_feedback_timer.timeout.connect(func() -> void:
		_roll_feedback_panel.visible = false
	)
	add_child(_roll_feedback_timer)


func _build_resource_fx_layer() -> void:
	_resource_fx_layer = Control.new()
	_resource_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resource_fx_layer.anchor_right = 1.0
	_resource_fx_layer.anchor_bottom = 1.0
	_resource_fx_layer.z_index = 30
	add_child(_resource_fx_layer)


func _spawn_source_pulse(source: Vector2, res: int) -> void:
	var ring := ColorRect.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(34, 34)
	ring.position = source - ring.size * 0.5
	ring.pivot_offset = ring.size * 0.5
	ring.color = _res_colors[res].lightened(0.18)
	ring.material = CanvasItemMaterial.new()
	ring.modulate = Color(1.0, 0.96, 0.90, 0.0)
	_resource_fx_layer.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.52)
	tween.tween_property(ring, "modulate", Color(1.0, 0.96, 0.90, 0.65), 0.12)
	tween.chain()
	tween.tween_property(ring, "modulate", Color(1.0, 0.96, 0.90, 0.0), 0.42)
	tween.finished.connect(ring.queue_free)


func _spawn_resource_chip(source: Vector2, target: Vector2, res: int, index: int) -> void:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size = Vector2(34, 24)
	chip.position = source - chip.size * 0.5 + Vector2(index * 6.0, -index * 4.0)
	chip.pivot_offset = chip.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = _res_colors[res].lightened(0.08)
	style.border_color = Color(1.0, 0.95, 0.86, 0.95)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	chip.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = _res_short[res]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", maxi(12, _font_size - 1))
	label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	chip.add_child(label)
	_resource_fx_layer.add_child(chip)

	var mid: Vector2 = source.lerp(target, 0.52) + Vector2(randf_range(-22.0, 22.0), -96.0 - index * 14.0)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.24 + index * 0.10)
	tween.tween_property(chip, "position", mid - chip.size * 0.5, 0.48)
	tween.tween_property(chip, "scale", Vector2(1.18, 1.18), 0.48)
	tween.chain().set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(chip, "position", target - chip.size * 0.5, 0.68)
	tween.tween_property(chip, "scale", Vector2(0.84, 0.84), 0.68)
	tween.tween_property(chip, "modulate", Color(1, 1, 1, 0.15), 0.68)
	tween.finished.connect(chip.queue_free)


func _spawn_resource_caption(target: Vector2, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.position = target + Vector2(-58.0, -52.0)
	label.modulate = Color(1.0, 0.93, 0.84, 0.0)
	label.add_theme_font_size_override("font_size", _font_size + 1)
	label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	_resource_fx_layer.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -16.0), 0.55)
	tween.tween_property(label, "modulate", Color(1.0, 0.93, 0.84, 1.0), 0.12)
	tween.chain()
	tween.tween_property(label, "modulate", Color(1.0, 0.93, 0.84, 0.0), 0.34)
	tween.finished.connect(label.queue_free)


func _roll_feedback_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.12, 0.09, 0.90)
	sb.border_color = Color(0.93, 0.78, 0.42, 0.95)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 12
	return sb
