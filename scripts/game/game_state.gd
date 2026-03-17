extends RefCounted

## Turn management, dice, resource collection, roads, cities, robber, win detection.

const HexGrid    = preload("res://scripts/board/hex_grid.gd")
const BoardGen   = preload("res://scripts/board/board_generator.gd")
const PlayerData = preload("res://scripts/player/player.gd")

enum Phase { SETUP, ROLL, BUILD, ROBBER_MOVE, GAME_OVER }

const PHASE_NAMES := {
	Phase.SETUP:       "SETUP",
	Phase.ROLL:        "ROLL",
	Phase.BUILD:       "BUILD",
	Phase.ROBBER_MOVE: "ROBBER",
	Phase.GAME_OVER:   "GAME OVER",
}

const WIN_VP       := 10
const ROAD_COST    := {PlayerData.RES_LUMBER: 1, PlayerData.RES_BRICK: 1}
const CITY_COST    := {PlayerData.RES_GRAIN: 2, PlayerData.RES_ORE: 3}
const PROX         := HexGrid.HEX_SIZE * 1.15  # adjacency radius

var players: Array = []
var current_player_index: int = 0
var phase: int = Phase.SETUP
var last_roll: int = 0
var winner_index: int = -1
var tile_data: Dictionary = {}        # "q,r" -> {terrain, number, center, area}
var robber_tile_key: String = ""      # "q,r" of tile holding the robber

# Road tracking: Array of {player_index, v1, v2, midpoint}
var roads: Array = []

signal turn_changed(player_ref)
signal dice_rolled(roll)
signal game_won(player_ref)
signal robber_moved(new_tile_key)


# --- Setup ---

func init_players(num_players: int) -> void:
	var colors := [
		Color(0.85, 0.10, 0.10),
		Color(0.15, 0.25, 0.90),
		Color(0.92, 0.92, 0.92),
		Color(0.95, 0.50, 0.05),
	]
	var names := ["Player 1", "Player 2", "Player 3", "Player 4"]
	for i in range(clamp(num_players, 2, 4)):
		players.append(PlayerData.new(names[i], colors[i]))
	print("[GAMESTATE] %d players ready" % players.size())
	for p in players:
		print("  %s" % p.debug_summary())


func init_robber() -> void:
	# Robber starts on the desert tile
	for key in tile_data:
		if tile_data[key].terrain == BoardGen.TerrainType.DESERT:
			robber_tile_key = key
			print("[GAMESTATE] Robber starts at desert tile %s" % key)
			return


# --- Accessors ---

func current_player() -> RefCounted:
	return players[current_player_index]


func phase_name() -> String:
	return PHASE_NAMES.get(phase, "UNKNOWN")


# --- Dice ---

func roll_dice() -> int:
	if phase != Phase.ROLL:
		return 0
	last_roll = randi_range(1, 6) + randi_range(1, 6)
	print("[GAME] %s rolled %d" % [current_player().player_name, last_roll])
	dice_rolled.emit(last_roll)

	if last_roll == 7:
		print("[GAME] Rolled 7 — robber must move!")
		phase = Phase.ROBBER_MOVE
	else:
		_collect_resources(last_roll)
		phase = Phase.BUILD
	return last_roll


## Public wrapper for debug controller
func debug_collect(roll: int) -> void:
	_collect_resources(roll)


func _collect_resources(roll: int) -> void:
	var total := 0
	for key in tile_data:
		if key == robber_tile_key:
			continue  # robber blocks production
		var tile: Dictionary = tile_data[key]
		if tile.number != roll:
			continue
		var res := _terrain_to_resource(tile.terrain)
		if res < 0:
			continue
		var center: Vector3 = tile.center
		for p in players:
			var multiplier := 0
			for spos in p.settlement_positions:
				if _dist_xz(spos, center) < PROX:
					multiplier += 2 if _is_city_at(p, spos) else 1
			if multiplier > 0:
				p.add_resource(res, multiplier)
				total += multiplier
	print("[GAME] Roll %d: %d total resources distributed" % [roll, total])


func _is_city_at(player: RefCounted, pos: Vector3) -> bool:
	for city_pos in player.city_positions:
		if _dist_xz(pos, city_pos) < 0.1:
			return true
	return false


func _dist_xz(a: Vector3, b: Vector3) -> float:
	var dx: float = a.x - b.x
	var dz: float = a.z - b.z
	return sqrt(dx * dx + dz * dz)


func _terrain_to_resource(terrain: int) -> int:
	match terrain:
		BoardGen.TerrainType.FOREST:    return PlayerData.RES_LUMBER
		BoardGen.TerrainType.HILLS:     return PlayerData.RES_BRICK
		BoardGen.TerrainType.PASTURE:   return PlayerData.RES_WOOL
		BoardGen.TerrainType.FIELDS:    return PlayerData.RES_GRAIN
		BoardGen.TerrainType.MOUNTAINS: return PlayerData.RES_ORE
		_:                              return -1


