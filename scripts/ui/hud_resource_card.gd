class_name HUDResourceCard
extends Control

const PlayerData = preload("res://scripts/player/player.gd")

const _RESOURCE_LABELS := {
	PlayerData.RES_LUMBER: "Lumber",
	PlayerData.RES_BRICK: "Brick",
	PlayerData.RES_WOOL: "Wool",
	PlayerData.RES_GRAIN: "Grain",
	PlayerData.RES_ORE: "Ore",
}

const _RESOURCE_ACCENTS := {
	PlayerData.RES_LUMBER: Color(0.20, 0.48, 0.22),
	PlayerData.RES_BRICK: Color(0.66, 0.25, 0.12),
	PlayerData.RES_WOOL: Color(0.38, 0.66, 0.26),
	PlayerData.RES_GRAIN: Color(0.86, 0.72, 0.22),
	PlayerData.RES_ORE: Color(0.42, 0.47, 0.60),
}

var _resource: int = PlayerData.RES_LUMBER
var _font_size: int = 15
var _face_down: bool = false
var _show_count_badge: bool = true
var _count: int = 0
var _dimmed: bool = false

var _title_label: Label
var _count_chip: PanelContainer
var _count_label: Label


func setup(resource: int, font_size: int, face_down: bool = false, show_count_badge: bool = true) -> void:
	_resource = resource
	_font_size = font_size
	_face_down = face_down
	_show_count_badge = show_count_badge
	custom_minimum_size = Vector2(maxf(104.0, font_size * 5.6), maxf(136.0, font_size * 8.1))
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ensure_nodes()
	_refresh()


func set_count(count: int) -> void:
	_count = count
	_refresh()


func set_face_down(face_down: bool) -> void:
	_face_down = face_down
	_refresh()


func set_dimmed(dimmed: bool) -> void:
	_dimmed = dimmed
	_refresh()


func set_resource(resource: int) -> void:
	_resource = resource
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_nodes()
		queue_redraw()


func _ensure_nodes() -> void:
	if _title_label != null:
		return

	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", clampi(int(round(_font_size * 0.66)), 10, 16))
	_title_label.add_theme_color_override("font_color", Color(0.19, 0.14, 0.10))
	add_child(_title_label)

	_count_chip = PanelContainer.new()
	_count_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_chip)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", maxi(12, _font_size))
	_count_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	_count_chip.add_child(_count_label)

	_layout_nodes()


func _layout_nodes() -> void:
	if _title_label == null:
		return
	var inset := 10.0
	var band_h := clampf(size.y * 0.20, 28.0, 36.0)
	_title_label.position = Vector2(inset + 4.0, size.y - band_h - 3.0)
	_title_label.size = Vector2(maxf(0.0, size.x - (inset + 4.0) * 2.0), band_h)

	var chip_size := Vector2(34.0, 28.0)
	_count_chip.position = Vector2(size.x - chip_size.x - 10.0, 10.0)
	_count_chip.size = chip_size
	_count_label.position = Vector2.ZERO
	_count_label.size = chip_size


func _refresh() -> void:
	_ensure_nodes()
	_title_label.text = _RESOURCE_LABELS.get(_resource, "Resource")
	_title_label.visible = not _face_down
	_count_chip.visible = _show_count_badge and not _face_down
	_count_label.text = str(_count)
	modulate = Color(1.0, 1.0, 1.0, 0.54) if _dimmed else Color.WHITE
	_count_chip.add_theme_stylebox_override("panel", _count_chip_style())
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 4.0 or rect.size.y <= 4.0:
		return

	_draw_card_shell(rect)
	if _face_down:
		_draw_back_face(rect)
	else:
		_draw_front_face(rect)


func _draw_card_shell(rect: Rect2) -> void:
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.95, 0.89, 0.76)
	shell.border_color = Color(0.39, 0.28, 0.18)
	shell.set_border_width_all(3)
	shell.corner_radius_top_left = 16
	shell.corner_radius_top_right = 16
	shell.corner_radius_bottom_left = 16
	shell.corner_radius_bottom_right = 16
	shell.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	shell.shadow_size = 10
	draw_style_box(shell, rect)

	var inner := rect.grow(-6.0)
	var parchment := StyleBoxFlat.new()
	parchment.bg_color = Color(0.98, 0.95, 0.88)
	parchment.corner_radius_top_left = 12
	parchment.corner_radius_top_right = 12
	parchment.corner_radius_bottom_left = 12
	parchment.corner_radius_bottom_right = 12
	draw_style_box(parchment, inner)


