extends RefCounted

## Turn management, dice, resource collection, roads, cities, robber, win detection.

const HexGrid    = preload("res://scripts/board/hex_grid.gd")
const BoardGen   = preload("res://scripts/board/board_generator.gd")
const PlayerData = preload("res://scripts/player/player.gd")
const DevCards   = preload("res://scripts/game/dev_cards.gd")

enum Phase { SETUP, ROLL, BUILD, ROBBER_MOVE, GAME_OVER }

## Sub-phases within SETUP — each turn is: place settlement → place road
enum SetupSubPhase { PLACE_SETTLEMENT, PLACE_ROAD }

const PHASE_NAMES := {
	Phase.SETUP:       "SETUP",
	Phase.ROLL:        "ROLL",
	Phase.BUILD:       "BUILD",
	Phase.ROBBER_MOVE: "ROBBER",
	Phase.GAME_OVER:   "GAME OVER",
}

const WIN_VP          := 10
const MAX_SETTLEMENTS := 5   # standard Catan piece limits
const MAX_CITIES      := 4
const MAX_ROADS       := 15
const ROAD_COST    := {PlayerData.RES_LUMBER: 1, PlayerData.RES_BRICK: 1}
const CITY_COST    := {PlayerData.RES_GRAIN: 2, PlayerData.RES_ORE: 3}
const DEV_COST     := {PlayerData.RES_ORE: 1, PlayerData.RES_GRAIN: 1, PlayerData.RES_WOOL: 1}
const PROX         := HexGrid.HEX_SIZE * 1.15  # adjacency radius
const RESOURCE_BANK_START := 19

var players: Array = []
var current_player_index: int = 0
var phase: int = Phase.SETUP
var last_roll: int = 0
var winner_index: int = -1
var tile_data: Dictionary = {}        # "q,r" -> {terrain, number, center, area}
var robber_tile_key: String = ""      # "q,r" of tile holding the robber
var robber_pick_pending: bool = false
var resource_bank: Dictionary = {}

# Setup state machine
var setup_sub_phase: int = SetupSubPhase.PLACE_SETTLEMENT
var setup_round: int = 1              # 1 = forward order, 2 = snake/reverse
var _setup_queue: Array = []          # player indices for current round
var _setup_queue_pos: int = 0         # current position in queue
var last_setup_pos: Vector3 = Vector3.ZERO  # just-placed settlement (road must connect here)

# Road tracking: Array of {player_index, v1, v2}
var roads: Array = []

# Dev card deck
var dev_deck: Array = []

# Sprint 2B — dev card timing rules
var dev_cards_new_this_turn: Dictionary = {}  # card_type -> count bought this turn
var dev_cards_played_this_turn: int = 0       # max 1 per turn

# Bonus VP tracking
var longest_road_holder: int  = -1
var longest_road_length: int  = 0
var largest_army_holder: int  = -1
var largest_army_size: int    = 0

signal turn_changed(player_ref)
signal dice_rolled(roll)
signal game_won(player_ref)
signal robber_moved(new_tile_key)
signal bonuses_changed()          # longest road / largest army changed
signal setup_sub_phase_changed()  # settlement→road within setup turn
signal resource_payouts_generated(payouts)


# --- Setup ---

func init_players(num_players: int) -> void:
	resource_bank = _new_resource_bank()
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


func init_dev_deck() -> void:
	dev_deck = DevCards.make_deck()


func init_robber() -> void:
	for key in tile_data:
		if tile_data[key].terrain == BoardGen.TerrainType.DESERT:
			robber_tile_key = key
			Log.info("[GAMESTATE] Robber starts at desert tile %s" % key)
			return


## Initializes the snake-order setup queue. Call after init_players().
func init_setup() -> void:
	setup_round      = 1
	setup_sub_phase  = SetupSubPhase.PLACE_SETTLEMENT
	_setup_queue     = Array(range(players.size()))  # [0, 1, …]
	_setup_queue_pos = 0
	current_player_index = _setup_queue[0]
	Log.info("[SETUP] Round 1 order: %s" % str(_setup_queue))


## Called after a settlement is placed in SETUP — records position, moves to PLACE_ROAD.
func setup_settlement_placed(pos: Vector3) -> void:
	last_setup_pos  = pos
	var player := current_player()
	player.place_settlement_free(pos)
	# Round 2: collect starting resources from adjacent tiles
	if setup_round == 2:
		_collect_starting_resources(player, pos)
	setup_sub_phase = SetupSubPhase.PLACE_ROAD
	Log.info("[SETUP] %s placed settlement (round %d) → now place a road" % [
		player.player_name, setup_round])
	GameEvents.record(GameEvents.EventType.SETTLEMENT_PLACED, player.player_name,
		{"setup_round": setup_round, "vp": player.victory_points,
		 "pos_x": pos.x, "pos_z": pos.z})
	setup_sub_phase_changed.emit()
	_check_win()


