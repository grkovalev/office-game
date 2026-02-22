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
## Impact tween: scale punch duration in seconds.
var impact_duration: float = 0.08
## Impact tween: max scale (e.g. 1.2 = 20% bigger at peak).
var impact_scale: float = 1.2
## Impact tween: modulate flash (e.g. 1.4 = brief brighten). 0 = no flash.
var impact_modulate_peak: float = 1.35
## Impact tween: max rotation tilt in radians (~0.06 = 3.4°). Kept small so bricks don't overlap neighbors.
var impact_tilt_angle: float = 0.06

## Call when the ball hits this brick. Returns true if the brick should be removed, false if it only got damaged.
## impact_normal: outward normal of the brick face that was hit (from ball); used for tilt direction.
func take_hit(impact_normal: Vector2 = Vector2.ZERO) -> bool:
	_play_impact_tween(impact_normal)
	hits_left -= 1
	if hits_left <= 0:
		return true
	if cracked_texture != null:
		for child in get_children():
			if child is Sprite2D:
				(child as Sprite2D).texture = cracked_texture
				break
	return false

func _play_impact_tween(impact_normal: Vector2 = Vector2.ZERO) -> void:
	var sprite: Sprite2D = _get_sprite()
	if sprite == null:
		return
	var start_scale: Vector2 = sprite.scale
	var start_mod: Color = sprite.modulate
	var start_rotation: float = sprite.rotation
	# Tilt direction from impact side: normal.x - normal.y gives consistent lean per face, small so no overlap
	var norm: Vector2 = impact_normal.normalized() if impact_normal != Vector2.ZERO else Vector2.ZERO
	var tilt_rad: float = impact_tilt_angle * (norm.x - norm.y) if norm != Vector2.ZERO else 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	# Scale punch: grow then back
	tween.tween_property(sprite, "scale", start_scale * impact_scale, impact_duration * 0.4)
	tween.tween_property(sprite, "scale", start_scale, impact_duration * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Rotation tilt (sprite only) so collision stays axis-aligned and bricks don't overlap
	if abs(tilt_rad) > 0.0001:
		tween.parallel().tween_property(sprite, "rotation", start_rotation + tilt_rad, impact_duration * 0.35)
		tween.parallel().tween_property(sprite, "rotation", start_rotation, impact_duration * 0.65).set_delay(impact_duration * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if impact_modulate_peak > 0.0:
		var peak_mod := Color(start_mod.r * impact_modulate_peak, start_mod.g * impact_modulate_peak, start_mod.b * impact_modulate_peak, start_mod.a)
		tween.parallel().tween_property(sprite, "modulate", peak_mod, impact_duration * 0.25)
		tween.parallel().tween_property(sprite, "modulate", start_mod, impact_duration * 0.75).set_delay(impact_duration * 0.25)

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
