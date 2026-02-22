extends Node2D

@onready var winlostmsgbg: Sprite2D = $winlostmsgbg
@onready var gg_tetris: Sprite2D = $gg_tetris
@onready var glost_tetris: Sprite2D = $glost_tetris
@onready var gg_text: Label = $gg_text
@onready var glost_text: Label = $glost_text

func _ready() -> void:
	hide_msg()

func show_win() -> void:
	z_index = 100  # On top of everything
	winlostmsgbg.visible = true
	gg_tetris.visible = true
	gg_text.visible = true
	glost_tetris.visible = false
	glost_text.visible = false
	show()

func show_lose() -> void:
	z_index = 100  # On top of everything
	winlostmsgbg.visible = true
	glost_tetris.visible = true
	glost_text.visible = true
	gg_tetris.visible = false
	gg_text.visible = false
	show()

func hide_msg() -> void:
	winlostmsgbg.visible = false
	gg_tetris.visible = false
	glost_tetris.visible = false
	gg_text.visible = false
	glost_text.visible = false
	hide()