## Called after a road is placed in SETUP — advances the queue or ends setup.
func setup_road_placed() -> void:
	Log.info("[SETUP] %s placed road" % current_player().player_name)
	_setup_queue_pos += 1

	if _setup_queue_pos >= _setup_queue.size():
		# Current round exhausted
		if setup_round == 1:
			# Begin round 2 in reverse (snake) order
			setup_round      = 2
			_setup_queue      = _setup_queue.duplicate()
			_setup_queue.reverse()
			_setup_queue_pos  = 0
			current_player_index = _setup_queue[0]
			setup_sub_phase   = SetupSubPhase.PLACE_SETTLEMENT
			Log.info("[SETUP] Round 2 (snake) order: %s" % str(_setup_queue))
			turn_changed.emit(current_player())
		else:
			# Both rounds done — start main game with Player 1 in ROLL phase
			phase                = Phase.ROLL
			current_player_index = 0
			last_roll            = 0
			Log.info("[SETUP] Setup complete — main game begins (Player 1 rolls)")
			_print_all_resources()
			turn_changed.emit(current_player())
	else:
		# Advance to next player in current round
		current_player_index = _setup_queue[_setup_queue_pos]
		setup_sub_phase      = SetupSubPhase.PLACE_SETTLEMENT
		turn_changed.emit(current_player())


func _collect_starting_resources(player: RefCounted, settlement_pos: Vector3) -> void:
	var collected := 0
	for key in tile_data:
		var tile: Dictionary = tile_data[key]
		if tile.number <= 0:
			continue  # desert
		if _dist_xz(settlement_pos, tile.center) < PROX:
			var res := _terrain_to_resource(tile.terrain)
			if res >= 0 and _take_from_bank(player, res, 1):
				collected += 1
	Log.info("[SETUP] %s receives %d starting resource(s) from 2nd settlement" % [
		player.player_name, collected])


# --- Accessors ---

func current_player() -> RefCounted:
	return players[current_player_index]


func phase_name() -> String:
	return PHASE_NAMES.get(phase, "UNKNOWN")


func get_player(player_idx: int) -> RefCounted:
	if player_idx < 0 or player_idx >= players.size():
		return null
	return players[player_idx]


func get_resource_bank_view() -> Dictionary:
	return resource_bank.duplicate(true)


func get_dev_deck_counts_view() -> Dictionary:
	var counts: Dictionary = {}
	for card_type in DevCards.COUNTS:
		counts[card_type] = 0
	for card_type in dev_deck:
		counts[card_type] = counts.get(card_type, 0) + 1
	return counts


func get_resource_hand_view(player_idx: int) -> Array:
	var player := get_player(player_idx)
	var view: Array = []
	if player == null:
		return view
	for resource in [PlayerData.RES_LUMBER, PlayerData.RES_BRICK, PlayerData.RES_WOOL, PlayerData.RES_GRAIN, PlayerData.RES_ORE]:
		view.append({
			"resource": resource,
			"count": int(player.resources.get(resource, 0)),
		})
	return view


func get_dev_hand_view(player_idx: int, include_revealed: bool = false) -> Array:
	var player := get_player(player_idx)
	var cards: Array = []
	if player == null:
		return cards
	var source: Array = player.revealed_dev_cards if include_revealed else player.dev_cards
	var counts: Dictionary = {}
	for card_type in source:
		counts[card_type] = counts.get(card_type, 0) + 1
	for card_type in [DevCards.Type.KNIGHT, DevCards.Type.ROAD_BUILDING,
			DevCards.Type.YEAR_OF_PLENTY, DevCards.Type.MONOPOLY, DevCards.Type.VP]:
		var count: int = int(counts.get(card_type, 0))
		if count <= 0:
			continue
		cards.append({
			"card_type": card_type,
			"count": count,
		})
	return cards


func get_revealed_dev_hand_view(player_idx: int) -> Array:
	return get_dev_hand_view(player_idx, true)


func get_dev_supply_view() -> Dictionary:
	var revealed_counts: Dictionary = {}
	for card_type in DevCards.COUNTS:
		revealed_counts[card_type] = 0
	for player in players:
		for card_type in player.revealed_dev_cards:
			revealed_counts[card_type] = revealed_counts.get(card_type, 0) + 1
	return {
		"remaining_total": dev_deck.size(),
		"remaining_counts": get_dev_deck_counts_view(),
		"revealed_counts": revealed_counts,
	}


func passes_distance_rule(pos: Vector3) -> bool:
	return _respects_distance_rule(pos)


func is_city_for_player_at(player_idx: int, pos: Vector3) -> bool:
	var player := get_player(player_idx)
	if player == null:
		return false
	return _is_city_at(player, pos)


func can_move_robber_to(tile_key: String) -> bool:
	if phase != Phase.ROBBER_MOVE:
		return false
	if tile_key not in tile_data:
		return false
	return tile_key != robber_tile_key


func get_robber_victims(tile_key: String) -> Array:
	var victims: Array = []
	if tile_key not in tile_data:
		return victims
	var center: Vector3 = tile_data[tile_key].center
	for i in range(players.size()):
		if i == current_player_index:
			continue
		for spos in players[i].settlement_positions:
			if _dist_xz(spos, center) < PROX:
				victims.append(i)
				break
	return victims


func get_hand_cards(player_idx: int, shuffled: bool = false) -> Array:
	var player := get_player(player_idx)
	var cards: Array = []
	if player == null:
		return cards
	for resource in [PlayerData.RES_LUMBER, PlayerData.RES_BRICK, PlayerData.RES_WOOL, PlayerData.RES_GRAIN, PlayerData.RES_ORE]:
		var count: int = int(player.resources.get(resource, 0))
		for copy_index in range(count):
			cards.append({
				"resource": resource,
				"card_id": "%d_%d" % [resource, copy_index],
			})
	if shuffled:
		cards.shuffle()
	return cards


