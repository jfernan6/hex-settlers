class_name HUDPhaseCopy
extends RefCounted


func describe(player, phase_name: String, state = null) -> Dictionary:
	return {
		"badge_color": _phase_badge_color(phase_name),
		"badge_text": _phase_badge_text(player, phase_name, state),
		"focus_text": _phase_focus_text(player, phase_name, state),
		"hint_text": _phase_hint_text(player, phase_name, state),
		"economy_text": _economy_text(player, phase_name, state),
	}


func _phase_badge_color(phase_name: String) -> Color:
	match phase_name:
		"SETUP":
			return Color(0.93, 0.75, 0.32)
		"ROLL":
			return Color(0.54, 0.78, 0.94)
		"BUILD":
			return Color(0.53, 0.83, 0.55)
		"ROBBER":
			return Color(0.96, 0.51, 0.33)
		"GAME OVER":
			return Color(0.92, 0.40, 0.35)
		_:
			return Color(0.72, 0.76, 0.82)


func _phase_badge_text(player, phase_name: String, state = null) -> String:
	if phase_name == "SETUP" and state != null:
		var action := "SETTLEMENT" if state.setup_sub_phase == state.SetupSubPhase.PLACE_SETTLEMENT else "ROAD"
		return "ROUND %d %s" % [state.setup_round, action]
	if phase_name == "BUILD" and player.is_ai:
		return "AI BUILD"
	return phase_name


func _phase_focus_text(player, phase_name: String, state = null) -> String:
	match phase_name:
		"SETUP":
			if state != null and state.setup_sub_phase == state.SetupSubPhase.PLACE_ROAD:
				return "Extend one road from the settlement you just placed."
			return "Claim an opening settlement with strong adjacent numbers."
		"ROLL":
			return "Roll first, then use whatever the board produces."
		"BUILD":
			if player.is_ai:
				return "%s is evaluating builds, trades, and dev cards." % player.player_name
			return "Spend resources, place pieces, or buy a development card."
		"ROBBER":
			if player.is_ai:
				return "%s is choosing a robber target." % player.player_name
			return "Move the robber to a new tile and disrupt a productive spot."
		"GAME OVER":
			return "%s reached the victory threshold." % player.player_name
		_:
			return ""


func _phase_hint_text(player, phase_name: String, state = null) -> String:
	match phase_name:
		"SETUP":
			if state != null and state.setup_sub_phase == state.SetupSubPhase.PLACE_ROAD:
				return "Blue road bars must touch the new settlement."
			return "Gold dots mark legal settlement vertices."
		"ROLL":
			return "Roll Dice is the only action available before build time."
		"BUILD":
			if player.is_ai:
				return "Buttons stay disabled while the AI resolves its turn."
			return "Use the board for roads and settlements, or the panel buttons for card actions."
		"ROBBER":
			return "Pick any different tile; staying on the same tile is invalid."
		"GAME OVER":
			return "Press Esc to leave or F12 to capture the final board."
		_:
			return ""


func _economy_text(player, phase_name: String, state = null) -> String:
	if phase_name == "GAME OVER":
		return "Final economy: %s" % player.resource_summary()
	if phase_name == "SETUP":
		return "Opening stock: %s" % player.resource_summary()

	var options: Array[String] = []
	var can_build_road: bool = (
		player.free_roads > 0 or
		(player.resources.get(0, 0) >= 1 and player.resources.get(1, 0) >= 1)
	)
	var can_build_city: bool = (
		player.resources.get(3, 0) >= 2 and
		player.resources.get(4, 0) >= 3 and
		player.city_positions.size() < 4 and
		player.settlement_positions.size() > player.city_positions.size()
	)
	if can_build_road:
		options.append("Road")
	if player.can_build_settlement():
		options.append("Settlement")
	if can_build_city:
		options.append("City")
	var can_buy_dev: bool = (
		state != null and
		not state.dev_deck.is_empty() and
		player.resources.get(4, 0) >= 1 and
		player.resources.get(3, 0) >= 1 and
		player.resources.get(2, 0) >= 1
	)
	if can_buy_dev:
		options.append("Dev Card")
	return "Build options: %s" % (", ".join(options) if not options.is_empty() else "None yet")
