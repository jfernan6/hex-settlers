class_name HUDDevCard
extends Control

const DevCards = preload("res://scripts/game/dev_cards.gd")

const _CARD_LABELS := {
	DevCards.Type.KNIGHT: "Knight",
	DevCards.Type.ROAD_BUILDING: "Road Building",
	DevCards.Type.YEAR_OF_PLENTY: "Year of Plenty",
	DevCards.Type.MONOPOLY: "Monopoly",
	DevCards.Type.VP: "Victory Point",
}

const _CARD_ACCENTS := {
	DevCards.Type.KNIGHT: Color(0.74, 0.18, 0.16),
	DevCards.Type.ROAD_BUILDING: Color(0.16, 0.38, 0.76),
	DevCards.Type.YEAR_OF_PLENTY: Color(0.20, 0.62, 0.28),
	DevCards.Type.MONOPOLY: Color(0.58, 0.18, 0.68),
	DevCards.Type.VP: Color(0.82, 0.66, 0.18),
}

var _card_type: int = DevCards.Type.KNIGHT
var _font_size: int = 15
var _show_count_badge: bool = true
var _face_down: bool = false
var _count: int = 0
var _dimmed: bool = false

var _title_label: Label
var _count_chip: PanelContainer
var _count_label: Label


func setup(card_type: int, font_size: int, show_count_badge: bool = true, face_down: bool = false) -> void:
	_card_type = card_type
	_font_size = font_size
	_show_count_badge = show_count_badge
	_face_down = face_down
	custom_minimum_size = Vector2(maxf(102.0, font_size * 5.4), maxf(142.0, font_size * 8.3))
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ensure_nodes()
	_refresh()


func set_count(count: int) -> void:
	_count = count
	_refresh()


func set_dimmed(dimmed: bool) -> void:
	_dimmed = dimmed
	_refresh()


func set_face_down(face_down: bool) -> void:
	_face_down = face_down
	_refresh()


func set_card_type(card_type: int) -> void:
	_card_type = card_type
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
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", clampi(int(round(_font_size * 0.58)), 9, 15))
	_title_label.add_theme_color_override("font_color", Color(0.18, 0.12, 0.10))
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
	var band_h := clampf(size.y * 0.22, 32.0, 40.0)
	_title_label.position = Vector2(inset + 4.0, size.y - band_h - 5.0)
	_title_label.size = Vector2(maxf(0.0, size.x - (inset + 4.0) * 2.0), band_h)

	var chip_size := Vector2(34.0, 28.0)
	_count_chip.position = Vector2(size.x - chip_size.x - 10.0, 10.0)
	_count_chip.size = chip_size
	_count_label.position = Vector2.ZERO
	_count_label.size = chip_size


func _refresh() -> void:
	_ensure_nodes()
	_title_label.text = _CARD_LABELS.get(_card_type, "Dev Card")
	_title_label.visible = not _face_down
	_count_chip.visible = _show_count_badge and not _face_down
	_count_label.text = str(_count)
	modulate = Color(1.0, 1.0, 1.0, 0.52) if _dimmed else Color.WHITE
	_count_chip.add_theme_stylebox_override("panel", _count_chip_style())
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 4.0 or rect.size.y <= 4.0:
		return
	_draw_card_shell(rect)
	if _face_down:
		_draw_back(rect)
	else:
		_draw_front(rect)


func _draw_card_shell(rect: Rect2) -> void:
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.95, 0.88, 0.74)
	shell.border_color = Color(0.36, 0.26, 0.18)
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
	parchment.bg_color = Color(0.99, 0.95, 0.87)
	parchment.corner_radius_top_left = 12
	parchment.corner_radius_top_right = 12
	parchment.corner_radius_bottom_left = 12
	parchment.corner_radius_bottom_right = 12
	draw_style_box(parchment, inner)


func _draw_front(rect: Rect2) -> void:
	var inset := 10.0
	var band_h := clampf(rect.size.y * 0.22, 32.0, 40.0)
	var art_rect := Rect2(rect.position + Vector2(inset, inset + 2.0),
		Vector2(rect.size.x - inset * 2.0, rect.size.y - band_h - inset * 2.2))
	var accent: Color = _CARD_ACCENTS.get(_card_type, Color(0.4, 0.4, 0.4))

	var art_frame := StyleBoxFlat.new()
	art_frame.bg_color = Color(0.15, 0.15, 0.17)
	art_frame.corner_radius_top_left = 12
	art_frame.corner_radius_top_right = 12
	art_frame.corner_radius_bottom_left = 12
	art_frame.corner_radius_bottom_right = 12
	draw_style_box(art_frame, art_rect)

	var art_inner := art_rect.grow(-4.0)
	draw_rect(art_inner, accent.darkened(0.35))
	draw_rect(Rect2(art_inner.position, Vector2(art_inner.size.x, art_inner.size.y * 0.42)),
		Color(1.0, 1.0, 1.0, 0.05))
	_draw_card_icon(art_inner, accent)

	var band_rect := Rect2(rect.position + Vector2(inset, rect.size.y - band_h - 10.0),
		Vector2(rect.size.x - inset * 2.0, band_h))
	var band := StyleBoxFlat.new()
	band.bg_color = Color(1.0, 0.95, 0.86)
	band.border_color = accent.darkened(0.25)
	band.set_border_width_all(2)
	band.corner_radius_top_left = 10
	band.corner_radius_top_right = 10
	band.corner_radius_bottom_left = 10
	band.corner_radius_bottom_right = 10
	draw_style_box(band, band_rect)