func complete_robber_phase() -> void:
	robber_pick_pending = false
	if phase == Phase.ROBBER_MOVE:
		phase = Phase.BUILD


func steal_specific_resource(victim_idx: int, resource: int) -> bool:
	if victim_idx < 0 or victim_idx >= players.size():
		return false
	if victim_idx == current_player_index:
		return false
	var victim: RefCounted = players[victim_idx]
	if victim.resources.get(resource, 0) <= 0:
		return false
	victim.resources[resource] -= 1
	current_player().add_resource(resource)
	Log.info("[GAME] %s stole 1 %s from %s" % [
		current_player().player_name, PlayerData.RES_NAMES[resource], victim.player_name])
	GameEvents.record(GameEvents.EventType.RESOURCE_STOLEN, current_player().player_name,
		{"resource": PlayerData.RES_NAMES[resource], "from": victim.player_name})
	return true


func can_place_setup_settlement_at(pos: Vector3) -> bool:
	return phase == Phase.SETUP and setup_sub_phase == SetupSubPhase.PLACE_SETTLEMENT and _respects_distance_rule(pos)


func can_place_settlement_at(player_idx: int, pos: Vector3) -> bool:
	var player := get_player(player_idx)
	if player == null:
		return false
	if phase != Phase.BUILD:
		return false
	if not player.can_build_settlement():
		return false
	if not _respects_distance_rule(pos):
		return false
	return can_connect_settlement_at(player_idx, pos)


func can_connect_settlement_at(player_idx: int, pos: Vector3) -> bool:
	var player := get_player(player_idx)
	if player == null:
		return false
	if phase != Phase.BUILD:
		return false
	if not _respects_distance_rule(pos):
		return false
	return _has_connected_road_for_settlement(player, pos)


func can_upgrade_city_at(player_idx: int, pos: Vector3) -> bool:
	var player := get_player(player_idx)
	if player == null:
		return false
	if phase != Phase.BUILD:
		return false
	if player.city_positions.size() >= MAX_CITIES:
		return false
	if not _has_settlement_at(player, pos):
		return false
	if _is_city_at(player, pos):
		return false
	return _has_resources(player, CITY_COST)


func can_place_setup_road_at(player_idx: int, v1: Vector3, v2: Vector3) -> bool:
	var player := get_player(player_idx)
	if player == null:
		return false
	if phase != Phase.SETUP or setup_sub_phase != SetupSubPhase.PLACE_ROAD:
		return false
	if _road_exists(v1, v2):
		return false
	return _road_is_connected(player, player_idx, v1, v2)


func can_connect_road_at(player_idx: int, v1: Vector3, v2: Vector3) -> bool:
	var player := get_player(player_idx)
	if player == null:
		return false
	if phase != Phase.BUILD:
		return false
	if _road_exists(v1, v2):
		return false
	var player_road_count: int = roads.filter(func(r): return r.player_index == player_idx).size()
	if player_road_count >= MAX_ROADS:
		return false
	return _road_is_connected(player, player_idx, v1, v2)


func can_place_road_at(player_idx: int, v1: Vector3, v2: Vector3) -> bool:
	var player := get_player(player_idx)
	if player == null:
		return false
	if phase != Phase.BUILD:
		return false
	if not can_connect_road_at(player_idx, v1, v2):
		return false
	var free: bool = player.free_roads > 0
	if not free and not _has_resources(player, ROAD_COST):
		return false
	return true


func can_buy_dev_card_for(player_idx: int) -> bool:
	var player := get_player(player_idx)
	if player == null:
		return false
	if phase != Phase.BUILD:
		return false
	if dev_deck.is_empty():
		return false
	return _has_resources(player, DEV_COST)


func force_check_win() -> void:
	_check_win()


func check_win() -> void:
	_check_win()


func apply_robber_discard() -> void:
	_apply_robber_discard()


func collect_resources_for_roll(roll: int) -> void:
	_collect_resources(roll)


func get_trade_rate_for(player: RefCounted, give_res: int) -> int:
	return _get_trade_rate(player, give_res)


# --- Dice ---

func roll_dice() -> int:
	if phase != Phase.ROLL:
		return 0
	last_roll = randi_range(1, 6) + randi_range(1, 6)
	Log.info("[GAME] %s rolled %d" % [current_player().player_name, last_roll])
	GameEvents.record(GameEvents.EventType.DICE_ROLLED, current_player().player_name,
		{"roll": last_roll})
	dice_rolled.emit(last_roll)

	if last_roll == 7:
		print("[GAME] Rolled 7 — robber must move!")
		_apply_robber_discard()  # Players with 8+ cards must discard half
		robber_pick_pending = false
		phase = Phase.ROBBER_MOVE
	else:
		_collect_resources(last_roll)
		phase = Phase.BUILD
	return last_roll


## Public wrapper for debug controller
func debug_collect(roll: int) -> void:
	_collect_resources(roll)


