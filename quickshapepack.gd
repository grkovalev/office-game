extends Node2D

const ATLAS_CELL_SIZE := 51
const ATLAS_INDEX_0 := Rect2(0, 0, 51, 51)
const ATLAS_INDEX_1 := Rect2(51, 0, 51, 51)
const ATLAS_INDEX_2 := Rect2(102, 0, 51, 51)

func _set_qshape_atlas(qs: Node2D, index: int) -> void:
	var img: Sprite2D = qs.get_node_or_null("qshape_img")
	if img == null:
		return
	match index:
		0:
			img.region_rect = ATLAS_INDEX_0
		1:
			img.region_rect = ATLAS_INDEX_1
		2:
			img.region_rect = ATLAS_INDEX_2
		_:
			img.region_rect = ATLAS_INDEX_0

@onready var tetromino_lib = $"../tetromino_lib"
@onready var quickshapes: Array[Node2D] = [
	$quickshape, $quickshape2, $quickshape3, $quickshape4,
	$quickshape5, $quickshape6
]

var dragging_quickshape: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO
var quickshape_original_pos: Vector2 = Vector2.ZERO
var _initial_positions: Array[Vector2] = []
var _templates: Array[Node2D] = []

func _ready() -> void:
	_initial_positions.clear()
	_templates.clear()
	for qs in quickshapes:
		_initial_positions.append(qs.position)
		_templates.append(qs.duplicate())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_try_start_quickshape_drag()
		else:
			if dragging_quickshape != null:
				_finish_quickshape_drag()
	elif event is InputEventMouseMotion:
		if dragging_quickshape != null:
			_update_quickshape_drag()

func _try_start_quickshape_drag() -> void:
	if tetromino_lib == null:
		return
	var mouse_pos := get_global_mouse_position()
	for qs in quickshapes:
		if not is_instance_valid(qs):
			continue
		if _is_quickshape_used(qs):
			continue
		var dist := qs.global_position.distance_to(mouse_pos)
		if dist < 40:
			dragging_quickshape = qs
			drag_offset = qs.global_position - mouse_pos
			quickshape_original_pos = qs.global_position
			_set_qshape_atlas(qs, 1)
			get_viewport().set_input_as_handled()
			return

func _update_quickshape_drag() -> void:
	if dragging_quickshape == null:
		return
	dragging_quickshape.global_position = get_global_mouse_position() + drag_offset

func _finish_quickshape_drag() -> void:
	if dragging_quickshape == null:
		return
	if tetromino_lib == null:
		_set_qshape_atlas(dragging_quickshape, 0)
		dragging_quickshape.global_position = quickshape_original_pos
		dragging_quickshape = null
		return
	var mouse_pos := get_global_mouse_position()
	var dropped_on_slot := _is_over_spawn_slot(mouse_pos)
	if dropped_on_slot >= 0:
		# Spawn area is blocked until the current quickshape (1-tile) is placed and a new piece is spawned
		if tetromino_lib.slot_has_quickshape_piece(dropped_on_slot):
			_set_qshape_atlas(dragging_quickshape, 0)
			dragging_quickshape.global_position = quickshape_original_pos
		else:
			_assign_quickshape_to_slot(dropped_on_slot, dragging_quickshape)
	else:
		_set_qshape_atlas(dragging_quickshape, 0)
		dragging_quickshape.global_position = quickshape_original_pos
	dragging_quickshape = null

func _is_quickshape_used(qs: Node2D) -> bool:
	if not is_instance_valid(qs):
		return true
	return tetromino_lib.is_quickshape_assigned(qs)

func _is_over_spawn_slot(global_pos: Vector2) -> int:
	for i in range(tetromino_lib.slots.size()):
		var slot: Node2D = tetromino_lib.slots[i]
		var dist := slot.global_position.distance_to(global_pos)
		if dist < 60:
			return i
	return -1

func _assign_quickshape_to_slot(slot_index: int, qs: Node2D) -> void:
	tetromino_lib.assign_quickshape_to_slot(slot_index, qs)
	
func reset_quickshapes() -> void:
	if tetromino_lib != null:
		tetromino_lib.reset_quickshape_assignments()

	for i in range(quickshapes.size()):
		var qs: Node2D = quickshapes[i]
		if not is_instance_valid(qs):
			var template: Node2D = _templates[i]
			if template != null:
				qs = template.duplicate()
				add_child(qs)
				quickshapes[i] = qs

		if is_instance_valid(qs):
			qs.position = _initial_positions[i]
			_set_qshape_atlas(qs, 0)
			
func get_available_quickshape_count() -> int:
	var count := 0
	for qs in quickshapes:
		if is_instance_valid(qs) and not _is_quickshape_used(qs):
			count += 1
	return count
