extends BaseAI
class_name HeuristicAI

func choose_move(board: Array) -> Dictionary:
	var legal := ConnectFourRules.get_valid_columns(board)
	if legal.is_empty():
		return {"col": -1, "nodes": 0, "prunes": 0}

	var best_col := legal[0]
	var best_score := -99999999

	for col in legal:
		var temp := ConnectFourRules.copy_board(board)
		var row := ConnectFourRules.get_next_open_row(temp, col)
		ConnectFourRules.drop_piece(temp, row, col, ConnectFourRules.AI)

		var score := ConnectFourRules.evaluate_position(temp, ConnectFourRules.AI)
		if score > best_score:
			best_score = score
			best_col = col

	return {"col": best_col, "nodes": legal.size(), "prunes": 0}