## Robber discard rule: any player holding 8+ cards must discard half (rounded down).
func _apply_robber_discard() -> void:
	for p in players:
		var total := 0
		for r in p.resources:
			total += p.resources[r]
		if total >= 8:
			var discard_count: int = total / 2
			var discarded := 0
			while discarded < discard_count:
				# Discard from largest pile first
				var max_r := 0
				var max_amt := -1
				for r in p.resources:
					if p.resources[r] > max_amt:
						max_amt = p.resources[r]
						max_r = r
				if max_amt <= 0:
					break
				p.resources[max_r] -= 1
				_return_to_bank(max_r, 1)
				discarded += 1
			Log.info("[GAME] %s had %d cards — discarded %d (robber rule)" % [
				p.player_name, total, discarded])
			GameEvents.record(GameEvents.EventType.RESOURCE_DISCARDED, p.player_name,
				{"had": total, "discarded": discarded})


func _collect_resources(roll: int) -> void:
	var total := 0
	var payouts: Array = []
	var pending_by_resource: Dictionary = {}
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
		for player_index in range(players.size()):
			var p = players[player_index]
			var multiplier := 0
			for spos in p.settlement_positions:
				if _dist_xz(spos, center) < PROX:
					multiplier += 2 if _is_city_at(p, spos) else 1
			if multiplier > 0:
				if res not in pending_by_resource:
					pending_by_resource[res] = []
				pending_by_resource[res].append({
					"player_index": player_index,
					"resource": res,
					"amount": multiplier,
					"tile_key": key,
					"center": center,
					"terrain": tile.terrain,
					"roll": roll,
				})
	for res in pending_by_resource:
		var pending: Array = pending_by_resource[res]
		var total_needed := 0
		for payout in pending:
			total_needed += int(payout.amount)
		if resource_bank.get(res, 0) < total_needed:
			Log.warn("[GAME] Bank lacks %d %s for roll %d — no payouts of that resource" % [
				total_needed, PlayerData.RES_NAMES[res], roll])
			continue
		for payout in pending:
			var amount: int = int(payout.amount)
			if _take_from_bank(players[int(payout.player_index)], res, amount):
				total += amount
				payouts.append(payout)
	Log.debug("[GAME] Roll %d: %d total resources distributed" % [roll, total])
	resource_payouts_generated.emit(payouts)
	if total > 0:
		GameEvents.record(GameEvents.EventType.RESOURCE_COLLECTED, "all",
			{"roll": roll, "total": total})


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

func move_robber(tile_key: String, auto_resolve_steal: bool = true) -> bool:
	if phase != Phase.ROBBER_MOVE:
		return false
	if tile_key not in tile_data:
		Log.warn("[GAME] Ignoring invalid robber tile %s" % tile_key)
		return false
	if tile_key == robber_tile_key:
		Log.warn("[GAME] Robber is already on %s" % tile_key)
		return false
	robber_tile_key = tile_key
	robber_pick_pending = not auto_resolve_steal
	Log.info("[GAME] Robber moved to %s" % tile_key)
	GameEvents.record(GameEvents.EventType.ROBBER_MOVED, current_player().player_name,
		{"tile": tile_key})
	if auto_resolve_steal:
		_try_steal_from_tile(tile_key)
		complete_robber_phase()
	robber_moved.emit(tile_key)
	return true


func _try_steal_from_tile(tile_key: String) -> void:
	var victims: Array = []
	for victim_idx in get_robber_victims(tile_key):
		if not get_hand_cards(victim_idx, false).is_empty():
			victims.append(victim_idx)
	if victims.is_empty():
		print("[GAME] No opponents adjacent to robber tile — no steal")
		return
	var victim_idx: int = victims[randi() % victims.size()]
	var available: Array = get_hand_cards(victim_idx, true)
	if available.is_empty():
		print("[GAME] Victim %s has no resources to steal" % players[victim_idx].player_name)
		return
	steal_specific_resource(victim_idx, int(available[0]["resource"]))


# --- Settlements & cities ---

func try_place_settlement(player: RefCounted, pos: Vector3) -> bool:
	if not player.can_build_settlement():
		print("[GAME] %s cannot afford settlement" % player.player_name)
		return false
	# Catan distance rule: no settlement within 1 edge of any other settlement
	if not _respects_distance_rule(pos):
		print("[GAME] %s: placement violates distance rule (too close to existing settlement)" % player.player_name)
		return false
	if not _has_connected_road_for_settlement(player, pos):
		print("[GAME] %s: settlement must connect to an existing road" % player.player_name)
		return false
	player.place_settlement(pos)
	_return_resources_to_bank(PlayerData.SETTLEMENT_COST)
	_check_win()
	return true


## Returns true if `pos` is at least 2 edges away from all existing settlements.
## Adjacent vertex distance for our grid ≈ HEX_SIZE (1.05 units).
func _respects_distance_rule(pos: Vector3) -> bool:
	for p in players:
		for spos in p.settlement_positions:
			if _dist_xz(pos, spos) < HexGrid.HEX_SIZE * 1.05:
				return false
	return true


