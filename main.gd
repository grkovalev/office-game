extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Set bg transparent.
	get_tree().get_root().set_transparent_background(true)
