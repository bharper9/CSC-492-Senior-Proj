extends RefCounted
class_name BaseAI

func choose_move(board: Array) -> Dictionary:
	return {
		"col": -1,
		"nodes": 0,
		"prunes": 0
	}

func evaluate_board_state(board: Array, player: int = ConnectFourRules.AI) -> int:
	if player == ConnectFourRules.AI:
		return ConnectFourRules.evaluate_position(board, ConnectFourRules.AI)

	return -ConnectFourRules.evaluate_position(board, ConnectFourRules.AI)
