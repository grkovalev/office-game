extends Node

@onready var sprite: AnimatedSprite2D = get_node("/root/main/anim_idlescreen")
@onready var btn := get_parent() as TextureButton

func _ready() -> void:
	btn.toggled.connect(_on_toggled)

func _play(anim_name: String):
	sprite.play(anim_name)

func _on_toggled(pressed: bool):
	print("Toggled:", pressed)
	if pressed:
		_play("anim_focused")
	else:
		_play("anim_idle_default")
