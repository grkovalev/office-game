extends Line2D

const WORK_START := 9
const WORK_END := 18
const UPDATE_INTERVAL_SEC := 900.0  # 15 minutes

# Set to 0–23 in Inspector to test; -1 = use real time
@export var debug_hour: int = -1

@onready var timescale: Node2D = $"../timescale"
var _timer: Timer


func _ready() -> void:
	z_index = 10  # draw on top of meeting_lib and grid
	default_color.a = 0.5
	_timer = Timer.new()
	_timer.wait_time = UPDATE_INTERVAL_SEC
	_timer.one_shot = false
	_timer.timeout.connect(_update_timeline)
	add_child(_timer)
	_update_timeline()
	_timer.start()


func _update_timeline() -> void:
	var hour: int = debug_hour if debug_hour >= 0 else Time.get_time_dict_from_system().hour

	if hour < WORK_START or hour > WORK_END:
		visible = false
		return

	visible = true

	var hour_str := "%02d" % hour
	var label_node = timescale.get_node_or_null(hour_str)
	if label_node == null or not label_node is Control:
		visible = false
		return

	var label_control: Control = label_node
	var label_center_y: float = label_control.global_position.y + label_control.size.y * 0.5
	position.y = label_center_y - points[0].y
