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

var session_start_ms: int = 0
var human_move_times: Array = []
var session_id: int = 0
var winner_label: String = ""

var adaptive_state: AdaptiveSessionState
var adaptive_controller: AdaptiveDifficultyController

# --- AI Helper Functions ---
const AI_DEPTH := 1 # Diffuclty spike 1 = easy 4+ AI is smart
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
		"minimax":
			var minimax_ai := MinimaxAI.new()
			minimax_ai.depth = 5
			ai_player = minimax_ai
# --- AI Helper ends --- 
func _ready() -> void:
	randomize()
	ai_type = GameSettings.ai_type
	setup_ai()

	adaptive_state = AdaptiveSessionState.new()
	adaptive_controller = AdaptiveDifficultyController.new(adaptive_state)

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
	human_move_times = []
	total_ai_nodes = 0
	total_ai_prunes = 0
	game_result = ""
	winner_label = ""
	session_id = Time.get_unix_time_from_system()
	session_start_ms = Time.get_ticks_msec()
	turn_start_ms = session_start_ms

	# Timer reset + start
	elapsed_seconds = 0
	update_timer_label()
	game_timer.start()
	current_player = HUMAN
	status_label.text = "Player 1 turn: click a column"
	board_view.call("set_board", board)
	board_view.call("set_last_move", last_move_row, last_move_col)
	board_view.queue_redraw()
	update_stats_panel()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var col: int = board_view.call("mouse_to_column", event.position)
		if col == -1:
			return
		try_move(col)

func clone_board(src_board: Array) -> Array:
	return src_board.duplicate(true)

func get_legal_move_objects() -> Array:
	var legal: Array = []
	for c in get_legal_columns():
		legal.append({
			"col": c,
			"row": get_drop_row(c)
		})
	return legal

func evaluate_position(for_player: int, eval_board: Array) -> float:
	return 0.0

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

	var board_before := clone_board(board)
	var analysis = analyze_position_move(board_before, col, HUMAN)
	var legal_before := get_legal_move_objects()
	var human_move_time_ms := Time.get_ticks_msec() - turn_start_ms
	human_move_times.append(human_move_time_ms)

	var eval_before := evaluate_position(HUMAN, board_before)

	var simulated_after := clone_board(board_before)
	simulated_after[drop_row][col] = HUMAN
	var eval_after := evaluate_position(HUMAN, simulated_after)

	var human_extra := {
		"legal_moves_before": legal_before,
		"evaluation_before": eval_before,
		"evaluation_after": eval_after,
		"best_move": analysis.get("best_move", null),
		"best_score": analysis.get("best_score", null),
		"second_best_score": analysis.get("second_best_score", null),
		"confidence_gap": analysis.get("confidence_gap", null),
		"chosen_move_score": analysis.get("chosen_move_score", null),
		"was_best_move": analysis.get("mistake_label", "none") == "none",
		"mistake_loss": analysis.get("mistake_loss", null),
		"mistake_label": analysis.get("mistake_label", "none"),
		"is_critical": analysis.get("is_critical", false),
		"annotation": analysis.get("reason", "Human move recorded.")
	}

	apply_move(drop_row, col, HUMAN, human_move_time_ms, human_extra)

	if check_win(drop_row, col, HUMAN):
		end_game("You win!")
		return

	if check_draw():
		end_game("Draw.")
		return

	# Switch to AI turn
	current_player = AI
	status_label.text = "AI thinking..."
	await get_tree().process_frame
	make_ai_move()

func make_ai_move() -> void:
	if game_over:
		return
	if current_player != AI:
		return

	var start_ms := Time.get_ticks_msec()
	var result := ai_player.choose_move(board.duplicate(true))
	var end_ms := Time.get_ticks_msec()

	var move_time_ms := end_ms - start_ms
	ai_move_times.append(move_time_ms)
	total_ai_nodes += int(result.get("nodes", 0))
	total_ai_prunes += int(result.get("prunes", 0))

	var col: int = int(result["col"])

	print("AI type=", ai_type,
		" col=", col,
		" time_ms=", move_time_ms)

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

	# Save detailed game log first
	save_game_log()

	# Build summary for adaptive difficulty
	var summary := build_game_summary()
	adaptive_state.add_game_summary(summary)

	# Evaluate whether difficulty should change
	var adjustment := adaptive_controller.evaluate_adjustment()

	# Apply the new difficulty to the AI
	apply_adaptive_level_to_ai()

	# Debug output so you can verify it works
	print("Adaptive summary: ", summary)
	print("Adaptive adjustment: ", adjustment)
	print("Adaptive level now: ", adaptive_state.current_level)

	# Optional: show in UI
	if adjustment.get("changed", false):
		status_label.text += "\nAdaptive difficulty changed to level %d" % adaptive_state.current_level

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
	return cols#HHHHHHHHHHH


