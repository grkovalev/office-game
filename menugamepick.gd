extends Node2D

@onready var exitbtn: TextureButton = $exitbtn

func _ready() -> void:
	exitbtn.pressed.connect(_on_exitbtn_pressed)

func _on_exitbtn_pressed() -> void:
	queue_free()
