extends RefCounted

const GameplayActionController = preload("res://scripts/game/gameplay_action_controller.gd")
const GameState = preload("res://scripts/game/game_state.gd")
const PlayerData = preload("res://scripts/player/player.gd")
const HexGrid = preload("res://scripts/board/hex_grid.gd")
const BoardGen = preload("res://scripts/board/board_generator.gd")

var _runner


class FakeHUD extends RefCounted:
	var messages: Array = []
	var activities: Array = []
	var picker_mode: String = ""
	var robber_victims: Array = []
	var robber_picker_cards: Array = []
	var robber_picker_victim_idx: int = -1
	var robber_picker_victim_name: String = ""
	var robber_picker_face_up: bool = false

	func push_activity(text: String, tone: String = "info", pin_to_message: bool = true, _duration: float = 0.0) -> void:
		activities.append({"text": text, "tone": tone, "pin": pin_to_message})
		if pin_to_message:
			messages.append(text)

	func set_message(text: String) -> void:
		messages.append(text)

	func show_resource_picker(mode: String) -> void:
		picker_mode = mode

	func show_robber_victim_picker(victims: Array) -> void:
		robber_victims = victims.duplicate(true)

	func show_robber_card_picker(victim_idx: int, victim_name: String, cards: Array, face_up: bool = false) -> void:
		robber_picker_victim_idx = victim_idx
		robber_picker_victim_name = victim_name
		robber_picker_cards = cards.duplicate(true)
		robber_picker_face_up = face_up


class FakeFeedback extends RefCounted:
	func reset_roll_context() -> void:
		pass

	func show_roll_feedback(_player_name: String, _roll: int, _robber_triggered: bool, _show_dice_anim: bool) -> void:
		pass


func run() -> void:
	_test_buy_dev_card_reports_success_activity()
	_test_trade_decline_reports_warning_activity()
	_test_trade_accept_reports_success_activity_and_moves_resources()
	_test_human_robber_with_one_victim_opens_visible_picker()
	_test_human_robber_card_pick_transfers_exact_resource()
	_test_human_robber_with_multiple_victims_opens_victim_chooser()


func _make_state() -> RefCounted:
	var state := GameState.new()
	state.init_players(2)
	state.init_dev_deck()
	state.phase = GameState.Phase.BUILD
	return state


func _make_controller(state, hud: FakeHUD) -> GameplayActionController:
	var controller := GameplayActionController.new()
	controller.setup(state, FakeFeedback.new(), {
		"refresh_hud": Callable(self, "_noop"),
		"queue_ai_followup": Callable(self, "_noop"),
		"forced_roll_provider": Callable(self, "_zero_roll"),
	})
	controller.update_bindings(hud, null)
	return controller


func _test_buy_dev_card_reports_success_activity() -> void:
	var state := _make_state()
	var hud := FakeHUD.new()
	var controller := _make_controller(state, hud)
	var player: RefCounted = state.current_player()
	player.resources = {
		PlayerData.RES_LUMBER: 0,
		PlayerData.RES_BRICK: 0,
		PlayerData.RES_WOOL: 1,
		PlayerData.RES_GRAIN: 1,
		PlayerData.RES_ORE: 1,
	}

	controller.buy_dev_card()

	_runner.assert_eq(hud.activities.size(), 1,
		"Controller posts one activity when buying a dev card")
	_runner.assert_eq(hud.activities[0]["text"], "Dev card purchased!",
		"Controller reports a successful dev-card purchase")
	_runner.assert_eq(hud.activities[0]["tone"], "success",
		"Successful dev-card purchase uses success tone")


func _test_trade_decline_reports_warning_activity() -> void:
	var state := _make_state()
	var hud := FakeHUD.new()
	var controller := _make_controller(state, hud)
	var human: RefCounted = state.players[0]
	var ai: RefCounted = state.players[1]
	ai.is_ai = true
	human.resources[PlayerData.RES_LUMBER] = 2
	ai.resources[PlayerData.RES_LUMBER] = 5
	ai.resources[PlayerData.RES_GRAIN] = 1

	controller.on_trade_proposed(
		{PlayerData.RES_LUMBER: 1},
		{PlayerData.RES_GRAIN: 1},
		1)

	_runner.assert_eq(hud.activities.size(), 1,
		"Controller posts one activity when a trade is declined")
	_runner.assert_eq(hud.activities[0]["text"], "Player 2 declined the trade offer.",
		"Declined trades report the correct activity text")
	_runner.assert_eq(hud.activities[0]["tone"], "warn",
		"Declined trades use warning tone")


