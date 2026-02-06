extends Node2D

signal rows_cleared(num_rows)
signal free_rows_updated(total)

const GRID_WIDTH  := 20
const GRID_HEIGHT := 10
const TILE_SIZE   := 50
const CHAR_ATLAS_COLS := 3
const CHAR_ATLAS_ROWS := 7
const CHAR_TILE_W := 256
const CHAR_TILE_H := 256

@onready var tetromino_lib = $"../tetromino_lib"
@onready var restartbtn: TextureButton = $"../restartbtn"
@onready var exitbtn: TextureButton = $"../exitbtn"
@onready var quickshapepack = $"../quickshapepack"
@onready var calchars: Node2D = $calchars
@onready var meeting_lib: Node2D = $"../meeting_lib"

var cells: Array = []
var cell_player_placed: Array = []  # [y][x] = true if placed by player (not prefilled)
var tile_nodes: Array = []
var _meeting_sprites: Array = []  # Sprites created for each meeting (persist until restart)
var cell_colors: Array = []  # [y][x] = Color or null, for neighbor-avoiding color pick
var _region_default_atlas_row: Dictionary = {}
var free_region_rows_remaining: int = 0

func _ready() -> void:
	randomize()
	# Draw pieces above the grid (grid_container has z_index 4) so hovering/dragged pieces are always on top
	if tetromino_lib != null:
		tetromino_lib.z_index = 10
	if quickshapepack != null:
		quickshapepack.z_index = 10
	# Reparent meeting_lib under grid_container so it shares coords and draws above tiles
	if meeting_lib != null:
		var old_parent = meeting_lib.get_parent()
		if old_parent != self:
			old_parent.remove_child(meeting_lib)
			add_child(meeting_lib)
		meeting_lib.position = Vector2.ZERO
		meeting_lib.z_index = 5
		# Hide template sprites (we duplicate them for each meeting)
		for name in ["1rowmeeting", "2rowmeeting", "3rowmeeting"]:
			var t = meeting_lib.get_node_or_null(name)
			if t != null:
				t.visible = false
	_init_cells()
	create_grid()
	prefill_regions_with_random_shapes.call_deferred()
	_randomize_region_characters()
	restartbtn.pressed.connect(_on_restartbtn_pressed)
	exitbtn.pressed.connect(_on_exitbtn_pressed)


func _init_cells() -> void:
	cells.clear()
	cell_colors.clear()
	cell_player_placed.clear()
	for y in range(GRID_HEIGHT):
		var row: Array = []
		var color_row: Array = []
		var placed_row: Array = []
		for x in range(GRID_WIDTH):
			row.append(false)
			color_row.append(null)
			placed_row.append(false)
		cells.append(row)
		cell_colors.append(color_row)
		cell_player_placed.append(placed_row)


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

func _randomize_region_characters() -> void:
	if calchars == null:
		return

	# Collect all Sprite2D children under calchars (reg1_char, reg2_char, etc.)
	var sprites: Array[Sprite2D] = []
	for child in calchars.get_children():
		if child is Sprite2D:
			sprites.append(child)

	if sprites.is_empty():
		return

	# First column only, rows 0..5; pick one per sprite, no duplicates
	var available_rows: Array[int] = [0, 1, 2, 3, 4, 5]
	available_rows.shuffle()

	var count: int = min(sprites.size(), available_rows.size())
	for i in range(count):
		var sprite := sprites[i] as Sprite2D
		var row_idx: int = available_rows[i]
		var col_idx: int = 0

		_region_default_atlas_row[i] = row_idx
		sprite.region_enabled = true
		sprite.region_rect = Rect2(
			col_idx * CHAR_TILE_W,
			row_idx * CHAR_TILE_H,
			CHAR_TILE_W,
			CHAR_TILE_H
		)
const HOVER_ATLAS_COL := 0  # default: atlas column 0 (first column)
const HOVER_ATLAS_COL_ACTIVE := 2  # hover on row 4/5: atlas column 2
const HOVER_ATLAS_COL_ROW10 := 1  # hover on row 10: atlas column 1

