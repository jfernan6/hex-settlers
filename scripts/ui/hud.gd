extends CanvasLayer

## In-game HUD: player info panel (top-right) + message bar (bottom).

signal roll_dice_pressed
signal end_turn_pressed
signal buy_dev_card_pressed

var _player_label: Label
var _phase_label: Label
var _resources_label: Label
var _vp_label: Label
var _cards_label: Label    # dev card hand summary
var _bonus_label: Label    # longest road / largest army
var _dice_label: Label
var _roll_btn: Button
var _end_btn: Button
var _buy_card_btn: Button
var _message_label: Label
var _font_size: int = 15


func _ready() -> void:
	_build_ui()
	print("[HUD] UI built")


func _build_ui() -> void:
	# Scale panel based on actual viewport so it looks right at any resolution
	var vp: Vector2  = get_viewport().get_visible_rect().size
	var pw: float    = maxf(260.0, vp.x * 0.18)   # 18% of screen width, min 260px
	var ph: float    = maxf(420.0, vp.y * 0.55)   # 55% of screen height, min 420px
	_font_size       = int(maxf(14.0, vp.x * 0.012)) # font scales with width
	print("[HUD] vp=%s  panel=%.0fx%.0f  font=%d" % [vp, pw, ph, _font_size])

	# ---- Right info panel ----
	var panel := PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left   = -(pw + 12.0)
	panel.offset_right  = -12.0
	panel.offset_top    = 12.0
	panel.offset_bottom = ph + 12.0
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_player_label    = _lbl("--- Player ---")
	_phase_label     = _lbl("Phase: SETUP")
	_resources_label = _lbl("")
	_cards_label     = _lbl("Cards: none")
	_bonus_label     = _lbl("")
	_vp_label        = _lbl("VP: 0")
	_dice_label      = _lbl("Dice: -")

	for node in [_player_label, _phase_label]:
		vbox.add_child(node)
	vbox.add_child(_sep())
	vbox.add_child(_lbl("Resources:"))
	_resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_resources_label)
	vbox.add_child(_sep())
	vbox.add_child(_cards_label)
	vbox.add_child(_bonus_label)
	vbox.add_child(_sep())
	vbox.add_child(_vp_label)
	vbox.add_child(_sep())
	vbox.add_child(_dice_label)

	_roll_btn     = _btn("Roll Dice",     func(): roll_dice_pressed.emit())
	_buy_card_btn = _btn("Buy Dev Card",  func(): buy_dev_card_pressed.emit())
	_end_btn      = _btn("End Turn",      func(): end_turn_pressed.emit())
	_roll_btn.disabled     = true
	_buy_card_btn.disabled = true
	_end_btn.disabled      = true
	vbox.add_child(_roll_btn)
	vbox.add_child(_buy_card_btn)
	vbox.add_child(_end_btn)

	# ---- Bottom message bar ----
	var msg_panel := PanelContainer.new()
	msg_panel.anchor_left   = 0.0
	msg_panel.anchor_right  = 1.0
	msg_panel.anchor_top    = 1.0
	msg_panel.anchor_bottom = 1.0
	msg_panel.offset_left   = 5.0
	msg_panel.offset_right  = -295.0
	msg_panel.offset_top    = -56.0
	msg_panel.offset_bottom = -5.0
	add_child(msg_panel)

	_message_label = _lbl("Welcome to Hex Settlers!  Place your first settlement.")
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_panel.add_child(_message_label)


# --- Public refresh ---

func refresh(player, phase_name: String, dice_roll: int, state = null) -> void:
	var tag := " [AI]" if player.is_ai else ""
	_player_label.text     = "%s%s's Turn" % [player.player_name, tag]
	_player_label.modulate = player.color
	_phase_label.text      = "Phase: %s" % phase_name
	_resources_label.text  = player.resource_summary()
	_vp_label.text         = "Victory Points: %d" % player.victory_points
	_dice_label.text       = "Dice: %s" % (str(dice_roll) if dice_roll > 0 else "-")

	# Dev card hand
	var DevCards = load("res://scripts/game/dev_cards.gd")
	if DevCards and player.dev_cards.size() > 0:
		_cards_label.text = "Cards: %s" % DevCards.hand_summary(player.dev_cards)
	else:
		_cards_label.text = "Cards: none"

	# Bonus VP holders
	if state != null:
		var bonuses := []
		if state.longest_road_holder >= 0:
			bonuses.append("Road: %s" % state.players[state.longest_road_holder].player_name)
		if state.largest_army_holder >= 0:
			bonuses.append("Army: %s" % state.players[state.largest_army_holder].player_name)
		_bonus_label.text = "\n".join(bonuses)
	else:
		_bonus_label.text = ""

	var in_build := phase_name == "BUILD"
	_roll_btn.disabled = phase_name != "ROLL"
	_end_btn.disabled  = (phase_name != "BUILD" and phase_name != "ROBBER")

	# Buy Dev Card: disabled when not in BUILD, deck empty, or player can't afford
	var can_buy := in_build
	if can_buy and state != null:
		can_buy = not state.dev_deck.is_empty()
		if can_buy:
			can_buy = (player.resources.get(4, 0) >= 1 and   # Ore
					   player.resources.get(3, 0) >= 1 and   # Grain
					   player.resources.get(2, 0) >= 1)       # Wool
	_buy_card_btn.disabled = not can_buy
	if state != null and state.dev_deck.is_empty():
		_buy_card_btn.text = "Dev Deck Empty"
	else:
		_buy_card_btn.text = "Buy Dev Card"


func set_message(msg: String) -> void:
	_message_label.text = msg
	print("[HUD] %s" % msg)


# --- Helpers ---

func _lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _font_size)
	return l


func _sep() -> HSeparator:
	return HSeparator.new()


func _btn(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", _font_size)
	b.custom_minimum_size = Vector2(0, max(36, _font_size * 2.5))
	b.pressed.connect(callback)
	return b
