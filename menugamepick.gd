extends Node2D

const MINESWEEPER_SCENE := preload("res://minesweeper.tscn")
const CALENDARTETRIS_SCENE := preload("res://calendartetris.tscn")

@onready var exitbtn: TextureButton = $exitbtn
@onready var flagbtn_minesweeper: TextureButton = get_node("01_task/minesweeper_btn/01flagbtn")
@onready var flagbtn_calendartetris: TextureButton = get_node("02_task/tetris_btn/02flagbtn")

func _ready() -> void:
	exitbtn.pressed.connect(_on_exitbtn_pressed)
	flagbtn_minesweeper.pressed.connect(_on_01flagbtn_pressed)
	flagbtn_calendartetris.pressed.connect(_on_02flagbtn_pressed)

func _on_exitbtn_pressed() -> void:
	queue_free()

func _on_01flagbtn_pressed() -> void:
	queue_free()
	var minesweeper := MINESWEEPER_SCENE.instantiate()
	get_tree().root.add_child(minesweeper)

func _on_02flagbtn_pressed() -> void:
	queue_free()
	var calendartetris := CALENDARTETRIS_SCENE.instantiate()
	get_tree().root.add_child(calendartetris)
