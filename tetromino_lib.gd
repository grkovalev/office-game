extends Node2D

@onready var board = $"../grid_container"
@onready var slots = [ $spawn_slot_0]
@onready var quickshapepack = $"../quickshapepack"
var quickshape_slots: Dictionary = {}

@onready var TEMPLATE_SHAPES := {
	"O": $shape_o_area,
	"I": $shape_i_area,
	"S": $shape_s_area,
	"Z": $shape_z_area,
	"L": $shape_l_area,
	"J": $shape_j_area,
	"T": $shape_t_area,
}


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

const PIVOT_OFFSETS := {
	"O": Vector2(0.5, 0.5),
	"I": Vector2(0.5, 0.0),
	"S": Vector2(0.0, 0.5),
	"Z": Vector2(0.0, 0.5),
	"L": Vector2(0.0, 0.0),
	"J": Vector2(0.0, 0.0),
	"T": Vector2(0.0, 0.5),
}

var pieces: Array = []
var dragging: bool = false
var selected_slot: int = -1
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	randomize()
	pieces.resize(slots.size())
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

		if _is_quickshape_piece(piece):
			var qs: Node2D = piece["quickshape"]
			if not is_instance_valid(qs):
				pieces[i] = null
				quickshape_slots.erase(i)
				continue
			var dist := qs.global_position.distance_to(mouse_pos)
			if dist < 40:
				selected_slot = i
				dragging = true
				drag_offset = qs.global_position - mouse_pos
				break
		else:
			var area: Area2D = piece["area"]
			if not is_instance_valid(area):
				continue
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

	var mouse_pos := get_global_mouse_position()
	if _is_quickshape_piece(piece):
		var qs: Node2D = piece["quickshape"]
		if is_instance_valid(qs):
			qs.global_position = mouse_pos + drag_offset
	else:
		var area: Area2D = piece["area"]
		if is_instance_valid(area):
			area.global_position = mouse_pos + drag_offset


func _finish_drag() -> void:
	if selected_slot < 0:
		dragging = false
		return

	var piece = pieces[selected_slot]
	if _is_quickshape_piece(piece):
		_try_place_quickshape_on_board(selected_slot)
	else:
		_try_place_piece_on_board(selected_slot)

	selected_slot = -1
	dragging = false


func _rotate_selected_piece() -> void:
	if selected_slot < 0:
		return
	var piece = pieces[selected_slot]
	if piece == null:
		return
	if _is_quickshape_piece(piece):
		return

	var shape_id: String = piece["shape_id"]
	var rotation: int = piece["rotation"]
	var rotations_count: int = SHAPES[shape_id].size()

	rotation = (rotation + 1) % rotations_count
	piece["rotation"] = rotation
	pieces[selected_slot] = piece

	var area: Area2D = piece["area"]
	area.rotation = float(rotation) * PI / 2.0

func get_rotated_pivot_offset(shape_id: String, rotation: int) -> Vector2:
	var base_offset: Vector2 = PIVOT_OFFSETS.get(shape_id, Vector2.ZERO)
	match rotation:
		0:
			return base_offset
		1:
			return Vector2(-base_offset.y, base_offset.x)
		2:
			return Vector2(-base_offset.x, -base_offset.y)
		3:
			return Vector2(base_offset.y, -base_offset.x)
	return base_offset

func _try_place_quickshape_on_board(slot_index: int) -> void:
	var piece = pieces[slot_index]
	if piece == null or not _is_quickshape_piece(piece):
		return

	var qs: Node2D = piece["quickshape"]
	if not is_instance_valid(qs):
		pieces[slot_index] = null
		quickshape_slots.erase(slot_index)
		return

	var cell: Vector2i = board.world_to_cell(qs.global_position)
	if not board.cell_in_bounds(cell):
		qs.global_position = piece["original_pos"]
		return
	if board.is_cell_occupied(cell):
		qs.global_position = piece["original_pos"]
		return

	board.place_quick_shape(cell)
	qs.queue_free()
	quickshape_slots.erase(slot_index)
	pieces[slot_index] = null
	spawn_piece(slot_index)

func _try_place_piece_on_board(slot_index: int) -> void:
	var piece = pieces[slot_index]
	if piece == null:
		return
	if piece.get("placed", false):
		return

	var area: Area2D = piece["area"]
	var threshold: float = board.PLACEMENT_COVERAGE_THRESHOLD

	if board.can_place_piece_by_collision(area, threshold):
		board.place_piece_by_collision(area, threshold)
		area.queue_free()
		pieces[slot_index] = null
		spawn_piece(slot_index)
	else:
		area.global_position = piece["original_pos"]

func is_quickshape_assigned(qs: Node2D) -> bool:
	for slot_i in quickshape_slots:
		if quickshape_slots[slot_i] == qs:
			return true
	return false

func assign_quickshape_to_slot(slot_index: int, qs: Node2D) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	# Remove existing tetromino piece from slot
	var old_piece = pieces[slot_index]
	if old_piece != null:
		var area: Area2D = old_piece["area"]
		if is_instance_valid(area):
			area.queue_free()
		pieces[slot_index] = null
	quickshape_slots[slot_index] = qs
	_set_qshape_atlas(qs, 2)
	qs.global_position = slots[slot_index].global_position
	pieces[slot_index] = {
		"shape_id": "Q",
		"rotation": 0,
		"area": null,
		"quickshape": qs,
		"slot": slot_index,
		"placed": false,
		"original_pos": qs.global_position,
	}

func _set_qshape_atlas(qs: Node2D, index: int) -> void:
	var img: Sprite2D = qs.get_node_or_null("qshape_img")
	if img == null:
		return
	match index:
		0:
			img.region_rect = Rect2(0, 0, 51, 51)
		1:
			img.region_rect = Rect2(51, 0, 51, 51)
		2:
			img.region_rect = Rect2(102, 0, 51, 51)
		_:
			img.region_rect = Rect2(0, 0, 51, 51)

func _is_quickshape_piece(piece: Variant) -> bool:
	if piece == null:
		return false
	return piece.get("quickshape", null) != null
	
func reset_quickshape_assignments() -> void:
	quickshape_slots.clear()

	for i in range(pieces.size()):
		var piece = pieces[i]
		if piece == null:
			continue
		if _is_quickshape_piece(piece):
			pieces[i] = null

	for i in range(slots.size()):
		if pieces[i] == null:
			spawn_piece(i)
