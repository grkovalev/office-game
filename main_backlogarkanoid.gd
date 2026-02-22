extends Node2D

const PADDLE_SPEED := 900.0
# Mug atlas 1000x500: two 500x500 tiles — frame 0 = full, frame 1 = broken
const HEALTHCUP_REGION_FRAME_0 := Rect2(0, 0, 500, 500)
const HEALTHCUP_REGION_FRAME_1 := Rect2(500, 0, 500, 500)

@onready var paddle: CharacterBody2D = $player/playctrl/play_char
@onready var paddle_coll: CollisionShape2D = $player/playctrl/play_char/play_coll
@onready var paddle_pressed: CharacterBody2D = $player/playctrl/play_char_pressed
@onready var paddle_pressed_coll: CollisionShape2D = $player/playctrl/play_char_pressed/playpressed_coll
@onready var tiles: TextureRect = $bg/bg_tiles
@onready var exitbtn: TextureButton = $exitbtn
@onready var restartbtn: TextureButton = $restartbtn
@onready var grid: Node2D = $env/grid
@onready var ball_char: CharacterBody2D = $ball/ballctrl/ball_char
@onready var player_ctrl: Node2D = $player/playctrl
@onready var health_node: Node2D = $health
@onready var ball_node: Node2D = $ball
@onready var player_node: Node2D = $player
@onready var gamewon_node: Node2D = $gamewon
@onready var gamelost_node: Node2D = $gamelost
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
@onready var pause_node: Node2D = $pause

var paddle_half_width: float
var paddle_half_height: float
var _paddle_fixed_y: float  # Lock paddle to X-only movement
var bounds_rect: Rect2
var _initial_player_position: Vector2
var lives_remaining: int = 3
var _health_animation_running: bool = false
var _pending_blink_cup_index: int = -1
var is_paused: bool = false
var _pause_base_scale: Vector2 = Vector2.ONE
var _paddle_pressed_timer: float = 0.0
const PADDLE_PRESSED_DURATION := 0.12
var _game_ended: bool = false

func _ready() -> void:
	_initial_player_position = player_ctrl.position
	exitbtn.pressed.connect(_on_exitbtn_pressed)
	restartbtn.pressed.connect(_on_restartbtn_pressed)
	ball_char.hit_bottom.connect(_on_ball_hit_bottom)
	ball_char.emergence_finished.connect(_on_ball_emergence_finished)
	ball_char.paddle_bounced.connect(_on_ball_paddle_bounced)
	_pause_base_scale = pause_node.scale
	pause_node.hide()
	gamewon_node.hide()
	gamelost_node.hide()
	# Restart/exit only on left click, not Space/Enter
	exitbtn.focus_mode = Control.FOCUS_NONE
	restartbtn.focus_mode = Control.FOCUS_NONE

	var paddle_shape := paddle_coll.shape as RectangleShape2D
	paddle_half_width = 0.5 * paddle_shape.size.x * paddle_coll.global_scale.x
	paddle_half_height = 0.5 * paddle_shape.size.y * paddle_coll.global_scale.y
	_paddle_fixed_y = paddle.global_position.y

	var r := tiles.get_global_rect()
	bounds_rect = Rect2(r.position, r.size)
	# Use correct 500x500 regions for 1000x500 atlas at start
	for i in range(health_cup_sprites.size()):
		health_cup_sprites[i].region_rect = HEALTHCUP_REGION_FRAME_0
	_update_paddle_visual(ball_char.attached)

func _on_ball_paddle_bounced() -> void:
	_paddle_pressed_timer = PADDLE_PRESSED_DURATION

func _update_paddle_visual(use_pressed: bool) -> void:
	if use_pressed:
		paddle.visible = false
		paddle_coll.disabled = true
		paddle_pressed.visible = true
		paddle_pressed_coll.disabled = false
	else:
		paddle.visible = true
		paddle_coll.disabled = false
		paddle_pressed.visible = false
		paddle_pressed_coll.disabled = true

