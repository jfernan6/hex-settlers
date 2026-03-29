class_name HUDCardTable
extends Control

const PlayerData = preload("res://scripts/player/player.gd")
const DevCards = preload("res://scripts/game/dev_cards.gd")
const HUDResourceCard = preload("res://scripts/ui/hud_resource_card.gd")
const HUDDevCard = preload("res://scripts/ui/hud_dev_card.gd")

signal roll_dice_pressed
signal end_turn_pressed
signal buy_dev_card_pressed
signal propose_trade_pressed
signal play_dev_card_requested(card_type: int)
signal layout_metrics_changed(insets: Dictionary)

const _RESOURCE_ORDER := [
	PlayerData.RES_LUMBER,
	PlayerData.RES_BRICK,
	PlayerData.RES_WOOL,
	PlayerData.RES_GRAIN,
	PlayerData.RES_ORE,
]

const _DEV_ORDER := [
	DevCards.Type.KNIGHT,
	DevCards.Type.ROAD_BUILDING,
	DevCards.Type.YEAR_OF_PLENTY,
	DevCards.Type.MONOPOLY,
	DevCards.Type.VP,
]

const _ACTIVITY_LIMIT := 4

var _font_size: int = 15
var _opponents_face_up: bool = true

var _player_rail: PanelContainer
var _player_rail_box: VBoxContainer

var _utility_bar: PanelContainer
var _bank_summary_chip: PanelContainer
var _bank_summary_label: Label
var _dev_summary_chip: PanelContainer
var _dev_summary_label: Label
var _table_btn: Button

var _ribbon_panel: PanelContainer
var _local_name_label: Label
var _local_meta_label: Label
var _turn_label: Label
var _phase_badge: Label
var _dice_badge: Label
var _prompt_label: Label
var _hand_btn: Button
var _roll_btn: Button
var _buy_dev_btn: Button
var _trade_btn: Button
var _end_btn: Button
var _ribbon_status_row: HBoxContainer
var _ribbon_resource_strip: HBoxContainer
var _ribbon_resource_nodes: Dictionary = {}
var _ribbon_resource_count_labels: Dictionary = {}
var _ribbon_dev_chip: PanelContainer
var _ribbon_dev_label: Label
var _ribbon_played_chip: PanelContainer
var _ribbon_played_label: Label

var _inspect_panel: PanelContainer
var _inspect_title: Label
var _inspect_meta: Label
var _inspect_note: Label
var _inspect_resource_label: Label
var _inspect_resource_row: HBoxContainer
var _inspect_dev_label: Label
var _inspect_dev_row: FlowContainer
var _inspect_revealed_label: Label
var _inspect_revealed_row: FlowContainer
var _inspect_close_btn: Button

var _table_panel: PanelContainer
var _table_meta: Label
var _table_bank_row: HBoxContainer
var _table_dev_row: FlowContainer
var _table_revealed_label: Label
var _table_feed_labels: Array = []
var _table_close_btn: Button

var _local_player_index: int = -1
var _selected_player_index: int = -1
var _table_overlay_open: bool = false
var _last_state = null
var _last_turn_index: int = -1
var _last_phase_name: String = ""
var _last_activity_entries: Array = []
var _persistent_safe_insets := {
	"left": 0.0,
	"top": 0.0,
	"right": 0.0,
	"bottom": 0.0,
}


func setup(font_size: int) -> void:
	_font_size = font_size
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_layout_panels()


func set_ai_face_up(face_up: bool) -> void:
	_opponents_face_up = face_up
	_refresh_inspect_overlay()


func get_persistent_safe_insets() -> Dictionary:
	return _persistent_safe_insets.duplicate(true)


func refresh(state, turn_player, phase_name: String, dice_roll: int, phase_ui: Dictionary,
		activity_entries: Array, prompt_text: String, result_text: String, result_tone: String) -> void:
	if state == null:
		return
	_last_state = state
	_last_turn_index = state.current_player_index
	_last_phase_name = phase_name
	_last_activity_entries = activity_entries.duplicate(true)
	_local_player_index = _find_local_player_index(state, state.current_player_index)
	if _selected_player_index >= state.players.size():
		_selected_player_index = -1

	_layout_panels()
	_refresh_player_rail(state)
	_refresh_utility_bar(state)
	_refresh_ribbon(state, turn_player, phase_name, dice_roll, phase_ui, prompt_text, result_text, result_tone)
	_refresh_inspect_overlay()
	_refresh_table_overlay()


