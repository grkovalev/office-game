extends TextureButton

@export var hover_scale := Vector2(1.1, 1.1)
@export var pressed_scale := Vector2(0.95, 0.95)
@export var tween_time := 0.15

var _tween: Tween

func _ready() -> void:
	pivot_offset = size / 2
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)
	button_down.connect(_on_pressed)
	button_up.connect(_on_release)

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
	animate_to(hover_scale)

func _on_exit():
	if toggle_mode and button_pressed:
		return
	animate_to(Vector2.ONE)

func _on_pressed():
	animate_to(pressed_scale)

func _on_release():
	if toggle_mode:
		var target_scale = pressed_scale if button_pressed else Vector2.ONE
		animate_to(target_scale)
	else:
		animate_to(hover_scale)
