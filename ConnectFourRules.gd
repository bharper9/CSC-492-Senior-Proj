extends RefCounted
class_name ConnectFourRules

const ROWS := 6
const COLS := 7
const EMPTY := 0
const HUMAN := 1
const AI := 2

static func copy_board(b: Array) -> Array:
	return b.duplicate(true)

static func get_valid_columns(b: Array) -> Array[int]:
	var cols: Array[int] = []
	for c in COLS:
		if b[ROWS - 1][c] == EMPTY:
			cols.append(c)
	return cols

static func get_next_open_row(b: Array, col: int) -> int:
	for r in ROWS:
		if b[r][col] == EMPTY:
			return r
	return -1

static func drop_piece(b: Array, row: int, col: int, player: int) -> void:
	b[row][col] = player

static func winning_move(b: Array, player: int) -> bool:
	for r in ROWS:
		for c in range(0, COLS - 3):
			if b[r][c] == player and b[r][c+1] == player and b[r][c+2] == player and b[r][c+3] == player:
				return true

	for c in COLS:
		for r in range(0, ROWS - 3):
			if b[r][c] == player and b[r+1][c] == player and b[r+2][c] == player and b[r+3][c] == player:
				return true

	for r in range(0, ROWS - 3):
		for c in range(0, COLS - 3):
			if b[r][c] == player and b[r+1][c+1] == player and b[r+2][c+2] == player and b[r+3][c+3] == player:
				return true

	for r in range(3, ROWS):
		for c in range(0, COLS - 3):
			if b[r][c] == player and b[r-1][c+1] == player and b[r-2][c+2] == player and b[r-3][c+3] == player:
				return true

	return false

static func is_terminal_node(b: Array) -> bool:
	return winning_move(b, HUMAN) or winning_move(b, AI) or get_valid_columns(b).is_empty()

static func ordered_columns(cols: Array[int]) -> Array[int]:
	var order := [3, 2, 4, 1, 5, 0, 6]
	var out: Array[int] = []
	for c in order:
		if cols.has(c):
			out.append(c)
	return out

static func score_window(window: Array, player: int) -> int:
	var score := 0
	var opp := HUMAN if player == AI else AI

	var p := 0
	var o := 0
	var e := 0

	for v in window:
		if v == player:
			p += 1
		elif v == opp:
			o += 1
		else:
			e += 1

	if p == 4:
		score += 100000
	elif p == 3 and e == 1:
		score += 100
	elif p == 2 and e == 2:
		score += 10

	if o == 3 and e == 1:
		score -= 120

	return score

static func evaluate_position(b: Array, player: int) -> int:
	var score := 0
	var center_col := COLS / 2
	var center_count := 0

	for r in ROWS:
		if b[r][center_col] == player:
			center_count += 1
	score += center_count * 6

	for r in ROWS:
		for c in range(0, COLS - 3):
			score += score_window([b[r][c], b[r][c+1], b[r][c+2], b[r][c+3]], player)

	for c in COLS:
		for r in range(0, ROWS - 3):
			score += score_window([b[r][c], b[r+1][c], b[r+2][c], b[r+3][c]], player)

	for r in range(0, ROWS - 3):
		for c in range(0, COLS - 3):
			score += score_window([b[r][c], b[r+1][c+1], b[r+2][c+2], b[r+3][c+3]], player)

	for r in range(3, ROWS):
		for c in range(0, COLS - 3):
			score += score_window([b[r][c], b[r-1][c+1], b[r-2][c+2], b[r-3][c+3]], player)

	return score
