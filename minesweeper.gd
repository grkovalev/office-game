extends Node2D

@onready var tiles = $Window/tiles_minesweeper/grid9x9
@onready var tile: TileTemplateButton = $Window/tiles_minesweeper/grid9x9/tile
@onready var avaAnim: AnimatedSprite2D = $Window/avatar_slack

var board:Board
var buttons:={}

func _ready() -> void:
	if tiles == null:
		push_error("Tiles are not defined")
	
	if tile == null:
		push_error("Tile is not defined")
	

	board = Board.new()
	for i in range(board.cells_count):
		var row := int(i / board.columns)
		var column := int(i % board.columns)
		var tile_copy = tile.duplicate()
		tile_copy.row_index = row
		tile_copy.column_index = column
		tile_copy.gui_input.connect(
			func(event):
				_on_button_gui_input(event, tile_copy)
				)
		tile_copy.mouse_entered.connect(
			func(): _on_button_hover(tile_copy)
			)
		tiles.add_child(tile_copy)
		buttons[Vector2i(column, row)] = tile_copy
	tiles.remove_child(tile)

func _on_button_hover(btn: TileTemplateButton):
	var column = btn.column_index
	var anim_idx = int((column + 1) / 3)
	if anim_idx == 1:
		avaAnim.play("def_left")
		return
	if anim_idx == 2:
		avaAnim.play("def_center")
		return
	if anim_idx == 3:
		avaAnim.play("def_right")

func _on_button_gui_input(event: InputEvent, btn: TileTemplateButton) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_on_left_click(btn)
			MOUSE_BUTTON_RIGHT:
				_on_right_click(btn)
func _on_right_click(btn: TileTemplateButton) -> void:
	var state = board._get_cell_state(btn.column_index, btn.row_index)
	if state.open:
		return
	if state.has_flag:
		state.has_flag = false
		btn.set_tile(0)
		return
	state.has_flag = true
	btn.set_tile(6)
	
func _on_left_click(btn: TileTemplateButton) -> void:
	var state:CellState= board._get_cell_state(btn.column_index, btn.row_index)
	if state.open:
		return
	state.open = true
	if state.has_mine:
		btn.set_tile(7)
		return
	var danger_level = board._get_danger_level(btn.column_index, btn.row_index)
	if danger_level > 0:
		btn.set_tile(danger_level + 1)
		return

	var opened = board.open_adjacent_cells(btn.column_index, btn.row_index)
	for v in opened:
		var cell = buttons[v]
		var c_danger_level = board._get_danger_level(v.x, v.y)
		if c_danger_level == 0:
			cell.set_tile(1)
			continue
		cell.set_tile(c_danger_level + 1)


class CellState:
	var has_mine: bool
	var open: bool
	var has_flag: bool
	var adjacent_mines:int

	func _init(mine: bool) -> void:
		self.has_mine = mine
		self.open = false
		self.has_flag = false


