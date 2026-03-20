extends CanvasLayer

## In-game HUD: player info panel (top-right) + message bar (bottom).
## Sprint 1A: visual resource cards.
## Sprint 1B: dice roll animation overlay.
## Sprint 1C: clickable dev card hand + resource picker for YoP/Monopoly.
## Sprint 2C: player trade dialog.

const _DevCards = preload("res://scripts/game/dev_cards.gd")

signal roll_dice_pressed
signal end_turn_pressed
signal buy_dev_card_pressed
signal play_dev_card_requested(card_type: int)
signal year_of_plenty_chosen(r1: int, r2: int)
signal monopoly_chosen(res: int)
signal trade_proposed(offer: Dictionary, want: Dictionary, to_player_idx: int)

# Core labels / buttons
var _player_label:  Label
var _phase_label:   Label
var _vp_label:      Label
var _bonus_label:   Label
var _dice_label:    Label
var _roll_btn:      Button
var _end_btn:       Button
var _buy_card_btn:  Button
var _trade_btn:     Button
var _message_label: Label
var _font_size: int = 15

# 1A — resource card display (5 coloured tiles)
var _res_count_labels: Array = []
var _res_panels:       Array = []

const _RES_COLORS: Array = [
	Color(0.12, 0.42, 0.08),  # Lumber  - forest green
	Color(0.65, 0.20, 0.06),  # Brick   - terracotta
	Color(0.28, 0.68, 0.12),  # Wool    - meadow green
	Color(0.85, 0.70, 0.04),  # Grain   - gold
	Color(0.38, 0.40, 0.50),  # Ore     - steel grey-blue
]
const _RES_SHORT: Array  = ["LU", "BR", "WO", "GR", "OR"]
const _RES_NAMES: Array  = ["Lumber", "Brick", "Wool", "Grain", "Ore"]

# 1B — dice animation
var _dice_overlay:    Panel
var _dice_anim_label: Label
var _dice_anim_timer: Timer
var _dice_final:  int = 0
var _dice_frame:  int = 0
const _DICE_FRAMES    := 18
const _DICE_FRAME_T   := 0.045

# 1C — dev card hand + resource picker
var _dev_card_section: VBoxContainer
var _res_picker:        PanelContainer
var _res_picker_mode:   String = ""
var _res_picker_sel:    Array  = []

const _CARD_COLORS: Dictionary = {
	0: Color(0.80, 0.14, 0.10),  # Knight        - crimson
	1: Color(0.14, 0.40, 0.80),  # Road Building - blue
	2: Color(0.12, 0.65, 0.28),  # Year of Plenty- green
	3: Color(0.60, 0.14, 0.75),  # Monopoly      - purple
}

# 2C — trade dialog
var _trade_dialog:        PanelContainer
var _trade_offer:         Array = [0, 0, 0, 0, 0]
var _trade_want:          Array = [0, 0, 0, 0, 0]
var _trade_offer_labels:  Array = []
var _trade_want_labels:   Array = []
var _trade_player_names:  Array = []
var _trade_player_count:  int   = 0
var _current_player_resources: Dictionary = {}


func _ready() -> void:
	_build_ui()
	print("[HUD] UI built")