func label_mistake(best_score: float, chosen_score: float) -> String:
	var loss := best_score - chosen_score

	if loss <= 0.0:
		return "none"
	elif loss >= 1000.0:
		return "blunder"
	elif loss >= 200.0:
		return "major"
	elif loss >= 50.0:
		return "minor"
	else:
		return "slight"

func compute_confidence_gap(best_score: Variant, second_best_score: Variant) -> Variant:
	if best_score == null or second_best_score == null:
		return null
	return float(best_score) - float(second_best_score)

func board_to_string(src_board: Array) -> String:
	var rows_text: Array = []
	for row in src_board:
		var row_text: Array = []
		for cell in row:
			row_text.append(str(cell))
		rows_text.append(",".join(row_text))
	return " | ".join(rows_text)

func apply_move(
	row: int,
	col: int,
	player: int,
	move_time_ms: int = -1,
	extra_data: Dictionary = {}
) -> void:
	var board_before: Array = clone_board(board)

	board[row][col] = player
	last_move_row = row
	last_move_col = col

	var board_after: Array = clone_board(board)

	var move_entry := {
		"turn": move_history.size() + 1,
		"player": "human" if player == HUMAN else "ai",
		"row": row,
		"col": col,
		"timestamp": Time.get_datetime_string_from_system(),
		"elapsed_ms": Time.get_ticks_msec() - session_start_ms,
		"board_before": board_before,
		"board_after": board_after
	}

	if move_time_ms >= 0:
		move_entry["move_time_ms"] = move_time_ms

	for key in extra_data.keys():
		move_entry[key] = extra_data[key]

	move_history.append(move_entry)

	board_view.call("set_board", board)
	board_view.call("set_last_move", last_move_row, last_move_col)
	board_view.queue_redraw()
	update_stats_panel()
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

	var human_mistakes := 0
	var ai_mistakes := 0
	var confidence_values: Array = []

	for move in move_history:
		var label = move.get("mistake_label", "none")
		if label != "none" and label != "unlabeled":
			if move.get("player", "") == "human":
				human_mistakes += 1
			elif move.get("player", "") == "ai":
				ai_mistakes += 1

		var gap = move.get("confidence_gap", null)
		if gap != null:
			confidence_values.append(float(gap))

	var game_data := {
		"game_id": session_id,
		"timestamp": timestamp,
		"result": game_result,
		"winner": winner_label,
		"duration_seconds": elapsed_seconds,
		"duration_ms": Time.get_ticks_msec() - session_start_ms,
		"num_moves": move_history.size(),
		"ai_type": ai_type,
		"ai_depth": AI_DEPTH,
		"avg_ai_move_time_ms": average_array(ai_move_times),
		"avg_human_move_time_ms": average_array(human_move_times),
		"total_ai_nodes": total_ai_nodes,
		"total_ai_prunes": total_ai_prunes,
		"human_mistakes": human_mistakes,
		"ai_mistakes": ai_mistakes,
		"avg_confidence_gap": average_array(confidence_values),
		"final_board": clone_board(board),
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

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://Scenes/GameStart.tscn")

func csv_escape(value) -> String:
	var s := str(value)
	s = s.replace("\"", "\"\"")
	return "\"" + s + "\""

func save_game_log_csv() -> void:
	var path := "user://connect_four_moves.csv"
	var file_exists := FileAccess.file_exists(path)

	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Could not open CSV log file.")
			return

	file.seek_end()

	if not file_exists or file.get_length() == 0:
		file.store_line(
			"game_id,timestamp,turn,player,row,col,move_time_ms,elapsed_ms,evaluation_before,evaluation_after,best_score,second_best_score,confidence_gap,chosen_move_score,was_best_move,mistake_label,legal_moves_before,board_before,board_after,nodes,prunes"
		)

	for move in move_history:
		var row := [
			csv_escape(session_id),
			csv_escape(Time.get_datetime_string_from_system()),
			csv_escape(move.get("turn", "")),
			csv_escape(move.get("player", "")),
			csv_escape(move.get("row", "")),
			csv_escape(move.get("col", "")),
			csv_escape(move.get("move_time_ms", "")),
			csv_escape(move.get("elapsed_ms", "")),
			csv_escape(move.get("evaluation_before", "")),
			csv_escape(move.get("evaluation_after", "")),
			csv_escape(move.get("best_score", "")),
			csv_escape(move.get("second_best_score", "")),
			csv_escape(move.get("confidence_gap", "")),
			csv_escape(move.get("chosen_move_score", "")),
			csv_escape(move.get("was_best_move", "")),
			csv_escape(move.get("mistake_label", "")),
			csv_escape(JSON.stringify(move.get("legal_moves_before", []))),
			csv_escape(JSON.stringify(move.get("board_before", []))),
			csv_escape(JSON.stringify(move.get("board_after", []))),
			csv_escape(move.get("nodes", "")),
			csv_escape(move.get("prunes", ""))
		]
		file.store_line(",".join(row))

	file.close()
	print("Saved CSV move log to: ", path)

@onready var stats_label: Label = $Label
func update_stats_panel() -> void:
	var avg_ai := average_array(ai_move_times)
	var avg_human := average_array(human_move_times)

	stats_label.text = \
		"Game ID: %s\n" % str(session_id) + \
		"Moves: %d\n" % move_history.size() + \
		"AI Type: %s\n" % ai_type + \
		"Avg Human Move: %.1f ms\n" % avg_human + \
		"Avg AI Move: %.1f ms\n" % avg_ai + \
		"AI Nodes: %d\n" % total_ai_nodes + \
		"AI Prunes: %d\n" % total_ai_prunes

@onready var summary_panel: Control = $SummaryPanel
@onready var summary_label: Label = $SummaryPanel/SummaryLabel

func show_game_summary() -> void:
	var avg_ai := average_array(ai_move_times)
	var avg_human := average_array(human_move_times)

	var human_mistakes := 0
	var ai_mistakes := 0

	for move in move_history:
		var label = str(move.get("mistake_label", "none"))
		if label != "none" and label != "unlabeled":
			if move.get("player", "") == "human":
				human_mistakes += 1
			elif move.get("player", "") == "ai":
				ai_mistakes += 1

	summary_label.text = \
		"Game Summary\n\n" + \
		"Result: %s\n" % game_result + \
		"Winner: %s\n" % winner_label + \
		"Duration: %d sec\n" % elapsed_seconds + \
		"Moves: %d\n" % move_history.size() + \
		"AI Type: %s\n" % ai_type + \
		"Avg Human Move: %.1f ms\n" % avg_human + \
		"Avg AI Move: %.1f ms\n" % avg_ai + \
		"AI Nodes: %d\n" % total_ai_nodes + \
		"AI Prunes: %d\n" % total_ai_prunes + \
		"Human Mistakes: %d\n" % human_mistakes + \
		"AI Mistakes: %d" % ai_mistakes

	summary_panel.visible = true

func save_latest_replay() -> void:
	var latest_game_data := {
		"game_id": session_id,
		"timestamp": Time.get_datetime_string_from_system(),
		"result": game_result,
		"duration_seconds": elapsed_seconds,
		"num_moves": move_history.size(),
		"ai_type": ai_type,
		"moves": move_history,
		"final_board": board.duplicate(true)
	}

	var path := "user://latest_replay.json"
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("Could not save latest replay.")
		return

	file.store_string(JSON.stringify(latest_game_data))
	file.close()

	print("Saved latest replay to: ", ProjectSettings.globalize_path(path))


func _on_setting_pressed():
	$"Settings Window".visible = true


func _on_replay_pressed():
	get_tree().change_scene_to_file("res://node_2d.tscn")

func analyze_position_move(board_before: Array, chosen_col: int, player: int) -> Dictionary:
	var valid_cols := ConnectFourRules.get_valid_columns(board_before)
	valid_cols = ConnectFourRules.ordered_columns(valid_cols)

	if valid_cols.is_empty():
		return {}

	var move_scores: Array = []

	for col in valid_cols:
		var temp := ConnectFourRules.copy_board(board_before)
		var row := ConnectFourRules.get_next_open_row(temp, col)
		if row == -1:
			continue

		ConnectFourRules.drop_piece(temp, row, col, player)

		var score := 0
		if ai_player != null and ai_player.has_method("evaluate_board_state"):
			score = int(ai_player.call("evaluate_board_state", temp, player))

		move_scores.append({
			"col": col,
			"row": row,
			"score": score
		})

	if move_scores.is_empty():
		return {}

	move_scores.sort_custom(func(a, b): return a["score"] > b["score"])

	var best_entry = move_scores[0]
	var best_score := int(best_entry["score"])

	var second_best_score = null
	if move_scores.size() > 1:
		second_best_score = int(move_scores[1]["score"])

	var chosen_score = best_score
	for entry in move_scores:
		if int(entry["col"]) == chosen_col:
			chosen_score = int(entry["score"])
			break

	var confidence_gap = null
	if second_best_score != null:
		confidence_gap = best_score - second_best_score

	var mistake_loss: float = float(best_score) - float(chosen_score)
	var mistake_label := classify_mistake(mistake_loss)
	var reason := infer_move_reason(board_before, chosen_col, player, best_score, chosen_score)

	return {
		"best_move": {
			"col": int(best_entry["col"]),
			"row": int(best_entry["row"])
		},
		"best_score": best_score,
		"second_best_score": second_best_score,
		"confidence_gap": confidence_gap,
		"chosen_move_score": chosen_score,
		"mistake_loss": mistake_loss,
		"mistake_label": mistake_label,
		"is_critical": is_critical_position(board_before, chosen_col, player, best_score, chosen_score, confidence_gap, mistake_loss),
		"reason": reason,
		"move_scores": move_scores
	}

func classify_mistake(loss: float) -> String:
	if loss <= 0.0:
		return "none"
	elif loss <= 10.0:
		return "slight"
	elif loss <= 40.0:
		return "minor"
	elif loss <= 100.0:
		return "major"
	else:
		return "blunder"

func move_creates_immediate_win(board_before: Array, col: int, player: int) -> bool:
	var temp := ConnectFourRules.copy_board(board_before)
	var row := ConnectFourRules.get_next_open_row(temp, col)
	if row == -1:
		return false

	ConnectFourRules.drop_piece(temp, row, col, player)
	return ConnectFourRules.winning_move(temp, player)

func move_blocks_opponent_win(board_before: Array, col: int, player: int) -> bool:
	var opponent := ConnectFourRules.HUMAN if player == ConnectFourRules.AI else ConnectFourRules.AI

	var threat_cols: Array = []
	var valid_cols := ConnectFourRules.get_valid_columns(board_before)

	for opp_col in valid_cols:
		var temp := ConnectFourRules.copy_board(board_before)
		var row := ConnectFourRules.get_next_open_row(temp, opp_col)
		if row == -1:
			continue

		ConnectFourRules.drop_piece(temp, row, opp_col, opponent)
		if ConnectFourRules.winning_move(temp, opponent):
			threat_cols.append(opp_col)

	return threat_cols.has(col)

func move_prefers_center(col: int) -> bool:
	return col == COLS / 2

func infer_move_reason(board_before: Array, chosen_col: int, player: int, best_score: float, chosen_score: float) -> String:
	if move_creates_immediate_win(board_before, chosen_col, player):
		return "Creates an immediate winning move."

	if move_blocks_opponent_win(board_before, chosen_col, player):
		return "Blocks the opponent's immediate win."

	if move_prefers_center(chosen_col):
		return "Strengthens center control."

	var loss := best_score - chosen_score

	if loss <= 0.0:
		return "Matches the best evaluated move."
	elif loss <= 10.0:
		return "Very close to the strongest move."
	elif loss <= 40.0:
		return "Reasonable move, but not the best option."
	elif loss <= 100.0:
		return "Misses a stronger tactical move."
	else:
		return "Misses the best move by a large margin."

func is_critical_position(
	board_before: Array,
	chosen_col: int,
	player: int,
	best_score: float,
	chosen_score: float,
	confidence_gap,
	mistake_loss: float
) -> bool:
	if move_creates_immediate_win(board_before, chosen_col, player):
		return true

	if move_blocks_opponent_win(board_before, chosen_col, player):
		return true

	if mistake_loss >= 100.0:
		return true

	if confidence_gap != null and float(confidence_gap) >= 50.0:
		return true

	return false

func count_human_mistakes() -> int:
	var total := 0
	for move in move_history:
		if str(move.get("player", "")) == "human":
			var label := str(move.get("mistake_label", "none"))
			if label != "none" and label != "unlabeled":
				total += 1
	return total

func count_ai_mistakes() -> int:
	var total := 0
	for move in move_history:
		if str(move.get("player", "")) == "ai":
			var label := str(move.get("mistake_label", "none"))
			if label != "none" and label != "unlabeled":
				total += 1
	return total

func average_confidence_gap() -> float:
	var total := 0.0
	var count := 0

	for move in move_history:
		if move.has("confidence_gap") and move["confidence_gap"] != null:
			total += float(move["confidence_gap"])
			count += 1

	if count == 0:
		return 0.0

	return total / count

func apply_adaptive_level_to_ai() -> void:
	if ai_player == null:
		return

	if ai_player is MinimaxAI:
		match adaptive_state.current_level:
			1, 2:
				ai_player.depth = 2
			3, 4:
				ai_player.depth = 3
			5:
				ai_player.depth = 4
			6, 7:
				ai_player.depth = 5

func build_game_summary() -> Dictionary:
	return {
		"result": game_result,
		"num_moves": move_history.size(),
		"duration_seconds": elapsed_seconds,
		"human_mistakes": count_human_mistakes(),
		"ai_mistakes": count_ai_mistakes(),
		"avg_confidence_gap": average_confidence_gap()
	}
