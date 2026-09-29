extends SceneTree

func _init() -> void:
	var s = load("res://src/player/player_controller.gd")
	if s == null:
		print("FAIL load controller")
		quit(1)
		return
	print("controller script loaded: ", s)
	var inst = s.new()
	print("instance: ", inst)
	var s2 = load("res://src/player/player.gd")
	print("player script: ", s2)
	var inst2 = s2.new()
	print("player instance: ", inst2)
	quit(0)