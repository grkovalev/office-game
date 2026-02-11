extends Node2D

@export var columns: int = 13
@export var rows: int = 10

# Atlas and brick settings
@export var brick_atlas: Texture2D
@export var brick_source_size := Vector2i(400, 200)
@export var brick_display_size := Vector2(75, 35)

# Spacing between bricks
@export var brick_gap := Vector2(5, 5)

# Atlas layout (we still only use indices 0 and 1)
@export var brick_variants := Vector2i(2, 2)

# Probabilities
@export_range(0.0, 1.0, 0.01)
var empty_probability: float = 0.1   # 10% empty by default

@export_range(0.0, 1.0, 0.01)
var variant0_probability: float = 0.5   # among occupied tiles

@export_range(0.0, 1.0, 0.01)
var variant1_probability: float = 0.5   # among occupied tiles

func _ready() -> void:
	randomize()
	generate_grid()

func generate_grid() -> void:
	# Clear previous bricks
	for child in get_children():
		child.queue_free()

	if brick_atlas == null:
		push_error("brick_atlas is not assigned on grid.")
		return

	var total_variants := brick_variants.x * brick_variants.y
	if total_variants <= 0:
		push_error("brick_variants is invalid (must be > 0).")
		return

	# Normalize variant probabilities (only used for non-empty tiles)
	var p0: float = max(variant0_probability, 0.0)
	var p1: float = max(variant1_probability, 0.0)
	var sum_p: float = p0 + p1

	if sum_p == 0.0:
		p0 = 0.5
		p1 = 0.5
		sum_p = 1.0

	p0 /= sum_p
	p1 /= sum_p

	for row in range(rows):
		for col in range(columns):
			# Decide if this cell is empty
			if randf() < empty_probability:
				continue

			# Pick between variant 0 and 1 using normalized probabilities
			var r := randf()
			var variant_index := 0 if r < p0 else 1

			var tex := _create_variant_texture(variant_index)
			if tex == null:
				continue

			# Create a brick (backlog_brick.gd holds hits_left and cracked_texture)
			var brick := StaticBody2D.new()
			brick.set_script(preload("res://backlog_brick.gd"))
			brick.collision_layer = 1
			brick.collision_mask = 0
			add_child(brick)
			brick.position = Vector2(
				col * (brick_display_size.x + brick_gap.x),
				row * (brick_display_size.y + brick_gap.y)
			)
			brick.add_to_group("brick")

			if variant_index == 0:
				brick.hits_left = 2
				var cracked_tex: Texture2D = _create_variant_texture(1)
				if cracked_tex != null:
					brick.cracked_texture = cracked_tex
			else:
				brick.hits_left = 1

			# Visual
			var sprite := Sprite2D.new()
			brick.add_child(sprite)
			sprite.texture = tex
			sprite.scale = Vector2(
				brick_display_size.x / float(brick_source_size.x),
				brick_display_size.y / float(brick_source_size.y)
			)

			# Collision: each brick gets its own shape so collisions are reliable
			var brick_shape := RectangleShape2D.new()
			brick_shape.size = brick_display_size
			var coll := CollisionShape2D.new()
			coll.shape = brick_shape
			brick.add_child(coll)

func _create_variant_texture(variant_index: int) -> Texture2D:
	if brick_atlas == null:
		return null

	var cols := brick_variants.x
	if cols <= 0:
		return null

	var row := variant_index / cols
	var col := variant_index % cols

	var region := Rect2(
		col * brick_source_size.x,
		row * brick_source_size.y,
		brick_source_size.x,
		brick_source_size.y
	)

	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = brick_atlas
	atlas_tex.region = region
	return atlas_tex
