extends Node
## Autoload "Game": configuración global del prototipo e inputs.
## Los inputs se registran por código para mantener project.godot limpio
## y centralizar los binds (provisional, ajustable desde aquí).

func _ready() -> void:
	_setup_input()


func _setup_input() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_key_action("crouch", [KEY_S, KEY_DOWN, KEY_CTRL])
	_add_key_action("reload", [KEY_R])
	_add_key_action("switch_weapon", [KEY_Q])
	_add_key_action("build_place", [KEY_F])
	_add_key_action("build_destroy", [KEY_G])
	_add_key_action("restart_round", [KEY_ENTER])
	_add_key_action("use_utility", [KEY_E, KEY_SHIFT])
	_add_key_action("pause_menu", [KEY_ESCAPE])
	_add_key_action("scoreboard", [KEY_TAB])

	_add_mouse_action("fire_primary", MOUSE_BUTTON_LEFT)
	_add_mouse_action("fire_secondary", MOUSE_BUTTON_RIGHT)


func _add_key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	for code: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		InputMap.action_add_event(action, ev)


func _add_mouse_action(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)