func _draw_back(rect: Rect2) -> void:
	var inner := rect.grow(-10.0)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.23, 0.18, 0.14)
	back.border_color = Color(0.90, 0.79, 0.54, 0.78)
	back.set_border_width_all(2)
	back.corner_radius_top_left = 12
	back.corner_radius_top_right = 12
	back.corner_radius_bottom_left = 12
	back.corner_radius_bottom_right = 12
	draw_style_box(back, inner)
	var lines := 6
	var gap := inner.size.y / float(lines)
	for i in range(lines):
		var y := inner.position.y + gap * (i + 0.5)
		draw_line(Vector2(inner.position.x + 10.0, y), Vector2(inner.end.x - 10.0, y),
			Color(0.94, 0.84, 0.61, 0.18), 2.0, true)
	var c := inner.get_center()
	draw_circle(c, minf(inner.size.x, inner.size.y) * 0.18, Color(0.88, 0.75, 0.48, 0.88))
	draw_circle(c, minf(inner.size.x, inner.size.y) * 0.10, Color(0.23, 0.18, 0.14, 0.92))


func _draw_card_icon(rect: Rect2, accent: Color) -> void:
	match _card_type:
		DevCards.Type.KNIGHT:
			_draw_knight(rect, accent)
		DevCards.Type.ROAD_BUILDING:
			_draw_road_building(rect, accent)
		DevCards.Type.YEAR_OF_PLENTY:
			_draw_year_of_plenty(rect, accent)
		DevCards.Type.MONOPOLY:
			_draw_monopoly(rect, accent)
		DevCards.Type.VP:
			_draw_vp(rect, accent)


func _draw_knight(rect: Rect2, accent: Color) -> void:
	var center := rect.get_center()
	draw_circle(center + Vector2(0, -18), 22.0, Color(0.92, 0.92, 0.94))
	draw_rect(Rect2(center + Vector2(-16, 2), Vector2(32, 44)), Color(0.18, 0.20, 0.26))
	draw_rect(Rect2(center + Vector2(-4, -30), Vector2(8, 72)), accent.lightened(0.25))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-18, -6),
		center + Vector2(0, -38),
		center + Vector2(18, -6),
	]), accent)


func _draw_road_building(rect: Rect2, accent: Color) -> void:
	var ground := Rect2(rect.position + Vector2(0, rect.size.y * 0.64), Vector2(rect.size.x, rect.size.y * 0.36))
	draw_rect(ground, Color(0.48, 0.34, 0.20))
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.92),
		rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.54),
		rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.60),
		rect.position + Vector2(rect.size.x * 0.88, rect.size.y * 0.18),
		rect.position + Vector2(rect.size.x * 0.96, rect.size.y * 0.26),
		rect.position + Vector2(rect.size.x * 0.70, rect.size.y * 0.68),
		rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.62),
		rect.position + Vector2(rect.size.x * 0.20, rect.size.y * 0.96),
	]), Color(0.20, 0.22, 0.25))
	draw_line(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.82),
		rect.position + Vector2(rect.size.x * 0.80, rect.size.y * 0.32), Color(0.92, 0.84, 0.48), 4.0, true)
	draw_circle(rect.position + Vector2(rect.size.x * 0.30, rect.size.y * 0.34), 18.0, accent)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.38, rect.size.y * 0.30), Vector2(34.0, 10.0)),
		accent.lightened(0.18))


func _draw_year_of_plenty(rect: Rect2, accent: Color) -> void:
	var center := rect.get_center()
	draw_circle(center + Vector2(-28, 8), 22.0, Color(0.96, 0.82, 0.24))
	draw_circle(center + Vector2(24, -12), 18.0, Color(0.88, 0.90, 0.95))
	draw_circle(center + Vector2(24, -12), 10.0, Color(0.54, 0.62, 0.76))
	for i in range(5):
		var t := float(i) / 4.0
		draw_line(center + Vector2(-42 + t * 22.0, 36), center + Vector2(-36 + t * 18.0, -24),
			accent.lightened(0.35), 3.0, true)
	draw_line(center + Vector2(-10, 38), center + Vector2(28, -2), Color(0.94, 0.88, 0.72), 4.0, true)


func _draw_monopoly(rect: Rect2, accent: Color) -> void:
	var center := rect.get_center()
	for i in range(3):
		draw_circle(center + Vector2(-18 + i * 18.0, 14 - i * 5.0), 18.0, Color(0.95, 0.79, 0.38))
		draw_circle(center + Vector2(-18 + i * 18.0, 14 - i * 5.0), 10.0, accent.darkened(0.22))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-30, -12),
		center + Vector2(-18, -34),
		center + Vector2(-2, -18),
		center + Vector2(12, -38),
		center + Vector2(28, -12),
	]), accent)
	draw_rect(Rect2(center + Vector2(-26, 34), Vector2(52, 6)), Color(0.18, 0.20, 0.26))


func _draw_vp(rect: Rect2, accent: Color) -> void:
	var center := rect.get_center()
	for i in range(6):
		var angle := TAU * (float(i) / 6.0) - PI * 0.5
		var p1 := center + Vector2.RIGHT.rotated(angle) * 34.0
		var p2 := center + Vector2.RIGHT.rotated(angle + TAU / 12.0) * 16.0
		var p3 := center + Vector2.RIGHT.rotated(angle + TAU / 6.0) * 34.0
		draw_colored_polygon(PackedVector2Array([center, p1, p2, p3]), accent.lightened(0.28))
	draw_circle(center, 16.0, Color(0.96, 0.93, 0.84))
	draw_circle(center, 8.0, accent.darkened(0.25))
	draw_line(center + Vector2(-28, 44), center + Vector2(-10, 18), accent, 6.0, true)
	draw_line(center + Vector2(28, 44), center + Vector2(10, 18), accent, 6.0, true)


func _count_chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _CARD_ACCENTS.get(_card_type, Color(0.35, 0.35, 0.35))
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	return style
