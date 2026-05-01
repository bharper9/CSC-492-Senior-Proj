extends Control

func _on_random_pressed()-> void:
	GameSettings.ai_type = "random"
	get_tree().change_scene_to_file("res://Scenes/Board.tscn")

func _on_min_max_pressed()-> void:
	GameSettings.ai_type = "minimax"
	get_tree().change_scene_to_file("res://Scenes/Board.tscn")

func _on_herustic_pressed()-> void:
	GameSettings.ai_type = "heuristic"
	get_tree().change_scene_to_file("res://Scenes/Board.tscn")

func _on_adapt_pressed()-> void:
	GameSettings.ai_type = "adaptive"
	get_tree().change_scene_to_file("res://Scenes/Board.tscn")


func _on_replays_pressed():
	get_tree().change_scene_to_file("res://Scenes/node_2d.tscn")


func _on_setting_pressed():
	$"Settings Window".visible = true
