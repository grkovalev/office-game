extends Node2D

const PADDLE_SPEED := 900.0

@onready var paddle: CharacterBody2D = $player/playctrl/play_char
@onready var paddle_coll: CollisionShape2D = $player/playctrl/play_char/play_coll

@onready var tiles: TextureRect = $bg/bg_tiles

var paddle_half_width: float
var paddle_half_height: float
var bounds_rect: Rect2

func _ready() -> void:
	var paddle_shape := paddle_coll.shape as RectangleShape2D
	paddle_half_width = 0.5 * paddle_shape.size.x * paddle_coll.global_scale.x
	paddle_half_height = 0.5 * paddle_shape.size.y * paddle_coll.global_scale.y

	var r := tiles.get_global_rect()
	bounds_rect = Rect2(r.position, r.size)

func _physics_process(delta: float) -> void:
	_update_paddle(delta)

func _update_paddle(delta: float) -> void:
	var move_dir := 0.0

	if Input.is_action_pressed("ui_left"):
		move_dir -= 1.0
	if Input.is_action_pressed("ui_right"):
		move_dir += 1.0
	if Input.is_action_pressed("move_left"):
		move_dir -= 1.0
	if Input.is_action_pressed("move_right"):
		move_dir += 1.0

	paddle.velocity.x = move_dir * PADDLE_SPEED
	paddle.velocity.y = 0.0
	paddle.move_and_slide()

	var p := paddle.global_position
	var left_limit := bounds_rect.position.x + paddle_half_width
	var right_limit := bounds_rect.position.x + bounds_rect.size.x - paddle_half_width
	p.x = clamp(p.x, left_limit, right_limit)
	paddle.global_position = p
