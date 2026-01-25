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

var board: Array = []               # board[row][col]
var current_player: int = HUMAN
var game_over: bool = false

var last_move_row: int = -1
var last_move_col: int = -1

var elapsed_seconds: int = 0

func _ready() -> void:
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

	# Timer reset + start
	elapsed_seconds = 0
	update_timer_label()
	game_timer.start()

	status_label.text = "Your turn: click a column"
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
		try_human_move(col)

func try_human_move(col: int) -> void:
	if current_player != HUMAN or game_over:
		return

	var drop_row := get_drop_row(col)
	if drop_row == -1:
		status_label.text = "Column is full. Choose another."
		return

	apply_move(drop_row, col, HUMAN)

	# End conditions
	if check_win(drop_row, col, HUMAN):
		end_game("You win! 🎉")
		return

	if check_draw():
		end_game("Draw.")
		return

	# For now, still human's turn (since AI not added yet)
	current_player = HUMAN
	status_label.text = "Your turn: click a column"

func end_game(result_text: String) -> void:
	game_over = true
	game_timer.stop()

	print("Game result: ", result_text)
	print("Game duration (seconds): ", elapsed_seconds)

	status_label.text = result_text

func get_drop_row(col: int) -> int:
	if col < 0 or col >= COLS:
		return -1
	# row 0 is bottom; find lowest EMPTY
	for r in ROWS:
		if board[r][col] == EMPTY:
			return r
	return -1

func apply_move(row: int, col: int, player: int) -> void:
	board[row][col] = player
	last_move_row = row
	last_move_col = col

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
