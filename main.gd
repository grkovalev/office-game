extends Node2D

const MINESWEEPER_SCENE := preload("res://minesweeper.tscn")

func _ready() -> void:
	get_tree().get_root().set_transparent_background(true)
	$btn_offer_help.pressed.connect(_on_btn_offer_help_pressed)

func _on_btn_offer_help_pressed() -> void:
	var minesweeper := MINESWEEPER_SCENE.instantiate()
	get_tree().root.add_child(minesweeper)
	minesweeper.get_node("Window").popup_centered()
