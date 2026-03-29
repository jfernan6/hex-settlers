extends CanvasLayer

## In-game HUD: local command hand + opponent chips + shared supply lane.

const HUDFXLayer = preload("res://scripts/ui/hud_fx_layer.gd")
const HUDCardTable = preload("res://scripts/ui/hud_card_table.gd")
const HUDTradeDialog = preload("res://scripts/ui/hud_trade_dialog.gd")
const HUDPhaseCopy = preload("res://scripts/ui/hud_phase_copy.gd")
const HUDResourcePicker = preload("res://scripts/ui/hud_resource_picker.gd")
const HUDRobberPicker = preload("res://scripts/ui/hud_robber_picker.gd")

signal roll_dice_pressed
signal end_turn_pressed
signal buy_dev_card_pressed
signal play_dev_card_requested(card_type: int)
signal year_of_plenty_chosen(r1: int, r2: int)
signal monopoly_chosen(res: int)
signal trade_proposed(offer: Dictionary, want: Dictionary, to_player_idx: int)
signal robber_victim_chosen(victim_idx: int)
signal robber_card_chosen(victim_idx: int, resource: int)
signal layout_metrics_changed(insets: Dictionary)

const _ACTIVITY_LIMIT := 4

const _RES_COLORS: Array = [
	Color(0.12, 0.42, 0.08),
	Color(0.65, 0.20, 0.06),
	Color(0.28, 0.68, 0.12),
	Color(0.85, 0.70, 0.04),
	Color(0.38, 0.40, 0.50),
]
const _RES_SHORT: Array = ["LU", "BR", "WO", "GR", "OR"]
const _RES_NAMES: Array = ["Lumber", "Brick", "Wool", "Grain", "Ore"]

var _font_size: int = 15
var _activity_entries: Array = []
var _phase_prompt_text: String = ""
var _result_text: String = ""
var _result_tone: String = "info"

var _card_table: HUDCardTable
var _hud_fx: Control
var _res_picker: HUDResourcePicker
var _trade_dialog: HUDTradeDialog
var _robber_picker: HUDRobberPicker
var _phase_copy := HUDPhaseCopy.new()
var _result_clear_timer: Timer

var _last_player = null
var _last_phase_name: String = ""
var _last_dice_roll: int = 0
var _last_state = null


func _ready() -> void:
	_build_ui()
	print("[HUD] UI built")


func _build_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_font_size = int(maxf(14.0, vp.x * 0.012))
	print("[HUD] vp=%s  hand-font=%d" % [vp, _font_size])

	_card_table = HUDCardTable.new()
	_card_table.layout_metrics_changed.connect(func(insets: Dictionary) -> void:
		layout_metrics_changed.emit(insets)
	)
	_card_table.setup(_font_size)
	_card_table.roll_dice_pressed.connect(func() -> void:
		roll_dice_pressed.emit()
	)
	_card_table.end_turn_pressed.connect(func() -> void:
		end_turn_pressed.emit()
	)
	_card_table.buy_dev_card_pressed.connect(func() -> void:
		buy_dev_card_pressed.emit()
	)
	_card_table.propose_trade_pressed.connect(func() -> void:
		if _trade_dialog != null:
			_trade_dialog.open_dialog()
	)
	_card_table.play_dev_card_requested.connect(func(card_type: int) -> void:
		play_dev_card_requested.emit(card_type)
	)
	add_child(_card_table)

	_hud_fx = HUDFXLayer.new()
	_hud_fx.setup(_font_size, _RES_COLORS, _RES_SHORT, _RES_NAMES,
		Callable(self, "get_resource_card_center"),
		Callable(self, "pulse_resource_card"))
	add_child(_hud_fx)

	_build_res_picker()
	_build_trade_dialog()
	_build_robber_picker()

	_result_clear_timer = Timer.new()
	_result_clear_timer.one_shot = true
	_result_clear_timer.timeout.connect(_clear_result_text)
	add_child(_result_clear_timer)


func refresh(player, phase_name: String, dice_roll: int, state = null) -> void:
	_last_player = player
	_last_phase_name = phase_name
	_last_dice_roll = dice_roll
	_last_state = state

	if state != null and _trade_dialog != null:
		var local_idx := _find_local_player_index(state)
		var local_player = state.get_player(local_idx)
		var names: Array = []
		for p in state.players:
			names.append(p.player_name)
		_trade_dialog.set_context(local_player.resources if local_player != null else player.resources,
			names, local_idx)

	_sync_card_table()


func show_dice_animation(result: int) -> void:
	if _hud_fx != null:
		_hud_fx.show_dice_animation(result)


