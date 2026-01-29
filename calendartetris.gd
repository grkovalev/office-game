extends Node2D

const GRID_WIDTH  := 20
const GRID_HEIGHT := 10
const TILE_SIZE   := 50

@onready var tetromino_lib = $"../tetromino_lib"

var cells: Array = []
var tile_nodes: Array = []

func _ready() -> void:
	_init_cells()
	create_grid()
	prefill_regions_with_random_shapes.call_deferred()


func _init_cells() -> void:
	cells.clear()
	for y in range(GRID_HEIGHT):
		var row: Array = []
		for x in range(GRID_WIDTH):
			row.append(false)
		cells.append(row)


func create_grid() -> void:
	tile_nodes.clear()
	for row in range(GRID_HEIGHT):
		var row_tiles: Array = []
		for col in range(GRID_WIDTH):
			var tile = create_tile(col)
			tile.position = Vector2(col * TILE_SIZE, row * TILE_SIZE)
			add_child(tile)
			row_tiles.append(tile)
		tile_nodes.append(row_tiles)


func create_tile(col: int) -> Panel:
	var tile = Panel.new()
	tile.size = Vector2(TILE_SIZE, TILE_SIZE)
	var stylebox = StyleBoxFlat.new()
	if col % 10 < 5:
		stylebox.bg_color = Color(0.443, 0.686, 0.898, 0.5)
	else:
		stylebox.bg_color = Color(0.871, 0.925, 0.976, 0.5)
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
			set_cell_color(cell, Color(1.0, 0.502, 0.0, 0.792))
			
func set_cell_color(cell: Vector2i, color: Color) -> void:
	if not cell_in_bounds(cell):
		return
	var tile: Panel = tile_nodes[cell.y][cell.x]
	var stylebox: StyleBoxFlat = tile.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	stylebox.bg_color = color
	tile.add_theme_stylebox_override("panel", stylebox)
	
func mark_cells_occupied(covered_cells: Array, color: Color) -> void:
	for cell in covered_cells:
		var c: Vector2i = cell
		if cell_in_bounds(c):
			cells[c.y][c.x] = true
			set_cell_color(c, color)

const PREFILLED_TILE := Color(0.0, 0.271, 0.471, 0.443)
const COLUMNS_PER_REGION := 5

## Returns [min_col, max_col, min_row, max_row] for base_cell so that base_cell + local stays in region and bounds.
func _base_cell_range_in_region(local_cells: Array, col_start: int, col_end: int) -> Array:
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
	var min_base_col := maxi(0, col_start - min_lx)
	var max_base_col := mini(GRID_WIDTH - 1 - max_lx, col_end - max_lx)
	var min_base_row := maxi(0, -min_ly)
	var max_base_row := GRID_HEIGHT - 1 - max_ly
	return [min_base_col, max_base_col, min_base_row, max_base_row]

func prefill_regions_with_random_shapes() -> void:
	if tetromino_lib == null:
		return
	var shape_ids: Array = tetromino_lib.SHAPES.keys()
	if shape_ids.is_empty():
		return
	await get_tree().process_frame

	const SHAPES_PER_REGION := 2
	var num_regions := GRID_WIDTH / COLUMNS_PER_REGION
	for region_index in range(num_regions):
		var col_start := region_index * COLUMNS_PER_REGION
		var col_end := col_start + COLUMNS_PER_REGION - 1
		var shapes_placed := 0

		while shapes_placed < SHAPES_PER_REGION:
			var placed_this_attempt := false
			for _attempt in range(80):
				var shape_id: String = shape_ids[randi() % shape_ids.size()]
				var rotation: int = randi() % 4
				var local_cells: Array = tetromino_lib.SHAPES[shape_id][rotation]

				var range_v: Array = _base_cell_range_in_region(local_cells, col_start, col_end)
				var min_base_col: int = range_v[0]
				var max_base_col: int = range_v[1]
				var min_base_row: int = range_v[2]
				var max_base_row: int = range_v[3]
				if min_base_col > max_base_col or min_base_row > max_base_row:
					continue

				var base_col := min_base_col + randi() % (max_base_col - min_base_col + 1)
				var base_row := min_base_row + randi() % (max_base_row - min_base_row + 1)
				var base_cell := Vector2i(base_col, base_row)

				if not can_place_piece(local_cells, base_cell):
					continue

				for local in local_cells:
					var offset: Vector2i = local
					var cell: Vector2i = base_cell + offset
					if cell_in_bounds(cell):
						cells[cell.y][cell.x] = true
						set_cell_color(cell, PREFILLED_TILE)
				placed_this_attempt = true
				shapes_placed += 1
				break
			if not placed_this_attempt:
				break

func cell_to_world(cell:Vector2i)->Vector2:
	return to_global(Vector2(cell.x*TILE_SIZE+
	TILE_SIZE*0.5,cell.y*TILE_SIZE+TILE_SIZE*0.5))


const PLACEMENT_COVERAGE_THRESHOLD := 0.9
func _polygon_area(poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return 0.0
	var area := 0.0
	for i in range(poly.size()):
		var j := (i + 1) % poly.size()
		area += poly[i].x * poly[j].y - poly[j].x * poly[i].y
	return abs(area) * 0.5

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

func _tile_rect_world(col: int, row: int) -> PackedVector2Array:
	var a := to_global(Vector2(col * TILE_SIZE, row * TILE_SIZE))
	var b := to_global(Vector2((col + 1) * TILE_SIZE, row * TILE_SIZE))
	var c := to_global(Vector2((col + 1) * TILE_SIZE, (row + 1) * TILE_SIZE))
	var d := to_global(Vector2(col * TILE_SIZE, (row + 1) * TILE_SIZE))
	return PackedVector2Array([a, b, c, d])

func _tile_covered_by_polygons(col: int, row: int, shape_polygons: Array, threshold: float) -> bool:
	var tile_poly: PackedVector2Array = _tile_rect_world(col, row)
	var tile_center := to_global(Vector2(col * TILE_SIZE + TILE_SIZE * 0.5, row * TILE_SIZE + TILE_SIZE * 0.5))
	for shape_poly in shape_polygons:
		var sp: PackedVector2Array = shape_poly
		if Geometry2D.is_point_in_polygon(tile_center, sp):
			return true
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
			set_cell_color(c, Color(1.0, 0.502, 0.0, 0.718))