# --- Robber ---

func move_robber(tile_key: String) -> void:
	if phase != Phase.ROBBER_MOVE:
		return
	robber_tile_key = tile_key
	print("[GAME] Robber moved to %s" % tile_key)
	# Steal 1 random resource from an opponent adjacent to the tile
	_try_steal_from_tile(tile_key)
	phase = Phase.BUILD
	robber_moved.emit(tile_key)


func _try_steal_from_tile(tile_key: String) -> void:
	if tile_key not in tile_data:
		return
	var center: Vector3 = tile_data[tile_key].center
	var victims: Array = []
	for i in players.size():
		if i == current_player_index:
			continue
		for spos in players[i].settlement_positions:
			if _dist_xz(spos, center) < PROX:
				victims.append(i)
				break
	if victims.is_empty():
		print("[GAME] No opponents adjacent to robber tile — no steal")
		return
	var victim_idx: int = victims[randi() % victims.size()]
	var victim: RefCounted = players[victim_idx]
	# Steal a random resource the victim has
	var available: Array = []
	for r in victim.resources:
		for _n in range(victim.resources[r]):
			available.append(r)
	if available.is_empty():
		print("[GAME] Victim %s has no resources to steal" % victim.player_name)
		return
	var stolen: int = available[randi() % available.size()]
	victim.resources[stolen] -= 1
	current_player().add_resource(stolen)
	print("[GAME] %s stole 1 %s from %s" % [
		current_player().player_name,
		PlayerData.RES_NAMES[stolen],
		victim.player_name])


# --- Settlements & cities ---

func try_place_settlement(player: RefCounted, pos: Vector3) -> bool:
	if not player.can_build_settlement():
		print("[GAME] %s cannot afford settlement" % player.player_name)
		return false
	player.place_settlement(pos)
	_check_win()
	return true


func try_place_city(player: RefCounted, settlement_pos: Vector3) -> bool:
	if not _has_resources(player, CITY_COST):
		print("[GAME] %s cannot afford city (needs 2 Grain + 3 Ore)" % player.player_name)
		return false
	_spend_resources(player, CITY_COST)
	player.city_positions.append(settlement_pos)
	player.victory_points += 1  # net +1 (settlement was already 1VP)
	print("[GAME] %s built city at %s  VP:%d" % [player.player_name, settlement_pos, player.victory_points])
	_check_win()
	return true


# --- Roads ---

func try_place_road(player: RefCounted, player_idx: int, v1: Vector3, v2: Vector3) -> bool:
	if not _has_resources(player, ROAD_COST):
		print("[GAME] %s cannot afford road (needs 1 Lumber + 1 Brick)" % player.player_name)
		return false
	if not _road_is_connected(player, player_idx, v1, v2):
		print("[GAME] Road not connected to %s's network" % player.player_name)
		return false
	_spend_resources(player, ROAD_COST)
	roads.append({"player_index": player_idx, "v1": v1, "v2": v2})
	print("[GAME] %s placed road  roads total: %d" % [player.player_name, roads.size()])
	return true


func _road_is_connected(player: RefCounted, player_idx: int, v1: Vector3, v2: Vector3) -> bool:
	# Connected if v1 or v2 has player's settlement
	for spos in player.settlement_positions:
		if _dist_xz(spos, v1) < 0.1 or _dist_xz(spos, v2) < 0.1:
			return true
	# Or connected via existing road sharing an endpoint
	for road in roads:
		if road.player_index != player_idx:
			continue
		var rv1: Vector3 = road.v1
		var rv2: Vector3 = road.v2
		if _dist_xz(rv1, v1) < 0.1 or _dist_xz(rv1, v2) < 0.1:
			return true
		if _dist_xz(rv2, v1) < 0.1 or _dist_xz(rv2, v2) < 0.1:
			return true
	return false


# --- Turn management ---

func end_turn() -> void:
	if phase == Phase.GAME_OVER:
		return
	print("[GAME] %s ends turn" % current_player().player_name)
	_print_all_resources()
	current_player_index = (current_player_index + 1) % players.size()
	last_roll = 0
	var any_free := false
	for p in players:
		if p.free_placements_left > 0:
			any_free = true
			break
	phase = Phase.SETUP if any_free else Phase.ROLL
	print("[GAME] → %s's turn  [%s]" % [current_player().player_name, phase_name()])
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


# --- Helpers ---

func _has_resources(player: RefCounted, cost: Dictionary) -> bool:
	for r in cost:
		if player.resources.get(r, 0) < cost[r]:
			return false
	return true


func _spend_resources(player: RefCounted, cost: Dictionary) -> void:
	for r in cost:
		player.resources[r] -= cost[r]


func _print_all_resources() -> void:
	print("[GAME] --- End-of-turn snapshot ---")
	for p in players:
		print("  %s" % p.debug_summary())
