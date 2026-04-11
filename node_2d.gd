extends Node2D

const ROWS := 6
const COLS := 7
const EMPTY := 0
const HUMAN := 1
const AI := 2

@onready var board_view: Node2D = $ReplayBoardView
@onready var move_label: Label = $ReplayInfoPanel/MarginContainer/VBoxContainer/Movelabel
@onready var player_label: Label = $ReplayInfoPanel/MarginContainer/VBoxContainer/PlayerLabel
@onready var eval_label: Label = $ReplayInfoPanel/MarginContainer/VBoxContainer/EvaLabel
@onready var annotation_label: Label = $ReplayInfoPanel/MarginContainer/VBoxContainer/Annotationlabel

@onready var prev_button: Button = $ControlsPanel/MarginContainer/VBoxContainer/PrevButton
@onready var next_button: Button = $ControlsPanel/MarginContainer/VBoxContainer/NextButton
@onready var play_pause_button: Button = $ControlsPanel/MarginContainer/VBoxContainer/PlayPauseButton
@onready var speed_slider: HSlider = $ControlsPanel/MarginContainer/VBoxContainer/SpeedSlider
@onready var move_spinbox: SpinBox = $ControlsPanel/MarginContainer/VBoxContainer/MoveSpinBox
@onready var load_latest_button: Button = $ControlsPanel/MarginContainer/VBoxContainer/LoadLatestButton
@onready var replay_timer: Timer = $ReplayTimer

var replay_moves: Array = []
var replay_board: Array = []
var replay_index: int = 0
var autoplay_on: bool = false
var winning_cells: Array = []

func _ready() -> void:
	reset_replay_board()
	replay_timer.wait_time = 0.75
	if speed_slider:
		speed_slider.min_value = 0.1
		speed_slider.max_value = 2.0
		speed_slider.step = 0.1
		speed_slider.value = 0.75
	update_replay_ui()

func reset_replay_board() -> void:
	replay_board = []
	for r in range(ROWS):
		var row := []
		for c in range(COLS):
			row.append(EMPTY)
		replay_board.append(row)

	winning_cells = []

	if is_instance_valid(board_view) and board_view.has_method("set_board"):
		board_view.call("set_board", replay_board)

	if is_instance_valid(board_view) and board_view.has_method("set_last_move"):
		board_view.call("set_last_move", -1, -1)

	if is_instance_valid(board_view) and board_view.has_method("set_winning_cells"):
		board_view.call("set_winning_cells", winning_cells)

	if is_instance_valid(board_view):
		board_view.queue_redraw()

func load_replay(moves: Array) -> void:
	replay_moves = moves.duplicate(true)
	replay_index = 0
	winning_cells = []
	reset_replay_board()
	update_replay_ui()

	move_spinbox.min_value = 0
	move_spinbox.max_value = replay_moves.size()
	move_spinbox.step = 1
	move_spinbox.value = 0

	autoplay_on = false
	play_pause_button.text = "Play"
	replay_timer.stop()

func rebuild_board_to_move(target_index: int) -> void:
	reset_replay_board()

	if replay_moves.is_empty():
		replay_index = 0
		update_replay_ui()
		return

	target_index = clamp(target_index, 0, replay_moves.size())

	if target_index <= 0:
		replay_index = 0
		move_spinbox.value = 0
		update_replay_ui()
		return

	var last_row := -1
	var last_col := -1

	for i in range(target_index):
		var move: Dictionary = replay_moves[i]
		var row := int(move.get("row", -1))
		var col := int(move.get("col", -1))
		var player_str := str(move.get("player", "human")).to_lower()
		var player := HUMAN if player_str == "human" else AI

		if row >= 0 and row < ROWS and col >= 0 and col < COLS:
			replay_board[row][col] = player
			last_row = row
			last_col = col

	replay_index = target_index
	move_spinbox.value = replay_index

	if board_view.has_method("set_board"):
		board_view.call("set_board", replay_board)
	if board_view.has_method("set_last_move"):
		board_view.call("set_last_move", last_row, last_col)

	update_winning_highlight(last_row, last_col)
	update_replay_ui()
	board_view.queue_redraw()

func step_forward() -> void:
	if replay_index < replay_moves.size():
		rebuild_board_to_move(replay_index + 1)

func step_backward() -> void:
	if replay_index > 0:
		rebuild_board_to_move(replay_index - 1)

func update_replay_ui() -> void:
	if replay_moves.is_empty():
		move_label.text = "Move: 0 / 0"
		player_label.text = "Player: None"
		eval_label.text = "Evaluation: N/A"
		annotation_label.text = "No replay loaded"
		prev_button.disabled = true
		next_button.disabled = true
		return

	prev_button.disabled = replay_index <= 0
	next_button.disabled = replay_index >= replay_moves.size()

	if replay_index == 0:
		move_label.text = "Move: 0 / %d" % replay_moves.size()
		player_label.text = "Player: None"
		eval_label.text = "Evaluation: N/A"
		annotation_label.text = "Game start"
		return

	var move: Dictionary = replay_moves[replay_index - 1]

	move_label.text = "Move: %d / %d" % [replay_index, replay_moves.size()]
	player_label.text = "Player: %s | Row: %s | Col: %s" % [
		str(move.get("player", "")),
		str(move.get("row", "")),
		str(move.get("col", ""))
	]
	eval_label.text = "Eval: %s -> %s" % [
		str(move.get("evaluation_before", "N/A")),
		str(move.get("evaluation_after", "N/A"))
	]
	annotation_label.text = make_annotation(move)

