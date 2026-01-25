extends Node2D

@onready var blue_piece : Sprite2D = $BlueConnectfour

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_click"):
		var tween = create_tween()
		tween.tween_property(blue_piece, "position", Vector2(-100,0), 1)
