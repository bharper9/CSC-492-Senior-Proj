extends RichTextLabel

var colors := [
	"red",
	"orange",
	"yellow",
	"green",
	"cyan",
	"blue",
	"purple"
]

var color_index := 0
var display_text := "CONNECT FOUR"

func _ready() -> void:
	bbcode_enabled = true
	update_text()

	var timer := Timer.new()
	timer.wait_time = 0.3
	timer.autostart = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func _on_timer_timeout() -> void:
	color_index = (color_index + 1) % colors.size()
	update_text()

func update_text() -> void:
	text = "[center][color=%s]%s[/color][/center]" % [
		colors[color_index],
		display_text
	]