func try_place_city(player: RefCounted, settlement_pos: Vector3) -> bool:
	if player.city_positions.size() >= MAX_CITIES:
		print("[GAME] %s has reached max cities (%d)" % [player.player_name, MAX_CITIES])
		return false
	if not _has_settlement_at(player, settlement_pos):
		print("[GAME] %s must upgrade an existing settlement into a city" % player.player_name)
		return false
	if _is_city_at(player, settlement_pos):
		print("[GAME] %s already has a city at %s" % [player.player_name, settlement_pos])
		return false
	if not _has_resources(player, CITY_COST):
		print("[GAME] %s cannot afford city (needs 2 Grain + 3 Ore)" % player.player_name)
		return false
	_spend_resources(player, CITY_COST)
	player.city_positions.append(settlement_pos)
	player.victory_points += 1
	Log.info("[GAME] %s built city at %s  VP:%d" % [player.player_name, settlement_pos, player.victory_points])
	GameEvents.record(GameEvents.EventType.CITY_BUILT, player.player_name,
		{"vp": player.victory_points})
	_check_win()
	return true


# --- Roads ---

func try_place_road(player: RefCounted, player_idx: int, v1: Vector3, v2: Vector3) -> bool:
	# Piece limit
	var player_road_count: int = roads.filter(func(r): return r.player_index == player_idx).size()
	if player_road_count >= MAX_ROADS:
		print("[GAME] %s has reached max roads (%d)" % [player.player_name, MAX_ROADS])
		return false
	if _road_exists(v1, v2):
		print("[GAME] Road already exists between %s and %s" % [v1, v2])
		return false
	# Setup roads are always free (no cost, no Road Building card needed)
	var setup_free: bool = (phase == Phase.SETUP and setup_sub_phase == SetupSubPhase.PLACE_ROAD)
	var free: bool = setup_free or player.free_roads > 0
	if not free and not _has_resources(player, ROAD_COST):
		Log.warn("[GAME] %s cannot afford road" % player.player_name)
		return false
	if not _road_is_connected(player, player_idx, v1, v2):
		print("[GAME] Road not connected to %s's network" % player.player_name)
		return false
	if not setup_free:
		if free:
			player.free_roads -= 1
		else:
			_spend_resources(player, ROAD_COST)
	roads.append({"player_index": player_idx, "v1": v1, "v2": v2})
	Log.info("[GAME] %s placed road (free=%s)  total: %d" % [player.player_name, free, roads.size()])
	GameEvents.record(GameEvents.EventType.ROAD_BUILT, player.player_name,
		{"free": free, "total_roads": roads.size()})
	update_longest_road()
	return true


func _road_is_connected(player: RefCounted, player_idx: int, v1: Vector3, v2: Vector3) -> bool:
	# During setup: road must connect to the JUST-placed settlement specifically
	if phase == Phase.SETUP and setup_sub_phase == SetupSubPhase.PLACE_ROAD:
		return _dist_xz(last_setup_pos, v1) < 0.15 or _dist_xz(last_setup_pos, v2) < 0.15

	# BUILD phase: connected if v1 or v2 has player's settlement
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


# --- Development cards ---

func buy_dev_card(player: RefCounted) -> bool:
	if dev_deck.is_empty():
		print("[GAME] Dev deck is empty!")
		return false
	if not _has_resources(player, DEV_COST):
		print("[GAME] %s cannot afford dev card (needs 1 Ore+Grain+Wool)" % player.player_name)
		return false
	_spend_resources(player, DEV_COST)
	var card: int = dev_deck.pop_back()
	_grant_dev_card_to_player(player, card, true)
	if card == DevCards.Type.VP:
		Log.info("[GAME] %s drew VP card — VP now %d  (deck: %d left)" % [
			player.player_name, player.victory_points, dev_deck.size()])
		GameEvents.record(GameEvents.EventType.DEV_CARD_BOUGHT, player.player_name,
			{"card": "VP", "deck_left": dev_deck.size()})
		_check_win()
	else:
		Log.info("[GAME] %s drew %s  (deck: %d left)" % [
			player.player_name, DevCards.NAMES[card], dev_deck.size()])
		GameEvents.record(GameEvents.EventType.DEV_CARD_BOUGHT, player.player_name,
			{"card": DevCards.NAMES[card], "deck_left": dev_deck.size()})
	return true


## Sprint 2B — returns false if timing rules prevent playing this card.
## Rules: max 1 dev card per turn; can't play a card bought this same turn.
func _can_play_card(player: RefCounted, card_type: int) -> bool:
	if card_type not in player.dev_cards:
		return false
	if dev_cards_played_this_turn >= 1:
		Log.warn("[GAME] %s already played a dev card this turn (max 1)" % player.player_name)
		return false
	# How many of this type did the player buy this turn?
	var bought_now: int = dev_cards_new_this_turn.get(card_type, 0)
	if bought_now > 0:
		# Count how many they own total vs. bought this turn
		var owned: int = 0
		for c in player.dev_cards:
			if c == card_type:
				owned += 1
		if owned <= bought_now:
			Log.warn("[GAME] %s can't play %s — bought this same turn" % [
				player.player_name, DevCards.NAMES[card_type]])
			return false
	return true