func _get_region_sprites_ordered() -> Array:
	if calchars == null:
		return []
	var sprites: Array = []
	for child in calchars.get_children():
		if child is Sprite2D:
			sprites.append(child)
	return sprites

func _set_region_sprite_atlas_column(region_index: int, atlas_col: int) -> void:
	var sprites := _get_region_sprites_ordered()
	if region_index < 0 or region_index >= sprites.size():
		return
	var row: int = _region_default_atlas_row.get(region_index, 0)
	var sprite: Sprite2D = sprites[region_index]
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		atlas_col * CHAR_TILE_W,
		row * CHAR_TILE_H,
		CHAR_TILE_W,
		CHAR_TILE_H
	)

func _restore_all_region_characters_to_default() -> void:
	var sprites := _get_region_sprites_ordered()
	for i in range(sprites.size()):
		_set_region_sprite_atlas_column(i, HOVER_ATLAS_COL)

const HOVER_ROW_MIN := 3  # 0-based: rows 3–5 so row 4 and 5 both trigger (3 covers top of row 4)
const HOVER_ROW_MAX := 5
const HOVER_ROW_10 := 9  # 0-based: row 10 (last row)

func _update_region_characters_for_hover(covered_cells: Array) -> void:
	# Per region: which atlas column to use (0 default, 1 row-10, 2 rows 4/5)
	# Only consider unoccupied cells — hovering over filled tiles does not change the sprite
	var regions_to_atlas_col: Dictionary = {}
	for cell in covered_cells:
		var c: Vector2i = cell
		if is_cell_occupied(c):
			continue
		var region_index: int = c.x / COLUMNS_PER_REGION
		if c.y == HOVER_ROW_10:
			regions_to_atlas_col[region_index] = HOVER_ATLAS_COL_ROW10
		elif c.y >= HOVER_ROW_MIN and c.y <= HOVER_ROW_MAX:
			# Only set if not already set to row-10 (row 10 takes precedence if we ever overlap)
			if not regions_to_atlas_col.has(region_index):
				regions_to_atlas_col[region_index] = HOVER_ATLAS_COL_ACTIVE
	var sprites := _get_region_sprites_ordered()
	for i in range(sprites.size()):
		var col: int = regions_to_atlas_col.get(i, HOVER_ATLAS_COL)
		_set_region_sprite_atlas_column(i, col)

func _process(_delta: float) -> void:
	if calchars == null:
		return
	# Quickshapepack: unassigned quickshape being dragged from "MAKE IT QUICK"
	if quickshapepack != null and is_instance_valid(quickshapepack.dragging_quickshape):
		var cell := world_to_cell(quickshapepack.dragging_quickshape.global_position)
		if cell_in_bounds(cell):
			_update_region_characters_for_hover([cell])
		else:
			_restore_all_region_characters_to_default()
		return
	# Tetromino_lib: piece from slot (tetromino Area2D or assigned quickshape)
	if tetromino_lib != null and tetromino_lib.dragging and tetromino_lib.selected_slot >= 0:
		var piece = tetromino_lib.pieces[tetromino_lib.selected_slot]
		if piece != null:
			if tetromino_lib._is_quickshape_piece(piece):
				var qs: Node2D = piece.get("quickshape")
				if is_instance_valid(qs):
					var cell := world_to_cell(qs.global_position)
					if cell_in_bounds(cell):
						_update_region_characters_for_hover([cell])
					else:
						_restore_all_region_characters_to_default()
				else:
					_restore_all_region_characters_to_default()
				return
			else:
				var area: Area2D = piece.get("area")
				if is_instance_valid(area):
					var covered := get_cells_covered_by_piece(area, PLACEMENT_COVERAGE_THRESHOLD)
					#opacity when hovering over the grid, full opacity otherwise
					area.modulate = Color(1.0, 1.0, 1.0, 0.9 if covered.size() > 0 else 1.0)
					_update_region_characters_for_hover(covered)
					return
	_restore_all_region_characters_to_default()

func cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT

func is_cell_occupied(cell: Vector2i) -> bool:
	if not cell_in_bounds(cell):
		return false
	return cells[cell.y][cell.x]

func place_quick_shape(cell: Vector2i) -> void:
	if not cell_in_bounds(cell):
		return
	var neighbor_colors := _get_neighbor_colors([cell])
	var color: Color = _pick_color_avoiding(neighbor_colors)
	cells[cell.y][cell.x] = true
	cell_player_placed[cell.y][cell.x] = true
	set_cell_color(cell, color)
	_apply_full_row_meeting([cell])

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
	var placed_cells: Array = []
	for local in local_cells:
		var offset: Vector2i = local
		var cell: Vector2i = base_cell + offset
		if cell_in_bounds(cell):
			placed_cells.append(cell)
	var neighbor_colors := _get_neighbor_colors(placed_cells)
	var color: Color = _pick_color_avoiding(neighbor_colors)
	for cell in placed_cells:
		var c: Vector2i = cell
		if cell_in_bounds(c):
			cells[c.y][c.x] = true
			cell_player_placed[c.y][c.x] = true
			set_cell_color(c, color)
	_apply_full_row_meeting(placed_cells)

func set_cell_color(cell: Vector2i, color: Color) -> void:
	if not cell_in_bounds(cell):
		return
	cell_colors[cell.y][cell.x] = color
	var tile: Panel = tile_nodes[cell.y][cell.x]
	var stylebox: StyleBoxFlat = tile.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	stylebox.bg_color = color
	tile.add_theme_stylebox_override("panel", stylebox)

# Returns distinct colors of cells that are 4-adjacent to any of the given cells
func _get_neighbor_colors(placed_cells: Array) -> Array:
	var colors: Array = []
	var seen: Dictionary = {}
	for cell in placed_cells:
		var c: Vector2i = cell
		for dx in [ -1, 1 ]:
			var nx: int = c.x + dx
			if nx >= 0 and nx < GRID_WIDTH:
				var col = cell_colors[c.y][nx]
				if col != null:
					var k: String = col.to_html(false)
					if not seen.has(k):
						seen[k] = true
						colors.append(col)
		for dy in [ -1, 1 ]:
			var ny: int = c.y + dy
			if ny >= 0 and ny < GRID_HEIGHT:
				var col = cell_colors[ny][c.x]
				if col != null:
					var k: String = col.to_html(false)
					if not seen.has(k):
						seen[k] = true
						colors.append(col)
	return colors

func _pick_color_avoiding(neighbor_colors: Array) -> Color:
	var candidates: Array = []
	for atlas_color in COLOR_ATLAS:
		var ok := true
		for n in neighbor_colors:
			if atlas_color.is_equal_approx(n):
				ok = false
				break
		if ok:
			candidates.append(atlas_color)
	if candidates.is_empty():
		return COLOR_ATLAS[0]
	return candidates[randi() % candidates.size()]

func mark_cells_occupied(covered_cells: Array, color: Color) -> void:
	for cell in covered_cells:
		var c: Vector2i = cell
		if cell_in_bounds(c):
			cells[c.y][c.x] = true
			set_cell_color(c, color)

const PREFILLED_TILE := Color(0.949, 0.475, 0.0, 0.7)
const COLUMNS_PER_REGION := 5

