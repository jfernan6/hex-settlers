extends Node

## Structured game event recorder. Registered as Autoload "GameEvents".
## Records every meaningful game action with turn number, player, and event type.
## Use flush_to_file() to dump a full log after --debug-fullgame runs.
## Use validate() to check that recorded events obey Catan rules.

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
var _game_start_ms: int = 0


# ---------------------------------------------------------------
# Core recording
# ---------------------------------------------------------------

func record(type: int, player_name: String, data: Dictionary = {}) -> void:
	if _game_start_ms == 0:
		_game_start_ms = Time.get_ticks_msec()
	entries.append({
		"turn":      turn_number,
		"player":    player_name,
		"type":      type,
		"type_name": TYPE_NAMES.get(type, "UNKNOWN"),
		"data":      data,
		"ms":        Time.get_ticks_msec() - _game_start_ms,
	})


func advance_turn(player_name: String) -> void:
	turn_number += 1
	record(EventType.TURN_START, player_name, {"turn": turn_number})


func get_recent(n: int = 10) -> Array:
	return entries.slice(max(0, entries.size() - n))


func clear() -> void:
	entries.clear()
	turn_number = 0
	_game_start_ms = 0


# ---------------------------------------------------------------
# Validation — checks recorded events obey Catan rules.
# Returns an Array of human-readable issue strings (empty = all OK).
# ---------------------------------------------------------------

func validate() -> Array:
	var issues: Array = []

	# 1. Exactly one GAME_OVER
	var go_events: Array = entries.filter(func(e): return e.type == EventType.GAME_OVER)
	if go_events.is_empty():
		issues.append("No GAME_OVER event recorded — game may not have ended cleanly")
	elif go_events.size() > 1:
		issues.append("Multiple GAME_OVER events (%d) — only one expected" % go_events.size())
	else:
		var vp: int = go_events[0].data.get("vp", -1)
		if vp < 10:
			issues.append("GAME_OVER recorded with VP=%d (must be ≥ 10)" % vp)
		var turns: int = go_events[0].data.get("turns", 0)
		if turns != turn_number:
			issues.append("GAME_OVER turn field (%d) ≠ recorded turn_number (%d)" % [turns, turn_number])

	# 2. All dice rolls in [2, 12]
	for e in entries:
		if e.type == EventType.DICE_ROLLED:
			var roll: int = e.data.get("roll", 0)
			if roll < 2 or roll > 12:
				issues.append("T%d: Invalid dice roll %d (must be 2–12)" % [e.turn, roll])

	# 3. TURN_START events are strictly sequential
	var expected: int = 1
	for e in entries:
		if e.type == EventType.TURN_START:
			var t: int = e.data.get("turn", 0)
			if t != expected:
				issues.append("Turn sequence: expected %d, got %d" % [expected, t])
				expected = t   # re-sync so we don't flood with follow-on errors
			else:
				expected += 1

	# 4. Longest Road length must be ≥ 5
	for e in entries:
		if e.type == EventType.LONGEST_ROAD:
			var length: int = e.data.get("length", 0)
			if length < 5:
				issues.append("T%d: Longest Road awarded with length=%d (must be ≥ 5)" % [e.turn, length])

	# 5. Largest Army knights must be ≥ 3
	for e in entries:
		if e.type == EventType.LARGEST_ARMY:
			var knights: int = e.data.get("knights", 0)
			if knights < 3:
				issues.append("T%d: Largest Army awarded with knights=%d (must be ≥ 3)" % [e.turn, knights])

	# 6. City VP must be > 0
	for e in entries:
		if e.type == EventType.CITY_BUILT:
			var vp: int = e.data.get("vp", 0)
			if vp <= 0:
				issues.append("T%d: CITY_BUILT recorded with VP=%d (must be > 0)" % [e.turn, vp])

	# 7. No RESOURCE_COLLECTED events with zero total
	for e in entries:
		if e.type == EventType.RESOURCE_COLLECTED:
			var total: int = e.data.get("total", 1)   # default 1 = not suspicious
			if total == 0:
				issues.append("T%d: RESOURCE_COLLECTED recorded with total=0 (no-op)" % e.turn)

	return issues


