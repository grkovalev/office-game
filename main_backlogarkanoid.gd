extends Node2D

const PADDLE_SPEED := 900.0
# Mug atlas 1000x500: two 500x500 tiles — frame 0 = full, frame 1 = broken
const HEALTHCUP_REGION_FRAME_0 := Rect2(0, 0, 500, 500)
const HEALTHCUP_REGION_FRAME_1 := Rect2(500, 0, 500, 500)

@onready var paddle: CharacterBody2D = $player/playctrl/play_char
@onready var paddle_coll: CollisionShape2D = $player/playctrl/play_char/play_coll
@onready var tiles: TextureRect = $bg/bg_tiles
@onready var exitbtn: TextureButton = $exitbtn
@onready var restartbtn: TextureButton = $restartbtn
@onready var grid: Node2D = $env/grid
@onready var ball_char: CharacterBody2D = $ball/ballctrl/ball_char
@onready var player_ctrl: Node2D = $player/playctrl
@onready var health_node: Node2D = $health
# Order: first life lost = 01, then 02, then 03 (scene has typo "heathcup")
@onready var health_cup_sprites: Array[Sprite2D] = [
	get_node("health/01_heathcup/01_healthcupimg"),
	get_node("health/02_heathcup/02_healthcupimg"),
	get_node("health/03_heathcup/03_healthcupimg")
]
@onready var health_cup_parents: Array[Node2D] = [
	get_node("health/01_heathcup"),
	get_node("health/02_heathcup"),
	get_node("health/03_heathcup")
]

var paddle_half_width: float
var paddle_half_height: float
var bounds_rect: Rect2
var _initial_player_position: Vector2
var lives_remaining: int = 3
var _health_animation_running: bool = false

func _ready() -> void:
	_initial_player_position = player_ctrl.position
	exitbtn.pressed.connect(_on_exitbtn_pressed)
	restartbtn.pressed.connect(_on_restartbtn_pressed)
	ball_char.hit_bottom.connect(_on_ball_hit_bottom)
	var paddle_shape := paddle_coll.shape as RectangleShape2D
	paddle_half_width = 0.5 * paddle_shape.size.x * paddle_coll.global_scale.x
	paddle_half_height = 0.5 * paddle_shape.size.y * paddle_coll.global_scale.y

	var r := tiles.get_global_rect()
	bounds_rect = Rect2(r.position, r.size)
	# Use correct 500x500 regions for 1000x500 atlas at start
	for i in range(health_cup_sprites.size()):
		health_cup_sprites[i].region_rect = HEALTHCUP_REGION_FRAME_0

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

func _on_ball_hit_bottom() -> void:
	if _health_animation_running:
		return
	if lives_remaining > 0:
		var cup_index: int = 3 - lives_remaining
		_lose_health_cup(cup_index)
		lives_remaining -= 1
		ball_char.stick_to_paddle()
	else:
		ball_char.disappear()

func _lose_health_cup(cup_index: int) -> void:
	if cup_index < 0 or cup_index >= health_cup_sprites.size():
		return
	var sprite: Sprite2D = health_cup_sprites[cup_index]
	var cup_parent: Node2D = health_cup_parents[cup_index]
	_health_animation_running = true

	# 1) Switch texture atlas to frame 1 (broken)
	sprite.region_rect = HEALTHCUP_REGION_FRAME_1

	# 2) Enlarge then shrink (like exitbtn/restartbtn)
	var base_scale: Vector2 = cup_parent.scale
	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(cup_parent, "scale", base_scale * 1.15, 0.15)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(cup_parent, "scale", base_scale, 0.15)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.5)  # Show index 1 texture a bit longer before blinking
	# Blink: dim and back (3 times)
	for _i in range(3):
		tween.tween_property(sprite, "modulate:a", 0.35, 0.08)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.08)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		cup_parent.hide()
		sprite.modulate.a = 1.0
		_health_animation_running = false
	)

func _restart_game() -> void:
	lives_remaining = 3
	_health_animation_running = false
	# Restore all health cups: visible, frame 0, full opacity
	for i in range(health_cup_parents.size()):
		var parent_node: Node2D = health_cup_parents[i]
		var spr: Sprite2D = health_cup_sprites[i]
		parent_node.show()
		spr.region_rect = HEALTHCUP_REGION_FRAME_0
		spr.modulate.a = 1.0
	if grid != null and grid.has_method("generate_grid"):
		grid.generate_grid()
	if ball_char != null and ball_char.has_method("reset_ball"):
		ball_char.reset_ball()
	if player_ctrl != null:
		player_ctrl.position = _initial_player_position