# Color atlas for placed tiles; same color is never picked for adjacent cells
const COLOR_ATLAS: Array[Color] = [
	Color(0.493, 0.531, 0.56, 0.7),
	Color(0.413, 0.449, 0.476, 0.7), 
	Color(0.365, 0.399, 0.424, 0.7), 
]
# Prefill count per region = PREFILLS_BY_ATLAS_ROW[atlas_row assigned to regN_char]. Index = atlas row 0..5.
const PREFILLS_BY_ATLAS_ROW: Array[int] = [5, 3, 4, 2, 3, 1]

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

	var num_regions := GRID_WIDTH / COLUMNS_PER_REGION
	for region_index in range(num_regions):
		var atlas_row: int = _region_default_atlas_row.get(region_index, 0)
		var shapes_target: int = PREFILLS_BY_ATLAS_ROW[atlas_row] if atlas_row < PREFILLS_BY_ATLAS_ROW.size() else 0
		var col_start := region_index * COLUMNS_PER_REGION
		var col_end := col_start + COLUMNS_PER_REGION - 1
		var shapes_placed := 0

		while shapes_placed < shapes_target:
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

	# After all prefilled shapes are placed, compute initial free rows per region
	free_region_rows_remaining = get_free_region_rows_count()
	emit_signal("free_rows_updated", free_region_rows_remaining)

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


const TETROMINO_CELL_COUNT := 4  # piece must cover this many grid cells to count as placed

func can_place_piece_by_collision(area: Area2D, threshold: float) -> bool:
	var covered: Array = get_cells_covered_by_piece(area, threshold)
	# Require piece to actually cover grid cells (reject drop outside grid or partial overlap)
	if covered.is_empty() or covered.size() < TETROMINO_CELL_COUNT:
		return false
	for cell in covered:
		var c: Vector2i = cell
		if not cell_in_bounds(c):
			return false
		if cells[c.y][c.x]:
			return false
	return true


func place_piece_by_collision(area: Area2D, threshold: float) -> void:
	var covered: Array = get_cells_covered_by_piece(area, threshold)
	var placed_cells: Array = []
	for cell in covered:
		var c: Vector2i = cell
		if cell_in_bounds(c):
			placed_cells.append(c)
	var neighbor_colors := _get_neighbor_colors(placed_cells)
	var color: Color = _pick_color_avoiding(neighbor_colors)
	for c in placed_cells:
		var cell: Vector2i = c
		if cell_in_bounds(cell):
			cells[cell.y][cell.x] = true
			cell_player_placed[cell.y][cell.x] = true
			set_cell_color(cell, color)
	_apply_full_row_meeting(placed_cells)

const MEETING_WHITE := Color(1.0, 1.0, 1.0, 1.0)

# Returns true if cell was placed by player (not prefilled)
func _is_cell_player_placed(cell: Vector2i) -> bool:
	if not cell_in_bounds(cell):
		return false
	return cell_player_placed[cell.y][cell.x]

# Check if a row in a region is fully filled by player-placed tiles only
func _is_region_row_full(region_index: int, row: int) -> bool:
	var col_start := region_index * COLUMNS_PER_REGION
	for c in range(COLUMNS_PER_REGION):
		var cell := Vector2i(col_start + c, row)
		if not _is_cell_player_placed(cell):
			return false
	return true

# Get list of rows in a region that became full from our last placement
func _get_completed_rows_in_region(region_index: int, placed_cells: Array) -> Array:
	var col_start := region_index * COLUMNS_PER_REGION
	var col_end := col_start + COLUMNS_PER_REGION - 1
	var candidate_rows: Dictionary = {}
	for cell in placed_cells:
		var c: Vector2i = cell
		if c.x >= col_start and c.x <= col_end:
			candidate_rows[c.y] = true
	var result: Array = []
	for row in candidate_rows.keys():
		if _is_region_row_full(region_index, row):
			result.append(row)
	result.sort()
	return result

# Returns longest consecutive run including topmost completed row
func _get_consecutive_completed_rows(rows: Array) -> Array:
	if rows.is_empty():
		return []
	rows = rows.duplicate()
	rows.sort()
	var best_start: int = rows[0]
	var best_len: int = 1
	var start: int = rows[0]
	var len: int = 1
	for i in range(1, rows.size()):
		if rows[i] == rows[i - 1] + 1:
			len += 1
		else:
			if len > best_len:
				best_len = len
				best_start = start
			start = rows[i]
			len = 1
	if len > best_len:
		best_len = len
		best_start = start
	var out: Array = []
	for r in range(best_len):
		out.append(best_start + r)
	return out

