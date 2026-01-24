extends Node2D

@onready var winlostimg: Sprite2D = $winlostimg
@onready var wintext: Label = $wintext
@onready var losttext: Label = $losttext
## Must be the full atlas image (e.g. winlostatlas.png), not an AtlasTexture.
@export var win_atlas: Texture2D
@export var win_atlas_columns: int = 4
@export var win_cell_size: Vector2i = Vector2i(256, 512)
@export var win_animation_speed: float = 0.3
## Format for losttext; %s is replaced by the number of unflagged bombs. E.g. "%s" or "These new %s burning tasks are all yours!"
@export var losttext_format: String = "%s"

var _win_anim_timer: Timer
var _win_frame: int = 0

func _ready() -> void:
	_win_anim_timer = Timer.new()
	_win_anim_timer.one_shot = false
	_win_anim_timer.timeout.connect(_on_win_anim_tick)
	add_child(_win_anim_timer)
	hide_msg()

func _get_atlas_region(index: int) -> Rect2:
	var col: int = index % win_atlas_columns
	var row: int = index / win_atlas_columns
	return Rect2(col * win_cell_size.x, row * win_cell_size.y, win_cell_size.x, win_cell_size.y)

func _get_atlas() -> Texture2D:
	if win_atlas != null:
		return win_atlas
	return winlostimg.texture

func _apply_region(index: int) -> void:
	winlostimg.region_rect = _get_atlas_region(index)
	winlostimg.queue_redraw()

func _on_win_anim_tick() -> void:
	_win_frame = 1 - _win_frame
	_apply_region(_win_frame)

func show_win() -> void:
	_win_anim_timer.stop()
	var atlas := _get_atlas()
	if atlas != null:
		winlostimg.texture = atlas
		winlostimg.region_enabled = true
		_win_frame = 0
		_apply_region(0)
		_win_anim_timer.wait_time = win_animation_speed
		_win_anim_timer.start()
	wintext.visible = true
	losttext.visible = false
	show()

func show_lose(flagged_bomb_count: int = 0, unflagged_bomb_count: int = 0) -> void:
	_win_anim_timer.stop()
	var atlas := _get_atlas()
	if atlas != null:
		var idx: int = clampi(11 - flagged_bomb_count, 0, 11)
		winlostimg.texture = atlas
		winlostimg.region_enabled = true
		_apply_region(idx)
	losttext.text = losttext_format % unflagged_bomb_count
	wintext.visible = false
	losttext.visible = true
	show()

func hide_msg() -> void:
	_win_anim_timer.stop()
	hide()
