extends HSlider

@export var bus_name: String = "Master"
var bus_index: int = -1

func _ready() -> void:
	bus_index = AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		push_error("Audio bus not found: " + bus_name)
		return

	min_value = 0.0
	max_value = 1.0
	step = 0.01

	value = db_to_linear(AudioServer.get_bus_volume_db(bus_index))
	value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: float) -> void:
	if bus_index == -1:
		return

	if new_value <= 0.0:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(new_value))
