extends CharacterBody2D

const BALL_SPEED := 900.0
const MAX_PADDLE_BOUNCE_ANGLE := deg_to_rad(60.0)
const MIN_VERTICAL_ANGLE := deg_to_rad(10.0) # minimum angle away from horizontal

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
			velocity = Vector2.UP * BALL_SPEED
		return

	velocity = _ensure_not_too_flat(velocity)
	move_and_slide()

	var bounced := false

	# Handle physics collisions (paddle + bricks), but only ONE meaningful bounce per frame
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		var normal := col.get_normal()

		if normal == Vector2.ZERO:
			continue

		if collider == paddle:
			_bounce_on_paddle()
			bounced = true
			break
		else:
			velocity = velocity.bounce(normal)
			bounced = true

			if collider != null and collider.is_in_group("brick"):
				collider.queue_free()
				# After hitting a brick, don't process more collisions this frame
				break

	if bounced:
		velocity = _ensure_not_too_flat(velocity)

	# Manual walls using bg_tiles rectangle
	_handle_bounds()

	velocity = _ensure_not_too_flat(velocity)

func _stick_to_paddle() -> void:
	var p := paddle.global_position
	global_position = Vector2(
		p.x,
		p.y - paddle_half_height - ball_radius - 2.0
	)
	velocity = Vector2.ZERO

func _bounce_on_paddle() -> void:
	# -1 = far left, 0 = center, +1 = far right
	var offset := (global_position.x - paddle.global_position.x) / paddle_half_width
	offset = clamp(offset, -1.0, 1.0)

	var angle := offset * MAX_PADDLE_BOUNCE_ANGLE
	var dir := Vector2(sin(angle), -cos(angle)) # straight up at center, more diagonal at edges
	velocity = _ensure_not_too_flat(dir * BALL_SPEED)

func _handle_bounds() -> void:
	var pos := global_position

	var left := bounds_rect.position.x + ball_radius
	var right := bounds_rect.position.x + bounds_rect.size.x - ball_radius
	var top := bounds_rect.position.y + ball_radius
	var bottom := bounds_rect.position.y + bounds_rect.size.y - ball_radius

	# Left / right walls
	if pos.x < left:
		pos.x = left
		velocity.x = abs(velocity.x)
	elif pos.x > right:
		pos.x = right
		velocity.x = -abs(velocity.x)

	# Top / bottom (bottom currently bounces; you can turn this into "lose ball" later)
	if pos.y < top:
		pos.y = top
		velocity.y = abs(velocity.y)
	elif pos.y > bottom:
		pos.y = bottom
		velocity.y = -abs(velocity.y)

	global_position = pos

func _ensure_not_too_flat(v: Vector2) -> Vector2:
	# If the vector is almost zero, reset to straight up
	if v.length_squared() < 0.0001:
		return Vector2(0, -1) * BALL_SPEED

	var n: Vector2 = v.normalized()

	# If it's too horizontal, force some vertical component
	if abs(n.y) < sin(MIN_VERTICAL_ANGLE):
		# Keep horizontal direction, but enforce vertical slope
		var sign_y: float = -1.0 if n.y == 0.0 else float(sign(n.y))
		n.y = sign_y * sin(MIN_VERTICAL_ANGLE)
		# Recompute x so length stays ~1
		var sx: float = sqrt(max(0.0, 1.0 - n.y * n.y))
		n.x = (sign(n.x) if n.x != 0.0 else 1.0) * sx

	return n.normalized() * BALL_SPEED
