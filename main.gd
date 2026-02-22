extends Node2D

const MENUGAMEPICK_SCENE := preload("res://menugamepick.tscn")

func _ready() -> void:
	get_tree().get_root().set_transparent_background(true)
	$btn_offer_help.pressed.connect(_on_btn_offer_help_pressed)

func _on_btn_offer_help_pressed() -> void:
	$btn_tomat.pause_if_running()
	var menugamepick := MENUGAMEPICK_SCENE.instantiate()
	get_tree().root.add_child(menugamepick)
