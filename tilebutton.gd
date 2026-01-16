extends TextureButton

@export var tile_size := Vector2i(50, 50)
@export var atlas_columns := 3
@export var max_tiles := 9

@export var hidden_index := 0
@export var flag_index := 6

var current_index := hidden_index
var is_flagged := false

@onready var atlas_texture: AtlasTexture = texture_normal.duplicate()

func _ready():
	texture_normal = atlas_texture
	texture_pressed = atlas_texture
	_set_tile(hidden_index)
	toggled.connect(_on_toggled)

# LEFT CLICK (toggle)
func _on_toggled(button_pressed: bool) -> void:
	if is_flagged:
		button_pressed = false
		button_pressed = false
		set_pressed_no_signal(false)
		return

	if button_pressed:
		current_index = (current_index + 1) % max_tiles
		_set_tile(current_index)
	else:
		_set_tile(hidden_index)

# RIGHT CLICK (flag)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_flag()
			accept_event()
			
func _set_tile(index: int) -> void:
	var col := index % atlas_columns
	var row := index / atlas_columns
	atlas_texture.region = Rect2(
		Vector2(col * tile_size.x, row * tile_size.y),
		tile_size
	)
signal flag_changed(_delta: int)
func _toggle_flag() -> void:
	is_flagged = !is_flagged

	if is_flagged:
		_set_tile(flag_index)
		flag_changed.emit(-1)
	else:
		_set_tile(hidden_index)
		flag_changed.emit(1)