func _build_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var pw: float   = maxf(265.0, vp.x * 0.18)
	var ph: float   = maxf(520.0, vp.y * 0.66)
	_font_size      = int(maxf(14.0, vp.x * 0.012))
	print("[HUD] vp=%s  panel=%.0fx%.0f  font=%d" % [vp, pw, ph, _font_size])

	# ---- Right info panel ----
	var panel := PanelContainer.new()
	panel.anchor_left   = 1.0; panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0; panel.anchor_bottom = 0.0
	panel.offset_left   = -(pw + 12.0); panel.offset_right  = -12.0
	panel.offset_top    = 12.0;          panel.offset_bottom = ph + 12.0
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	_player_label = _lbl("--- Player ---")
	_phase_label  = _lbl("Phase: SETUP")
	_vp_label     = _lbl("VP: 0")
	_bonus_label  = _lbl("")
	_dice_label   = _lbl("Dice: -")

	for node in [_player_label, _phase_label]:
		vbox.add_child(node)
	vbox.add_child(_sep())

	# 1A: Visual resource cards
	vbox.add_child(_lbl("Resources:"))
	_build_resource_cards(vbox)
	vbox.add_child(_sep())

	# 1C: Clickable dev card hand
	_dev_card_section = VBoxContainer.new()
	_dev_card_section.add_theme_constant_override("separation", 3)
	vbox.add_child(_dev_card_section)
	_dev_card_section.add_child(_lbl("Cards: none"))
	vbox.add_child(_sep())

	vbox.add_child(_bonus_label)
	vbox.add_child(_vp_label)
	vbox.add_child(_sep())
	vbox.add_child(_dice_label)

	_roll_btn     = _btn("Roll Dice",    func(): roll_dice_pressed.emit())
	_buy_card_btn = _btn("Buy Dev Card", func(): buy_dev_card_pressed.emit())
	_trade_btn    = _btn("Propose Trade",func(): _open_trade_dialog())
	_end_btn      = _btn("End Turn",     func(): end_turn_pressed.emit())
	_roll_btn.disabled     = true
	_buy_card_btn.disabled = true
	_trade_btn.disabled    = true
	_end_btn.disabled      = true
	vbox.add_child(_roll_btn)
	vbox.add_child(_buy_card_btn)
	vbox.add_child(_trade_btn)
	vbox.add_child(_end_btn)

	# ---- Bottom message bar ----
	var msg_panel := PanelContainer.new()
	msg_panel.anchor_left   = 0.0; msg_panel.anchor_right  = 1.0
	msg_panel.anchor_top    = 1.0; msg_panel.anchor_bottom = 1.0
	msg_panel.offset_left   = 5.0; msg_panel.offset_right  = -295.0
	msg_panel.offset_top    = -56.0; msg_panel.offset_bottom = -5.0
	add_child(msg_panel)

	_message_label = _lbl("Welcome to Hex Settlers!  Place your first settlement.")
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_panel.add_child(_message_label)

	# ---- 1B: Dice animation overlay ----
	_build_dice_overlay()

	# ---- 1C: Resource picker overlay ----
	_build_res_picker()

	# ---- 2C: Trade dialog overlay ----
	_build_trade_dialog()


# ---------------------------------------------------------------
# Sprint 1A — Resource card grid
# ---------------------------------------------------------------

