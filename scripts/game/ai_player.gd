## Greedy AI strategy helper.
## All methods are static — call without instantiation.
## Priority: city > settlement > road > dev card > bank trade > end turn.

const HexGrid    = preload("res://scripts/board/hex_grid.gd")
const PlayerData = preload("res://scripts/player/player.gd")
const DevCards   = preload("res://scripts/game/dev_cards.gd")

const PROX := HexGrid.HEX_SIZE * 1.15


# ---------------------------------------------------------------
# Setup placement
# ---------------------------------------------------------------

## Returns the best unoccupied vertex for a settlement (highest pip sum).
## Respects the Catan distance rule (no settlement adjacent to another).
static func pick_setup_vertex(vertex_slots: Array, tile_data: Dictionary, state = null) -> Object:
	var best: Object = null
	var best_score := -1
	for slot in vertex_slots:
		if slot.is_occupied:
			continue
		# Enforce distance rule if state is provided
		if state != null and not state._respects_distance_rule(slot.position):
			continue
		var score := _vertex_pip_score(slot.position, tile_data)
		if score > best_score:
			best_score = score
			best = slot
	return best


## Pip score for a vertex = sum of (6 - |7 - number|) for each adjacent non-desert tile.
static func _vertex_pip_score(pos: Vector3, tile_data: Dictionary) -> int:
	var score := 0
	for key in tile_data:
		var tile: Dictionary = tile_data[key]
		if tile.number <= 0:
			continue
		var center: Vector3 = tile.center
		var dx: float = pos.x - center.x
		var dz: float = pos.z - center.z
		if sqrt(dx * dx + dz * dz) < PROX:
			score += 6 - abs(7 - tile.number)
	return score


# ---------------------------------------------------------------
# Road placement
# ---------------------------------------------------------------

## Returns the first unoccupied edge connected to player's settlement/road network,
## preferring edges that lead toward high-value unoccupied vertices.
static func pick_road(edge_slots: Array, player: RefCounted, state: RefCounted) -> Object:
	for slot in edge_slots:
		if slot.is_occupied:
			continue
		if _edge_is_connected(slot, player, state):
			return slot
	return null


static func _edge_is_connected(slot: Object, player: RefCounted, state: RefCounted) -> bool:
	for spos in player.settlement_positions:
		if _dist(slot.v1, spos) < 0.15 or _dist(slot.v2, spos) < 0.15:
			return true
	for road in state.roads:
		if road.player_index != state.current_player_index:
			continue
		var rv1: Vector3 = road.v1
		var rv2: Vector3 = road.v2
		if _dist(rv1, slot.v1) < 0.15 or _dist(rv1, slot.v2) < 0.15:
			return true
		if _dist(rv2, slot.v1) < 0.15 or _dist(rv2, slot.v2) < 0.15:
			return true
	return false


# ---------------------------------------------------------------
# Build decision (called during BUILD phase)
# ---------------------------------------------------------------

## Returns a decision dict: {action: String, params: Dictionary}
## Plays optimally using known public information only.
static func decide_build(player: RefCounted, state: RefCounted,
		vertex_slots: Array, edge_slots: Array) -> Dictionary:

	var pidx: int = state.current_player_index

	# --- Aggressive bank trading first: dump 4+ surplus before deciding ---
	# Keeps resource count low and converts junk into useful cards
	var trade: Array = state.best_bank_trade(player)
	if not trade.is_empty():
		return {"action": "bank_trade", "params": {"give": trade[0], "recv": trade[1]}}

	# --- Play cards already in hand (free actions, if timing rules allow) ---
	if state.dev_cards_played_this_turn < 1:
		var playable := _best_card_to_play(player, state)
		if playable >= 0:
			return {"action": "play_card", "params": {"card": playable}}

	# --- City: best VP/resource ratio ---
	if _can_afford(player, state.CITY_COST):
		for slot in vertex_slots:
			if slot.is_occupied and slot.owner_index == pidx and not slot.is_city:
				return {"action": "city", "params": {"slot": slot}}

	# --- Settlement: only if a valid reachable spot exists ---
	if player.can_build_settlement() and player.free_placements_left == 0:
		var best := _best_reachable_vertex(vertex_slots, player, state, pidx)
		if best != null:
			return {"action": "settlement", "params": {"slot": best}}

	# --- Dev card: buy when can afford and deck has cards ---
	if _can_afford(player, state.DEV_COST) and not state.dev_deck.is_empty():
		return {"action": "dev_card", "params": {}}

	# --- Road: only if it leads somewhere (reachable expansion vertex exists) ---
	if player.free_roads > 0 or _can_afford(player, state.ROAD_COST):
		# Only build road if it opens up a valid settlement spot
		var road_slot := pick_road(edge_slots, player, state)
		if road_slot != null:
			var opens_spot := _road_opens_settlement(road_slot, vertex_slots, player, state, pidx)
			if opens_spot or player.free_roads > 0:
				return {"action": "road", "params": {"slot": road_slot}}

	return {"action": "end_turn", "params": {}}


