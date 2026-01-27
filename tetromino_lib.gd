extends Node2D

@onready var board = $"../grid_container"
@onready var slots = [ $spawn_slot_0, $spawn_slot_1, $spawn_slot_2 ]

const TILE_SIZE := 50
const SHAPES := {
	"O": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	],
	"I": [
		[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		[Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
		[Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
	],
	"S": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1)],
		[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1)],
		[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
	],
	"Z": [
		[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(1, -1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(1, -1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	],
	"L": [
		[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1)],
		[Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, -1)],
		[Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
		[Vector2i(-1, 1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)],
	],
	"J": [
		[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		[Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
		[Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)],
	],
	"T": [
		[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		[Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
		[Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1)],
	],
}
@onready var TEMPLATE_SHAPES := {
	"O": $shape_o_area,
	"I": $shape_i_area,
	"S": $shape_s_area,
	"Z": $shape_z_area,
	"L": $shape_l_area,
	"J": $shape_j_area,
	"T": $shape_t_area,
}

var pieces: Array = [null, null, null]
var dragging: bool = false
var selected_slot: int = -1
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	randomize()
	for i in range(slots.size()):
		spawn_piece(i)


func spawn_piece(slot_index: int) -> void:
	var shape_ids := TEMPLATE_SHAPES.keys()
	if shape_ids.is_empty():
		return

	var shape_id: String = shape_ids[randi() % shape_ids.size()]
	var template: Area2D = TEMPLATE_SHAPES[shape_id]

	var piece_area: Area2D = template.duplicate() as Area2D
	add_child(piece_area)
	piece_area.global_position = slots[slot_index].global_position
	piece_area.visible = true

	var piece := {
		"shape_id": shape_id,
		"rotation": 0,
		"area": piece_area,
		"slot": slot_index,
		"placed": false,
		"original_pos": piece_area.global_position,
	}
	pieces[slot_index] = piece


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_start_drag()
			else:
				if dragging and selected_slot != -1:
					_finish_drag()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if dragging and selected_slot != -1:
				_rotate_selected_piece()

	elif event is InputEventMouseMotion:
		if dragging and selected_slot != -1:
			_update_drag()


func _start_drag() -> void:
	var mouse_pos := get_global_mouse_position()
	selected_slot = -1

	for i in range(pieces.size()):
		var piece = pieces[i]
		if piece == null:
			continue
		if piece["placed"]:
			continue

		var area: Area2D = piece["area"]
		var local_pos := area.to_local(mouse_pos)
		var rect := Rect2(Vector2(-2 * TILE_SIZE, -2 * TILE_SIZE), Vector2(4 * TILE_SIZE, 4 * TILE_SIZE))
		if rect.has_point(local_pos):
			selected_slot = i
			dragging = true
			drag_offset = area.global_position - mouse_pos
			break


func _update_drag() -> void:
	if selected_slot < 0:
		return
	var piece = pieces[selected_slot]
	if piece == null:
		return

	var area: Area2D = piece["area"]
	var mouse_pos := get_global_mouse_position()
	area.global_position = mouse_pos + drag_offset


func _finish_drag() -> void:
	dragging = false
	if selected_slot < 0:
		return

	_try_place_piece_on_board(selected_slot)
	selected_slot = -1


func _rotate_selected_piece() -> void:
	if selected_slot < 0:
		return
	var piece = pieces[selected_slot]
	if piece == null:
		return

	var shape_id: String = piece["shape_id"]
	var rotation: int = piece["rotation"]
	var rotations_count: int = SHAPES[shape_id].size()

	rotation = (rotation + 1) % rotations_count
	piece["rotation"] = rotation
	pieces[selected_slot] = piece

	# Simple visual rotation (90 degrees per step).
	var area: Area2D = piece["area"]
	area.rotation = float(rotation) * PI / 2.0


func _try_place_piece_on_board(slot_index: int) -> void:
	var piece = pieces[slot_index]
	if piece == null:
		return
	if piece["placed"]:
		return

	var area: Area2D = piece["area"]
	var shape_id: String = piece["shape_id"]
	var rotation: int = piece["rotation"]
	var base_cell: Vector2i = board.world_to_cell(area.global_position)
	var local_cells: Array = SHAPES[shape_id][rotation]  # Array of Vector2i
	if board.can_place_piece(local_cells, base_cell):
		board.place_piece(local_cells, base_cell, shape_id)

		piece["placed"] = true
		pieces[slot_index] = piece
		pieces[slot_index] = null
		spawn_piece(slot_index)
	else:
		area.global_position = piece["original_pos"]
