extends SceneTree
## Opens Blocky Lab, spawns a test dummy, shows the debug overlay and saves a
## screenshot. Needs a display (or xvfb-run):
##   godot --path . -s res://tools/capture_lab.gd -- /path/to/shot.png

var _frame := 0

func _process(_delta: float) -> bool:
	_frame += 1
	var game: Node = root.get_node("Game")
	if _frame == 2:
		var result: Dictionary = game.open_lab()
		game.start_session(result.save)
	if game.session != null and game.session.is_playing and _frame > 10 and _frame < 1000:
		_frame = 1000
		var player: Player = game.session.player
		player.rotation.y = deg_to_rad(200)
		player.head.rotation.x = deg_to_rad(-20)
		game.session.debug_overlay.visible = true
		game.session.world.entities.spawn("blockyworld:test_dummy", player.global_position + Vector3(2, 0, 4))
	if _frame == 1060:
		var image := root.get_texture().get_image()
		image.save_png(OS.get_cmdline_user_args()[0])
		quit()
	return false