func _input(event: InputEvent) -> void:
	# Only runs when game is not paused; when paused, PauseInputHandler handles Space
	if event is InputEventKey:
		var key_ev: InputEventKey = event
		if key_ev.pressed and not key_ev.echo and key_ev.keycode == KEY_SPACE:
			_toggle_pause()
			get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	if is_paused:
		_unpause_game()
	else:
		_pause_game()

func _pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	pause_node.show()
	pause_node.scale = _pause_base_scale * 0.3  # Start small for pop
	# Tween must run on pause node so it keeps playing while tree is paused (pause node has PROCESS_MODE_ALWAYS)
	var tween := pause_node.create_tween()
	tween.set_parallel(false)
	# Burst: scale up past 1
	tween.tween_property(pause_node, "scale", _pause_base_scale * 1.18, 0.12)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	# Squeeze: settle to normal
	tween.tween_property(pause_node, "scale", _pause_base_scale, 0.15)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

func _unpause_game() -> void:
	is_paused = false
	get_tree().paused = false
	pause_node.hide()

func _physics_process(delta: float) -> void:
	if is_paused:
		return
	if not _game_ended and not ball_char.attached:
		_check_bricks_cleared()
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
	p.y = _paddle_fixed_y  # Keep paddle on fixed Y (X-only movement)
	var left_limit := bounds_rect.position.x + paddle_half_width
	var right_limit := bounds_rect.position.x + bounds_rect.size.x - paddle_half_width
	p.x = clamp(p.x, left_limit, right_limit)
	paddle.global_position = p
	paddle_pressed.global_position = p
	if _paddle_pressed_timer > 0.0:
		_paddle_pressed_timer -= _delta
	_update_paddle_visual(ball_char.attached or _paddle_pressed_timer > 0.0)

func _check_bricks_cleared() -> void:
	if get_tree().get_nodes_in_group("brick").size() > 0:
		return
	_show_game_won()

func _show_game_won() -> void:
	_game_ended = true
	ball_node.hide()
	player_node.hide()
	gamewon_node.show()

func _show_game_lost() -> void:
	_game_ended = true
	ball_node.hide()
	player_node.hide()
	gamelost_node.show()

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
		ball_char.return_to_paddle_after_delay(1.0)
	else:
		ball_char.disappear()
		_show_game_lost()

func _lose_health_cup(cup_index: int) -> void:
	if cup_index < 0 or cup_index >= health_cup_sprites.size():
		return
	var sprite: Sprite2D = health_cup_sprites[cup_index]
	var cup_parent: Node2D = health_cup_parents[cup_index]
	_health_animation_running = true
	_pending_blink_cup_index = cup_index

	# 1) Switch texture atlas to frame 1 (broken)
	sprite.region_rect = HEALTHCUP_REGION_FRAME_1

	# 2) Enlarge then shrink (like exitbtn/restartbtn); blink phase starts after ball emergence + 0.5s
	var base_scale: Vector2 = cup_parent.scale
	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(cup_parent, "scale", base_scale * 1.15, 0.15)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(cup_parent, "scale", base_scale, 0.15)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

func _on_ball_emergence_finished() -> void:
	if not _health_animation_running or _pending_blink_cup_index < 0:
		return
	var cup_index: int = _pending_blink_cup_index
	var sprite: Sprite2D = health_cup_sprites[cup_index]
	var cup_parent: Node2D = health_cup_parents[cup_index]
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		_run_health_cup_blink(cup_index, sprite, cup_parent)
		_pending_blink_cup_index = -1
	, CONNECT_ONE_SHOT)

func _run_health_cup_blink(cup_index: int, sprite: Sprite2D, cup_parent: Node2D) -> void:
	var tween := create_tween()
	tween.set_parallel(false)
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
	# Clear pause so pause node hides and game unfreezes
	if is_paused:
		is_paused = false
		get_tree().paused = false
		pause_node.hide()
	_game_ended = false
	gamewon_node.hide()
	gamelost_node.hide()
	ball_node.show()
	player_node.show()
	lives_remaining = 3
	_health_animation_running = false
	_pending_blink_cup_index = -1
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
