extends Node
## Runs when the scene tree is paused; forwards Space to parent to toggle pause.

func _ready() -> void:
	set_process_mode(PROCESS_MODE_ALWAYS)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_ev: InputEventKey = event
		if key_ev.pressed and not key_ev.echo and key_ev.keycode == KEY_SPACE:
			var main = get_parent()
			# Do not toggle pause while game-over popup (gamewon/gamelost) is showing
			if main.has_method("is_game_ended") and main.is_game_ended():
				get_viewport().set_input_as_handled()
				return
			if main.has_method("_toggle_pause"):
				main._toggle_pause()
			get_viewport().set_input_as_handled()
