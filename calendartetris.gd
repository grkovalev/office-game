extends Node2D

const GRID_WIDTH  := 20
const GRID_HEIGHT := 10
const TILE_SIZE   := 50

var cells: Array = []   # cells[y][x] = bool, true if occupied

func _ready() -> void:
	_init_cells()
	create_grid()


func _init_cells() -> void:
	cells.clear()
	for y in range(GRID_HEIGHT):
		var row: Array = []
		for x in range(GRID_WIDTH):
			row.append(false)    # start empty
		cells.append(row)


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


func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local_pos := to_local(world_pos)
	var col := int(floor(local_pos.x / TILE_SIZE))
	var row := int(floor(local_pos.y / TILE_SIZE))
	return Vector2i(col, row)


func cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


func can_place_piece(local_cells: Array, base_cell: Vector2i) -> bool:
	for local in local_cells:
		var offset: Vector2i = local
		var cell: Vector2i = base_cell + offset
		if not cell_in_bounds(cell):
			return false
		if cells[cell.y][cell.x]:
			return false
	return true


func place_piece(local_cells: Array, base_cell: Vector2i, shape_id: String) -> void:
	for local in local_cells:
		var offset: Vector2i = local
		var cell: Vector2i = base_cell + offset
		if cell_in_bounds(cell):
			cells[cell.y][cell.x] = true

func cell_to_world(cell:Vector2i)->Vector2:
	return to_global(Vector2(cell.x*TILE_SIZE+
	TILE_SIZE*0.5,cell.y*TILE_SIZE+TILE_SIZE*0.5))