class Board:
	var columns:int = 9
	var rows:int = 9
	var mines_count:int = 10
	var cells_count: int = 0
	var cells:Array[CellState]

	func _init() -> void:
		self.cells_count = self.columns * self.rows
		self.cells = Array([], TYPE_OBJECT, "RefCounted", CellState)
		var mine_positions = self._generate_mine_positions()
		for i in range(self.cells_count):
			var has_mine:bool = mine_positions.has(i)
			var cell_state = CellState.new(has_mine)
			self.cells.insert(i, cell_state)
	
	func _generate_mine_positions() -> Dictionary:
		var items_set :={}
		var rnd = RandomNumberGenerator.new()
		for i in range(mines_count):
			var mine_index = rnd.randi_range(0, self.cells_count)
			while items_set.has(mine_index):
				mine_index = rnd.randi_range(0, self.cells_count)

			items_set[mine_index] = null

		return items_set

	func _get_cell_state(column_index: int, row_index: int) ->CellState:
		if column_index == 0:
			return self.cells[row_index]

		var position = column_index * self.columns + row_index

		return self.cells[position]

	func _get_danger_level(column_index: int, row_index:int)->int:
		var row_has_mines: bool = (
			(_is_inside_board(column_index, row_index-1) and 
			_get_cell_state(column_index, row_index-1).has_mine) or
			(_is_inside_board(column_index, row_index +1) and
			_get_cell_state(column_index, row_index + 1).has_mine)
		)

		var column_has_mines: bool = (
			(_is_inside_board(column_index -1, row_index) and 
			_get_cell_state(max(column_index - 1, 0), row_index).has_mine) or
			(_is_inside_board(column_index +1, row_index) and 
			_get_cell_state(column_index + 1, row_index).has_mine)
		)

		var diag1_has_mines: bool = (
			(_is_inside_board(column_index -1, row_index -1) and 
			_get_cell_state(column_index - 1, row_index - 1).has_mine) or
			(_is_inside_board(column_index +1, row_index +1) and 
			_get_cell_state(column_index + 1, row_index + 1).has_mine)
		)

		var diag2_has_mines: bool = (
			(_is_inside_board(column_index + 1, row_index - 1) and 
			_get_cell_state(column_index + 1, row_index - 1).has_mine) or
			(_is_inside_board(column_index - 1, row_index + 1) and 
			_get_cell_state(column_index - 1, row_index + 1).has_mine)
		)
		return int(row_has_mines) + int(column_has_mines) + int(diag1_has_mines) + int(diag2_has_mines)

	func _is_inside_board(column_index: int, row_index:int) -> bool:
		return !_is_outside_board(column_index, row_index)

	func _is_outside_board(column_index: int, row_index:int) -> bool:
		return (
			column_index < 0 or
			column_index >= self.columns or
			row_index < 0 or row_index >= self.rows)
	
	func _is_visited(column_index:int, row_index:int) -> bool:
		var cell_state = _get_cell_state(column_index, row_index)
		return cell_state.open

	func _is_bobm(column_index:int, row_index:int) -> bool:
		var cell_state = _get_cell_state(column_index, row_index)
		return cell_state.has_mine



	func _visit(column_index:int, row_index:int) -> void:
		var cell_state = _get_cell_state(column_index, row_index)
		cell_state.open = true

	func _set_danger_level(column_index:int, row_index:int, danger_level:int) -> void:
		var cell_state = _get_cell_state(column_index, row_index)
		cell_state.adjacent_mines = danger_level


	func open_adjacent_cells(column_index: int, row_index: int) -> Array[Vector2i]:
		var queue = [Vector2i(column_index, row_index)]
		var result:Array[Vector2i] = []
		var visited_self = false
		_visit(column_index, row_index)
		result.append(Vector2i(column_index, row_index))
		while queue.size() > 0:
			var current_cell = queue.pop_front()
			var c_column_index = current_cell.x
			var c_row_index = current_cell.y
			if _is_outside_board(c_column_index, c_row_index):
				continue
			if _is_visited(c_column_index, c_row_index):
				var is_self = c_column_index == column_index and c_row_index == row_index
				if is_self && visited_self:
					continue
				if is_self:
					visited_self = true
			else:
				_visit(c_column_index, c_row_index)
				result.append(Vector2i(c_column_index, c_row_index))

			var danger_level = _get_danger_level(c_column_index, c_row_index)
			_set_danger_level(c_column_index, c_row_index, danger_level)

			if danger_level == 0:
				for delta_column in [-1, 0, 1]:
					for delta_row in [-1, 0, 1]:
						var n_column_index = c_column_index + delta_column
						var n_row_index = c_row_index + delta_row
						if _is_outside_board(n_column_index, n_row_index):
							continue
						if _is_visited(n_column_index, n_row_index):
							continue
						if _is_bobm(n_column_index, n_row_index):
							continue
						queue.append(Vector2i(n_column_index, n_row_index))
		return result


	func open_cell(column_index:int, row_index:int):
		var cell_state = self._get_cell_state(column_index, row_index)
		cell_state.open = true
