extends MinimaxAI
class_name AdaptiveAI

var min_depth: int = 3
var max_depth: int = 6
var target_win_rate: float = 0.5
var tolerance: float = 0.05

func update_difficulty(rolling_win_rate: float) -> void:
	if rolling_win_rate > target_win_rate + tolerance:
		depth = min(depth + 1, max_depth)
	elif rolling_win_rate < target_win_rate - tolerance:
		depth = max(depth - 1, min_depth)
