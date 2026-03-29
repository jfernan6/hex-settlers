class_name GamePhaseMessaging
extends RefCounted


func hud_message_for(state) -> String:
	if state == null or state.players.is_empty():
		return ""

	var player = state.current_player()
	match state.phase:
		state.Phase.SETUP:
			if state.setup_sub_phase == state.SetupSubPhase.PLACE_SETTLEMENT:
				return "%s: place your settlement  (round %d of 2)" % [
					player.player_name, state.setup_round]
			return "%s: place a road adjacent to your new settlement" % player.player_name
		state.Phase.ROLL:
			return "%s: press Roll Dice to produce resources" % player.player_name
		state.Phase.BUILD:
			var roll_str := " (rolled %d)" % state.last_roll if state.last_roll > 0 else ""
			if player.is_ai:
				return "%s (AI) is taking their turn%s..." % [player.player_name, roll_str]
			return "%s%s — click gold dots to build settlements, blue bars for roads, or use the buttons" % [
				player.player_name, roll_str]
		state.Phase.ROBBER_MOVE:
			if player.is_ai:
				return "%s (AI) is moving the robber..." % player.player_name
			if state.robber_pick_pending:
				return "%s: choose a player and steal a face-down card" % player.player_name
			return "%s: click any tile to move the robber there" % player.player_name
		state.Phase.GAME_OVER:
			var winner = state.players[state.winner_index]
			return "*** %s WINS with %d VP! ***" % [winner.player_name, winner.victory_points]
		_:
			return ""