func _build_resource_cards(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(hbox)

	var card_w := int(maxf(42.0, _font_size * 3.2))
	var card_h := int(card_w * 1.25)

	for r in 5:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(card_w, card_h)

		var style := StyleBoxFlat.new()
		style.bg_color = _RES_COLORS[r]
		style.corner_radius_top_left     = 5
		style.corner_radius_top_right    = 5
		style.corner_radius_bottom_left  = 5
		style.corner_radius_bottom_right = 5
		style.content_margin_left  = 3
		style.content_margin_right = 3
		style.content_margin_top   = 3
		style.content_margin_bottom = 3
		card.add_theme_stylebox_override("panel", style)

		var cvbox := VBoxContainer.new()
		cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cvbox.add_theme_constant_override("separation", 1)
		card.add_child(cvbox)

		var abbr := Label.new()
		abbr.text = _RES_SHORT[r]
		abbr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		abbr.add_theme_font_size_override("font_size", maxi(9, _font_size - 5))
		abbr.modulate = Color(1.0, 1.0, 1.0, 0.82)
		cvbox.add_child(abbr)

		var cnt := Label.new()
		cnt.text = "0"
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", maxi(14, _font_size + 2))
		cvbox.add_child(cnt)

		hbox.add_child(card)
		_res_count_labels.append(cnt)
		_res_panels.append(card)


# ---------------------------------------------------------------
# Sprint 1B — Dice roll animation
# ---------------------------------------------------------------

func _build_dice_overlay() -> void:
	_dice_overlay = Panel.new()
	_dice_overlay.visible = false
	_dice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_overlay.anchor_left   = 0.0; _dice_overlay.anchor_right  = 1.0
	_dice_overlay.anchor_top    = 0.0; _dice_overlay.anchor_bottom = 1.0

	var center := CenterContainer.new()
	center.anchor_left = 0.0; center.anchor_right  = 1.0
	center.anchor_top  = 0.0; center.anchor_bottom = 1.0
	_dice_overlay.add_child(center)

	var inner := PanelContainer.new()
	inner.custom_minimum_size = Vector2(160, 130)
	center.add_child(inner)

	_dice_anim_label = Label.new()
	_dice_anim_label.text = "?"
	_dice_anim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_anim_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_dice_anim_label.add_theme_font_size_override("font_size", 74)
	inner.add_child(_dice_anim_label)

	add_child(_dice_overlay)

	_dice_anim_timer = Timer.new()
	_dice_anim_timer.wait_time = _DICE_FRAME_T
	_dice_anim_timer.one_shot  = true
	_dice_anim_timer.timeout.connect(_on_dice_anim_tick)
	add_child(_dice_anim_timer)


func show_dice_animation(result: int) -> void:
	_dice_final = result
	_dice_frame = 0
	_dice_anim_label.text     = "?"
	_dice_anim_label.modulate = Color(1, 1, 1, 1)
	_dice_overlay.visible     = true
	_dice_anim_timer.start()


func _on_dice_anim_tick() -> void:
	_dice_frame += 1
	if _dice_frame >= _DICE_FRAMES:
		_dice_anim_label.text     = str(_dice_final)
		_dice_anim_label.modulate = Color(1.0, 0.88, 0.18)  # golden result
		await get_tree().create_timer(0.65).timeout
		_dice_overlay.visible = false
	else:
		_dice_anim_label.text     = str(randi_range(2, 12))
		_dice_anim_label.modulate = Color(1, 1, 1, 1)
		_dice_anim_timer.start()


# ---------------------------------------------------------------
# Sprint 1C — Dev card hand (clickable) + resource picker
# ---------------------------------------------------------------

func _refresh_dev_cards(hand: Array) -> void:
	for child in _dev_card_section.get_children():
		child.queue_free()

	if hand.is_empty():
		_dev_card_section.add_child(_lbl("Cards: none"))
		return

	_dev_card_section.add_child(_lbl("Dev Cards (click to play):"))

	var counts: Dictionary = {}
	for card in hand:
		counts[card] = counts.get(card, 0) + 1

	for card_type in [_DevCards.Type.KNIGHT, _DevCards.Type.ROAD_BUILDING,
			_DevCards.Type.YEAR_OF_PLENTY, _DevCards.Type.MONOPOLY]:
		var count: int = counts.get(card_type, 0)
		if count == 0:
			continue
		var t: int = card_type   # captured by closure
		var btn := Button.new()
		btn.text = "%s ×%d" % [_DevCards.NAMES[card_type], count]
		btn.add_theme_font_size_override("font_size", maxi(11, _font_size - 2))
		btn.custom_minimum_size = Vector2(0, maxi(28, _font_size * 1.9))
		var col: Color = _CARD_COLORS.get(card_type, Color.WHITE)
		btn.modulate = Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, 1.0)
		btn.pressed.connect(func(): play_dev_card_requested.emit(t))
		_dev_card_section.add_child(btn)


func _build_res_picker() -> void:
	_res_picker = PanelContainer.new()
	_res_picker.visible = false
	_res_picker.anchor_left   = 0.25; _res_picker.anchor_right  = 0.95
	_res_picker.anchor_top    = 0.28; _res_picker.anchor_bottom = 0.55
	_res_picker.z_index = 20
	add_child(_res_picker)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_res_picker.add_child(vb)

	var title := _lbl("Choose a resource:")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _font_size + 2)
	vb.add_child(title)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)

	for r in 5:
		var rv: int = r
		var btn := Button.new()
		btn.text = _RES_NAMES[r]
		btn.add_theme_font_size_override("font_size", _font_size)
		btn.custom_minimum_size = Vector2(maxi(60, _font_size * 4), maxi(36, _font_size * 2.5))
		var style := StyleBoxFlat.new()
		style.bg_color = _RES_COLORS[r]
		style.corner_radius_top_left     = 4
		style.corner_radius_top_right    = 4
		style.corner_radius_bottom_left  = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.pressed.connect(func(): _on_res_picker_btn(rv))
		hb.add_child(btn)

	var cancel := _btn("Cancel", func(): _res_picker.visible = false)
	cancel.add_theme_font_size_override("font_size", _font_size)
	vb.add_child(cancel)


