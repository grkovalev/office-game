extends TextureButton

@export var hover_scale := Vector2(1.1, 1.1)
@export var pressed_scale := Vector2(0.95, 0.95)
@export var tween_time := 0.15
<<<<<<< Updated upstream
@export var cooldown_seconds := 900 
=======
@export var cooldown_seconds := 900
>>>>>>> Stashed changes
@export var cooldown_texture: Texture2D
@export var anim_sprite: AnimatedSprite2D

@onready var label: Label = $Label

var _tween: Tween
var time_left := 0
var timer_running := false
var timer_paused := false
var original_texture: Texture2D
var _accumulator := 0.0

func _process(delta):
	if timer_running and not timer_paused:
		_accumulator += delta
		if _accumulator >= 1.0:
			_accumulator -= 1.0
			time_left -= 1
			if time_left <= 0:
				reset_button()
			update_label()
<<<<<<< Updated upstream

=======
>>>>>>> Stashed changes
	update_animation_state()

func _ready() -> void:
	pivot_offset = size / 2
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)
	button_down.connect(_on_pressed)
	button_up.connect(_on_release)
	original_texture = texture_normal

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			handle_left_click()
		elif event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			handle_right_click()

func handle_left_click():
	if not timer_running:
		start_cooldown()
	elif timer_running and not timer_paused:
		timer_paused = true
	elif timer_running and timer_paused:
		timer_paused = false

func handle_right_click():
	if timer_running and timer_paused:
		reset_button()

func animate_to(target_scale: Vector2):
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target_scale, tween_time)
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)

func _on_hover():
	if toggle_mode and button_pressed:
		return
	if timer_running:
		return
	animate_to(hover_scale)

func _on_exit():
	if toggle_mode and button_pressed:
		return
	if timer_running:
		return
	animate_to(Vector2.ONE)

func _on_pressed():
	if timer_running:
		return
	animate_to(pressed_scale)

func _on_release():
	if toggle_mode:
		var target_scale = pressed_scale if button_pressed else Vector2.ONE
		animate_to(target_scale)
	else:
		animate_to(hover_scale)
<<<<<<< Updated upstream
=======
func handle_left_click():
	if not timer_running:
		start_cooldown()
	elif timer_running and not timer_paused:
		timer_paused = true
	elif timer_running and timer_paused:
		timer_paused = false

func handle_right_click():
	if timer_running and timer_paused:
		reset_button()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			handle_left_click()
		elif event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			handle_right_click()
>>>>>>> Stashed changes

func start_cooldown():
	timer_running = true
	timer_paused = false
	time_left = cooldown_seconds

	if cooldown_texture:
		texture_normal = cooldown_texture

	label.visible = true
	update_label()

func reset_button():
	timer_running = false
	timer_paused = false
	time_left = 0

	if original_texture:
		texture_normal = original_texture

	label.text = ""
	label.visible = false
	animate_to(Vector2.ONE)

func update_label():
	var minutes := time_left / 60
	var seconds := time_left % 60
	label.text = "%02d:%02d" % [minutes, seconds]

func update_animation_state():
	if not anim_sprite:
		return

	if timer_running:
		if anim_sprite.animation != "anim_focused":
			anim_sprite.animation = "anim_focused"
			anim_sprite.play()
	else:
		if anim_sprite.animation != "anim_idle_default":
			anim_sprite.animation = "anim_idle_default"
			anim_sprite.play()