# ---------------------------------------------------------------
# Per-player statistics derived from the event log
# ---------------------------------------------------------------

func get_player_stats() -> Dictionary:
	var stats: Dictionary = {}
	for e in entries:
		var p: String = e.player
		if p == "all" or p == "":
			continue
		if p not in stats:
			stats[p] = {
				"settlements": 0, "cities": 0, "roads": 0,
				"dev_cards_bought": 0, "dev_cards_played": 0,
				"bank_trades": 0, "resources_stolen": 0,
				"times_robbed": 0, "final_vp": 0, "winner": false,
			}
		var s: Dictionary = stats[p]
		match e.type:
			EventType.SETTLEMENT_PLACED:
				s.settlements += 1
				if e.data.has("vp"):
					s.final_vp = maxi(s.final_vp, e.data["vp"])
			EventType.CITY_BUILT:
				s.cities += 1
				s.final_vp = maxi(s.final_vp, e.data.get("vp", s.final_vp))
			EventType.ROAD_BUILT:        s.roads += 1
			EventType.DEV_CARD_BOUGHT:   s.dev_cards_bought += 1
			EventType.DEV_CARD_PLAYED:   s.dev_cards_played += 1
			EventType.BANK_TRADE:        s.bank_trades += 1
			EventType.RESOURCE_STOLEN:   s.resources_stolen += 1
			EventType.GAME_OVER:
				s.final_vp = e.data.get("vp", s.final_vp)
				s.winner   = true
	# Capture VP of non-winner from their last city/settlement if no GAME_OVER
	return stats


# ---------------------------------------------------------------
# File output — call after a game ends to persist the full log
# ---------------------------------------------------------------

## Write events.json + events.txt into a session directory.
##
## session_dir: if provided (by debug_controller, which already created the dir),
##   write directly into it. If empty, create a new timestamped session dir.
## Returns the session dir path used (so callers can co-locate screenshots).
func flush_to_file(label: String = "", session_dir: String = "") -> String:
	var sess: String
	if session_dir != "":
		sess = session_dir
	else:
		var dt := Time.get_datetime_dict_from_system()
		var ts  := "%04d%02d%02d_%02d%02d%02d" % [
			dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
		var pfx := (label + "_") if label != "" else ""
		sess = Log.SESSION_DIR + pfx + ts + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sess))

	# --- JSON (machine-readable) ---
	var json_obj := {
		"turns":       turn_number,
		"event_count": entries.size(),
		"events":      entries,
	}
	var f_json := FileAccess.open(sess + "events.json", FileAccess.WRITE)
	if f_json:
		f_json.store_string(JSON.stringify(json_obj, "\t"))
		f_json.close()

	# --- Human-readable text ---
	var f_txt := FileAccess.open(sess + "events.txt", FileAccess.WRITE)
	if f_txt:
		f_txt.store_string(_build_text_log())
		f_txt.close()

	print("[EVENTS] Log saved → %sevents.json + events.txt" % sess)

	# Prune oldest sessions if cap exceeded
	_prune_old_sessions()

	return sess


## Delete oldest session directories beyond max_keep.
## Timestamp-named folders sort chronologically, so oldest = first after sort.
func _prune_old_sessions(max_keep: int = 20) -> void:
	var base_abs := ProjectSettings.globalize_path(Log.SESSION_DIR)
	var d := DirAccess.open(base_abs)
	if d == null:
		return
	var folders: Array = []
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if d.current_is_dir() and not name.begins_with("."):
			folders.append(name)
		name = d.get_next()
	d.list_dir_end()
	folders.sort()   # timestamp names sort chronologically; oldest first
	while folders.size() > max_keep:
		_delete_dir_recursive(base_abs + "/" + folders.pop_front())


