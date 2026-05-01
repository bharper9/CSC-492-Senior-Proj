class_name AdaptiveDifficultyController
extends RefCounted

var state: AdaptiveSessionState

# Smoothing / stability settings
var evaluation_window: int = 5
var min_games_before_adjustment: int = 3
var cooldown_games: int = 2

# Anti-oscillation thresholds
var upper_win_rate_threshold: float = 0.70
var lower_win_rate_threshold: float = 0.35

# Optional skill signals
var high_mistake_threshold: float = 3.0
var low_mistake_threshold: float = 1.0

func _init(session_state: AdaptiveSessionState) -> void:
	state = session_state

func evaluate_adjustment() -> Dictionary:
	if state.game_history.size() < min_games_before_adjustment:
		return {
			"new_level": state.current_level,
			"changed": false,
			"reason": "Not enough games yet."
		}

	if state.games_since_adjustment < cooldown_games:
		return {
			"new_level": state.current_level,
			"changed": false,
			"reason": "Cooldown active."
		}

	var win_rate := state.get_rolling_win_rate(evaluation_window)
	var avg_mistakes := state.get_moving_average("human_mistakes", evaluation_window)
	var avg_conf_gap := state.get_moving_average("avg_confidence_gap", evaluation_window)

	var delta := 0
	var reason := "Stable."

	# Make AI harder if player is winning too often and making few mistakes
	if win_rate >= upper_win_rate_threshold and avg_mistakes <= high_mistake_threshold:
		delta = 1
		reason = "Player outperforming AI."

	# Make AI easier if player is losing too often and making many mistakes
	elif win_rate <= lower_win_rate_threshold and avg_mistakes >= low_mistake_threshold:
		delta = -1
		reason = "Player struggling."

	# Near equilibrium: optionally add tiny variation
	elif abs(win_rate - 0.5) <= 0.10:
		if randf() < 0.20:
			delta = [-1, 0, 1][randi() % 3]
			reason = "Near equilibrium; slight randomized variation."

	var new_level: int = clamp(state.current_level + delta, state.min_level, state.max_level)
	var changed: bool = new_level != state.current_level

	if changed:
		state.current_level = new_level
		state.games_since_adjustment = 0

	return {
		"new_level": new_level,
		"changed": changed,
		"reason": reason,
		"win_rate": win_rate,
		"avg_mistakes": avg_mistakes,
		"avg_conf_gap": avg_conf_gap
	}
