extends StaticBody2D

## Number of hits left before breaking. 1 = one-hit brick, 2 = two-hit brick.
var hits_left: int = 1
## Texture to show after first hit (for two-hit bricks). Leave null for one-hit.
var cracked_texture: Texture2D = null
## Blink frames before disappearing (atlas indices 2 and 3). Set by grid.
var blink_texture_2: Texture2D = null
var blink_texture_3: Texture2D = null
## Duration per blink frame in seconds (~0.06–0.08 feels good).
var blink_duration: float = 0.07

## Call when the ball hits this brick. Returns true if the brick should be removed, false if it only got damaged.
func take_hit() -> bool:
	hits_left -= 1
	if hits_left <= 0:
		return true
	if cracked_texture != null:
		for child in get_children():
			if child is Sprite2D:
				(child as Sprite2D).texture = cracked_texture
				break
	return false

## Play blink (frame 2 → frame 3) then queue_free. Call when brick is being removed.
func play_destroy_animation() -> void:
	collision_layer = 0
	collision_mask = 0
	var sprite: Sprite2D = _get_sprite()
	if sprite == null:
		queue_free()
		return
	if blink_texture_2 != null:
		sprite.texture = blink_texture_2
	var t1: SceneTreeTimer = get_tree().create_timer(blink_duration)
	t1.timeout.connect(_on_blink_second_frame.bind(sprite))

func _on_blink_second_frame(sprite: Sprite2D) -> void:
	if not is_instance_valid(self):
		return
	if blink_texture_3 != null and sprite != null:
		sprite.texture = blink_texture_3
	var t2: SceneTreeTimer = get_tree().create_timer(blink_duration)
	t2.timeout.connect(_on_blink_done)

func _on_blink_done() -> void:
	queue_free()

func _get_sprite() -> Sprite2D:
	for child in get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null
