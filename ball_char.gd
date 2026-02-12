extends CharacterBody2D

signal hit_bottom

@export var ball_speed: float = 900.0
@export var brick_speed_boost: float = 0.0
@export var max_ball_speed: float = 0.0
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
var overlap_shape: CircleShape2D

var attached := true
var current_speed: float = 900.0
var paddle_ignore_time: float = 0.0
var _prev_global_position: Vector2
var _bottom_hit_emitted_this_frame: bool = false

func _ready() -> void:
	var p_shape := paddle_coll.shape as RectangleShape2D
	paddle_half_width = 0.5 * p_shape.size.x * paddle_coll.global_scale.x
	paddle_half_height = 0.5 * p_shape.size.y * paddle_coll.global_scale.y

	var b_shape := ball_coll.shape as CircleShape2D
	ball_radius = b_shape.radius * ball_coll.global_scale.x

	overlap_shape = CircleShape2D.new()
	overlap_shape.radius = ball_radius * 2.0

	var r := bounds_rect_node.get_global_rect()
	bounds_rect = Rect2(r.position, r.size)
	current_speed = ball_speed
	collision_mask = 1

	_stick_to_paddle()

func reset_ball() -> void:
	attached = true
	current_speed = ball_speed
	velocity = Vector2.ZERO
	_bottom_hit_emitted_this_frame = false
	show()
	set_physics_process(true)
	_stick_to_paddle()

func stick_to_paddle() -> void:
	attached = true
	current_speed = ball_speed
	velocity = Vector2.ZERO
	_bottom_hit_emitted_this_frame = false
	_stick_to_paddle()

func disappear() -> void:
	# Game over: ball leaves the play area
	velocity = Vector2.ZERO
	hide()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if attached:
		_stick_to_paddle()
		if Input.is_action_just_pressed("ui_up"):
			attached = false
			current_speed = ball_speed
			velocity = Vector2.UP * ball_speed
			paddle_ignore_time = 0.12
			_prev_global_position = global_position
		return

	if paddle_ignore_time > 0.0:
		paddle_ignore_time -= delta

	velocity = _ensure_not_too_flat(velocity, current_speed)
	move_and_slide()

	var hit_paddle := false
	var first_bounce_normal := Vector2.ZERO
	var bricks_hit: Array[Node] = []

	# Sample overlap along path (prev -> current) so we never miss a brick (tunneling or grazing)
	var path_normal: Vector2 = _collect_bricks_along_path(bricks_hit)

	# Collect all slide collisions this frame
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		var normal := col.get_normal()

		if normal == Vector2.ZERO:
			continue

		if collider == paddle and paddle_ignore_time <= 0.0:
			hit_paddle = true
		else:
			var brick_node: Node = _get_brick_node(collider)
			if brick_node != null:
				if brick_node not in bricks_hit:
					bricks_hit.append(brick_node)
				if first_bounce_normal == Vector2.ZERO:
					first_bounce_normal = normal
			elif first_bounce_normal == Vector2.ZERO:
				first_bounce_normal = normal

	if first_bounce_normal == Vector2.ZERO and path_normal != Vector2.ZERO:
		first_bounce_normal = path_normal

	if hit_paddle:
		_bounce_on_paddle()
	elif bricks_hit.size() > 0:
		# Only one brick per hit
		var brick: Node = bricks_hit[0]

		# Optional: still compute a normal for nudging out 2‑hit bricks
		var brick_normal: Vector2 = _get_brick_face_normal_from_velocity(brick, velocity)

		# Bounce strictly opposite to current trajectory
		velocity = -velocity
		velocity = _ensure_not_too_flat(velocity, current_speed)

		if is_instance_valid(brick):
			# Speed boost logic stays as before
			if brick_speed_boost > 0.0:
				var cap: float = max_ball_speed if max_ball_speed > 0.0 else ball_speed * 3.0
				current_speed = min(current_speed + brick_speed_boost, cap)

			if brick.has_method("take_hit"):
				if brick.take_hit():
					if brick.has_method("play_destroy_animation"):
						brick.play_destroy_animation()
					else:
						brick.queue_free()
			else:
				brick.queue_free()

			# Always nudge ball out after any brick hit so it doesn't register an adjacent brick next frame
			if brick_normal != Vector2.ZERO:
				global_position += brick_normal * (ball_radius * 2.5)
	elif first_bounce_normal != Vector2.ZERO:
		velocity = velocity.bounce(first_bounce_normal)
		velocity = _ensure_not_too_flat(velocity, current_speed)

	# Manual walls using bg_tiles rectangle
	_handle_bounds()

	velocity = _ensure_not_too_flat(velocity, current_speed)

	_prev_global_position = global_position
	_bottom_hit_emitted_this_frame = false

