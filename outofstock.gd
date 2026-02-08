extends Label

const DEFAULT_TEXT := "limited superpower"
const OUT_OF_STOCK_TEXT := "out of stock"

@onready var quickshapepack = get_parent().get_node_or_null("quickshapepack")
var _last_count: int = -1


func _ready() -> void:
	text = DEFAULT_TEXT


func _process(_delta: float) -> void:
	if quickshapepack == null or not is_instance_valid(quickshapepack):
		return
	var count: int = quickshapepack.get_available_quickshape_count()
	if count != _last_count:
		_last_count = count
		text = OUT_OF_STOCK_TEXT if count == 0 else DEFAULT_TEXT
