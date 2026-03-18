extends BaseAI
class_name RandomAI

func choose_move(board: Array) -> Dictionary:
	var legal := ConnectFourRules.get_valid_columns(board)
	if legal.is_empty():
		return {"col": -1, "nodes": 0, "prunes": 0}

	var col := legal[randi() % legal.size()]
	return {"col": col, "nodes": 0, "prunes": 0}