func _test_trade_accept_reports_success_activity_and_moves_resources() -> void:
	var state := _make_state()
	var hud := FakeHUD.new()
	var controller := _make_controller(state, hud)
	var human: RefCounted = state.players[0]
	var ai: RefCounted = state.players[1]
	ai.is_ai = true
	human.resources[PlayerData.RES_LUMBER] = 2
	ai.resources[PlayerData.RES_LUMBER] = 0
	ai.resources[PlayerData.RES_GRAIN] = 1

	controller.on_trade_proposed(
		{PlayerData.RES_LUMBER: 1},
		{PlayerData.RES_GRAIN: 1},
		1)

	_runner.assert_eq(hud.activities.size(), 1,
		"Controller posts one activity when a trade is accepted")
	_runner.assert_eq(hud.activities[0]["text"], "Trade accepted by Player 2!",
		"Accepted trades report the correct activity text")
	_runner.assert_eq(hud.activities[0]["tone"], "success",
		"Accepted trades use success tone")
	_runner.assert_eq(human.resources[PlayerData.RES_LUMBER], 1,
		"Accepted trade removes the offered resource from the human player")
	_runner.assert_eq(human.resources[PlayerData.RES_GRAIN], 1,
		"Accepted trade gives the requested resource to the human player")


func _test_human_robber_with_one_victim_opens_visible_picker() -> void:
	var state := _make_robber_state(2)
	var hud := FakeHUD.new()
	var controller := _make_controller(state, hud)

	controller.on_board_tile_clicked("0,0")

	_runner.assert_eq(state.robber_tile_key, "0,0",
		"Human robber move updates the robber tile before prompting for a steal")
	_runner.assert_eq(state.phase, GameState.Phase.ROBBER_MOVE,
		"Human robber move stays in ROBBER_MOVE until a card is chosen")
	_runner.assert_eq(hud.robber_picker_victim_idx, 1,
		"Human robber move with one victim opens the visible picker directly")
	_runner.assert_eq(hud.robber_picker_cards.size(), 2,
		"Visible picker shows one card per resource in the victim hand")
	_runner.assert_true(hud.robber_picker_face_up,
		"Visible-hand mode opens the robber picker face-up")


func _test_human_robber_card_pick_transfers_exact_resource() -> void:
	var state := _make_robber_state(2)
	var hud := FakeHUD.new()
	var controller := _make_controller(state, hud)

	controller.on_board_tile_clicked("0,0")
	controller.on_robber_card_chosen(1, PlayerData.RES_WOOL)

	_runner.assert_eq(state.phase, GameState.Phase.BUILD,
		"Choosing a robber card resumes the build phase")
	_runner.assert_eq(state.players[0].resources[PlayerData.RES_WOOL], 1,
		"Chosen robber card transfers the exact resource to the human player")
	_runner.assert_eq(state.players[1].resources[PlayerData.RES_WOOL], 1,
		"Chosen robber card removes exactly one matching resource from the victim")


func _test_human_robber_with_multiple_victims_opens_victim_chooser() -> void:
	var state := _make_robber_state(3)
	state.players[2].settlement_positions.append(Vector3(HexGrid.HEX_SIZE * 0.65, 0.15, 0.0))
	state.players[2].resources[PlayerData.RES_BRICK] = 1
	var hud := FakeHUD.new()
	var controller := _make_controller(state, hud)

	controller.on_board_tile_clicked("0,0")

	_runner.assert_eq(hud.robber_victims.size(), 2,
		"Human robber move with multiple victims opens a victim chooser first")
	_runner.assert_eq(state.phase, GameState.Phase.ROBBER_MOVE,
		"Victim selection keeps the game in ROBBER_MOVE until a card is picked")


func _noop() -> void:
	pass


func _zero_roll() -> int:
	return 0


func _make_robber_state(num_players: int) -> RefCounted:
	var state := GameState.new()
	state.init_players(num_players)
	state.init_dev_deck()
	state.phase = GameState.Phase.ROBBER_MOVE
	state.current_player_index = 0
	state.tile_data = {
		"0,0": {
			"terrain": BoardGen.TerrainType.HILLS,
			"number": 6,
			"center": HexGrid.axial_to_world(0, 0),
			"q": 0, "r": 0, "area": null,
		},
		"1,0": {
			"terrain": BoardGen.TerrainType.DESERT,
			"number": 0,
			"center": HexGrid.axial_to_world(1, 0),
			"q": 1, "r": 0, "area": null,
		},
	}
	state.robber_tile_key = "1,0"
	state.players[1].settlement_positions.append(Vector3(0.0, 0.15, 0.0))
	state.players[1].resources[PlayerData.RES_WOOL] = 2
	return state
