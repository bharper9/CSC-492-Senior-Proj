extends AudioStreamPlayer2D

@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var sounds = {
	"click": preload("res://Art/magiaz-bouncing_sound_effects_in_game-3-363533.mp3"),
	"move": preload("res://Art/freesound_community-playing-connect-4-on-hardwood-floor-17171.mp3"),
	"win": preload("res://Art/puyopuyomegafan1234-winner-game-sound-404167.mp3"),
	"lose": preload("res://Art/mori_sound-fx-game-over-497165.mp3")
}

func play_partial_sound(name: String, duration: float) -> void:
	if not sounds.has(name):
		return

	var player = AudioStreamPlayer.new()
	player.stream = sounds[name]
	player.bus = "SFX"

	add_child(player)
	player.play()

	# Stop after duration
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