func _draw_front_face(rect: Rect2) -> void:
	var inset := 10.0
	var band_h := clampf(rect.size.y * 0.20, 28.0, 36.0)
	var art_rect := Rect2(rect.position + Vector2(inset, inset + 2.0),
		Vector2(rect.size.x - inset * 2.0, rect.size.y - band_h - inset * 2.2))

	var art_frame := StyleBoxFlat.new()
	art_frame.bg_color = Color(0.16, 0.15, 0.14)
	art_frame.corner_radius_top_left = 12
	art_frame.corner_radius_top_right = 12
	art_frame.corner_radius_bottom_left = 12
	art_frame.corner_radius_bottom_right = 12
	draw_style_box(art_frame, art_rect)

	var art_inner := art_rect.grow(-4.0)
	_draw_art_scene(art_inner)

	var band_rect := Rect2(rect.position + Vector2(inset, rect.size.y - band_h - 10.0),
		Vector2(rect.size.x - inset * 2.0, band_h))
	var band := StyleBoxFlat.new()
	band.bg_color = Color(1.0, 0.95, 0.86)
	band.border_color = _RESOURCE_ACCENTS.get(_resource, Color(0.4, 0.4, 0.4)).darkened(0.25)
	band.set_border_width_all(2)
	band.corner_radius_top_left = 10
	band.corner_radius_top_right = 10
	band.corner_radius_bottom_left = 10
	band.corner_radius_bottom_right = 10
	draw_style_box(band, band_rect)

	var top_glow := StyleBoxFlat.new()
	top_glow.bg_color = Color(1.0, 1.0, 1.0, 0.05)
	top_glow.corner_radius_top_left = 12
	top_glow.corner_radius_top_right = 12
	top_glow.corner_radius_bottom_left = 12
	top_glow.corner_radius_bottom_right = 12
	draw_style_box(top_glow, Rect2(art_inner.position, Vector2(art_inner.size.x, art_inner.size.y * 0.38)))


func _draw_back_face(rect: Rect2) -> void:
	var inner := rect.grow(-10.0)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.19, 0.25, 0.36)
	back.border_color = Color(0.78, 0.84, 0.91, 0.74)
	back.set_border_width_all(2)
	back.corner_radius_top_left = 12
	back.corner_radius_top_right = 12
	back.corner_radius_bottom_left = 12
	back.corner_radius_bottom_right = 12
	draw_style_box(back, inner)

	var stripe_color := Color(0.34, 0.44, 0.58, 0.55)
	var stripe_count := 7
	var stripe_step := inner.size.x / float(stripe_count)
	for i in range(stripe_count):
		var x := inner.position.x + i * stripe_step
		draw_line(Vector2(x, inner.position.y), Vector2(x + inner.size.y * 0.42, inner.position.y + inner.size.y),
			stripe_color, 4.0, true)

	var emblem_center := inner.get_center()
	draw_circle(emblem_center, minf(inner.size.x, inner.size.y) * 0.18, Color(0.89, 0.82, 0.62, 0.95))
	draw_circle(emblem_center, minf(inner.size.x, inner.size.y) * 0.10, Color(0.24, 0.30, 0.40, 0.95))
	draw_colored_polygon(PackedVector2Array([
		emblem_center + Vector2(0, -20),
		emblem_center + Vector2(20, 0),
		emblem_center + Vector2(0, 20),
		emblem_center + Vector2(-20, 0),
	]), Color(0.93, 0.90, 0.78, 0.74))


func _draw_art_scene(art_rect: Rect2) -> void:
	match _resource:
		PlayerData.RES_LUMBER:
			_draw_forest(art_rect)
		PlayerData.RES_BRICK:
			_draw_brickworks(art_rect)
		PlayerData.RES_WOOL:
			_draw_pasture(art_rect)
		PlayerData.RES_GRAIN:
			_draw_fields(art_rect)
		PlayerData.RES_ORE:
			_draw_mountains(art_rect)


func _draw_forest(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.52)), Color(0.52, 0.76, 0.93))
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.52), Vector2(rect.size.x, rect.size.y * 0.48)), Color(0.37, 0.59, 0.29))
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(0, rect.size.y * 0.82),
		rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.48),
		rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.82),
	]), Color(0.22, 0.38, 0.17))
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.90),
		rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.34),
		rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.90),
	]), Color(0.18, 0.34, 0.15))
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.86),
		rect.position + Vector2(rect.size.x * 0.74, rect.size.y * 0.42),
		rect.position + Vector2(rect.size.x * 0.92, rect.size.y * 0.86),
	]), Color(0.24, 0.42, 0.20))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.38, rect.size.y * 0.70), Vector2(8, rect.size.y * 0.20)), Color(0.36, 0.24, 0.14))


func _draw_brickworks(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.48)), Color(0.73, 0.83, 0.94))
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.48), Vector2(rect.size.x, rect.size.y * 0.52)), Color(0.63, 0.42, 0.24))
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.74),
		rect.position + Vector2(rect.size.x * 0.38, rect.size.y * 0.55),
		rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.76),
		rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.90),
		rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.90),
	]), Color(0.71, 0.25, 0.14))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.42), Vector2(rect.size.x * 0.14, rect.size.y * 0.28)), Color(0.52, 0.18, 0.11))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.66, rect.size.y * 0.70), Vector2(rect.size.x * 0.16, rect.size.y * 0.08)), Color(0.74, 0.33, 0.20))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.78), Vector2(rect.size.x * 0.20, rect.size.y * 0.08)), Color(0.84, 0.43, 0.28))
	draw_circle(rect.position + Vector2(rect.size.x * 0.66, rect.size.y * 0.34), 10.0, Color(0.89, 0.81, 0.72, 0.75))


