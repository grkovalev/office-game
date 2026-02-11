extends Node2D

@export var columns: int = 13
@export var rows: int = 10

# Atlas and brick settings
@export var brick_atlas: Texture2D                # assign your 800x400 brick_atlas here
@export var brick_source_size := Vector2i(400, 200)
@export var brick_display_size := Vector2(75, 35) # on-screen size of each brick

# New: spacing between bricks (in pixels)
@export var brick_gap := Vector2(5, 5)            # horizontal / vertical gap

@export var brick_variants := Vector2i(2, 2)      # 2x2 = 4 variants
@export var use_random_variant: bool = true
@export var default_variant_index: int = 0        # 0–3

func _ready() -> void:
	randomize()
	generate_grid()

func generate_grid() -> void:
	for child in get_children():
		child.queue_free()

	if brick_atlas == null:
		push_error("brick_atlas is not assigned on grid.")
		return

	var total_variants := brick_variants.x * brick_variants.y
	if total_variants <= 0:
		push_error("brick_variants is invalid (must be > 0).")
		return

	for row in range(rows):
		for col in range(columns):
			var sprite := Sprite2D.new()
			add_child(sprite)

			# Use brick size + gap for spacing
			sprite.position = Vector2(
				col * (brick_display_size.x + brick_gap.x),
				row * (brick_display_size.y + brick_gap.y)
			)

			var variant_index := default_variant_index
			if use_random_variant:
				variant_index = randi() % total_variants

			var tex := _create_variant_texture(variant_index)
			if tex == null:
				continue

			sprite.texture = tex
			sprite.scale = Vector2(
				brick_display_size.x / float(brick_source_size.x),
				brick_display_size.y / float(brick_source_size.y)
			)

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
