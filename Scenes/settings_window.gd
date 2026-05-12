extends Window

@export var bus_music: String = "Music"
@export var bus_sfx: String = "Sfx"
func _ready():
	$".".visible = !true
	var test = AdaptiveSessionState.new()
	print("Adaptive system loaded: ", test)

func _on_close_requested():
	$".".visible = !true
	SoundManager.play_partial_sound("click", 1)


func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://Scenes/GameStart.tscn")
	SoundManager.play_partial_sound("click", 1)
