extends StaticBody2D

## Number of hits left before breaking. 1 = one-hit brick, 2 = two-hit brick.
var hits_left: int = 1
## Texture to show after first hit (for two-hit bricks). Leave null for one-hit.
var cracked_texture: Texture2D = null

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
