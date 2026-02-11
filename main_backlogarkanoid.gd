extends Node2D

const PADDLE_SPEED := 900.0
const BALL_SPEED := 900.0
const MAX_PADDLE_BOUNCE_ANGLE := deg_to_rad(60.0) # from straight up

@onready var paddle: CharacterBody2D = $player/playctrl/play_char
@onready var paddle_coll: CollisionShape2D = $player/playctrl/play_char/play_coll

@onready var ball: CharacterBody2D = $ball/ballctrl/ball_char
@onready var ball_coll: CollisionShape2D = $ball/ballctrl/ball_char/ball_coll

@onready var tiles: TextureRect = $bg/bg_tiles

var paddle_half_width: float
var paddle_half_height: float
var ball_radius: float
var bounds_rect: Rect2

var ball_attached := true
var ball_dir := Vector2.UP

func _ready() -> void:
	# Sizes based on collision shapes & world scale
	var paddle_shape := paddle_coll.shape as RectangleShape2D
	paddle_half_width = 0.5 * paddle_shape.size.x * paddle_coll.global_scale.x
	paddle_half_height = 0.5 * paddle_shape.size.y * paddle_coll.global_scale.y

	var ball_shape := ball_coll.shape as CircleShape2D
	ball_radius = ball_shape.radius * ball_coll.global_scale.x

	# Rectangle the ball must stay inside, in global coordinates
	var r := tiles.get_global_rect()
	bounds_rect = Rect2(r.position, r.size)

	# Put ball on top of paddle initially
	_stick_ball_to_paddle()

func _physics_process(delta: float) -> void:
	_update_paddle(delta)
	_update_ball(delta)

func _update_paddle(delta: float) -> void:
	var move_dir := 0.0

	# Arrows
	if Input.is_action_pressed("ui_left"):
		move_dir -= 1.0
	if Input.is_action_pressed("ui_right"):
		move_dir += 1.0

	# WASD
	if Input.is_action_pressed("move_left"):
		move_dir -= 1.0
	if Input.is_action_pressed("move_right"):
		move_dir += 1.0

	paddle.velocity.x = move_dir * PADDLE_SPEED
	paddle.velocity.y = 0.0
	paddle.move_and_slide()

	# Clamp paddle inside bg_tiles horizontally
	var p := paddle.global_position
	var left_limit := bounds_rect.position.x + paddle_half_width
	var right_limit := bounds_rect.position.x + bounds_rect.size.x - paddle_half_width
	p.x = clamp(p.x, left_limit, right_limit)
	paddle.global_position = p

	# While attached, keep the ball riding on the paddle
	if ball_attached:
		_stick_ball_to_paddle()

		# Launch with Up or W
		if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up"):
			ball_attached = false
			ball_dir = Vector2.UP
			ball.velocity = ball_dir * BALL_SPEED

func _update_ball(delta: float) -> void:
	if ball_attached:
		return

	# Move the ball and process collisions from physics
	ball.velocity = ball_dir * BALL_SPEED
	ball.move_and_slide()

	# Reflect on physics bodies (e.g. paddle, bricks if you add them)
	var slide_count := ball.get_slide_collision_count()
	for i in range(slide_count):
		var col := ball.get_slide_collision(i)
		var normal := col.get_normal()

		# Default: simple reflection
		ball_dir = ball_dir.bounce(normal).normalized()

		# If we hit the paddle, adjust angle depending on where we hit
		if col.get_collider() == paddle:
			_handle_paddle_bounce()

	# Manual walls using bg_tiles rectangle
	_handle_bounds_bounce()

	# Keep velocity updated from direction
	ball.velocity = ball_dir * BALL_SPEED

func _stick_ball_to_paddle() -> void:
	var p := paddle.global_position
	var b := ball.global_position
	b.x = p.x
	b.y = p.y - paddle_half_height - ball_radius - 2.0
	ball.global_position = b
	ball.velocity = Vector2.ZERO
	ball_dir = Vector2.UP

func _handle_paddle_bounce() -> void:
	# Where on the paddle did we hit? -1 = far left, 0 = center, +1 = far right
	var diff_x := (ball.global_position.x - paddle.global_position.x) / paddle_half_width
	diff_x = clamp(diff_x, -1.0, 1.0)

	# Convert to an angle from straight up
	var angle_from_up := diff_x * MAX_PADDLE_BOUNCE_ANGLE
	# Straight up is (0, -1). Rotate left/right around that.
	var dir := Vector2(sin(angle_from_up), -cos(angle_from_up))

	ball_dir = dir.normalized()

func _handle_bounds_bounce() -> void:
	var pos := ball.global_position

	# Left / right walls
	if pos.x - ball_radius < bounds_rect.position.x:
		pos.x = bounds_rect.position.x + ball_radius
		ball_dir.x = abs(ball_dir.x)
	elif pos.x + ball_radius > bounds_rect.position.x + bounds_rect.size.x:
		pos.x = bounds_rect.position.x + bounds_rect.size.x - ball_radius
		ball_dir.x = -abs(ball_dir.x)

	# Top / bottom walls
	if pos.y - ball_radius < bounds_rect.position.y:
		pos.y = bounds_rect.position.y + ball_radius
		ball_dir.y = abs(ball_dir.y)
	elif pos.y + ball_radius > bounds_rect.position.y + bounds_rect.size.y:
		# Arkanoid usually lets you lose the ball here; for now we bounce.
		pos.y = bounds_rect.position.y + bounds_rect.size.y - ball_radius
		ball_dir.y = -abs(ball_dir.y)

	ball.global_position = pos
	ball_dir = ball_dir.normalized()
