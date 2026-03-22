extends BaseAI
class_name HeuristicAI

const NEG_INF := -99999999

func choose_move(board: Array) -> Dictionary:
	var legal := ConnectFourRules.get_valid_columns(board)

	if legal.is_empty():
		return {
			"col": -1,
			"nodes": 0,
			"prunes": 0
		}

	legal = ConnectFourRules.ordered_columns(legal)

	var best_col := legal[0]
	var best_score := NEG_INF
	var nodes := 0

	for col in legal:
		nodes += 1

		var temp := ConnectFourRules.copy_board(board)
		var row := ConnectFourRules.get_next_open_row(temp, col)

		if row == -1:
			continue

		ConnectFourRules.drop_piece(temp, row, col, ConnectFourRules.AI)

		# Immediate win gets highest priority
		if ConnectFourRules.winning_move(temp, ConnectFourRules.AI):
			return {
				"col": col,
				"nodes": nodes,
				"prunes": 0
			}

		var score := ConnectFourRules.evaluate_position(temp, ConnectFourRules.AI)

		if score > best_score:
			best_score = score
			best_col = col

	return {
		"col": best_col,
		"nodes": nodes,
		"prunes": 0
	}
