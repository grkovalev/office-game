@tool
extends GridContainer

@onready var template = $Cell

func _ready():

	print("Build grid")
	if Engine.is_editor_hint():
		_build_grid()

func _build_grid():
	if template == null:
		push_error("Cell not found")
	
	for chilid in get_children():
		if chilid != template:
			remove_child(chilid)
			chilid.queue_free()
	
	var total_cells = columns * columns

	for i in range(total_cells):
		var cell = template.duplicate()
		cell.visible = true
		add_child(cell)
	
	template.visible = false


func _enter_tree() -> void:
	if template:
		template.connect("property_changed", self, "_on_template_property_changed", [], CONNECT_ONE_SHOT)

func _on_template_property_changed(prop_name: String):
	print("Template property changed", prop_name)