func play_knight(player: RefCounted, player_idx: int) -> bool:
	if not _can_play_card(player, DevCards.Type.KNIGHT):
		return false
	player.dev_cards.erase(DevCards.Type.KNIGHT)
	player.revealed_dev_cards.append(DevCards.Type.KNIGHT)
	player.knight_count += 1
	dev_cards_played_this_turn += 1
	print("[GAME] %s plays Knight (total knights: %d)" % [player.player_name, player.knight_count])
	GameEvents.record(GameEvents.EventType.DEV_CARD_PLAYED, player.player_name,
		{"card": "Knight", "knight_total": player.knight_count})
	_check_largest_army()
	robber_pick_pending = false
	phase = Phase.ROBBER_MOVE
	return true


func play_road_building(player: RefCounted) -> bool:
	if not _can_play_card(player, DevCards.Type.ROAD_BUILDING):
		return false
	player.dev_cards.erase(DevCards.Type.ROAD_BUILDING)
	player.revealed_dev_cards.append(DevCards.Type.ROAD_BUILDING)
	player.free_roads += 2
	dev_cards_played_this_turn += 1
	print("[GAME] %s plays Road Building — 2 free roads granted" % player.player_name)
	GameEvents.record(GameEvents.EventType.DEV_CARD_PLAYED, player.player_name,
		{"card": "Road Building"})
	return true


func play_year_of_plenty(player: RefCounted, res1: int, res2: int) -> bool:
	if not _can_play_card(player, DevCards.Type.YEAR_OF_PLENTY):
		return false
	var requested := {
		res1: 1,
		res2: 1,
	}
	if res1 == res2:
		requested[res1] = 2
	if not _bank_can_supply(requested):
		Log.warn("[GAME] Not enough bank supply for Year of Plenty")
		return false
	player.dev_cards.erase(DevCards.Type.YEAR_OF_PLENTY)
	player.revealed_dev_cards.append(DevCards.Type.YEAR_OF_PLENTY)
	_take_from_bank(player, res1, 1)
	_take_from_bank(player, res2, 1)
	dev_cards_played_this_turn += 1
	print("[GAME] %s plays Year of Plenty: +1 %s +1 %s" % [
		player.player_name, PlayerData.RES_NAMES[res1], PlayerData.RES_NAMES[res2]])
	GameEvents.record(GameEvents.EventType.DEV_CARD_PLAYED, player.player_name,
		{"card": "Year of Plenty", "r1": PlayerData.RES_NAMES[res1], "r2": PlayerData.RES_NAMES[res2]})
	return true


func play_monopoly(player: RefCounted, res: int) -> bool:
	if not _can_play_card(player, DevCards.Type.MONOPOLY):
		return false
	player.dev_cards.erase(DevCards.Type.MONOPOLY)
	player.revealed_dev_cards.append(DevCards.Type.MONOPOLY)
	var total := 0
	for p in players:
		if p == player:
			continue
		var amt: int = p.resources.get(res, 0)
		if amt > 0:
			p.resources[res] = 0
			total += amt
	player.add_resource(res, total)
	dev_cards_played_this_turn += 1
	print("[GAME] %s plays Monopoly on %s — stole %d total" % [
		player.player_name, PlayerData.RES_NAMES[res], total])
	GameEvents.record(GameEvents.EventType.DEV_CARD_PLAYED, player.player_name,
		{"card": "Monopoly", "resource": PlayerData.RES_NAMES[res], "stolen": total})
	return true


# --- Bank trading (Sprint 2A: harbour-aware rates) ---

## Returns the best trade rate for `give_res` considering the player's harbour access.
func _get_trade_rate(player: RefCounted, give_res: int) -> int:
	var best := 4
	for h: Dictionary in HexGrid.HARBORS:
		var v1 := Vector3(h["v1x"], 0.0, h["v1z"])
		var v2 := Vector3(h["v2x"], 0.0, h["v2z"])
		var at_port := false
		for spos in player.settlement_positions:
			if _dist_xz(spos, v1) < 0.25 or _dist_xz(spos, v2) < 0.25:
				at_port = true
				break
		if not at_port:
			continue
		var h_type: int = h["type"]
		if h_type == HexGrid.HARBOR_GENERIC:
			best = mini(best, 3)
		elif h_type == give_res:
			best = mini(best, 2)
	return best


func bank_trade(player: RefCounted, give_res: int, recv_res: int) -> bool:
	var rate: int = _get_trade_rate(player, give_res)
	if player.resources.get(give_res, 0) < rate:
		print("[GAME] %s cannot afford bank trade (%d %s needed)" % [
			player.player_name, rate, PlayerData.RES_NAMES[give_res]])
		return false
	if resource_bank.get(recv_res, 0) < 1:
		Log.warn("[GAME] Bank has no %s left for trade" % PlayerData.RES_NAMES[recv_res])
		return false
	player.resources[give_res] -= rate
	_return_to_bank(give_res, rate)
	_take_from_bank(player, recv_res, 1)
	Log.info("[GAME] %s bank trade: %d %s → 1 %s (rate %d:1)" % [
		player.player_name, rate,
		PlayerData.RES_NAMES[give_res], PlayerData.RES_NAMES[recv_res], rate])
	GameEvents.record(GameEvents.EventType.BANK_TRADE, player.player_name, {
		"give": PlayerData.RES_NAMES[give_res],
		"recv": PlayerData.RES_NAMES[recv_res], "rate": rate})
	return true