func get_resource_target_center(resource: int) -> Vector2:
	var chip: Control = _ribbon_resource_nodes.get(resource)
	if chip == null:
		return get_viewport().get_visible_rect().size * 0.5
	return chip.get_global_rect().get_center()


func pulse_resource_target(resource: int) -> void:
	var chip: Control = _ribbon_resource_nodes.get(resource)
	if chip == null:
		return
	chip.pivot_offset = chip.size * 0.5
	chip.scale = Vector2.ONE
	chip.modulate = Color.WHITE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(chip, "scale", Vector2(1.12, 1.12), 0.12)
	tween.tween_property(chip, "modulate", Color(1.12, 1.12, 1.12, 1.0), 0.12)
	tween.chain().set_parallel(true)
	tween.tween_property(chip, "scale", Vector2.ONE, 0.22)
	tween.tween_property(chip, "modulate", Color.WHITE, 0.22)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_panels()


func _build_ui() -> void:
	_player_rail = PanelContainer.new()
	_player_rail.add_theme_stylebox_override("panel", _panel_style(0.74))
	add_child(_player_rail)
	var rail_margin := _margin(10)
	_player_rail.add_child(rail_margin)
	_player_rail_box = VBoxContainer.new()
	_player_rail_box.add_theme_constant_override("separation", 10)
	rail_margin.add_child(_player_rail_box)

	_utility_bar = PanelContainer.new()
	_utility_bar.add_theme_stylebox_override("panel", _panel_style(0.66))
	add_child(_utility_bar)
	_build_utility_bar()

	_ribbon_panel = PanelContainer.new()
	_ribbon_panel.add_theme_stylebox_override("panel", _panel_style(0.86))
	add_child(_ribbon_panel)
	_build_ribbon()

	_inspect_panel = PanelContainer.new()
	_inspect_panel.visible = false
	_inspect_panel.add_theme_stylebox_override("panel", _panel_style(0.90))
	_inspect_panel.z_index = 20
	add_child(_inspect_panel)
	_build_inspect_panel()

	_table_panel = PanelContainer.new()
	_table_panel.visible = false
	_table_panel.add_theme_stylebox_override("panel", _panel_style(0.92))
	_table_panel.z_index = 20
	add_child(_table_panel)
	_build_table_overlay()


func _layout_panels() -> void:
	var vp := Vector2(DisplayServer.window_get_size())
	if get_viewport() != null:
		vp = get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return

	var rail_width := clampf(vp.x * 0.12, 142.0, 170.0)
	var player_slots: int = _last_state.players.size() if _last_state != null else 2
	var rail_height := clampf(20.0 + player_slots * 84.0 + maxi(0, player_slots - 1) * 10.0, 180.0, vp.y - 140.0)
	_player_rail.position = Vector2(14.0, 78.0)
	_player_rail.size = Vector2(rail_width, rail_height)

	var utility_width := clampf(vp.x * 0.22, 224.0, 320.0)
	_utility_bar.position = Vector2(vp.x - utility_width - 16.0, 16.0)
	_utility_bar.size = Vector2(utility_width, 52.0)

	var ribbon_left := _player_rail.position.x + _player_rail.size.x + 18.0
	var ribbon_right := 16.0
	var show_status_strip := false
	if _last_state != null and _local_player_index >= 0:
		show_status_strip = _show_ribbon_status_strip(_last_phase_name, _last_state.get_player(_local_player_index))
	var ribbon_height := 84.0 if show_status_strip else 56.0
	_ribbon_panel.position = Vector2(ribbon_left, vp.y - ribbon_height - 12.0)
	_ribbon_panel.size = Vector2(maxf(680.0, vp.x - ribbon_left - ribbon_right), ribbon_height)

	var inspect_width := clampf(vp.x * 0.54, 620.0, 820.0)
	var inspect_height := 0.0
	if _selected_player_index >= 0 and _last_state != null:
		var selected = _last_state.get_player(_selected_player_index)
		if selected != null:
			inspect_height = _inspect_height_for_player(selected)
	if inspect_height <= 0.0:
		inspect_height = clampf(vp.y * 0.28, 220.0, 320.0)
	var inspect_x := clampf(vp.x - inspect_width - 34.0, ribbon_left, vp.x - inspect_width - 16.0)
	var inspect_y := _ribbon_panel.position.y - inspect_height - 12.0
	_inspect_panel.position = Vector2(inspect_x, maxf(88.0, inspect_y))
	_inspect_panel.size = Vector2(inspect_width, inspect_height)

	var table_width := clampf(vp.x * 0.40, 500.0, 660.0)
	var table_height := clampf(vp.y * 0.52, 360.0, 520.0)
	_table_panel.position = Vector2(vp.x - table_width - 18.0, 84.0)
	_table_panel.size = Vector2(table_width, table_height)
	_update_layout_metrics(vp)