func _on_prev_button_pressed() -> void:
	step_backward()

func _on_next_button_pressed() -> void:
	step_forward()

func _on_play_pause_button_pressed() -> void:
	autoplay_on = not autoplay_on

	if autoplay_on:
		play_pause_button.text = "Pause"
		replay_timer.start()
	else:
		play_pause_button.text = "Play"
		replay_timer.stop()

func _on_replay_timer_timeout() -> void:
	if replay_index < replay_moves.size():
		step_forward()
	else:
		autoplay_on = false
		play_pause_button.text = "Play"
		replay_timer.stop()

func _on_speed_slider_value_changed(value: float) -> void:
	replay_timer.wait_time = max(0.05, value)

func _on_move_spinbox_value_changed(value: float) -> void:
	rebuild_board_to_move(int(value))

func make_annotation(move: Dictionary) -> String:
	var player := str(move.get("player", ""))
	var col := int(move.get("col", -1))
	var row := int(move.get("row", -1))
	var mistake := str(move.get("mistake_label", "none"))

	var text := "%s played at row %d, column %d" % [player.capitalize(), row, col]

	if mistake != "none" and mistake != "unlabeled" and mistake != "":
		text += " | Mistake: " + mistake

	return text

func collect_dir(board_data: Array, row: int, col: int, dr: int, dc: int, player: int) -> Array:
	var cells: Array = []
	var r := row + dr
	var c := col + dc

	while r >= 0 and r < ROWS and c >= 0 and c < COLS and board_data[r][c] == player:
		cells.append(Vector2i(r, c))
		r += dr
		c += dc

	return cells

func find_winning_cells(board_data: Array, row: int, col: int, player: int) -> Array:
	var directions = [
		Vector2i(0, 1),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(1, -1)
	]

	for dir in directions:
		var cells: Array = [Vector2i(row, col)]
		cells.append_array(collect_dir(board_data, row, col, dir.x, dir.y, player))
		cells.append_array(collect_dir(board_data, row, col, -dir.x, -dir.y, player))

		if cells.size() >= 4:
			return cells.slice(0, 4)

	return []

func update_winning_highlight(last_row: int, last_col: int) -> void:
	winning_cells = []

	if replay_index <= 0 or replay_index > replay_moves.size():
		if board_view.has_method("set_winning_cells"):
			board_view.call("set_winning_cells", winning_cells)
		return

	var move: Dictionary = replay_moves[replay_index - 1]
	var player_str := str(move.get("player", "human")).to_lower()
	var player := HUMAN if player_str == "human" else AI

	if last_row >= 0 and last_col >= 0:
		winning_cells = find_winning_cells(replay_board, last_row, last_col, player)

	if board_view.has_method("set_winning_cells"):
		board_view.call("set_winning_cells", winning_cells)

func load_saved_games() -> Array:
	var games: Array = []
	var path := "user://connect_four_logs.jsonl"

	if not FileAccess.file_exists(path):
		return games

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return games

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue

		var parsed = JSON.parse_string(line)
		if parsed != null and parsed is Dictionary:
			games.append(parsed)

	file.close()
	return games

func load_game_by_index(game_idx: int) -> void:
	var games = load_saved_games()
	if game_idx < 0 or game_idx >= games.size():
		print("Invalid game index.")
		return

	var game_data = games[game_idx]
	var moves = game_data.get("moves", [])
	load_replay(moves)

func load_latest_saved_game() -> void:
	var games := load_saved_games()
	if games.is_empty():
		print("No saved games found.")
		return
	load_game_by_index(games.size() - 1)

func load_moves_from_csv(path: String) -> Array:
	var moves: Array = []

	if not FileAccess.file_exists(path):
		return moves

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return moves

	var headers: PackedStringArray = []
	if not file.eof_reached():
		headers = file.get_csv_line()

	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty():
			continue

		var move := {}
		for i in range(min(headers.size(), row.size())):
			move[headers[i]] = row[i]

		if move.has("turn") and str(move["turn"]) != "":
			move["turn"] = int(move["turn"])
		if move.has("row") and str(move["row"]) != "":
			move["row"] = int(move["row"])
		if move.has("col") and str(move["col"]) != "":
			move["col"] = int(move["col"])
		if move.has("move_time_ms") and str(move["move_time_ms"]) != "":
			move["move_time_ms"] = int(move["move_time_ms"])

		moves.append(move)

	file.close()
	return moves

func _on_load_latest_button_pressed() -> void:
	load_latest_saved_game()
