extends RefCounted

## Manages turn order, phases, dice rolls, resource collection, and win detection.

const HexGrid    = preload("res://scripts/board/hex_grid.gd")
const BoardGen   = preload("res://scripts/board/board_generator.gd")
const PlayerData = preload("res://scripts/player/player.gd")

enum Phase { SETUP, ROLL, BUILD, GAME_OVER }

const PHASE_NAMES := {
	Phase.SETUP:      "SETUP",
	Phase.ROLL:       "ROLL",
	Phase.BUILD:      "BUILD",
	Phase.GAME_OVER:  "GAME OVER",
}

const WIN_VP := 10

var players: Array = []           # Array of PlayerData
var current_player_index: int = 0
var phase: int = Phase.SETUP
var last_roll: int = 0
var winner_index: int = -1
var tile_data: Dictionary = {}    # "q,r" -> {terrain, number, center}

signal turn_changed(player_ref)
signal dice_rolled(roll)
signal game_won(player_ref)


# --- Setup ---

func init_players(num_players: int) -> void:
	var colors := [
		Color(0.85, 0.10, 0.10),  # Red
		Color(0.15, 0.25, 0.90),  # Blue
		Color(0.92, 0.92, 0.92),  # White
		Color(0.95, 0.50, 0.05),  # Orange
	]
	var names := ["Player 1", "Player 2", "Player 3", "Player 4"]
	for i in range(clamp(num_players, 2, 4)):
		players.append(PlayerData.new(names[i], colors[i]))
	print("[GAMESTATE] %d players ready" % players.size())
	for p in players:
		print("  %s" % p.debug_summary())


# --- Accessors ---

func current_player() -> RefCounted:
	return players[current_player_index]


func phase_name() -> String:
	return PHASE_NAMES.get(phase, "UNKNOWN")


# --- Dice ---

func roll_dice() -> int:
	if phase != Phase.ROLL:
		print("[GAMESTATE] ERROR: tried to roll dice in phase %s" % phase_name())
		return 0

	last_roll = randi_range(1, 6) + randi_range(1, 6)
	print("[GAME] %s rolled %d" % [current_player().player_name, last_roll])
	dice_rolled.emit(last_roll)

	if last_roll == 7:
		print("[GAME] Rolled 7 — robber! (Phase 5: no action yet, skipping collection)")
	else:
		_collect_resources(last_roll)

	phase = Phase.BUILD
	return last_roll


func _collect_resources(roll: int) -> void:
	var total_given := 0
	for key in tile_data:
		var tile: Dictionary = tile_data[key]
		if tile.number != roll:
			continue
		var res := _terrain_to_resource(tile.terrain)
		if res < 0:
			continue
		var center: Vector3 = tile.center
		for p in players:
			for spos in p.settlement_positions:
				var dx: float = spos.x - center.x
				var dz: float = spos.z - center.z
				if sqrt(dx * dx + dz * dz) < HexGrid.HEX_SIZE * 1.15:
					p.add_resource(res)
					total_given += 1
	print("[GAME] Roll %d: %d total resources distributed" % [roll, total_given])


func _terrain_to_resource(terrain: int) -> int:
	match terrain:
		BoardGen.TerrainType.FOREST:    return PlayerData.RES_LUMBER
		BoardGen.TerrainType.HILLS:     return PlayerData.RES_BRICK
		BoardGen.TerrainType.PASTURE:   return PlayerData.RES_WOOL
		BoardGen.TerrainType.FIELDS:    return PlayerData.RES_GRAIN
		BoardGen.TerrainType.MOUNTAINS: return PlayerData.RES_ORE
		_:                              return -1  # Desert


# --- Turn management ---

func try_place_settlement(player: RefCounted, pos: Vector3) -> bool:
	if not player.can_build_settlement():
		print("[GAME] %s cannot afford settlement" % player.player_name)
		return false
	if phase == Phase.SETUP and player != current_player():
		print("[GAME] Not %s's turn in SETUP" % player.player_name)
		return false
	player.place_settlement(pos)
	_check_win()
	return true


func end_turn() -> void:
	if phase == Phase.GAME_OVER:
		return
	print("[GAME] %s ends turn" % current_player().player_name)
	_print_all_resources()

	current_player_index = (current_player_index + 1) % players.size()
	last_roll = 0

	# Stay in SETUP until everyone has used all free placements
	var any_free := false
	for p in players:
		if p.free_placements_left > 0:
			any_free = true
			break
	phase = Phase.SETUP if any_free else Phase.ROLL

	print("[GAME] → %s's turn  [phase: %s]" % [current_player().player_name, phase_name()])
	turn_changed.emit(current_player())


func _check_win() -> void:
	for i in players.size():
		if players[i].victory_points >= WIN_VP:
			winner_index = i
			phase = Phase.GAME_OVER
			print("[GAME] *** %s WINS with %d VP! ***" % [
				players[i].player_name, players[i].victory_points])
			game_won.emit(players[i])
			return


func _print_all_resources() -> void:
	print("[GAME] --- End-of-turn resource snapshot ---")
	for p in players:
		print("  %s" % p.debug_summary())
