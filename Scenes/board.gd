extends Node2D

const ROWS := 6
const COLS := 7
const EMPTY := 0
const HUMAN := 1
const AI := 2

@onready var board_view: Node2D = $BoardView
@onready var status_label: Label = $StatusLabel
@onready var reset_button: Button = $ResetButton

@onready var timer_label: Label = $TimerLabel
@onready var game_timer: Timer = $GameTimer

var ai_player: BaseAI
var ai_type: String = "minimax"
var game_id: int = 0
var move_history: Array = []
var ai_move_times: Array = []
var total_ai_nodes: int = 0
var total_ai_prunes: int = 0
var game_result: String = ""
var turn_start_ms: int = 0

var board: Array = []               # board[row][col]
var current_player: int = HUMAN
var game_over: bool = false

var last_move_row: int = -1
var last_move_col: int = -1

var elapsed_seconds: int = 0
var nodes_searched: int = 0
var prunes: int = 0

# --- AI Helper Functions ---
const AI_DEPTH := 5 # Diffuclty spike 1 = easy 4+ AI is smart
const NEG_INF := -99999999
const POS_INF :=  99999999

func copy_board(b: Array) -> Array:
	return b.duplicate(true)

func get_valid_columns(b: Array) -> Array[int]:
	var cols: Array[int] = []
	for c in COLS:
		if b[ROWS - 1][c] == EMPTY:
			cols.append(c)
	return cols

func get_next_open_row(b: Array, col: int) -> int:
	for r in ROWS:
		if b[r][col] == EMPTY:
			return r
	return -1

func drop_piece(b: Array, row: int, col: int, player: int) -> void:
	b[row][col] = player

#Terminal check
func winning_move(b: Array, player: int) -> bool:
	# Horizontal
	for r in ROWS:
		for c in range(0, COLS - 3):
			if b[r][c] == player and b[r][c+1] == player and b[r][c+2] == player and b[r][c+3] == player:
				return true
	# Vertical
	for c in COLS:
		for r in range(0, ROWS - 3):
			if b[r][c] == player and b[r+1][c] == player and b[r+2][c] == player and b[r+3][c] == player:
				return true
	# Diagonal up-right
	for r in range(0, ROWS - 3):
		for c in range(0, COLS - 3):
			if b[r][c] == player and b[r+1][c+1] == player and b[r+2][c+2] == player and b[r+3][c+3] == player:
				return true
	# Diagonal up-left
	for r in range(3, ROWS):
		for c in range(0, COLS - 3):
			if b[r][c] == player and b[r-1][c+1] == player and b[r-2][c+2] == player and b[r-3][c+3] == player:
				return true
	return false

func is_terminal_node(b: Array) -> bool:
	return winning_move(b, HUMAN) or winning_move(b, AI) or get_valid_columns(b).is_empty()
# --- Heuristic evaluation ---
func score_window(window: Array, player: int) -> int:
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

	# blocking opponent threats
	if o == 3 and e == 1:
		score -= 120

	return score

func evaluate_position(b: Array, player: int) -> int:
	var score := 0

	# Center control
	var center_col := COLS / 2
	var center_count := 0
	for r in ROWS:
		if b[r][center_col] == player:
			center_count += 1
	score += center_count * 6

	# Horizontal
	for r in ROWS:
		for c in range(0, COLS - 3):
			score += score_window([b[r][c], b[r][c+1], b[r][c+2], b[r][c+3]], player)

	# Vertical
	for c in COLS:
		for r in range(0, ROWS - 3):
			score += score_window([b[r][c], b[r+1][c], b[r+2][c], b[r+3][c]], player)

	# Diagonal up-right
	for r in range(0, ROWS - 3):
		for c in range(0, COLS - 3):
			score += score_window([b[r][c], b[r+1][c+1], b[r+2][c+2], b[r+3][c+3]], player)

	# Diagonal up-left
	for r in range(3, ROWS):
		for c in range(0, COLS - 3):
			score += score_window([b[r][c], b[r-1][c+1], b[r-2][c+2], b[r-3][c+3]], player)

	return score
#minmax helper
func ordered_columns(cols: Array[int]) -> Array[int]:
	var order := [3, 2, 4, 1, 5, 0, 6] 
	var out: Array[int] = []
	for c in order:
		if cols.has(c):
			out.append(c)
	return out

