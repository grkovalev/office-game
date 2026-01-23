class_name TileTemplateButton

extends TextureButton

var column_index: int
var row_index: int

@export var tile_size := Vector2i(50, 50)
@export var atlas_columns := 2
@export var max_tiles := 10




func _ready():
	texture_normal = texture_normal.duplicate()
	set_tile(0)

func set_tile(index: int) -> void:
	var atlas := texture_normal as AtlasTexture
	var col := index % atlas_columns
	var row := index / atlas_columns
	atlas.region = Rect2(
		Vector2(col * tile_size.x, row * tile_size.y),
		tile_size
	)
