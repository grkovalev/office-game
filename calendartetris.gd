extends Node2D

const GRID_WIDTH  := 20
const GRID_HEIGHT := 10
const TILE_SIZE   := 50

var cells: Array = []
var tile_nodes: Array = []

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
	tile_nodes.clear()
	for row in range(GRID_HEIGHT):
		var row_tiles: Array = []
		for col in range(GRID_WIDTH):
			var tile = create_tile()
			tile.position = Vector2(col * TILE_SIZE, row * TILE_SIZE)
			add_child(tile)
			row_tiles.append(tile)
		tile_nodes.append(row_tiles)


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


## Clamp base_cell so that every base_cell + local stays in grid bounds.
func clamp_base_cell_for_shape(local_cells: Array, base_cell: Vector2i) -> Vector2i:
	var min_lx := 0
	var max_lx := 0
	var min_ly := 0
	var max_ly := 0
	for local in local_cells:
		var o: Vector2i = local
		min_lx = mini(min_lx, o.x)
		max_lx = maxi(max_lx, o.x)
		min_ly = mini(min_ly, o.y)
		max_ly = maxi(max_ly, o.y)
	var clamp_x_min := maxi(0, -min_lx)
	var clamp_x_max := mini(GRID_WIDTH - 1 - max_lx, GRID_WIDTH - 1)
	var clamp_y_min := maxi(0, -min_ly)
	var clamp_y_max := mini(GRID_HEIGHT - 1 - max_ly, GRID_HEIGHT - 1)
	return Vector2i(
		clampi(base_cell.x, clamp_x_min, clamp_x_max),
		clampi(base_cell.y, clamp_y_min, clamp_y_max)
	)


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
			set_cell_color(cell, Color(0.8, 0.22, 0.543, 1.0))
			
func set_cell_color(cell: Vector2i, color: Color) -> void:
	if not cell_in_bounds(cell):
		return
	var tile: Panel = tile_nodes[cell.y][cell.x]
	var stylebox: StyleBoxFlat = tile.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	stylebox.bg_color = color
	tile.add_theme_stylebox_override("panel", stylebox)

func cell_to_world(cell:Vector2i)->Vector2:
	return to_global(Vector2(cell.x*TILE_SIZE+
	TILE_SIZE*0.5,cell.y*TILE_SIZE+TILE_SIZE*0.5))


# --- Collision-based placement (90% tile coverage) ---

const PLACEMENT_COVERAGE_THRESHOLD := 0.9

## Shoelace formula: signed area of polygon (positive = CCW).
func _polygon_area(poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return 0.0
	var area := 0.0
	for i in range(poly.size()):
		var j := (i + 1) % poly.size()
		area += poly[i].x * poly[j].y - poly[j].x * poly[i].y
	return abs(area) * 0.5


## Collect world-space polygons from an Area2D's collision (CollisionShape2D + CollisionPolygon2D).
func _get_shape_world_polygons(area: Area2D) -> Array:
	var polygons: Array = []
	var area_gt := area.global_transform
	for child in area.get_children():
		if child is CollisionShape2D:
			var cs: CollisionShape2D = child
			var shape: Shape2D = cs.shape
			if shape is RectangleShape2D:
				var rect: RectangleShape2D = shape
				var sz := rect.size
				var half := sz * 0.5
				var local := PackedVector2Array([
					Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
					Vector2(half.x, half.y), Vector2(-half.x, half.y)
				])
				var xf := area_gt * cs.transform
				var world := PackedVector2Array()
				for p in local:
					world.append(xf * p)
				polygons.append(world)
		elif child is CollisionPolygon2D:
			var cp: CollisionPolygon2D = child
			var local := cp.polygon
			var xf := cp.global_transform
			var world := PackedVector2Array()
			for p in local:
				world.append(xf * p)
			polygons.append(world)
	return polygons


## Four corners of tile (col, row) in world space.
func _tile_rect_world(col: int, row: int) -> PackedVector2Array:
	var a := to_global(Vector2(col * TILE_SIZE, row * TILE_SIZE))
	var b := to_global(Vector2((col + 1) * TILE_SIZE, row * TILE_SIZE))
	var c := to_global(Vector2((col + 1) * TILE_SIZE, (row + 1) * TILE_SIZE))
	var d := to_global(Vector2(col * TILE_SIZE, (row + 1) * TILE_SIZE))
	return PackedVector2Array([a, b, c, d])


## True if intersection area of tile with any shape polygon >= threshold * tile_area.
func _tile_covered_by_polygons(col: int, row: int, shape_polygons: Array, threshold: float) -> bool:
	var tile_poly: PackedVector2Array = _tile_rect_world(col, row)
	var tile_area := _polygon_area(tile_poly)
	if tile_area <= 0.0:
		return false
	var required := tile_area * threshold
	for shape_poly in shape_polygons:
		var sp: PackedVector2Array = shape_poly
		var intersection: Array = Geometry2D.intersect_polygons(tile_poly, sp)
		var total := 0.0
		for part in intersection:
			var piece: PackedVector2Array = part
			total += _polygon_area(piece)
		if total >= required:
			return true
	return false


func get_cells_covered_by_piece(area: Area2D, threshold: float) -> Array:
	var shape_polygons: Array = _get_shape_world_polygons(area)
	var covered: Array = []
	for row in range(GRID_HEIGHT):
		for col in range(GRID_WIDTH):
			if _tile_covered_by_polygons(col, row, shape_polygons, threshold):
				covered.append(Vector2i(col, row))
	return covered


func can_place_piece_by_collision(area: Area2D, threshold: float) -> bool:
	var covered: Array = get_cells_covered_by_piece(area, threshold)
	for cell in covered:
		var c: Vector2i = cell
		if not cell_in_bounds(c):
			return false
		if cells[c.y][c.x]:
			return false
	return true


func place_piece_by_collision(area: Area2D, threshold: float) -> void:
	var covered: Array = get_cells_covered_by_piece(area, threshold)
	for cell in covered:
		var c: Vector2i = cell
		if cell_in_bounds(c):
			cells[c.y][c.x] = true
			set_cell_color(c, Color(0.8, 0.22, 0.543, 1.0))
