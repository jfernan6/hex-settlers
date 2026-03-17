extends RefCounted

## Holds all data for one player: resources, settlements, victory points.

const RES_LUMBER := 0
const RES_BRICK  := 1
const RES_WOOL   := 2
const RES_GRAIN  := 3
const RES_ORE    := 4

const RES_NAMES: Dictionary = {
	0: "Lumber", 1: "Brick", 2: "Wool", 3: "Grain", 4: "Ore"
}

# Settlement costs: 1 of each (no ORE)
const SETTLEMENT_COST: Dictionary = {0: 1, 1: 1, 2: 1, 3: 1}

var player_name: String
var color: Color
var resources: Dictionary       # int -> int
var settlement_positions: Array # Array[Vector3]
var city_positions: Array       # Array[Vector3] — subset of settlement_positions
var victory_points: int = 0
var free_placements_left: int = 2

# Development cards
var dev_cards: Array = []   # Array of DevCards.Type ints (playable hand)
var knight_count: int = 0   # total knights played (for Largest Army tracking)
var free_roads: int = 0     # free roads remaining from Road Building card

# AI flag — set true for computer-controlled players
var is_ai: bool = false


func _init(p_name: String, p_color: Color) -> void:
	player_name    = p_name
	color          = p_color
	victory_points = 0
	resources      = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	settlement_positions = []
	city_positions       = []
	dev_cards            = []
	knight_count         = 0
	free_roads           = 0


# --- Resources ---

func add_resource(res: int, amount: int = 1) -> void:
	resources[res] = resources.get(res, 0) + amount
	Log.debug("[PLAYER] %s +%d %s  (now: %d)" % [
		player_name, amount, RES_NAMES[res], resources[res]])


func can_build_settlement() -> bool:
	# Standard Catan: max 5 settlement pieces total (cities consume a settlement slot)
	var active_settlements: int = settlement_positions.size() - city_positions.size()
	if active_settlements >= 5:
		return false
	if free_placements_left > 0:
		return true
	for r in SETTLEMENT_COST:
		if resources.get(r, 0) < SETTLEMENT_COST[r]:
			return false
	return true


func place_settlement(pos: Vector3) -> void:
	if free_placements_left > 0:
		free_placements_left -= 1
	else:
		for r in SETTLEMENT_COST:
			resources[r] -= SETTLEMENT_COST[r]
	settlement_positions.append(pos)
	victory_points += 1
	Log.info("[PLAYER] %s placed settlement @ (%.1f,%.1f) | VP:%d | free left:%d" % [
		player_name, pos.x, pos.z, victory_points, free_placements_left])
	GameEvents.record(GameEvents.EventType.SETTLEMENT_PLACED, player_name, {
		"pos_x": pos.x, "pos_z": pos.z, "vp": victory_points})


# --- Display ---

func resource_summary() -> String:
	var parts := []
	for r in [0, 1, 2, 3, 4]:
		parts.append("%s: %d" % [RES_NAMES[r], resources.get(r, 0)])
	return "\n".join(parts)


func debug_summary() -> String:
	var card_str := "cards:%d" % dev_cards.size()
	return "[%s%s] VP:%d  Free:%d  Res:%s  S:%d  %s  KN:%d" % [
		player_name,
		" (AI)" if is_ai else "",
		victory_points, free_placements_left,
		_short_resources(), settlement_positions.size(),
		card_str, knight_count]


func _short_resources() -> String:
	var parts := []
	for r in [0, 1, 2, 3, 4]:
		var name_short: String = RES_NAMES[r].left(2)
		parts.append("%s:%d" % [name_short, resources.get(r, 0)])
	return " ".join(parts)