## Returns [give_res, recv_res] for the best available trade, or [] if none possible.
func best_bank_trade(player: RefCounted) -> Array:
	var surplus := -1
	var surplus_rate := 4
	for r in [0, 1, 2, 3, 4]:
		var rate := _get_trade_rate(player, r)
		if player.resources.get(r, 0) >= rate:
			surplus = r; surplus_rate = rate
			break
	if surplus < 0:
		return []
	var need := -1
	var min_amt := 999
	for r in [0, 1, 2, 3, 4]:
		if r == surplus:
			continue
		if player.resources.get(r, 0) < min_amt:
			min_amt = player.resources.get(r, 0); need = r
	if need < 0:
		return []
	return [surplus, need]


## Sprint 2C — execute a player-to-player trade. Returns true if successful.
func player_trade(from_player: RefCounted, to_player: RefCounted,
		offer: Dictionary, want: Dictionary) -> bool:
	# Validate from_player has what they offer
	for r in offer:
		if from_player.resources.get(r, 0) < offer[r]:
			Log.warn("[TRADE] %s doesn't have enough to offer" % from_player.player_name)
			return false
	# Validate to_player has what's wanted
	for r in want:
		if to_player.resources.get(r, 0) < want[r]:
			Log.warn("[TRADE] %s doesn't have what's wanted" % to_player.player_name)
			return false
	# Execute
	for r in offer:
		from_player.resources[r] -= offer[r]
		to_player.resources[r]   = to_player.resources.get(r, 0) + offer[r]
	for r in want:
		to_player.resources[r]   -= want[r]
		from_player.resources[r]  = from_player.resources.get(r, 0) + want[r]
	Log.info("[TRADE] %s ↔ %s completed" % [from_player.player_name, to_player.player_name])
	GameEvents.record(GameEvents.EventType.BANK_TRADE, from_player.player_name,
		{"with": to_player.player_name, "offer": offer, "want": want})
	return true


# --- Longest Road ---

func update_longest_road() -> void:
	var changed := false
	for i in players.size():
		var length := _compute_road_length(i)
		if length >= 5 and length > longest_road_length:
			if longest_road_holder != i:
				if longest_road_holder >= 0:
					players[longest_road_holder].victory_points -= 2
					Log.info("[GAME] %s loses Longest Road" % players[longest_road_holder].player_name)
				longest_road_holder = i
				longest_road_length = length
				players[i].victory_points += 2
				Log.info("[GAME] %s takes Longest Road (%d) — VP:%d" % [
					players[i].player_name, length, players[i].victory_points])
				GameEvents.record(GameEvents.EventType.LONGEST_ROAD, players[i].player_name,
					{"length": length, "vp": players[i].victory_points})
				changed = true
				_check_win()
	if changed:
		bonuses_changed.emit()


func _compute_road_length(player_idx: int) -> int:
	# Build vertex adjacency from this player's roads
	var adj: Dictionary = {}
	for road in roads:
		if road.player_index != player_idx:
			continue
		var k1 := _vkey(road.v1)
		var k2 := _vkey(road.v2)
		if k1 not in adj: adj[k1] = []
		if k2 not in adj: adj[k2] = []
		if k2 not in adj[k1]: adj[k1].append(k2)
		if k1 not in adj[k2]: adj[k2].append(k1)
	if adj.is_empty():
		return 0
	var max_len := 0
	for start in adj:
		var visited_edges: Array = []
		var length := _dfs_road(adj, start, visited_edges)
		if length > max_len:
			max_len = length
	return max_len


func _dfs_road(adj: Dictionary, current: String, visited_edges: Array) -> int:
	var max_len := 0
	for neighbor in adj.get(current, []):
		var edge_key: String = (current + "|" + neighbor) if current < neighbor else (neighbor + "|" + current)
		if edge_key in visited_edges:
			continue
		visited_edges.append(edge_key)
		var length := 1 + _dfs_road(adj, neighbor, visited_edges)
		visited_edges.pop_back()
		if length > max_len:
			max_len = length
	return max_len


func _vkey(v: Vector3) -> String:
	return "%d_%d" % [roundi(v.x * 100), roundi(v.z * 100)]


# --- Largest Army ---

func _check_largest_army() -> void:
	var changed := false
	for i in players.size():
		var knights: int = players[i].knight_count
		if knights >= 3 and knights > largest_army_size:
			if largest_army_holder != i:
				if largest_army_holder >= 0:
					players[largest_army_holder].victory_points -= 2
					print("[GAME] %s loses Largest Army" % players[largest_army_holder].player_name)
				largest_army_holder = i
				largest_army_size = knights
				players[i].victory_points += 2
				print("[GAME] %s takes Largest Army (%d knights) — VP:%d" % [
					players[i].player_name, knights, players[i].victory_points])
				GameEvents.record(GameEvents.EventType.LARGEST_ARMY, players[i].player_name,
					{"knights": knights, "vp": players[i].victory_points})
				changed = true
				_check_win()
	if changed:
		bonuses_changed.emit()


# --- Turn management ---

func end_turn() -> void:
	if phase == Phase.GAME_OVER:
		return
	Log.debug("[GAME] %s ends turn" % current_player().player_name)
	_print_all_resources()
	GameEvents.advance_turn(current_player().player_name)
	current_player_index = (current_player_index + 1) % players.size()
	last_roll = 0
	phase     = Phase.ROLL
	# Sprint 2B: reset per-turn dev card counters
	dev_cards_new_this_turn    = {}
	dev_cards_played_this_turn = 0
	Log.info("[GAME] → %s's turn  [%s]" % [current_player().player_name, phase_name()])
	turn_changed.emit(current_player())