#Minimax + alpha-beta pruning
func minimax(b: Array, depth: int, alpha: int, beta: int, maximizing: bool) -> Dictionary:
	nodes_searched += 1  

	var valid_cols := get_valid_columns(b)
	valid_cols = ordered_columns(valid_cols)  

	var terminal := is_terminal_node(b)

	if depth == 0 or terminal:
		if terminal:
			if winning_move(b, AI):
				return {"col": -1, "score": 100000000}
			elif winning_move(b, HUMAN):
				return {"col": -1, "score": -100000000}
			else:
				return {"col": -1, "score": 0}
		return {"col": -1, "score": evaluate_position(b, AI)}

	if maximizing:
		var value := NEG_INF
		var best_col := valid_cols[randi() % valid_cols.size()]

		for col in valid_cols:
			var temp := copy_board(b)
			var row := get_next_open_row(temp, col)
			drop_piece(temp, row, col, AI)

			var res := minimax(temp, depth - 1, alpha, beta, false)
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
			var temp := copy_board(b)
			var row := get_next_open_row(temp, col)
			drop_piece(temp, row, col, HUMAN)

			var res := minimax(temp, depth - 1, alpha, beta, true)
			var s := int(res["score"])

			if s < value:
				value = s
				best_col = col

			beta = min(beta, value)
			if alpha >= beta:
				prunes += 1  
				break

		return {"col": best_col, "score": value}

func setup_ai() -> void:
	match ai_type:
		"random":
			ai_player = RandomAI.new()
		"heuristic":
			ai_player = HeuristicAI.new()
		"adaptive":
			var adaptive := AdaptiveAI.new()
			adaptive.depth = 5
			ai_player = adaptive
		_:
			var minimax_ai := MinimaxAI.new()
			minimax_ai.depth = 5
			ai_player = minimax_ai
# --- AI Helper ends --- 
func _ready() -> void:
	randomize()
	setup_ai()
	reset_game()

func reset_game() -> void:
	# Initialize board
	board = []
	for r in ROWS:
		var row := []
		for c in COLS:
			row.append(EMPTY)
		board.append(row)

	current_player = HUMAN
	game_over = false
	last_move_row = -1
	last_move_col = -1
#For game logs 
	move_history = []
	ai_move_times = []
	total_ai_nodes = 0
	total_ai_prunes = 0
	game_result = ""
	turn_start_ms = Time.get_ticks_msec()#Human logs????

	# Timer reset + start
	elapsed_seconds = 0
	update_timer_label()
	game_timer.start()
	current_player = HUMAN
	status_label.text = "Player 1 turn: click a column"
	board_view.call("set_board", board)
	board_view.call("set_last_move", last_move_row, last_move_col)
	board_view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var col: int = board_view.call("mouse_to_column", event.position)
		if col == -1:
			return
		try_move(col)

func try_move(col: int) -> void:
	if game_over:
		return

	# Only allow human clicks on human turn
	if current_player != HUMAN:
		return

	var drop_row := get_drop_row(col)
	if drop_row == -1:
		status_label.text = "Column is full. Choose another."
		return
	var human_move_time_ms := Time.get_ticks_msec() - turn_start_ms
	apply_move(drop_row, col, HUMAN, human_move_time_ms)

	if check_win(drop_row, col, HUMAN):
		end_game("You win!")
		return

	if check_draw():
		end_game("Draw.")
		return

	# Switch to AI turn
	current_player = AI
	status_label.text = "AI thinking..."
	await get_tree().process_frame  # lets UI update
	make_ai_move()

func make_ai_move() -> void:
	if game_over:
		return
	if current_player != AI:
		return

	var start_ms := Time.get_ticks_msec()
	var result := ai_player.choose_move(ConnectFourRules.copy_board(board))
	var end_ms := Time.get_ticks_msec()

	var move_time_ms := end_ms - start_ms
	ai_move_times.append(move_time_ms)
	total_ai_nodes += int(result.get("nodes", 0))
	total_ai_prunes += int(result.get("prunes", 0))

	var col: int = int(result["col"])

	print("AI type=", ai_type,
		" col=", col,
		" time_ms=", move_time_ms,
		" nodes=", result.get("nodes", 0),
		" prunes=", result.get("prunes", 0))

	if col == -1:
		end_game("Draw.")
		return

	var row := get_drop_row(col)
	if row == -1:
		var legal := get_legal_columns()
		if legal.is_empty():
			end_game("Draw.")
			return
		col = legal[randi() % legal.size()]
		row = get_drop_row(col)

	apply_move(row, col, AI, move_time_ms)

	if check_win(row, col, AI):
		end_game("AI wins.")
		return
	if check_draw():
		end_game("Draw.")
		return

	current_player = HUMAN
	turn_start_ms = Time.get_ticks_msec()
	status_label.text = "Your turn"
