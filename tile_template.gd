extends TextureButton

@export var atlas: Texture2D
@export var tile_size: Vector2 = Vector2(50,50)
@export var num_tiles_in_row: int = 9  # adjust depending on your atlas layout

func _ready():
	# Set initial tile (Hidden)
	set_random_tile()
	pressed.connect(_on_pressed)

func _on_pressed():
	# Show a new random tile from the atlas each time it’s clicked
	set_random_tile()

func set_random_tile():
	# Random column and row
	var col = randi() % num_tiles_in_row
	var row = randi() % num_tiles_in_row
	texture_normal = AtlasTexture.new()
	texture_normal.atlas = atlas
	texture_normal.region = Rect2(Vector2(col * tile_size.x, row * tile_size.y), tile_size)