func _collect_bricks_along_path(bricks_hit: Array[Node]) -> Vector2:
	var from_pos: Vector2 = _prev_global_position
	var to_pos: Vector2 = global_position
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = overlap_shape
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	query.collision_mask = 0xFFFFFFFF
	var first_normal := Vector2.ZERO
	var sample_positions: Array[Vector2] = [from_pos, (from_pos + to_pos) * 0.5, to_pos]
	for sample_pos in sample_positions:
		query.transform = Transform2D(0.0, sample_pos)
		var results: Array[Dictionary] = space_state.intersect_shape(query)
		for result in results:
			var body: Node = result.collider
			var brick_node: Node = _get_brick_node(body)
			if brick_node != null and brick_node not in bricks_hit:
				bricks_hit.append(brick_node)
				if first_normal == Vector2.ZERO:
					var brick_pos: Vector2 = brick_node.global_position
					first_normal = (sample_pos - brick_pos).normalized()
	return first_normal

func _get_brick_face_normal_from_velocity(_brick_node: Node, vel: Vector2) -> Vector2:
	# Pick the brick face we're moving toward (entry face). Its outward normal n should satisfy vel · n < 0.
	if vel.length_squared() < 0.0001:
		return Vector2.ZERO
	var v: Vector2 = vel.normalized()
	var best_normal := Vector2.ZERO
	var best_dot: float = 1.0
	for n in [Vector2(0.0, 1.0), Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(-1.0, 0.0)]:
		var d: float = v.dot(n)
		if d < best_dot:
			best_dot = d
			best_normal = n
	if best_dot >= 0.0:
		return Vector2.ZERO
	return best_normal

func _get_brick_node(collider: Node) -> Node:
	if collider == null:
		return null
	if collider.is_in_group("brick"):
		return collider
	var parent: Node = collider.get_parent()
	if parent != null and parent.is_in_group("brick"):
		return parent
	return null

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
	current_speed = ball_speed
	velocity = _ensure_not_too_flat(dir * ball_speed, current_speed)

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

	# Top wall bounces; bottom = lose life (main script handles stick or game over)
	if pos.y < top:
		pos.y = top
		velocity.y = abs(velocity.y)
	elif pos.y > bottom:
		pos.y = bottom
		velocity = Vector2.ZERO
		if not _bottom_hit_emitted_this_frame:
			_bottom_hit_emitted_this_frame = true
			hit_bottom.emit()

	global_position = pos

func _ensure_not_too_flat(v: Vector2, speed: float = -1.0) -> Vector2:
	var use_speed: float = speed if speed > 0.0 else ball_speed
	# If the vector is almost zero, reset to straight up
	if v.length_squared() < 0.0001:
		return Vector2(0, -1) * use_speed

	var n: Vector2 = v.normalized()

	# If it's too horizontal, force some vertical component
	if abs(n.y) < sin(MIN_VERTICAL_ANGLE):
		# Keep horizontal direction, but enforce vertical slope
		var sign_y: float = -1.0 if n.y == 0.0 else float(sign(n.y))
		n.y = sign_y * sin(MIN_VERTICAL_ANGLE)
		# Recompute x so length stays ~1
		var sx: float = sqrt(max(0.0, 1.0 - n.y * n.y))
		n.x = (sign(n.x) if n.x != 0.0 else 1.0) * sx

	return n.normalized() * use_speed
