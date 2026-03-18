extends BaseAI
class_name MinimaxAI

const NEG_INF := -99999999
const POS_INF := 99999999

var depth: int = 5
var nodes_searched: int = 0
var prunes: int = 0

func choose_move(board: Array) -> Dictionary:
	nodes_searched = 0
	prunes = 0

	var result := minimax(board, depth, NEG_INF, POS_INF, true)
	return {
		"col": result["col"],
		"nodes": nodes_searched,
		"prunes": prunes
	}

func minimax(b: Array, current_depth: int, alpha: int, beta: int, maximizing: bool) -> Dictionary:
	nodes_searched += 1

	var valid_cols := ConnectFourRules.get_valid_columns(b)
	valid_cols = ConnectFourRules.ordered_columns(valid_cols)

	var terminal := ConnectFourRules.is_terminal_node(b)

	if current_depth == 0 or terminal:
		if terminal:
			if ConnectFourRules.winning_move(b, ConnectFourRules.AI):
				return {"col": -1, "score": 100000000}
			elif ConnectFourRules.winning_move(b, ConnectFourRules.HUMAN):
				return {"col": -1, "score": -100000000}
			else:
				return {"col": -1, "score": 0}
		return {"col": -1, "score": ConnectFourRules.evaluate_position(b, ConnectFourRules.AI)}

	if maximizing:
		var value := NEG_INF
		var best_col := valid_cols[randi() % valid_cols.size()]

		for col in valid_cols:
			var temp := ConnectFourRules.copy_board(b)
			var row := ConnectFourRules.get_next_open_row(temp, col)
			ConnectFourRules.drop_piece(temp, row, col, ConnectFourRules.AI)

			var res := minimax(temp, current_depth - 1, alpha, beta, false)
			var s := int(res["score"])

			if s > value:
				value = s
				best_col = col

			alpha = max(alpha, value)
			if alpha >= beta:
				prunes += 1
				break

		return {"col": best_col, "score": value}
	else:
		var value := POS_INF
		var best_col := valid_cols[randi() % valid_cols.size()]

		for col in valid_cols:
			var temp := ConnectFourRules.copy_board(b)
			var row := ConnectFourRules.get_next_open_row(temp, col)
			ConnectFourRules.drop_piece(temp, row, col, ConnectFourRules.HUMAN)

			var res := minimax(temp, current_depth - 1, alpha, beta, true)
			var s := int(res["score"])

			if s < value:
				value = s
				best_col = col

			beta = min(beta, value)
			if alpha >= beta:
				prunes += 1
				break

		return {"col": best_col, "score": value}
