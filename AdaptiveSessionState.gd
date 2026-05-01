extends RefCounted
class_name AdaptiveSessionState

const MAX_HISTORY := 10

var game_history: Array = []
var current_level: int = 5
var min_level: int = 1
var max_level: int = 7

var games_since_adjustment: int = 0

func add_game_summary(summary: Dictionary) -> void:
	game_history.append(summary)
	if game_history.size() > MAX_HISTORY:
		game_history.pop_front()

	games_since_adjustment += 1

func get_recent_games(count: int = 5) -> Array:
	if game_history.is_empty():
		return []
	return game_history.slice(max(0, game_history.size() - count), game_history.size())

func get_rolling_win_rate(count: int = 5) -> float:
	var recent := get_recent_games(count)
	if recent.is_empty():
		return 0.5

	var wins := 0.0
	for game in recent:
		var result := str(game.get("result", "draw"))
		if result == "win":
			wins += 1.0
		elif result == "draw":
			wins += 0.5

	return wins / recent.size()

func get_moving_average(key: String, count: int = 5) -> float:
	var recent := get_recent_games(count)
	if recent.is_empty():
		return 0.0

	var total := 0.0
	var seen := 0

	for game in recent:
		if game.has(key):
			total += float(game[key])
			seen += 1

	if seen == 0:
		return 0.0

	return total / seen
