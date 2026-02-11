extends CharacterBody2D

const BALL_SPEED := 900.0
const MAX_PADDLE_BOUNCE_ANGLE := deg_to_rad(60.0)

@export var paddle_path: NodePath
@export var paddle_collision_path: NodePath
@export var bounds_path: NodePath

@onready var paddle: CharacterBody2D = get_node(paddle_path)
@onready var paddle_coll: CollisionShape2D = get_node(paddle_collision_path)
@onready var bounds_rect_node: TextureRect = get_node(bounds_path)
@onready var ball_coll: CollisionShape2D = $ball_coll

var paddle_half_width: float
var paddle_half_height: float
var ball_radius: float
var bounds_rect: Rect2

var attached := true
var dir := Vector2.UP

func _ready() -> void:
	var p_shape := paddle_coll.shape as RectangleShape2D
	paddle_half_width = 0.5 * p_shape.size.x * paddle_coll.global_scale.x
	paddle_half_height = 0.5 * p_shape.size.y * paddle_coll.global_scale.y

	var b_shape := ball_coll.shape as CircleShape2D
	ball_radius = b_shape.radius * ball_coll.global_scale.x

	var r := bounds_rect_node.get_global_rect()
	bounds_rect = Rect2(r.position, r.size)

	_stick_to_paddle()

func _physics_process(delta: float) -> void:
	if attached:
		_stick_to_paddle()
		if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up"):
			attached = false
			dir = Vector2.UP
			velocity = dir * BALL_SPEED
		return

	velocity = dir * BALL_SPEED
	move_and_slide()

	# Handle physics collisions (paddle + bricks)
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		var normal := col.get_normal()

		if collider == paddle:
			_bounce_on_paddle()
		else:
			dir = dir.bounce(normal).normalized()

		if collider != null and collider.is_in_group("brick"):
			collider.queue_free()

	# Manual walls using bg_tiles rectangle
	_handle_bounds()

	velocity = dir * BALL_SPEED

func _stick_to_paddle() -> void:
	var p := paddle.global_position
	global_position = Vector2(
		p.x,
		p.y - paddle_half_height - ball_radius - 2.0
	)
	velocity = Vector2.ZERO
	dir = Vector2.UP

func _bounce_on_paddle() -> void:
	# -1 = far left, 0 = center, +1 = far right
	var offset := (global_position.x - paddle.global_position.x) / paddle_half_width
	offset = clamp(offset, -1.0, 1.0)

	var angle := offset * MAX_PADDLE_BOUNCE_ANGLE
	var new_dir := Vector2(sin(angle), -cos(angle))
	dir = new_dir.normalized()

func _handle_bounds() -> void:
	var pos := global_position

	# Left / right
	if pos.x - ball_radius < bounds_rect.position.x:
		pos.x = bounds_rect.position.x + ball_radius
		dir.x = abs(dir.x)
	elif pos.x + ball_radius > bounds_rect.position.x + bounds_rect.size.x:
		pos.x = bounds_rect.position.x + bounds_rect.size.x - ball_radius
		dir.x = -abs(dir.x)

	# Top / bottom (bottom currently bounces; you can change this to "lose ball")
	if pos.y - ball_radius < bounds_rect.position.y:
		pos.y = bounds_rect.position.y + ball_radius
		dir.y = abs(dir.y)
	elif pos.y + ball_radius > bounds_rect.position.y + bounds_rect.size.y:
		pos.y = bounds_rect.position.y + bounds_rect.size.y - ball_radius
		dir.y = -abs(dir.y)

	global_position = pos
	dir = dir.normalized()