## Returns true if placing this road would open a reachable settlement spot.
static func _road_opens_settlement(road_slot: Object, vertex_slots: Array,
		player: RefCounted, state: RefCounted, pidx: int) -> bool:
	var v1: Vector3 = road_slot.v1
	var v2: Vector3 = road_slot.v2
	for slot in vertex_slots:
		if slot.is_occupied:
			continue
		if not state._respects_distance_rule(slot.position):
			continue
		if _dist(slot.position, v1) < 0.15 or _dist(slot.position, v2) < 0.15:
			return true
	return false


## Best vertex reachable from the player's road network that also passes
## the distance rule. Returns null if no valid expansion spot exists.
static func _best_reachable_vertex(vertex_slots: Array, player: RefCounted,
		state: RefCounted, pidx: int) -> Object:
	var best: Object = null
	var best_score := -1
	for slot in vertex_slots:
		if slot.is_occupied:
			continue
		# Must respect Catan distance rule
		if not state._respects_distance_rule(slot.position):
			continue
		# Must be adjacent to player's existing road
		var reachable := false
		for road in state.roads:
			if road.player_index != pidx:
				continue
			if _dist(road.v1, slot.position) < 0.15 or _dist(road.v2, slot.position) < 0.15:
				reachable = true
				break
		if not reachable:
			continue
		var score := _vertex_pip_score(slot.position, state.tile_data)
		if score > best_score:
			best_score = score
			best = slot
	return best


## Returns the best card type to play, or -1 if none.
## Respects Sprint 2B timing rules: can't play a card bought this same turn.
static func _best_card_to_play(player: RefCounted, state: RefCounted = null) -> int:
	for card_type in [DevCards.Type.KNIGHT, DevCards.Type.YEAR_OF_PLENTY,
			DevCards.Type.MONOPOLY, DevCards.Type.ROAD_BUILDING]:
		if card_type not in player.dev_cards:
			continue
		# Skip cards bought this turn (timing rule)
		if state != null:
			var bought_now: int = state.dev_cards_new_this_turn.get(card_type, 0)
			if bought_now > 0:
				var owned := 0
				for c in player.dev_cards:
					if c == card_type:
						owned += 1
				if owned <= bought_now:
					continue
		return card_type
	return -1


## Resource the AI most wants (lowest quantity in hand, non-zero for settlement build).
static func most_needed_resource(player: RefCounted) -> int:
	var need := 0
	var min_amt := 999
	for r in [0, 1, 2, 3, 4]:
		if player.resources.get(r, 0) < min_amt:
			min_amt = player.resources.get(r, 0)
			need = r
	return need


# ---------------------------------------------------------------
# Robber placement (called during ROBBER_MOVE phase)
# ---------------------------------------------------------------

## Returns the tile key the AI should move the robber to:
## picks the tile that blocks the opponent with the most settlements adjacent.
static func pick_robber_tile(state: RefCounted, player_idx: int) -> String:
	var best_key := ""
	var best_score := -1
	for key in state.tile_data:
		if key == state.robber_tile_key:
			continue
		var tile: Dictionary = state.tile_data[key]
		if tile.number <= 0:
			continue  # desert
		var center: Vector3 = tile.center
		var score := 0
		for i in state.players.size():
			if i == player_idx:
				continue
			for spos in state.players[i].settlement_positions:
				if _dist(spos, center) < state.PROX:
					score += 2 if state._is_city_at(state.players[i], spos) else 1
		# Weight by tile production value
		score *= (6 - abs(7 - tile.number))
		if score > best_score:
			best_score = score
			best_key = key
	# Fallback: any non-current tile
	if best_key == "":
		for key in state.tile_data:
			if key != state.robber_tile_key:
				best_key = key
				break
	return best_key


# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------

static func _can_afford(player: RefCounted, cost: Dictionary) -> bool:
	for r in cost:
		if player.resources.get(r, 0) < cost[r]:
			return false
	return true


static func _dist(a: Vector3, b: Vector3) -> float:
	var dx: float = a.x - b.x
	var dz: float = a.z - b.z
	return sqrt(dx * dx + dz * dz)