func _build_utility_bar() -> void:
	var margin := _margin(10)
	_utility_bar.add_child(margin)
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 8)
	margin.add_child(hb)

	_bank_summary_chip = _summary_chip("Bank", Color(0.30, 0.39, 0.26))
	_bank_summary_label = _chip_value_label(_bank_summary_chip)
	hb.add_child(_bank_summary_chip)

	_dev_summary_chip = _summary_chip("Dev", Color(0.34, 0.27, 0.18))
	_dev_summary_label = _chip_value_label(_dev_summary_chip)
	hb.add_child(_dev_summary_chip)

	_table_btn = _utility_button("Table", func() -> void:
		_table_overlay_open = not _table_overlay_open
		if _last_state != null:
			_refresh_utility_bar(_last_state)
		_refresh_table_overlay()
	)
	hb.add_child(_table_btn)


func _build_ribbon() -> void:
	var margin := _margin(8)
	_ribbon_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vb.add_child(top)

	var local_box := VBoxContainer.new()
	local_box.custom_minimum_size = Vector2(168.0, 0.0)
	local_box.add_theme_constant_override("separation", 2)
	top.add_child(local_box)

	_local_name_label = _headline("Player 1")
	_local_name_label.add_theme_font_size_override("font_size", _font_size + 1)
	local_box.add_child(_local_name_label)

	_local_meta_label = _muted_label("VP 0  |  Res 0  |  Dev 0")
	local_box.add_child(_local_meta_label)

	var center_box := VBoxContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.add_theme_constant_override("separation", 3)
	top.add_child(center_box)

	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 8)
	center_box.add_child(turn_row)

	_turn_label = _headline("Player 1's Turn")
	_turn_label.add_theme_font_size_override("font_size", _font_size)
	turn_row.add_child(_turn_label)

	_phase_badge = _capsule("ROLL")
	turn_row.add_child(_phase_badge)

	_dice_badge = _capsule("Dice -")
	turn_row.add_child(_dice_badge)

	_prompt_label = _muted_label("")
	_prompt_label.add_theme_font_size_override("font_size", maxi(10, _font_size - 3))
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt_label.clip_text = true
	center_box.add_child(_prompt_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	top.add_child(action_row)

	_hand_btn = _action_button("Hand", func() -> void:
		_toggle_player_overlay(_local_player_index)
	)
	action_row.add_child(_hand_btn)

	_roll_btn = _action_button("Roll", func() -> void:
		roll_dice_pressed.emit()
	)
	action_row.add_child(_roll_btn)

	_buy_dev_btn = _action_button("Buy Dev", func() -> void:
		buy_dev_card_pressed.emit()
	)
	action_row.add_child(_buy_dev_btn)

	_trade_btn = _action_button("Trade", func() -> void:
		propose_trade_pressed.emit()
	)
	action_row.add_child(_trade_btn)

	_end_btn = _action_button("End", func() -> void:
		end_turn_pressed.emit()
	)
	action_row.add_child(_end_btn)

	_ribbon_status_row = HBoxContainer.new()
	_ribbon_status_row.add_theme_constant_override("separation", 8)
	vb.add_child(_ribbon_status_row)

	_ribbon_resource_strip = HBoxContainer.new()
	_ribbon_resource_strip.add_theme_constant_override("separation", 5)
	_ribbon_resource_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ribbon_status_row.add_child(_ribbon_resource_strip)

	for resource in _RESOURCE_ORDER:
		var chip := _resource_chip(resource)
		_ribbon_resource_strip.add_child(chip)
		_ribbon_resource_nodes[resource] = chip

	_ribbon_dev_chip = _summary_chip("Dev", Color(0.46, 0.28, 0.18))
	_ribbon_dev_label = _chip_value_label(_ribbon_dev_chip)
	_ribbon_resource_strip.add_child(_ribbon_dev_chip)

	_ribbon_played_chip = _summary_chip("Play", Color(0.23, 0.32, 0.42))
	_ribbon_played_label = _chip_value_label(_ribbon_played_chip)
	_ribbon_resource_strip.add_child(_ribbon_played_chip)


func _build_inspect_panel() -> void:
	var margin := _margin(14)
	_inspect_panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vb.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	_inspect_title = _headline("Hand View")
	title_box.add_child(_inspect_title)

	_inspect_meta = _muted_label("")
	title_box.add_child(_inspect_meta)

	_inspect_close_btn = _action_button("Close", func() -> void:
		_selected_player_index = -1
		_layout_panels()
		_refresh_inspect_overlay()
		if _last_state != null:
			_refresh_player_rail(_last_state)
	)
	header.add_child(_inspect_close_btn)

	_inspect_note = _muted_label("")
	_inspect_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_inspect_note)

	_inspect_resource_label = _section_label("Resources")
	vb.add_child(_inspect_resource_label)
	_inspect_resource_row = HBoxContainer.new()
	_inspect_resource_row.add_theme_constant_override("separation", 8)
	vb.add_child(_inspect_resource_row)

	_inspect_dev_label = _section_label("Development Cards")
	vb.add_child(_inspect_dev_label)
	_inspect_dev_row = FlowContainer.new()
	_inspect_dev_row.add_theme_constant_override("h_separation", 8)
	_inspect_dev_row.add_theme_constant_override("v_separation", 8)
	vb.add_child(_inspect_dev_row)

	_inspect_revealed_label = _section_label("Played / Revealed")
	vb.add_child(_inspect_revealed_label)
	_inspect_revealed_row = FlowContainer.new()
	_inspect_revealed_row.add_theme_constant_override("h_separation", 8)
	_inspect_revealed_row.add_theme_constant_override("v_separation", 8)
	vb.add_child(_inspect_revealed_row)


