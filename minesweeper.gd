extends Node2D

@onready var tiles = $Window/tiles_minesweeper/grid9x9
@onready var tile: TileTemplateButton = $Window/tiles_minesweeper/grid9x9/tile

var board:Board

func _ready() -> void:
	if tiles == null:
		push_error("Tiles are not defined")
	
	if tile == null:
		push_error("Tile is not defined")
	

	board = Board.new()
	for i in range(board.cells_count):
		var row := i / board.columns
		var column := i % board.columns
		var tile_copy = tile.duplicate()
		tile_copy.row_index = row
		tile_copy.column_index = column
		tile_copy.gui_input.connect(
			func(event):
				_on_button_gui_input(event, tile_copy)
				)
		tiles.add_child(tile_copy)
	tiles.remove_child(tile)

		
func _on_button_gui_input(event: InputEvent, btn: TileTemplateButton) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				print("Left click:", btn.row_index, btn.column_index)
				_on_left_click(btn)
			MOUSE_BUTTON_RIGHT:
				print("Right click:", btn.row_index, btn.column_index)
				_on_right_click(btn)
func _on_right_click(btn: TileTemplateButton) -> void:
	var state = board._get_cell_state(btn.column_index, btn.row_index)
	if state.open:
		return
	if state.has_flag:
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
	print("Danger level:", danger_level)
	if danger_level == 0:
		btn.set_tile(1)
		return
	btn.set_tile(danger_level + 1)


class CellState:
	var has_mine: bool
	var open: bool
	var has_flag: bool

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
			if has_mine:
				print("Has mine at", i)
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
			print("Added mine at position: ", mine_index)

		return items_set

	func _get_cell_state(column_index: int, row_index: int) ->CellState:
		if column_index == 0:
			return self.cells[row_index]

		var position = column_index * self.columns + row_index

		return self.cells[position]

	func _get_danger_level(column_index: int, row_index:int)->int:
		var cell_state: CellState
		var row_has_mines:bool = false
		for i in range(self.rows):
			cell_state = _get_cell_state(column_index, i)
			row_has_mines = true
			if row_has_mines:
				break
		var column_has_mines:bool
		for i in range(self.columns):
			cell_state = _get_cell_state(i, row_index)
			column_has_mines = cell_state.has_mine
			if column_has_mines:
				break
		var diff = row_index - column_index
		var diag1_has_mines: bool = false
		for r in range(rows):
			var c = r - diff
			if c >= 0 and c < columns:
				cell_state = _get_cell_state(c, r)
				diag1_has_mines = cell_state.has_mine
				if diag1_has_mines:
					break
		
		# Check / diagonal (top-right to bottom-left)
		var sum_rc = row_index + column_index
		var diag2_has_mines: bool = false
		for r in range(rows):
			var c = sum_rc - r
			if c >= 0 and c < columns:
				cell_state = _get_cell_state(c, r)
				diag2_has_mines = cell_state.has_mine
				if diag2_has_mines:
					break
		return int(row_has_mines) + int(column_has_mines) + int(diag1_has_mines) + int(diag2_has_mines)

	func open_cell(column_index:int, row_index:int):
		var cell_state = self._get_cell_state(column_index, row_index)
		cell_state.open = true
