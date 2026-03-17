extends Node

## Structured game event recorder. Registered as Autoload "GameEvents".
## Records every meaningful game action with turn number, player, and event type.
## Separate from debug logging — this is game history, not console spam.

enum EventType {
	TURN_START,
	DICE_ROLLED,
	RESOURCE_COLLECTED,
	RESOURCE_DISCARDED,
	SETTLEMENT_PLACED,
	ROAD_BUILT,
	CITY_BUILT,
	DEV_CARD_BOUGHT,
	DEV_CARD_PLAYED,
	ROBBER_MOVED,
	RESOURCE_STOLEN,
	BANK_TRADE,
	LONGEST_ROAD,
	LARGEST_ARMY,
	GAME_OVER,
}

const TYPE_NAMES: Dictionary = {
	EventType.TURN_START:          "TURN_START",
	EventType.DICE_ROLLED:         "DICE_ROLLED",
	EventType.RESOURCE_COLLECTED:  "RESOURCE_COLLECTED",
	EventType.RESOURCE_DISCARDED:  "RESOURCE_DISCARDED",
	EventType.SETTLEMENT_PLACED:   "SETTLEMENT_PLACED",
	EventType.ROAD_BUILT:          "ROAD_BUILT",
	EventType.CITY_BUILT:          "CITY_BUILT",
	EventType.DEV_CARD_BOUGHT:     "DEV_CARD_BOUGHT",
	EventType.DEV_CARD_PLAYED:     "DEV_CARD_PLAYED",
	EventType.ROBBER_MOVED:        "ROBBER_MOVED",
	EventType.RESOURCE_STOLEN:     "RESOURCE_STOLEN",
	EventType.BANK_TRADE:          "BANK_TRADE",
	EventType.LONGEST_ROAD:        "LONGEST_ROAD",
	EventType.LARGEST_ARMY:        "LARGEST_ARMY",
	EventType.GAME_OVER:           "GAME_OVER",
}

var entries: Array = []
var turn_number: int = 0


func record(type: int, player_name: String, data: Dictionary = {}) -> void:
	entries.append({
		"turn":      turn_number,
		"player":    player_name,
		"type":      type,
		"type_name": TYPE_NAMES.get(type, "UNKNOWN"),
		"data":      data,
		"ms":        Time.get_ticks_msec(),
	})


func advance_turn(player_name: String) -> void:
	turn_number += 1
	record(EventType.TURN_START, player_name, {"turn": turn_number})


func get_recent(n: int = 10) -> Array:
	return entries.slice(max(0, entries.size() - n))


## Human-readable game recap (counts by event type + final VP).
func summary() -> String:
	if entries.is_empty():
		return "No events recorded."
	var lines: Array = []
	lines.append("=== Game Event Summary (%d events, %d turns) ===" % [
		entries.size(), turn_number])
	var type_counts: Dictionary = {}
	for e in entries:
		type_counts[e.type_name] = type_counts.get(e.type_name, 0) + 1
	for key in type_counts:
		lines.append("  %-22s %d" % [key + ":", type_counts[key]])
	return "\n".join(lines)


func clear() -> void:
	entries.clear()
	turn_number = 0