func _apply_full_row_meeting(placed_cells: Array) -> void:
	if meeting_lib == null or placed_cells.is_empty():
		return

	var num_regions := GRID_WIDTH / COLUMNS_PER_REGION
	var regions_to_show: Array = []
	var total_rows_cleared: int = 0

	for region_index in range(num_regions):
		var completed := _get_completed_rows_in_region(region_index, placed_cells)
		if completed.is_empty():
			continue
		var consecutive := _get_consecutive_completed_rows(completed)
		var count := consecutive.size()
		if count <= 0 or count > 3:
			continue
		# Turn tiles white
		for row in consecutive:
			var col_start := region_index * COLUMNS_PER_REGION
			for c in range(COLUMNS_PER_REGION):
				var cell := Vector2i(col_start + c, row)
				set_cell_color(cell, MEETING_WHITE)
		regions_to_show.append({
			"region": region_index,
			"rows": consecutive,
			"count": count
		})
		total_rows_cleared += count

	# Create persistent meeting sprites (one per region completion)
	var templates: Dictionary = {
		1: meeting_lib.get_node_or_null("1rowmeeting"),
		2: meeting_lib.get_node_or_null("2rowmeeting"),
		3: meeting_lib.get_node_or_null("3rowmeeting")
	}
	for entry in regions_to_show:
		var count: int = entry["count"]
		var template: Sprite2D = templates.get(count, null)
		if template == null or template.texture == null:
			continue
		var spr := Sprite2D.new()
		spr.texture = template.texture
		spr.centered = false
		spr.z_index = 1  # Above tiles (default 0)
		var reg: int = entry["region"]
		var rows: Array = entry["rows"]
		var r0: int = rows[0]
		# Position = top-left of first tile in block; tiles use (col*TILE_SIZE, row*TILE_SIZE)
		var left_col := reg * COLUMNS_PER_REGION
		var left := left_col * TILE_SIZE
		var top := r0 * TILE_SIZE
		spr.position = Vector2(left, top)
		add_child(spr)  # Direct child of grid_container, same as tiles
		_meeting_sprites.append(spr)

	if total_rows_cleared > 0:
		# Update remaining free rows counter and notify listeners
		free_region_rows_remaining = max(free_region_rows_remaining - total_rows_cleared, 0)
		emit_signal("rows_cleared", total_rows_cleared)
		emit_signal("free_rows_updated", free_region_rows_remaining)

func _on_restartbtn_pressed() -> void:
	_restart_grid()


func _on_exitbtn_pressed() -> void:
	get_parent().queue_free()
	
func get_free_region_rows_count() -> int:
	# Count, for each 5-column region, how many rows have zero *prefilled* cells.
	# Prefilled = cells[y][x] is true AND cell_player_placed[y][x] is false.
	var total_free_rows := 0
	var num_regions := GRID_WIDTH / COLUMNS_PER_REGION

	for region_index in range(num_regions):
		var col_start := region_index * COLUMNS_PER_REGION
		var col_end := col_start + COLUMNS_PER_REGION - 1

		for row in range(GRID_HEIGHT):
			var has_prefilled := false
			for col in range(col_start, col_end + 1):
				if cells[row][col] and not cell_player_placed[row][col]:
					has_prefilled = true
					break
			if not has_prefilled:
				# This row segment in this region has 0 prefilled cells
				total_free_rows += 1

	return total_free_rows


func _restart_grid() -> void:
	# Only free grid tiles, not calchars (so region sprites stay and can be refreshed)
	for row in tile_nodes:
		for tile in row:
			if is_instance_valid(tile):
				tile.queue_free()
	tile_nodes.clear()

	_init_cells()
	create_grid()
	prefill_regions_with_random_shapes.call_deferred()

	if is_instance_valid(quickshapepack):
		quickshapepack.reset_quickshapes()

	_randomize_region_characters()

	if meeting_lib != null:
		for spr in _meeting_sprites:
			if is_instance_valid(spr):
				spr.queue_free()
		_meeting_sprites.clear()