func _build_table_overlay() -> void:
	var margin := _margin(14)
	_table_panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vb.add_child(header)

	var title := _headline("Table Info")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_table_close_btn = _action_button("Close", func() -> void:
		_table_overlay_open = false
		if _last_state != null:
			_refresh_utility_bar(_last_state)
		_refresh_table_overlay()
	)
	header.add_child(_table_close_btn)

	_table_meta = _muted_label("")
	_table_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_table_meta)

	vb.add_child(_section_label("Resource Bank"))
	_table_bank_row = HBoxContainer.new()
	_table_bank_row.add_theme_constant_override("separation", 8)
	vb.add_child(_table_bank_row)

	vb.add_child(_section_label("Dev Deck Remaining"))
	_table_dev_row = FlowContainer.new()
	_table_dev_row.add_theme_constant_override("h_separation", 8)
	_table_dev_row.add_theme_constant_override("v_separation", 8)
	vb.add_child(_table_dev_row)

	_table_revealed_label = _muted_label("")
	_table_revealed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_table_revealed_label)

	vb.add_child(_section_label("Recent Actions"))
	for _i in range(_ACTIVITY_LIMIT):
		var row := _muted_label("")
		row.visible = false
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(row)
		_table_feed_labels.append(row)


func _refresh_player_rail(state) -> void:
	for child in _player_rail_box.get_children():
		_player_rail_box.remove_child(child)
		child.queue_free()

	for i in range(state.players.size()):
		var idx: int = i
		var player = state.players[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 84.0)
		button.text = _player_card_text(state, idx)
		button.add_theme_font_size_override("font_size", maxi(10, _font_size - 4))
		button.add_theme_stylebox_override("normal", _player_card_style(player.color,
			idx == state.current_player_index, idx == _local_player_index, idx == _selected_player_index))
		button.add_theme_stylebox_override("hover", _player_card_style(player.color.lightened(0.10),
			idx == state.current_player_index, idx == _local_player_index, true))
		button.add_theme_stylebox_override("pressed", _player_card_style(player.color.darkened(0.10),
			true, idx == _local_player_index, true))
		button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
		button.pressed.connect(func() -> void:
			_toggle_player_overlay(idx)
		)
		_player_rail_box.add_child(button)


func _refresh_utility_bar(state) -> void:
	_bank_summary_label.text = str(_bank_total(state.get_resource_bank_view()))
	var dev_supply: Dictionary = state.get_dev_supply_view()
	_dev_summary_label.text = str(int(dev_supply.get("remaining_total", 0)))
	_table_btn.text = "Table" if not _table_overlay_open else "Hide"


