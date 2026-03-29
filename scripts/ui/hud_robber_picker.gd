class_name HUDRobberPicker
extends PanelContainer

const HUDResourceCard = preload("res://scripts/ui/hud_resource_card.gd")
const PlayerData = preload("res://scripts/player/player.gd")

signal victim_chosen(victim_idx: int)
signal card_picked(victim_idx: int, resource: int)

var _font_size: int = 15
var _title: Label
var _subtitle: Label
var _content: VBoxContainer
var _card_buttons: Array = []


func setup(font_size: int) -> void:
	_font_size = font_size
	visible = false
	z_index = 45
	anchor_left = 0.17
	anchor_right = 0.83
	anchor_top = 0.12
	anchor_bottom = 0.80
	add_theme_stylebox_override("panel", _panel_style())
	_build_ui()


func open_victim_picker(victims: Array) -> void:
	_clear_content()
	_title.text = "Choose a player to rob"
	_subtitle.text = "Select one opponent adjacent to the robber."
	visible = true

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)

	for entry in victims:
		var victim_idx: int = int(entry.get("player_index", -1))
		var btn := Button.new()
		btn.text = "%s\n%d cards" % [str(entry.get("player_name", "Opponent")), int(entry.get("card_count", 0))]
		btn.flat = false
		btn.custom_minimum_size = Vector2(140.0, 76.0)
		btn.add_theme_font_size_override("font_size", _font_size)
		btn.add_theme_stylebox_override("normal", _option_style(Color(0.21, 0.26, 0.34), Color(0.54, 0.64, 0.76)))
		btn.add_theme_stylebox_override("hover", _option_style(Color(0.27, 0.33, 0.42), Color(0.70, 0.79, 0.90)))
		btn.add_theme_stylebox_override("pressed", _option_style(Color(0.16, 0.20, 0.27), Color(0.82, 0.88, 0.96)))
		btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
		btn.pressed.connect(func() -> void:
			visible = false
			victim_chosen.emit(victim_idx)
		)
		row.add_child(btn)


func open_card_picker(victim_idx: int, victim_name: String, cards: Array, face_up: bool = false) -> void:
	_clear_content()
	_title.text = "Pick a card from %s" % victim_name
	_subtitle.text = "Choose a visible card to steal." if face_up else "Cards are face down and shuffled."
	visible = true

	var flow := FlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	_content.add_child(flow)

	for card_data in cards:
		var resource: int = int(card_data.get("resource", 0))
		var button := Button.new()
		button.flat = true
		button.custom_minimum_size = Vector2(maxf(96.0, _font_size * 5.5), maxf(132.0, _font_size * 8.0))
		button.add_theme_stylebox_override("normal", _clear_button_style())
		button.add_theme_stylebox_override("hover", _clear_button_style())
		button.add_theme_stylebox_override("pressed", _clear_button_style())
		button.add_theme_stylebox_override("focus", _clear_button_style())

		var card := HUDResourceCard.new()
		card.setup(resource, _font_size, not face_up, false)
		card.anchor_right = 1.0
		card.anchor_bottom = 1.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(card)

		button.pressed.connect(func() -> void:
			if face_up:
				_pick_face_up_card(victim_idx, resource)
			else:
				_reveal_card(button, card, victim_idx, resource)
		)
		flow.add_child(button)
		_card_buttons.append(button)


func _reveal_card(_button: Button, card: HUDResourceCard, victim_idx: int, resource: int) -> void:
	for item in _card_buttons:
		item.disabled = true
	card.set_face_down(false)
	_title.text = "Revealed: %s" % PlayerData.RES_NAMES.get(resource, "Resource")
	_subtitle.text = "Transferring the stolen card..."
	var timer := get_tree().create_timer(0.55)
	timer.timeout.connect(func() -> void:
		visible = false
		card_picked.emit(victim_idx, resource)
	)


func _pick_face_up_card(victim_idx: int, resource: int) -> void:
	for item in _card_buttons:
		item.disabled = true
	_title.text = "Stealing %s" % PlayerData.RES_NAMES.get(resource, "Resource")
	_subtitle.text = "Transferring the chosen card..."
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(func() -> void:
		visible = false
		card_picked.emit(victim_idx, resource)
	)


func _build_ui() -> void:
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 18)
	outer.add_theme_constant_override("margin_right", 18)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_bottom", 18)
	add_child(outer)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	outer.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", _font_size + 5)
	_title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.90))
	vb.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", _font_size)
	_subtitle.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90))
	vb.add_child(_subtitle)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 10)
	vb.add_child(_content)


func _clear_content() -> void:
	_card_buttons.clear()
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.96)
	style.border_color = Color(0.39, 0.46, 0.56, 0.94)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 22
	return style


func _option_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _clear_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	return style
