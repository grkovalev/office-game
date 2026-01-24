extends Node2D

@onready var winlostimg: Sprite2D = $winlostimg
@onready var wintext: Label = $wintext
@onready var losttext: Label = $losttext
@export var win_atlas: Texture2D
@export var win_atlas_columns: int = 4
@export var win_cell_size: Vector2i = Vector2i(256, 512)
@export var win_animation_speed: float = 0.3

var _win_atlas_tex: AtlasTexture
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
	return Rect2(
		Vector2(col * win_cell_size.x, row * win_cell_size.y),
		Vector2(win_cell_size.x, win_cell_size.y)
	)

func _on_win_anim_tick() -> void:
	_win_frame = 1 - _win_frame
	if _win_atlas_tex:
		_win_atlas_tex.region = _get_atlas_region(_win_frame)

func show_win() -> void:
	_win_anim_timer.stop()
	if win_atlas:
		if _win_atlas_tex == null:
			_win_atlas_tex = AtlasTexture.new()
			_win_atlas_tex.atlas = win_atlas
		_win_frame = 0
		_win_atlas_tex.region = _get_atlas_region(0)
		winlostimg.texture = _win_atlas_tex
		_win_anim_timer.wait_time = win_animation_speed
		_win_anim_timer.start()
	wintext.visible = true
	losttext.visible = false
	show()

func show_lose(flagged_bomb_count: int = 0) -> void:
	_win_anim_timer.stop()
	if win_atlas:
		var idx: int = clampi(11 - flagged_bomb_count, 0, 11)
		var tex := AtlasTexture.new()
		tex.atlas = win_atlas
		tex.region = _get_atlas_region(idx)
		winlostimg.texture = tex
	wintext.visible = false
	losttext.visible = true
	show()

func hide_msg() -> void:
	_win_anim_timer.stop()
	hide()