func show_resource_picker(mode: String) -> void:
	_res_picker_mode = mode
	_res_picker_sel  = []
	# Update title
	var vb: VBoxContainer = _res_picker.get_child(0)
	var title: Label = vb.get_child(0)
	if mode == "yop":
		title.text = "Year of Plenty — pick 2 resources:"
	else:
		title.text = "Monopoly — pick 1 resource to claim from all:"
	_res_picker.visible = true


func _on_res_picker_btn(res: int) -> void:
	if _res_picker_mode == "mono":
		_res_picker.visible = false
		monopoly_chosen.emit(res)
		return
	# YoP: need 2 picks
	_res_picker_sel.append(res)
	if _res_picker_sel.size() >= 2:
		_res_picker.visible = false
		year_of_plenty_chosen.emit(_res_picker_sel[0], _res_picker_sel[1])
		_res_picker_sel = []
	else:
		var vb: VBoxContainer = _res_picker.get_child(0)
		var title: Label = vb.get_child(0)
		title.text = "Year of Plenty — pick 1 more resource:"


# ---------------------------------------------------------------
# Sprint 2C — Player-to-player trade dialog
# ---------------------------------------------------------------

func _build_trade_dialog() -> void:
	_trade_dialog = PanelContainer.new()
	_trade_dialog.visible = false
	_trade_dialog.anchor_left   = 0.05; _trade_dialog.anchor_right  = 0.95
	_trade_dialog.anchor_top    = 0.12; _trade_dialog.anchor_bottom = 0.88
	_trade_dialog.z_index = 20
	add_child(_trade_dialog)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 10)
	_trade_dialog.add_child(root_vb)

	# Title
	var title := _lbl("Propose Trade")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _font_size + 4)
	root_vb.add_child(title)

	root_vb.add_child(_sep())

	# "I Offer" row
	var offer_lbl := _lbl("I Offer:")
	offer_lbl.add_theme_font_size_override("font_size", _font_size + 1)
	root_vb.add_child(offer_lbl)
	root_vb.add_child(_build_trade_row(true))

	root_vb.add_child(_sep())

	# "I Want" row
	var want_lbl := _lbl("I Want:")
	want_lbl.add_theme_font_size_override("font_size", _font_size + 1)
	root_vb.add_child(want_lbl)
	root_vb.add_child(_build_trade_row(false))

	root_vb.add_child(_sep())

	# Opponent buttons container (populated in _open_trade_dialog)
	var opp_hb := HBoxContainer.new()
	opp_hb.name = "OppButtons"
	opp_hb.add_theme_constant_override("separation", 8)
	opp_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vb.add_child(opp_hb)

	# Cancel
	var cancel := _btn("Cancel", func(): _trade_dialog.visible = false)
	root_vb.add_child(cancel)


func _build_trade_row(is_offer: bool) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	for r in 5:
		var rv: int = r
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		hb.add_child(col)

		# Resource label
		var rl := Label.new()
		rl.text = _RES_SHORT[r]
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.add_theme_font_size_override("font_size", _font_size - 2)
		rl.modulate = _RES_COLORS[r] * 1.6
		col.add_child(rl)

		# Count label
		var cnt := Label.new()
		cnt.text = "0"
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", _font_size + 2)
		col.add_child(cnt)
		if is_offer:
			_trade_offer_labels.append(cnt)
		else:
			_trade_want_labels.append(cnt)

		# + / - buttons
		var pbtn := _btn("+", func(): _trade_adjust(rv, is_offer, 1))
		var mbtn := _btn("-", func(): _trade_adjust(rv, is_offer, -1))
		pbtn.custom_minimum_size = Vector2(32, 28)
		mbtn.custom_minimum_size = Vector2(32, 28)
		col.add_child(pbtn)
		col.add_child(mbtn)

	return hb


func _trade_adjust(res: int, is_offer: bool, delta: int) -> void:
	if is_offer:
		var max_offer: int = _current_player_resources.get(res, 0)
		_trade_offer[res] = clampi(_trade_offer[res] + delta, 0, max_offer)
		_trade_offer_labels[res].text = str(_trade_offer[res])
	else:
		_trade_want[res] = clampi(_trade_want[res] + delta, 0, 9)
		_trade_want_labels[res].text = str(_trade_want[res])


