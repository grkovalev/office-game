extends Label

const DAY_NAMES: Array[String] = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

func _ready() -> void:
	var date: Dictionary = Time.get_date_dict_from_system()
	var day_name: String = DAY_NAMES[date["weekday"]]
	var day: int = date["day"]
	var year: int = date["year"]
	text = "%s, %d Worktober %d" % [day_name, day, year]
