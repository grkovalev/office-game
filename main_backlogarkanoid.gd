extends Node2D

const PADDLE_SPEED := 900.0

@onready var paddle: CharacterBody2D = $player/playctrl/play_char
@onready var paddle_coll: CollisionShape2D = $player/playctrl/play_char/play_coll
@onready var tiles: TextureRect = $bg/bg_tiles
@onready var exitbtn: TextureButton = $exitbtn
@onready var restartbtn: TextureButton = $restartbtn
@onready var grid: Node2D = $env/grid
@onready var ball_char: CharacterBody2D = $ball/ballctrl/ball_char
@onready var player_ctrl: Node2D = $player/playctrl

var paddle_half_width: float
var paddle_half_height: float
var bounds_rect: Rect2
var _initial_player_position: Vector2

func _ready() -> void:
	_initial_player_position = player_ctrl.position
	exitbtn.pressed.connect(_on_exitbtn_pressed)
	restartbtn.pressed.connect(_on_restartbtn_pressed)
	var paddle_shape := paddle_coll.shape as RectangleShape2D
	paddle_half_width = 0.5 * paddle_shape.size.x * paddle_coll.global_scale.x
	paddle_half_height = 0.5 * paddle_shape.size.y * paddle_coll.global_scale.y

	var r := tiles.get_global_rect()
	bounds_rect = Rect2(r.position, r.size)

func _physics_process(delta: float) -> void:
	_update_paddle(delta)

func _update_paddle(_delta: float) -> void:
	var move_dir := 0.0

	if Input.is_action_pressed("ui_left"):
		move_dir -= 1.0
	if Input.is_action_pressed("ui_right"):
		move_dir += 1.0

	paddle.velocity.x = move_dir * PADDLE_SPEED
	paddle.velocity.y = 0.0
	paddle.move_and_slide()

	var p := paddle.global_position
	var left_limit := bounds_rect.position.x + paddle_half_width
	var right_limit := bounds_rect.position.x + bounds_rect.size.x - paddle_half_width
	p.x = clamp(p.x, left_limit, right_limit)
	paddle.global_position = p

func _on_exitbtn_pressed() -> void:
	queue_free()

func _on_restartbtn_pressed() -> void:
	_restart_game()

func _restart_game() -> void:
	if grid != null and grid.has_method("generate_grid"):
		grid.generate_grid()
	if ball_char != null and ball_char.has_method("reset_ball"):
		ball_char.reset_ball()
	if player_ctrl != null:
		player_ctrl.position = _initial_player_position