func _check_win() -> void:
	for i in players.size():
		if players[i].victory_points >= WIN_VP:
			winner_index = i
			phase = Phase.GAME_OVER
			Log.info("[GAME] *** %s WINS with %d VP! ***" % [
				players[i].player_name, players[i].victory_points])
			GameEvents.record(GameEvents.EventType.GAME_OVER, players[i].player_name,
				{"vp": players[i].victory_points, "turns": GameEvents.turn_number})
			game_won.emit(players[i])
			return


# --- Helpers ---

func debug_adjust_resource(player_idx: int, res: int, amount: int) -> int:
	var player := get_player(player_idx)
	if player == null or amount == 0:
		return 0
	if amount > 0:
		var granted: int = mini(amount, int(resource_bank.get(res, 0)))
		if granted > 0:
			_take_from_bank(player, res, granted)
		return granted
	var removed: int = mini(-amount, int(player.resources.get(res, 0)))
	if removed > 0:
		player.resources[res] -= removed
		_return_to_bank(res, removed)
	return -removed


func debug_take_dev_card(player_idx: int, card_type: int) -> bool:
	var player := get_player(player_idx)
	if player == null:
		return false
	var deck_index: int = dev_deck.find(card_type)
	if deck_index < 0:
		return false
	dev_deck.remove_at(deck_index)
	_grant_dev_card_to_player(player, card_type, false)
	if card_type == DevCards.Type.VP:
		_check_win()
	return true


func debug_draw_dev_card(player_idx: int) -> bool:
	var player := get_player(player_idx)
	if player == null or dev_deck.is_empty():
		return false
	var card_type: int = dev_deck.pop_back()
	_grant_dev_card_to_player(player, card_type, false)
	if card_type == DevCards.Type.VP:
		_check_win()
	return true


func _new_resource_bank() -> Dictionary:
	return {
		PlayerData.RES_LUMBER: RESOURCE_BANK_START,
		PlayerData.RES_BRICK: RESOURCE_BANK_START,
		PlayerData.RES_WOOL: RESOURCE_BANK_START,
		PlayerData.RES_GRAIN: RESOURCE_BANK_START,
		PlayerData.RES_ORE: RESOURCE_BANK_START,
	}


func _bank_can_supply(requested: Dictionary) -> bool:
	for res in requested:
		if int(resource_bank.get(res, 0)) < int(requested[res]):
			return false
	return true


func _take_from_bank(player: RefCounted, res: int, amount: int) -> bool:
	if amount <= 0:
		return true
	if int(resource_bank.get(res, 0)) < amount:
		return false
	resource_bank[res] = int(resource_bank.get(res, 0)) - amount
	player.add_resource(res, amount)
	return true


func _return_to_bank(res: int, amount: int) -> void:
	if amount <= 0:
		return
	resource_bank[res] = clampi(int(resource_bank.get(res, 0)) + amount, 0, RESOURCE_BANK_START)


func _return_resources_to_bank(cost: Dictionary) -> void:
	for res in cost:
		_return_to_bank(int(res), int(cost[res]))


func _grant_dev_card_to_player(player: RefCounted, card_type: int, mark_new_this_turn: bool) -> void:
	if card_type == DevCards.Type.VP:
		player.revealed_dev_cards.append(card_type)
		player.victory_points += 1
		return
	player.dev_cards.append(card_type)
	if mark_new_this_turn:
		dev_cards_new_this_turn[card_type] = dev_cards_new_this_turn.get(card_type, 0) + 1


func _has_resources(player: RefCounted, cost: Dictionary) -> bool:
	for r in cost:
		if player.resources.get(r, 0) < cost[r]:
			return false
	return true


func _spend_resources(player: RefCounted, cost: Dictionary) -> void:
	for r in cost:
		player.resources[r] -= cost[r]
		_return_to_bank(r, int(cost[r]))


func _has_settlement_at(player: RefCounted, pos: Vector3) -> bool:
	for settlement_pos in player.settlement_positions:
		if _dist_xz(settlement_pos, pos) < 0.1:
			return true
	return false


func _has_connected_road_for_settlement(player: RefCounted, pos: Vector3) -> bool:
	var player_idx: int = players.find(player)
	if player_idx < 0:
		return false
	for road in roads:
		if road.player_index != player_idx:
			continue
		if _dist_xz(road.v1, pos) < 0.1 or _dist_xz(road.v2, pos) < 0.1:
			return true
	return false


func _road_exists(v1: Vector3, v2: Vector3) -> bool:
	for road in roads:
		var same_dir := _dist_xz(road.v1, v1) < 0.1 and _dist_xz(road.v2, v2) < 0.1
		var reverse_dir := _dist_xz(road.v1, v2) < 0.1 and _dist_xz(road.v2, v1) < 0.1
		if same_dir or reverse_dir:
			return true
	return false


func _print_all_resources() -> void:
	print("[GAME] --- End-of-turn snapshot ---")
	for p in players:
		print("  %s" % p.debug_summary())
