class_name HUDTradeDialog
extends PanelContainer

signal trade_proposed(offer: Dictionary, want: Dictionary, to_player_idx: int)

var _font_size: int = 15
var _res_colors: Array = []
var _res_short: Array = []
var _offer: Array = [0, 0, 0, 0, 0]
var _want: Array = [0, 0, 0, 0, 0]
var _offer_labels: Array = []
var _want_labels: Array = []
var _player_names: Array = []
var _player_count: int = 0
var _current_player_resources: Dictionary = {}
var _source_player_idx: int = 0


func setup(font_size: int, res_colors: Array, res_short: Array) -> void:
	_font_size = font_size
	_res_colors = res_colors
	_res_short = res_short
	visible = false
	anchor_left = 0.05
	anchor_right = 0.95
	anchor_top = 0.12
	anchor_bottom = 0.88
	z_index = 20
	_build_ui()


func set_context(player_resources: Dictionary, player_names: Array, source_player_idx: int = 0) -> void:
	_current_player_resources = player_resources
	_player_names = player_names
	_player_count = player_names.size()
	_source_player_idx = source_player_idx


func open_dialog() -> void:
	for r in 5:
		_offer[r] = 0
		_want[r] = 0
		if r < _offer_labels.size():
			_offer_labels[r].text = "0"
		if r < _want_labels.size():
			_want_labels[r].text = "0"

	var opp_hb: HBoxContainer = get_child(0).get_node("OppButtons")
	for child in opp_hb.get_children():
		child.queue_free()

	for i in _player_count:
		if i == _source_player_idx:
			continue
		var pi: int = i
		var pname: String = _player_names[i] if i < _player_names.size() else ("Player %d" % (i + 1))
		var btn := _btn("Offer to %s" % pname, func(): _emit_trade(pi))
		btn.add_theme_font_size_override("font_size", _font_size)
		opp_hb.add_child(btn)

	visible = true


func _build_ui() -> void:
	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 10)
	add_child(root_vb)

	var title := _lbl("Propose Trade")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _font_size + 4)
	root_vb.add_child(title)
	root_vb.add_child(HSeparator.new())

	var offer_lbl := _lbl("I Offer:")
	offer_lbl.add_theme_font_size_override("font_size", _font_size + 1)
	root_vb.add_child(offer_lbl)
	root_vb.add_child(_build_trade_row(true))

	root_vb.add_child(HSeparator.new())

	var want_lbl := _lbl("I Want:")
	want_lbl.add_theme_font_size_override("font_size", _font_size + 1)
	root_vb.add_child(want_lbl)
	root_vb.add_child(_build_trade_row(false))

	root_vb.add_child(HSeparator.new())

	var opp_hb := HBoxContainer.new()
	opp_hb.name = "OppButtons"
	opp_hb.add_theme_constant_override("separation", 8)
	opp_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vb.add_child(opp_hb)

	root_vb.add_child(_btn("Cancel", func(): visible = false))


func _build_trade_row(is_offer: bool) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	for r in 5:
		var rv: int = r
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		hb.add_child(col)

		var rl := Label.new()
		rl.text = _res_short[r]
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.add_theme_font_size_override("font_size", _font_size - 2)
		rl.modulate = _res_colors[r] * 1.6
		col.add_child(rl)

		var cnt := Label.new()
		cnt.text = "0"
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", _font_size + 2)
		col.add_child(cnt)
		if is_offer:
			_offer_labels.append(cnt)
		else:
			_want_labels.append(cnt)

		var pbtn := _btn("+", func(): _adjust(rv, is_offer, 1))
		var mbtn := _btn("-", func(): _adjust(rv, is_offer, -1))
		pbtn.custom_minimum_size = Vector2(32, 28)
		mbtn.custom_minimum_size = Vector2(32, 28)
		col.add_child(pbtn)
		col.add_child(mbtn)

	return hb


func _adjust(res: int, is_offer: bool, delta: int) -> void:
	if is_offer:
		var max_offer: int = _current_player_resources.get(res, 0)
		_offer[res] = clampi(_offer[res] + delta, 0, max_offer)
		_offer_labels[res].text = str(_offer[res])
	else:
		_want[res] = clampi(_want[res] + delta, 0, 9)
		_want_labels[res].text = str(_want[res])


func _emit_trade(player_idx: int) -> void:
	var offer: Dictionary = {}
	var want: Dictionary = {}
	for r in 5:
		if _offer[r] > 0:
			offer[r] = _offer[r]
		if _want[r] > 0:
			want[r] = _want[r]
	if offer.is_empty() and want.is_empty():
		return
	visible = false
	trade_proposed.emit(offer, want, player_idx)


func _lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", _font_size)
	b.custom_minimum_size = Vector2(0, maxi(34, _font_size * 2.4))
	b.add_theme_stylebox_override("normal", _button_style(Color(0.18, 0.22, 0.28), Color(0.36, 0.43, 0.52)))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.29, 0.36), Color(0.52, 0.60, 0.72)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.12, 0.15, 0.20), Color(0.62, 0.69, 0.78)))
	b.add_theme_stylebox_override("disabled", _button_style(Color(0.11, 0.13, 0.16, 0.92), Color(0.20, 0.23, 0.27)))
	b.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	b.add_theme_color_override("font_disabled_color", Color(0.48, 0.52, 0.58))
	b.pressed.connect(callback)
	return b


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