func _refresh_ribbon(state, turn_player, phase_name: String, dice_roll: int, phase_ui: Dictionary,
		prompt_text: String, result_text: String, result_tone: String) -> void:
	var local_player = state.get_player(_local_player_index)
	if local_player == null:
		return

	var local_dev_cards: Array = state.get_dev_hand_view(_local_player_index)
	var local_revealed_cards: Array = state.get_revealed_dev_hand_view(_local_player_index)
	var is_local_turn: bool = (_local_player_index == state.current_player_index and not local_player.is_ai)
	var show_status_strip := _show_ribbon_status_strip(phase_name, local_player)

	_local_name_label.text = "%s%s" % [local_player.player_name, "  YOU" if not local_player.is_ai else ""]
	_local_name_label.modulate = local_player.color
	_local_meta_label.text = "VP %d  |  Res %d  |  Dev %d%s" % [
		local_player.victory_points,
		_resource_total(local_player),
		local_player.dev_cards.size(),
		_player_bonus_suffix(state, _local_player_index),
	]

	_turn_label.text = "%s's Turn" % turn_player.player_name
	_turn_label.modulate = turn_player.color
	_phase_badge.text = str(phase_ui.get("badge_text", phase_name))
	_phase_badge.add_theme_stylebox_override("normal",
		_capsule_style(phase_ui.get("badge_color", Color(0.72, 0.76, 0.82))))
	_dice_badge.text = "Dice %s" % (str(dice_roll) if dice_roll > 0 else "-")

	var using_result := result_text.strip_edges() != ""
	_prompt_label.text = result_text if using_result else prompt_text
	_prompt_label.modulate = _activity_color(result_tone) if using_result else Color(0.72, 0.77, 0.82)
	var status_visibility_changed := _ribbon_status_row.visible != show_status_strip
	_ribbon_status_row.visible = show_status_strip

	for resource in _RESOURCE_ORDER:
		var chip: PanelContainer = _ribbon_resource_nodes.get(resource)
		var count_label: Label = _ribbon_resource_count_labels.get(resource)
		var count: int = int(local_player.resources.get(resource, 0))
		if count_label != null:
			count_label.text = "%d" % count
		if chip != null:
			chip.modulate = Color(1, 1, 1, 0.42) if count <= 0 else Color.WHITE

	_ribbon_dev_label.text = "%d" % local_player.dev_cards.size()
	_ribbon_played_label.text = "%d" % local_player.revealed_dev_cards.size()

	_hand_btn.visible = true
	_hand_btn.text = "Hand"
	_roll_btn.visible = is_local_turn and phase_name == "ROLL"
	_trade_btn.visible = is_local_turn and phase_name == "BUILD" and state.players.size() > 1
	_end_btn.visible = is_local_turn and phase_name == "BUILD"
	_buy_dev_btn.visible = is_local_turn and phase_name == "BUILD" and not state.dev_deck.is_empty()
	_buy_dev_btn.disabled = not state.can_buy_dev_card_for(_local_player_index)
	_trade_btn.disabled = false
	_roll_btn.disabled = false
	_end_btn.disabled = false

	if not _buy_dev_btn.visible:
		_buy_dev_btn.disabled = true

	_hand_btn.text = "Hide" if _selected_player_index == _local_player_index else "Hand"
	_ribbon_dev_chip.visible = not local_dev_cards.is_empty() or not local_revealed_cards.is_empty()
	_ribbon_played_chip.visible = not local_revealed_cards.is_empty()

	if status_visibility_changed:
		_layout_panels()


func _refresh_inspect_overlay() -> void:
	if _last_state == null or _selected_player_index < 0:
		_inspect_panel.visible = false
		return
	var player = _last_state.get_player(_selected_player_index)
	if player == null:
		_inspect_panel.visible = false
		return

	var is_local: bool = (_selected_player_index == _local_player_index)
	var interactive_dev: bool = is_local and _last_phase_name == "BUILD" and _last_turn_index == _local_player_index
	var face_down: bool = (not is_local and not _opponents_face_up)
	var dev_cards: Array = _last_state.get_dev_hand_view(_selected_player_index)
	var revealed_cards: Array = _last_state.get_revealed_dev_hand_view(_selected_player_index)

	_inspect_panel.visible = true
	_inspect_title.text = "%s Hand" % player.player_name
	_inspect_title.modulate = player.color
	_inspect_meta.text = "VP %d  |  Res %d  |  Dev %d  |  Played %d%s" % [
		player.victory_points,
		_resource_total(player),
		player.dev_cards.size(),
		player.revealed_dev_cards.size(),
		_player_bonus_suffix(_last_state, _selected_player_index),
	]
	if is_local:
		_inspect_note.text = "Open hand view. Dev cards are clickable during your build phase."
	else:
		_inspect_note.text = "Visible opponent hand." if _opponents_face_up else "Hidden opponent hand."

	_rebuild_resource_cards(_inspect_resource_row,
		_last_state.get_resource_hand_view(_selected_player_index), face_down)
	_rebuild_dev_row(_inspect_dev_row, dev_cards, interactive_dev, interactive_dev, face_down, Vector2(72.0, 102.0))
	_rebuild_dev_row(_inspect_revealed_row, revealed_cards, false, false, false, Vector2(68.0, 98.0))
	_inspect_dev_label.visible = not dev_cards.is_empty()
	_inspect_dev_row.visible = not dev_cards.is_empty()
	_inspect_revealed_label.visible = not revealed_cards.is_empty()
	_inspect_revealed_row.visible = not revealed_cards.is_empty()


