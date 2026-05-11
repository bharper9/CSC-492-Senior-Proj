extends Node2D

const ROWS := 6
const COLS := 7
const EMPTY := 0
const HUMAN := 1
const AI := 2

@onready var ai_explanation_label: Label = $ReplayInfoPanel/MarginContainer/VBoxContainer/AIExplanationLabel
@onready var mistake_label_ui: Label = $ReplayInfoPanel/MarginContainer/VBoxContainer/MistakeLabel
@onready var confidence_label: Label = $ReplayInfoPanel/MarginContainer/VBoxContainer/ConfidenceLabel
@onready var eval_change_label: Label = $ReplayInfoPanel/MarginContainer/VBoxContainer/EvalChangeLabel
@onready var critical_move_label: Label = $ReplayInfoPanel/MarginContainer/VBoxContainer/CriticalMoveLabel
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

	if is_instance_valid(replay_timer):
		replay_timer.wait_time = 0.75

	if is_instance_valid(speed_slider):
		speed_slider.min_value = 0.1
		speed_slider.max_value = 2.0
		speed_slider.step = 0.1
		speed_slider.value = 0.75

	update_replay_ui()
	load_latest_replay_file()

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
	highlight_critical_move()
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
		ai_explanation_label.text = ""
		mistake_label_ui.text = ""
		confidence_label.text = ""
		eval_change_label.text = ""
		critical_move_label.text = ""
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
		ai_explanation_label.text = ""
		mistake_label_ui.text = ""
		confidence_label.text = ""
		eval_change_label.text = ""
		critical_move_label.text = ""
		return

	var move: Dictionary = replay_moves[replay_index - 1]

	move_label.text = "Move: %d / %d" % [replay_index, replay_moves.size()]
	player_label.text = "Player: %s | Row: %s | Col: %s" % [
		str(move.get("player", "")),
		str(move.get("row", "")),
		str(move.get("col", ""))
	]

	var eval_before = move.get("evaluation_before", null)
	var eval_after = move.get("evaluation_after", null)

	eval_label.text = "Eval: %s -> %s" % [
		str(eval_before if eval_before != null else "N/A"),
		str(eval_after if eval_after != null else "N/A")
	]

	annotation_label.text = str(move.get("annotation", make_annotation(move)))

	ai_explanation_label.text = build_ai_explanation_text(move)
	mistake_label_ui.text = build_mistake_text(move)
	confidence_label.text = build_confidence_text(move)
	eval_change_label.text = build_eval_change_text(move)
	critical_move_label.text = build_critical_move_text(move)
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

func load_latest_replay_file() -> void:
	var path := "user://latest_replay.json"

	if not FileAccess.file_exists(path):
		print("No latest replay file found.")
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Could not open latest replay file.")
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		print("Invalid replay JSON.")
		return

	var game_data: Dictionary = parsed
	var moves: Array = game_data.get("moves", [])
	load_replay(moves)

	print("Loaded latest replay.")

func build_replay_explanation_text(move: Dictionary) -> String:
	var player := str(move.get("player", "")).to_lower()

	if player == "ai":
		var best_move = move.get("best_move", null)
		var best_score = move.get("best_score", "N/A")
		var second_best_score = move.get("second_best_score", "N/A")
		var confidence_gap = move.get("confidence_gap", "N/A")
		var reason = str(move.get("annotation", "No explanation available."))

		var best_move_text := "N/A"
		if best_move != null and best_move is Dictionary:
			best_move_text = "Column %s" % str(best_move.get("col", "N/A"))
		else:
			best_move_text = "Column %s" % str(move.get("col", "N/A"))

		return (
			"AI Explanation\n" +
			"Best Move: %s\n" % best_move_text +
			"Score: %s\n" % str(best_score) +
			"Second Best: %s\n" % str(second_best_score) +
			"Confidence Gap: %s\n" % str(confidence_gap) +
			"Why: %s" % reason
		)

	if player == "human":
		var mistake_label = str(move.get("mistake_label", "none"))
		var reason = str(move.get("annotation", "Human move recorded."))

		return (
			"Human Move Analysis\n" +
			"Mistake Label: %s\n" % mistake_label +
			"Why: %s" % reason
		)

	return ""

func build_ai_explanation_text(move: Dictionary) -> String:
	var player := str(move.get("player", "")).to_lower()
	if player != "ai":
		return "AI Explanation: N/A"

	var reason := str(move.get("annotation", "No explanation available."))
	var best_score = move.get("best_score", "N/A")
	var second_best_score = move.get("second_best_score", "N/A")

	return (
		"AI Explanation: %s\n" % reason +
		"Best Score: %s\n" % str(best_score) +
		"Second Best: %s" % str(second_best_score)
	)

func build_mistake_text(move: Dictionary) -> String:
	var label := str(move.get("mistake_label", "none"))
	return "Mistake Label: %s" % label
func build_confidence_text(move: Dictionary) -> String:
	var gap = move.get("confidence_gap", null)
	if gap == null:
		return "Confidence Gap: N/A"
	return "Confidence Gap: %s" % str(gap)

func build_eval_change_text(move: Dictionary) -> String:
	var before = move.get("evaluation_before", null)
	var after = move.get("evaluation_after", null)

	if before == null or after == null:
		return "Evaluation Change: N/A"

	var delta = float(after) - float(before)
	var sign = "+"
	if delta < 0:
		sign = ""

	return "Evaluation Change: %s%s" % [sign, str(delta)]

func build_critical_move_text(move: Dictionary) -> String:
	if is_critical_move(move):
		return "Critical Move: YES"
	return "Critical Move: No"

func is_critical_move(move: Dictionary) -> bool:
	var gap = move.get("confidence_gap", null)
	var before = move.get("evaluation_before", null)
	var after = move.get("evaluation_after", null)
	var mistake = str(move.get("mistake_label", "none")).to_lower()
	var annotation = str(move.get("annotation", "")).to_lower()

	if mistake == "major" or mistake == "blunder":
		return true

	if annotation.find("win") != -1:
		return true

	if annotation.find("block") != -1:
		return true

	if gap != null and float(gap) >= 50.0:
		return true

	if before != null and after != null:
		var delta = abs(float(after) - float(before))
		if delta >= 75.0:
			return true

	return false

func highlight_critical_move() -> void:
	if replay_index <= 0 or replay_index > replay_moves.size():
		return

	var move: Dictionary = replay_moves[replay_index - 1]
	if not is_critical_move(move):
		return

	# For now, just change the annotation label or panel color later if desired.
	annotation_label.modulate = Color(1.0, 0.85, 0.4)

func reset_analysis_colors() -> void:
	annotation_label.modulate = Color(1, 1, 1)


func _on_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/GameStart.tscn")