func _delete_dir_recursive(abs_path: String) -> void:
	var d := DirAccess.open(abs_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not name.begins_with("."):
			if d.current_is_dir():
				_delete_dir_recursive(abs_path + "/" + name)
			else:
				d.remove(name)
		name = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(abs_path)


func _build_text_log() -> String:
	var lines: Array = []
	var dur_s: float = entries[-1].ms / 1000.0 if not entries.is_empty() else 0.0

	lines.append("╔══════════════════════════════════════════════════════╗")
	lines.append("║          HEX SETTLERS — FULL GAME EVENT LOG          ║")
	lines.append("╚══════════════════════════════════════════════════════╝")
	lines.append("%d turns | %d events | %.1fs" % [turn_number, entries.size(), dur_s])
	lines.append("")

	# --- Event timeline ---
	lines.append("── TIMELINE ────────────────────────────────────────────")
	for e in entries:
		var data_str := _fmt_data(e.type, e.data)
		lines.append("T%04d  %-16s  %-20s  %s" % [
			e.turn, e.player.left(16), e.type_name, data_str])

	# --- Validation ---
	lines.append("")
	lines.append("── VALIDATION ──────────────────────────────────────────")
	var issues := validate()
	if issues.is_empty():
		lines.append("  ✓  All %d events valid. No rule violations detected." % entries.size())
	else:
		lines.append("  %d VIOLATION(S) FOUND:" % issues.size())
		for issue in issues:
			lines.append("  ✗  " + issue)

	# --- Per-player summary ---
	lines.append("")
	lines.append("── PLAYER SUMMARY ──────────────────────────────────────")
	var stats := get_player_stats()
	for player in stats:
		var s: Dictionary = stats[player]
		var tag := "  ★ WINNER" if s.winner else "        "
		lines.append("  %s  %s" % [tag, player])
		lines.append("         VP: %d | S:%d  C:%d  R:%d | dev_bought:%d  dev_played:%d | trades:%d  stolen:%d" % [
			s.final_vp, s.settlements, s.cities, s.roads,
			s.dev_cards_bought, s.dev_cards_played, s.bank_trades, s.resources_stolen])

	lines.append("")
	return "\n".join(lines)


func _fmt_data(type: int, data: Dictionary) -> String:
	match type:
		EventType.DICE_ROLLED:
			return "roll=%d" % data.get("roll", "?")
		EventType.RESOURCE_COLLECTED:
			return "roll=%d  total=%d" % [data.get("roll", 0), data.get("total", 0)]
		EventType.RESOURCE_DISCARDED:
			return "kept=%s  discarded=%s" % [str(data.get("kept","?")), str(data.get("discarded","?"))]
		EventType.SETTLEMENT_PLACED:
			return "vp=%s  round=%s  pos=(%.1f,%.1f)" % [
				str(data.get("vp", "?")),
				str(data.get("setup_round", "-")),
				data.get("pos_x", 0.0), data.get("pos_z", 0.0)]
		EventType.ROAD_BUILT:
			return "free=%s  total=%d" % [data.get("free", "?"), data.get("total_roads", 0)]
		EventType.CITY_BUILT:
			return "VP:%d" % data.get("vp", "?")
		EventType.DEV_CARD_BOUGHT:
			return data.get("card_type", "")
		EventType.DEV_CARD_PLAYED:
			return data.get("card", "")
		EventType.ROBBER_MOVED:
			return "tile=%s" % data.get("tile", "?")
		EventType.RESOURCE_STOLEN:
			return "%s from %s" % [data.get("resource", "?"), data.get("from", "?")]
		EventType.BANK_TRADE:
			return "give=%s  recv=%s" % [data.get("give", "?"), data.get("recv", "?")]
		EventType.LONGEST_ROAD:
			return "length=%d  VP:%d" % [data.get("length", 0), data.get("vp", 0)]
		EventType.LARGEST_ARMY:
			return "knights=%d  VP:%d" % [data.get("knights", 0), data.get("vp", 0)]
		EventType.GAME_OVER:
			return "WINNER — %d VP in %d turns" % [data.get("vp", 0), data.get("turns", 0)]
		_:
			return str(data) if not data.is_empty() else ""


# ---------------------------------------------------------------
# Legacy summary (count by type) — kept for backward compat
# ---------------------------------------------------------------

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
