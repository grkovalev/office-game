extends Label

@export var start_value := 10
var current_value := 0

func _ready():
	current_value = start_value
	text = str(current_value)

func on_flag_changed(_delta: int) -> void:
	current_value +=_delta
	text = str(current_value)


func _on_tile_flag_changed(_delta: int) -> void:
	pass # Replace with function body.
