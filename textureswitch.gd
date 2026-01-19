extends Node
@export var normal_texture: AtlasTexture
@export var try_again_texture: AtlasTexture

@onready var button = get_parent() as TextureButton
@onready var main_minesweeper = get_tree().root.get_node("main_minesweeper")

func _ready():
	button.texture_normal = normal_texture
	button.texture_hover = normal_texture
	button.texture_pressed = normal_texture

	if main_minesweeper.has_signal("game_over_signal"):
		main_minesweeper.connect("game_over_signal", Callable(self, "game_over"))
	if main_minesweeper.has_signal("new_game_signal"):
		main_minesweeper.connect("new_game_signal", Callable(self, "reset"))

func game_over():
	button.texture_normal = try_again_texture
	button.texture_hover = try_again_texture
	button.texture_pressed = try_again_texture
	
func reset():
	if not button:
		return
	button.texture_normal = normal_texture
	button.texture_hover = normal_texture
	button.texture_pressed = normal_texture
