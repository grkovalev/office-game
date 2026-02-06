extends Label

@export var calendar_tetris_path: NodePath
@export var restart_button_path: NodePath

var calendar_tetris: Node = null
var restart_button: Button = null


func _ready() -> void:
	if calendar_tetris_path != NodePath(""):
		calendar_tetris = get_node(calendar_tetris_path)

	if restart_button_path != NodePath(""):
		restart_button = get_node(restart_button_path) as Button

	# Update once when the scene is ready
	_update_text_deferred()

	# Update again when the restart button is pressed
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)


func _on_restart_pressed() -> void:
	_update_text_deferred()


func _update_text_deferred() -> void:
	# Defer so that prefill (which is also deferred) has time to run
	call_deferred("_update_text_after_prefill")


func _update_text_after_prefill() -> void:
	# Wait at least one frame so the deferred prefill has run
	await get_tree().process_frame

	if calendar_tetris == null:
		return

	var free_rows: int = _compute_free_region_rows()
	text = "%d left" % free_rows


func _compute_free_region_rows() -> int:
	if calendar_tetris == null:
		return 0

	var grid_width: int = calendar_tetris.GRID_WIDTH
	var grid_height: int = calendar_tetris.GRID_HEIGHT
	var columns_per_region: int = calendar_tetris.COLUMNS_PER_REGION
	var cells: Array = calendar_tetris.cells

	var total_free_rows: int = 0
	var num_regions: int = grid_width / columns_per_region

	for region_index in range(num_regions):
		var col_start := region_index * columns_per_region
		var col_end := col_start + columns_per_region - 1

		for row in range(grid_height):
			var has_occupied := false
			for col in range(col_start, col_end + 1):
				if cells[row][col]:
					has_occupied = true
					break
			if not has_occupied:
				total_free_rows += 1

	return total_free_rows
