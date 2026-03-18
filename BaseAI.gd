extends RefCounted
class_name BaseAI

func choose_move(board: Array) -> Dictionary:
	return {
		"col": -1,
		"nodes": 0,
		"prunes": 0
	}
