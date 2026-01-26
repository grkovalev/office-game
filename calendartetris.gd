extends Node2D

const GRID_WIDTH = 20
const GRID_HEIGHT = 10
const TILE_SIZE = 50

func _ready() -> void:
	create_grid()

func create_grid() -> void:
	for row in range(GRID_HEIGHT):
		for col in range(GRID_WIDTH):
			var tile = create_tile()
			tile.position = Vector2(col * TILE_SIZE, row * TILE_SIZE)
			add_child(tile)

func create_tile() -> Panel:
	var tile = Panel.new()
	tile.size = Vector2(TILE_SIZE, TILE_SIZE)
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.804, 0.854, 0.99, 0.4)
	stylebox.border_color = Color(1.0, 1.0, 1.0, 0.7) 
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	tile.add_theme_stylebox_override("panel", stylebox)
	
	return tile