func _refresh_table_overlay() -> void:
	_table_panel.visible = _table_overlay_open
	if not _table_overlay_open or _last_state == null:
		return

	var bank_view: Dictionary = _last_state.get_resource_bank_view()
	var dev_supply: Dictionary = _last_state.get_dev_supply_view()
	_table_meta.text = "%d resource cards in bank  |  %d dev cards left in deck" % [
		_bank_total(bank_view),
		int(dev_supply.get("remaining_total", 0)),
	]
	_rebuild_resource_bank_row(_table_bank_row, bank_view)
	_rebuild_dev_row(_table_dev_row, _grouped_dev_counts(dev_supply.get("remaining_counts", {})),
		false, false, false, Vector2(58.0, 84.0))
	_table_revealed_label.text = "Played / revealed: %s" % _format_dev_counts(dev_supply.get("revealed_counts", {}))

	for i in range(_table_feed_labels.size()):
		var row: Label = _table_feed_labels[i]
		if i >= _last_activity_entries.size():
			row.visible = false
			row.text = ""
			continue
		var entry: Dictionary = _last_activity_entries[i]
		row.visible = true
		row.text = "• %s" % str(entry.get("text", ""))
		row.modulate = _activity_color(str(entry.get("tone", "info")))


func _toggle_player_overlay(player_idx: int) -> void:
	if player_idx < 0:
		return
	if _selected_player_index == player_idx:
		_selected_player_index = -1
	else:
		_selected_player_index = player_idx
	_layout_panels()
	_refresh_inspect_overlay()
	if _last_state != null:
		_refresh_player_rail(_last_state)


func _rebuild_resource_cards(row: HBoxContainer, view: Array, face_down: bool) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()

	for entry in view:
		var resource: int = int(entry.get("resource", 0))
		var count: int = int(entry.get("count", 0))
		var card := HUDResourceCard.new()
		card.setup(resource, maxi(11, _font_size - 4), face_down, true)
		card.custom_minimum_size = Vector2(72.0, 100.0)
		card.set_count(count)
		card.set_dimmed(count <= 0)
		row.add_child(card)


func _rebuild_resource_bank_row(row: HBoxContainer, bank_view: Dictionary) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()

	for resource in _RESOURCE_ORDER:
		var card := HUDResourceCard.new()
		card.setup(resource, maxi(11, _font_size - 4), false, true)
		card.custom_minimum_size = Vector2(70.0, 98.0)
		var remaining: int = int(bank_view.get(resource, 0))
		card.set_count(remaining)
		card.set_dimmed(remaining <= 0)
		row.add_child(card)


func _rebuild_dev_row(row: Control, cards: Array, interactive: bool, enabled: bool,
		face_down: bool, card_size: Vector2) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()

	if cards.is_empty():
		return

	for entry in cards:
		var card_type: int = int(entry.get("card_type", DevCards.Type.KNIGHT))
		var count: int = int(entry.get("count", 0))
		if count <= 0:
			continue

		if interactive:
			var t := card_type
			var button := Button.new()
			button.flat = true
			button.focus_mode = Control.FOCUS_NONE
			button.disabled = not enabled
			button.custom_minimum_size = card_size
			button.add_theme_stylebox_override("normal", _clear_button_style())
			button.add_theme_stylebox_override("hover", _clear_button_style())
			button.add_theme_stylebox_override("pressed", _clear_button_style())
			button.add_theme_stylebox_override("disabled", _clear_button_style())
			var active_card := HUDDevCard.new()
			active_card.setup(card_type, maxi(11, _font_size - 4), true, false)
			active_card.custom_minimum_size = card_size
			active_card.anchor_right = 1.0
			active_card.anchor_bottom = 1.0
			active_card.set_count(count)
			active_card.set_dimmed(not enabled)
			active_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(active_card)
			button.pressed.connect(func() -> void:
				play_dev_card_requested.emit(t)
			)
			row.add_child(button)
			continue

		var display_card := HUDDevCard.new()
		display_card.setup(card_type, maxi(10, _font_size - 5), true, face_down)
		display_card.custom_minimum_size = card_size
		display_card.set_count(count)
		display_card.set_dimmed(count <= 0)
		row.add_child(display_card)


