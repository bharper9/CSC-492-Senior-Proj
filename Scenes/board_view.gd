extends Node2D

const ROWS := 6
const COLS := 7
const EMPTY := 0
const HUMAN := 1
const AI := 2

@export var cell_size: float = 80.0
@export var padding: float = 20.0

var board: Array = []
var last_move_row: int = -1
var last_move_col: int = -1

func set_board(new_board: Array) -> void:
	board = new_board

func set_last_move(r: int, c: int) -> void:
	last_move_row = r
	last_move_col = c


func mouse_to_column(mouse_pos: Vector2) -> int:
	var local := to_local(mouse_pos)
	var board_origin := Vector2(padding, padding)

	var x := local.x - board_origin.x
	var y := local.y - board_origin.y

	var w := COLS * cell_size
	var h := ROWS * cell_size

	if x < 0.0 or x >= w or y < 0.0 or y >= h:
		return -1

	return int(floor(x / cell_size))

func _draw() -> void:
	var origin := Vector2(padding, padding)
	var w := COLS * cell_size
	var h := ROWS * cell_size

	# Board background
	draw_rect(Rect2(origin, Vector2(w, h)), Color(0.15, 0.15, 0.18), true)

	for r in ROWS:
		for c in COLS:
			# Flip y so row 0 is bottom visually
			var cell_top_left := origin + Vector2(c * cell_size, (ROWS - 1 - r) * cell_size)
			draw_rect(Rect2(cell_top_left, Vector2(cell_size, cell_size)), Color(0.25, 0.25, 0.30), false, 2.0)

			var center := cell_top_left + Vector2(cell_size / 2.0, cell_size / 2.0)
			var radius := cell_size * 0.38

			var v := EMPTY
			if board.size() == ROWS and board[r].size() == COLS:
				v = board[r][c]

			var piece_color := Color(0.08, 0.08, 0.10) # empty slot
			if v == HUMAN:
				piece_color = Color(0.90, 0.25, 0.25)
			elif v == AI:
				piece_color = Color(0.90, 0.85, 0.25)

			draw_circle(center, radius, piece_color)

			# Highlight last move
			if r == last_move_row and c == last_move_col and last_move_row != -1:
				draw_arc(center, radius + 3.0, 0.0, TAU, 48, Color(1, 1, 1), 2.0)