func _draw_pasture(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.45)), Color(0.64, 0.84, 0.96))
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.45), Vector2(rect.size.x, rect.size.y * 0.55)), Color(0.47, 0.72, 0.34))
	draw_arc(rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.90), rect.size.x * 0.28, PI * 1.03, PI * 1.97, 20, Color(0.54, 0.38, 0.20), 3.0)
	_draw_sheep(rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.72), 1.0)
	_draw_sheep(rect.position + Vector2(rect.size.x * 0.68, rect.size.y * 0.78), 0.82)


func _draw_fields(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.40)), Color(0.74, 0.87, 0.96))
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.40), Vector2(rect.size.x, rect.size.y * 0.60)), Color(0.84, 0.68, 0.26))
	for i in range(6):
		var x := rect.position.x + rect.size.x * (0.10 + i * 0.14)
		draw_line(Vector2(x, rect.position.y + rect.size.y * 0.44), Vector2(x, rect.position.y + rect.size.y * 0.92),
			Color(0.75, 0.54, 0.12), 3.0, true)
		draw_line(Vector2(x, rect.position.y + rect.size.y * 0.54), Vector2(x - 7.0, rect.position.y + rect.size.y * 0.48),
			Color(0.96, 0.88, 0.48), 2.0, true)
		draw_line(Vector2(x, rect.position.y + rect.size.y * 0.60), Vector2(x + 7.0, rect.position.y + rect.size.y * 0.53),
			Color(0.96, 0.88, 0.48), 2.0, true)
		draw_line(Vector2(x, rect.position.y + rect.size.y * 0.68), Vector2(x - 7.0, rect.position.y + rect.size.y * 0.62),
			Color(0.98, 0.91, 0.55), 2.0, true)
		draw_line(Vector2(x, rect.position.y + rect.size.y * 0.74), Vector2(x + 7.0, rect.position.y + rect.size.y * 0.66),
			Color(0.98, 0.91, 0.55), 2.0, true)


func _draw_mountains(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.46)), Color(0.64, 0.80, 0.95))
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.46), Vector2(rect.size.x, rect.size.y * 0.54)), Color(0.46, 0.46, 0.52))
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.02, rect.size.y * 0.90),
		rect.position + Vector2(rect.size.x * 0.26, rect.size.y * 0.38),
		rect.position + Vector2(rect.size.x * 0.48, rect.size.y * 0.90),
	]), Color(0.38, 0.41, 0.48))
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.28, rect.size.y * 0.92),
		rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.28),
		rect.position + Vector2(rect.size.x * 0.90, rect.size.y * 0.92),
	]), Color(0.49, 0.52, 0.60))
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.56),
		rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.28),
		rect.position + Vector2(rect.size.x * 0.66, rect.size.y * 0.56),
	]), Color(0.91, 0.92, 0.94))
	draw_circle(rect.position + Vector2(rect.size.x * 0.70, rect.size.y * 0.70), 10.0, Color(0.54, 0.80, 0.94))
	draw_circle(rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.78), 7.0, Color(0.70, 0.87, 0.98))


func _draw_sheep(center: Vector2, scale: float) -> void:
	var body_r := 13.0 * scale
	var wool_color := Color(0.97, 0.98, 0.94)
	draw_circle(center, body_r, wool_color)
	draw_circle(center + Vector2(-body_r * 0.56, -body_r * 0.24), body_r * 0.55, wool_color)
	draw_circle(center + Vector2(body_r * 0.48, -body_r * 0.18), body_r * 0.48, wool_color)
	draw_circle(center + Vector2(body_r * 1.05, -body_r * 0.14), body_r * 0.52, Color(0.16, 0.16, 0.16))
	draw_circle(center + Vector2(body_r * 1.28, -body_r * 0.08), body_r * 0.18, Color(0.16, 0.16, 0.16))
	draw_line(center + Vector2(-body_r * 0.38, body_r * 0.70), center + Vector2(-body_r * 0.38, body_r * 1.45), Color(0.18, 0.18, 0.18), 2.0, true)
	draw_line(center + Vector2(body_r * 0.12, body_r * 0.72), center + Vector2(body_r * 0.12, body_r * 1.42), Color(0.18, 0.18, 0.18), 2.0, true)


func _count_chip_style() -> StyleBoxFlat:
	var accent: Color = _RESOURCE_ACCENTS.get(_resource, Color(0.4, 0.4, 0.4))
	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.18)
	style.border_color = Color(1.0, 0.96, 0.88, 0.90)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style