func _open_trade_dialog() -> void:
	# Reset amounts
	for r in 5:
		_trade_offer[r] = 0; _trade_want[r] = 0
		if r < _trade_offer_labels.size():
			_trade_offer_labels[r].text = "0"
		if r < _trade_want_labels.size():
			_trade_want_labels[r].text = "0"

	# Repopulate opponent buttons
	var opp_hb: HBoxContainer = _trade_dialog.get_child(0).get_node("OppButtons")
	for child in opp_hb.get_children():
		child.queue_free()

	for i in _trade_player_count:
		if i == 0:
			continue  # skip self (assume human is player 0)
		var pi: int = i
		var pname: String = _trade_player_names[i] if i < _trade_player_names.size() else ("Player %d" % (i + 1))
		var btn := _btn("Offer to %s" % pname, func(): _propose_to(pi))
		btn.add_theme_font_size_override("font_size", _font_size)
		opp_hb.add_child(btn)

	_trade_dialog.visible = true


func _propose_to(player_idx: int) -> void:
	var offer: Dictionary = {}
	var want: Dictionary  = {}
	for r in 5:
		if _trade_offer[r] > 0:
			offer[r] = _trade_offer[r]
		if _trade_want[r] > 0:
			want[r] = _trade_want[r]
	if offer.is_empty() and want.is_empty():
		return
	_trade_dialog.visible = false
	trade_proposed.emit(offer, want, player_idx)


## Called by main.gd each refresh so the dialog knows current player's resources.
func set_trade_context(player_resources: Dictionary, player_names: Array) -> void:
	_current_player_resources = player_resources
	_trade_player_names        = player_names
	_trade_player_count        = player_names.size()


# ---------------------------------------------------------------
# Public refresh (called by main.gd every state change)
# ---------------------------------------------------------------

func refresh(player, phase_name: String, dice_roll: int, state = null) -> void:
	var tag := " [AI]" if player.is_ai else ""
	_player_label.text     = "%s%s's Turn" % [player.player_name, tag]
	_player_label.modulate = player.color
	_phase_label.text      = "Phase: %s" % phase_name
	_vp_label.text         = "Victory Points: %d" % player.victory_points
	_dice_label.text       = "Dice: %s" % (str(dice_roll) if dice_roll > 0 else "-")

	# 1A: resource cards
	for r in 5:
		var count: int = player.resources.get(r, 0)
		_res_count_labels[r].text = str(count)
		_res_panels[r].modulate   = Color.WHITE if count > 0 else Color(0.55, 0.55, 0.55, 0.75)

	# 1C: dev card hand
	_refresh_dev_cards(player.dev_cards)

	# Bonus VP holders
	if state != null:
		var bonuses: Array = []
		if state.longest_road_holder >= 0:
			bonuses.append("Road: %s" % state.players[state.longest_road_holder].player_name)
		if state.largest_army_holder >= 0:
			bonuses.append("Army: %s" % state.players[state.largest_army_holder].player_name)
		_bonus_label.text = "\n".join(bonuses)
	else:
		_bonus_label.text = ""

	var in_build: bool = (phase_name == "BUILD")
	_roll_btn.disabled  = (phase_name != "ROLL")
	_end_btn.disabled   = (phase_name != "BUILD" and phase_name != "ROBBER")

	# Trade only for human player in BUILD phase with opponents to trade with
	var can_trade: bool = in_build and not player.is_ai and (state != null and state.players.size() > 1)
	_trade_btn.disabled = not can_trade

	var can_buy := in_build
	if can_buy and state != null:
		can_buy = not state.dev_deck.is_empty()
		if can_buy:
			can_buy = (player.resources.get(4, 0) >= 1 and
					   player.resources.get(3, 0) >= 1 and
					   player.resources.get(2, 0) >= 1)
	_buy_card_btn.disabled = not can_buy
	if state != null and state.dev_deck.is_empty():
		_buy_card_btn.text = "Dev Deck Empty"
	else:
		_buy_card_btn.text = "Buy Dev Card"

	# Update trade context
	if state != null:
		var names: Array = []
		for p in state.players:
			names.append(p.player_name)
		set_trade_context(player.resources, names)


func set_message(msg: String) -> void:
	_message_label.text = msg
	print("[HUD] %s" % msg)


# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------

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
	b.custom_minimum_size = Vector2(0, maxi(34, _font_size * 2.4))
	b.pressed.connect(callback)
	return b