func _grouped_dev_counts(counts: Dictionary) -> Array:
	var view: Array = []
	for card_type in _DEV_ORDER:
		var count: int = int(counts.get(card_type, 0))
		if count <= 0:
			continue
		view.append({
			"card_type": card_type,
			"count": count,
		})
	return view


func _show_ribbon_status_strip(phase_name: String, local_player) -> bool:
	if local_player == null:
		return false
	if phase_name == "ROLL" or phase_name == "BUILD":
		return true
	return _resource_total(local_player) > 0 or not local_player.dev_cards.is_empty() or not local_player.revealed_dev_cards.is_empty()


func _find_local_player_index(state, fallback_idx: int) -> int:
	for i in range(state.players.size()):
		if not state.players[i].is_ai:
			return i
	return fallback_idx


func _resource_total(player) -> int:
	var total := 0
	for resource in _RESOURCE_ORDER:
		total += int(player.resources.get(resource, 0))
	return total


func _update_layout_metrics(vp: Vector2) -> void:
	var next_insets := {
		"left": clampf(_player_rail.position.x + _player_rail.size.x + 18.0, 0.0, vp.x * 0.42),
		"top": clampf(_utility_bar.position.y + _utility_bar.size.y + 16.0, 0.0, vp.y * 0.24),
		"right": 20.0,
		"bottom": clampf(vp.y - _ribbon_panel.position.y + 24.0, 0.0, vp.y * 0.44),
	}
	if _layout_metrics_match(next_insets, _persistent_safe_insets):
		_persistent_safe_insets = next_insets
		return
	_persistent_safe_insets = next_insets
	layout_metrics_changed.emit(get_persistent_safe_insets())


func _layout_metrics_match(a: Dictionary, b: Dictionary) -> bool:
	return (
		absf(float(a.get("left", 0.0)) - float(b.get("left", 0.0))) < 0.5 and
		absf(float(a.get("top", 0.0)) - float(b.get("top", 0.0))) < 0.5 and
		absf(float(a.get("right", 0.0)) - float(b.get("right", 0.0))) < 0.5 and
		absf(float(a.get("bottom", 0.0)) - float(b.get("bottom", 0.0))) < 0.5
	)


func _inspect_height_for_player(player) -> float:
	var height := 212.0
	if not player.dev_cards.is_empty():
		height += 74.0
	if not player.revealed_dev_cards.is_empty():
		height += 70.0
	return height


func _player_card_text(state, player_idx: int) -> String:
	var player = state.get_player(player_idx)
	if player == null:
		return ""
	var flags: Array[String] = []
	if player_idx == _local_player_index:
		flags.append("YOU")
	if player_idx == state.current_player_index:
		flags.append("TURN")
	if state.longest_road_holder == player_idx:
		flags.append("ROAD")
	if state.largest_army_holder == player_idx:
		flags.append("ARMY")
	var flag_text := "  •  ".join(flags)
	return "%s\nVP %d  |  Res %d  |  Dev %d%s" % [
		player.player_name,
		player.victory_points,
		_resource_total(player),
		player.dev_cards.size(),
		"\n%s" % flag_text if flag_text != "" else "",
	]


func _player_bonus_suffix(state, player_idx: int) -> String:
	var flags: Array[String] = []
	if state.longest_road_holder == player_idx:
		flags.append("Road")
	if state.largest_army_holder == player_idx:
		flags.append("Army")
	return "" if flags.is_empty() else "  |  %s" % "/".join(flags)


func _bank_total(bank_view: Dictionary) -> int:
	var total := 0
	for resource in _RESOURCE_ORDER:
		total += int(bank_view.get(resource, 0))
	return total


