extends SceneTree
## Missing-mod safety across real game processes:
##   --phase=place    world with example_mod; place example:ruby_block; save
##   --phase=missing  example_mod disabled: world opens with a warning, the
##                    block is a placeholder that keeps its id; save again
##   --phase=restore  example_mod enabled again: the ruby block is back
## Each phase toggles example_mod in user://mods.cfg for the next process
## ("missing" always re-enables it).

const WORLD_NAME := "Missing Mod Test (automated)"
const POS_PATH := "user://missing_mod_state.json"
const TIMEOUT_SEC := 90.0

var _failures: PackedStringArray = PackedStringArray()
var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run.call_deferred()
	return false


func _run() -> void:
	var phase := "place"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.substr(8)
	var game: Node = root.get_node("Game")
	await _wait(func() -> bool: return game.content != null, "boot")
	match phase:
		"place":
			game.set_mod_enabled("example_mod", true)
			for world in SaveManager.list_worlds():
				if world.name == WORLD_NAME:
					SaveManager.delete_world(world.directory)
			var created: Dictionary = game.create_world(WORLD_NAME, "5", GameConfig.LAB_GENERATOR, true)
			game.start_session(created.save)
			await _wait(func() -> bool: return game.session != null and game.session.is_playing, "spawn")
			var world: World = game.session.world
			var pos := Vector3i(3, 33, 3)
			var ruby := world.content.registries.blocks.get_runtime_id("example:ruby_block")
			check(world.set_block(pos, ruby), "ruby placed")
			var file := FileAccess.open(POS_PATH, FileAccess.WRITE)
			file.store_string(JSON.stringify([pos.x, pos.y, pos.z]))
			file.close()
			game.session.save_game()
			if _failures.is_empty():
				game.set_mod_enabled("example_mod", false)
		"missing", "restore":
			var pos_data: Array = JSON.parse_string(FileAccess.get_file_as_string(POS_PATH))
			var pos := Vector3i(pos_data[0], pos_data[1], pos_data[2])
			var directory := ""
			for world in SaveManager.list_worlds():
				if world.name == WORLD_NAME:
					directory = world.directory
			var opened: Dictionary = game.open_world(directory)
			var missing_ids: Array = []
			for mod in opened.missing_mods:
				missing_ids.append(mod.id)
			if phase == "missing":
				check(not game.content.registries.blocks.has("example:ruby_block") or game.content.registries.blocks.get_block("example:ruby_block").missing, "example_mod is not loaded")
				check(missing_ids.has("example_mod"), "open_world reports example_mod as missing (%s)" % [missing_ids])
			else:
				check(missing_ids.is_empty(), "nothing missing after re-enabling")
			game.start_session(opened.save, opened.missing_mods)
			await _wait(func() -> bool: return game.session != null and game.session.is_playing, "spawn")
			var world: World = game.session.world
			var definition := world.get_block_definition(pos)
			check(definition != null and definition.id == "example:ruby_block", "block keeps id example:ruby_block (got %s)" % (definition.id if definition != null else "null"))
			if phase == "missing":
				check(definition != null and definition.missing, "block is a missing-mod placeholder")
				world.set_block(pos + Vector3i(0, 0, 1), world.content.registries.blocks.get_runtime_id("blockyworld:stone"))
				game.session.save_game()
				game.set_mod_enabled("example_mod", true)
			else:
				check(definition != null and not definition.missing, "block is the real ruby block again")
				check(world.get_block_definition(pos + Vector3i(0, 0, 1)).id == "blockyworld:stone", "edit made while the mod was missing kept")
				if _failures.is_empty():
					game.session.close_session()
					SaveManager.delete_world(directory)
					DirAccess.remove_absolute(POS_PATH)
	if game.session != null:
		game.session.close_session()
	print("MISSING-MOD %s: %s (%d failure(s))" % [phase, "PASSED" if _failures.is_empty() else "FAILED", _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	print("  %s %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures.append(label)


func _wait(condition: Callable, label: String) -> void:
	var deadline := Time.get_ticks_msec() + int(TIMEOUT_SEC * 1000)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			check(false, "timed out waiting for " + label)
			return
		await process_frame
