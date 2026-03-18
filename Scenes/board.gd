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
		"ai_type": ai_type,
		"ai_depth": ai_player.depth if ai_player is MinimaxAI else 0,
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