func _format_dev_counts(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for card_type in _DEV_ORDER:
		var count: int = int(counts.get(card_type, 0))
		if count <= 0:
			continue
		parts.append("%s×%d" % [_dev_short_name(card_type), count])
	return ", ".join(parts) if not parts.is_empty() else "None"


func _dev_short_name(card_type: int) -> String:
	match card_type:
		DevCards.Type.KNIGHT:
			return "KN"
		DevCards.Type.ROAD_BUILDING:
			return "RB"
		DevCards.Type.YEAR_OF_PLENTY:
			return "YP"
		DevCards.Type.MONOPOLY:
			return "MO"
		DevCards.Type.VP:
			return "VP"
		_:
			return "?"


func _resource_chip(resource: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(54.0, 30.0)
	chip.add_theme_stylebox_override("panel", _summary_chip_style(_resource_accent(resource)))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(hb)

	var short := Label.new()
	short.text = _resource_short(resource)
	short.add_theme_font_size_override("font_size", maxi(9, _font_size - 8))
	short.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	hb.add_child(short)

	var count := Label.new()
	count.text = "0"
	count.add_theme_font_size_override("font_size", maxi(10, _font_size - 6))
	count.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	hb.add_child(count)
	_ribbon_resource_count_labels[resource] = count
	return chip


func _summary_chip(title: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(58.0, 30.0)
	chip.add_theme_stylebox_override("panel", _summary_chip_style(accent))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(hb)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", maxi(9, _font_size - 8))
	title_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	hb.add_child(title_label)
	var value_label := Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", maxi(10, _font_size - 6))
	value_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	hb.add_child(value_label)
	return chip


func _chip_value_label(chip: PanelContainer) -> Label:
	var hb: HBoxContainer = chip.get_child(0)
	return hb.get_child(1)


func _resource_short(resource: int) -> String:
	match resource:
		PlayerData.RES_LUMBER:
			return "LU"
		PlayerData.RES_BRICK:
			return "BR"
		PlayerData.RES_WOOL:
			return "WO"
		PlayerData.RES_GRAIN:
			return "GR"
		PlayerData.RES_ORE:
			return "OR"
		_:
			return "?"


func _resource_accent(resource: int) -> Color:
	match resource:
		PlayerData.RES_LUMBER:
			return Color(0.18, 0.43, 0.22)
		PlayerData.RES_BRICK:
			return Color(0.64, 0.22, 0.12)
		PlayerData.RES_WOOL:
			return Color(0.36, 0.60, 0.25)
		PlayerData.RES_GRAIN:
			return Color(0.78, 0.63, 0.14)
		PlayerData.RES_ORE:
			return Color(0.40, 0.45, 0.58)
		_:
			return Color(0.34, 0.38, 0.45)


func _activity_color(tone: String) -> Color:
	match tone:
		"success":
			return Color(0.72, 0.92, 0.72)
		"warn":
			return Color(0.98, 0.76, 0.48)
		"error":
			return Color(0.98, 0.58, 0.52)
		_:
			return Color(0.80, 0.84, 0.90)


func _margin(amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	return margin


func _headline(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _font_size + 2)
	label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.90))
	return label


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(11, _font_size - 3))
	label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	return label


func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(10, _font_size - 4))
	label.add_theme_color_override("font_color", Color(0.72, 0.77, 0.82))
	return label


func _capsule(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(10, _font_size - 5))
	label.add_theme_color_override("font_color", Color(0.12, 0.14, 0.18))
	label.add_theme_stylebox_override("normal", _capsule_style(Color(0.87, 0.88, 0.91)))
	return label


func _action_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(68.0, 28.0)
	button.add_theme_font_size_override("font_size", maxi(10, _font_size - 6))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.17, 0.21, 0.27), Color(0.34, 0.42, 0.51)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.23, 0.28, 0.34), Color(0.50, 0.59, 0.70)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.12, 0.15, 0.20), Color(0.60, 0.68, 0.78)))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.10, 0.12, 0.16, 0.90), Color(0.20, 0.23, 0.28)))
	button.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.52, 0.58))
	button.pressed.connect(callback)
	return button


func _utility_button(text: String, callback: Callable) -> Button:
	var button := _action_button(text, callback)
	button.custom_minimum_size = Vector2(68.0, 30.0)
	return button


func _panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, alpha)
	style.border_color = Color(0.29, 0.35, 0.43, 0.94)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	style.shadow_size = 12
	return style


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _capsule_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _summary_chip_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.58, accent.g * 0.58, accent.b * 0.58, 0.92)
	style.border_color = accent.lightened(0.20)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _player_card_style(base: Color, active_turn: bool, is_local: bool, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := base.darkened(0.36)
	if is_local:
		bg = base.darkened(0.28)
	if active_turn:
		bg = bg.lightened(0.12)
	style.bg_color = Color(bg.r, bg.g, bg.b, 0.94)
	style.border_color = base.lightened(0.28) if (active_turn or selected) else base.lightened(0.08)
	style.set_border_width_all(3 if (active_turn or selected) else 2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _clear_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	return style