# Ai turn over

func end_game(result_text: String) -> void:
	game_over = true
	game_timer.stop()

	print("Game result: ", result_text)
	print("Game duration (seconds): ", elapsed_seconds)

	status_label.text = result_text

	if result_text == "You win!":
		game_result = "win"
	elif result_text == "AI wins.":
		game_result = "loss"
	else:
		game_result = "draw"

	save_game_log()

func average_array(values: Array) -> float:
	if values.is_empty():
		return 0.0

	var total := 0.0
	for v in values:
		total += float(v)
	return total / values.size()

func get_drop_row(col: int) -> int:
	if col < 0 or col >= COLS:
		return -1
	# row 0 is bottom; find lowest EMPTY
	for r in ROWS:
		if board[r][col] == EMPTY:
			return r
	return -1

func get_legal_columns() -> Array[int]:
	var cols: Array[int] = []
	for c in COLS:
		if get_drop_row(c) != -1:
			cols.append(c)
	return cols

func apply_move(row: int, col: int, player: int, move_time_ms: int = -1) -> void:
	board[row][col] = player
	last_move_row = row
	last_move_col = col

	var move_entry := {
		"turn": move_history.size() + 1,
		"player": "human" if player == HUMAN else "ai",
		"row": row,
		"col": col
	}

	if move_time_ms >= 0:
		move_entry["move_time_ms"] = move_time_ms

	move_history.append(move_entry)

	board_view.call("set_board", board)
	board_view.call("set_last_move", last_move_row, last_move_col)
	board_view.queue_redraw()
func check_draw() -> bool:
	# If top row is full across all columns, it's a draw (assuming no win)
	for c in COLS:
		if board[ROWS - 1][c] == EMPTY:
			return false
	return true

func check_win(row: int, col: int, player: int) -> bool:
	return (
		count_line(row, col, 0, 1, player) >= 4 or
		count_line(row, col, 1, 0, player) >= 4 or
		count_line(row, col, 1, 1, player) >= 4 or
		count_line(row, col, 1, -1, player) >= 4
	)

func count_line(row: int, col: int, dr: int, dc: int, player: int) -> int:
	var total := 1
	total += count_dir(row, col, dr, dc, player)
	total += count_dir(row, col, -dr, -dc, player)
	return total

func count_dir(row: int, col: int, dr: int, dc: int, player: int) -> int:
	var r := row + dr
	var c := col + dc
	var count := 0
	while r >= 0 and r < ROWS and c >= 0 and c < COLS and board[r][c] == player:
		count += 1
		r += dr
		c += dc
	return count

# --- Timer code ---
func _on_game_timer_timeout() -> void:
	elapsed_seconds += 1
	update_timer_label()

func update_timer_label() -> void:
	var minutes := elapsed_seconds / 60
	var seconds := elapsed_seconds % 60
	timer_label.text = "Time: %02d:%02d" % [minutes, seconds]

func _on_reset_button_pressed() -> void:
	reset_game()

func save_game_log() -> void:
	var timestamp := Time.get_datetime_string_from_system()

	var game_data := {
		"game_id": Time.get_unix_time_from_system(),
		"timestamp": timestamp,
		"result": game_result,
		"duration_seconds": elapsed_seconds,
		"num_moves": move_history.size(),
		"ai_depth": AI_DEPTH,
		"avg_ai_move_time_ms": average_array(ai_move_times),
		"total_ai_nodes": total_ai_nodes,
		"total_ai_prunes": total_ai_prunes,
		"moves": move_history
	}

	var path := "user://connect_four_logs.jsonl"
	print("Absolute log path: ", ProjectSettings.globalize_path(path))
	var file := FileAccess.open(path, FileAccess.READ_WRITE)

	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Could not open log file.")
			return

	file.seek_end()
	file.store_line(JSON.stringify(game_data))
	file.close()

	print("Saved game log to: ", path)
	print(JSON.stringify(game_data))
