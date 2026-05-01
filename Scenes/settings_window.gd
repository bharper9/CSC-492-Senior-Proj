extends Window


func _ready():
	$".".visible = !true
	var test = AdaptiveSessionState.new()
	print("Adaptive system loaded: ", test)

func _on_close_requested():
	$".".visible = !true


func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://Scenes/GameStart.tscn")
