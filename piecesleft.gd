extends Label

@export var calendar_tetris_path: NodePath
@export var restart_button_path: NodePath

var calendar_tetris: Node = null
var restart_button: Button = null
var current_free_rows: int = 0


func _ready() -> void:
	if calendar_tetris_path != NodePath(""):
		calendar_tetris = get_node(calendar_tetris_path)

	if restart_button_path != NodePath(""):
		restart_button = get_node(restart_button_path) as Button

	# Update when the restart button is pressed (grid will emit when ready)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

	# Listen for updates from calendartetris: initial, restart, and after clears
	if calendar_tetris:
		calendar_tetris.free_rows_updated.connect(_on_free_rows_updated)
		calendar_tetris.rows_cleared.connect(_on_rows_cleared)


func _on_restart_pressed() -> void:
	# No direct action; after restart and prefill, calendartetris will
	# recompute and emit free_rows_updated, which we listen to.
	pass


func _on_free_rows_updated(total: int) -> void:
	current_free_rows = total
	text = "%d left" % current_free_rows


func _on_rows_cleared(num_rows: int) -> void:
	# calendartetris already maintains and emits the updated total,
	# so this can stay empty or be used for animations / effects.
	pass