func get_roll_feedback_delay(show_dice_anim: bool) -> float:
	if _hud_fx == null:
		return 0.40
	return _hud_fx.get_roll_feedback_delay(show_dice_anim)


func show_roll_feedback(player_name: String, roll: int, gains: Dictionary, robber_triggered: bool) -> void:
	if _hud_fx != null:
		_hud_fx.show_roll_feedback(player_name, roll, gains, robber_triggered)


func get_resource_card_center(res: int) -> Vector2:
	if _card_table != null and _card_table.has_method("get_resource_target_center"):
		return _card_table.get_resource_target_center(res)
	return get_viewport().get_visible_rect().size * 0.5


func get_persistent_safe_insets() -> Dictionary:
	if _card_table != null and _card_table.has_method("get_persistent_safe_insets"):
		return _card_table.get_persistent_safe_insets()
	return {
		"left": 0.0,
		"top": 0.0,
		"right": 0.0,
		"bottom": 0.0,
	}


func pulse_resource_card(res: int) -> void:
	if _card_table != null and _card_table.has_method("pulse_resource_target"):
		_card_table.pulse_resource_target(res)


func show_resource_chip_flight(res: int, source_points: Array, amount: int, caption: String = "") -> void:
	if _hud_fx != null:
		_hud_fx.show_resource_chip_flight(res, source_points, amount, caption)


func set_phase_prompt(msg: String) -> void:
	_phase_prompt_text = msg
	_sync_card_table()


func push_activity(text: String, tone: String = "info", pin_to_message: bool = true, duration: float = 2.8) -> void:
	if text.strip_edges() == "":
		return
	_activity_entries.push_front({"text": text, "tone": tone})
	if _activity_entries.size() > _ACTIVITY_LIMIT:
		_activity_entries.resize(_ACTIVITY_LIMIT)
	if pin_to_message:
		_result_text = text
		_result_tone = tone
		if _result_clear_timer != null:
			if duration > 0.0:
				_result_clear_timer.start(duration)
			else:
				_result_clear_timer.stop()
	_sync_card_table()


func set_message(msg: String) -> void:
	push_activity(msg, "info", true)


func show_resource_picker(mode: String) -> void:
	_res_picker.open_picker(mode)


func show_robber_victim_picker(victims: Array) -> void:
	if _robber_picker != null:
		_robber_picker.open_victim_picker(victims)


func show_robber_card_picker(victim_idx: int, victim_name: String, cards: Array, face_up: bool = false) -> void:
	if _robber_picker != null:
		_robber_picker.open_card_picker(victim_idx, victim_name, cards, face_up)


func _build_res_picker() -> void:
	_res_picker = HUDResourcePicker.new()
	_res_picker.setup(_font_size, _RES_COLORS, _RES_NAMES)
	_res_picker.year_of_plenty_chosen.connect(func(r1: int, r2: int) -> void:
		year_of_plenty_chosen.emit(r1, r2)
	)
	_res_picker.monopoly_chosen.connect(func(res: int) -> void:
		monopoly_chosen.emit(res)
	)
	add_child(_res_picker)


func _build_trade_dialog() -> void:
	_trade_dialog = HUDTradeDialog.new()
	_trade_dialog.setup(_font_size, _RES_COLORS, _RES_SHORT)
	_trade_dialog.trade_proposed.connect(func(offer: Dictionary, want: Dictionary, to_player_idx: int) -> void:
		trade_proposed.emit(offer, want, to_player_idx)
	)
	add_child(_trade_dialog)


func _build_robber_picker() -> void:
	_robber_picker = HUDRobberPicker.new()
	_robber_picker.setup(_font_size)
	_robber_picker.victim_chosen.connect(func(victim_idx: int) -> void:
		robber_victim_chosen.emit(victim_idx)
	)
	_robber_picker.card_picked.connect(func(victim_idx: int, resource: int) -> void:
		robber_card_chosen.emit(victim_idx, resource)
	)
	add_child(_robber_picker)


func _clear_result_text() -> void:
	_result_text = ""
	_result_tone = "info"
	_sync_card_table()


func _sync_card_table() -> void:
	if _card_table == null or _last_player == null or _last_state == null:
		return
	var phase_ui: Dictionary = _phase_copy.describe(_last_player, _last_phase_name, _last_state)
	_card_table.refresh(_last_state, _last_player, _last_phase_name, _last_dice_roll, phase_ui,
		_activity_entries, _phase_prompt_text, _result_text, _result_tone)


func _find_local_player_index(state) -> int:
	for i in range(state.players.size()):
		if not state.players[i].is_ai:
			return i
	return state.current_player_index
