extends SceneTree
## End-to-end check of the 0.1 milestone gate, driving the real game.
##
##   godot --path . -s res://tests/smoke/milestone_smoke.gd -- --phase=create
##   godot --path . -s res://tests/smoke/milestone_smoke.gd -- --phase=verify
##
## "create" makes a fresh world, walks, jumps, breaks and places blocks
## (including example_mod's block), crosses chunk borders, then saves and
## quits. "verify" (a new process) reopens the world and checks that every
## edit and the player state persisted, then deletes the test world (pass
## --keep to inspect it). Add --shots=<dir> under a display to save
## screenshots. Exit code 0 = pass.

const WORLD_NAME := "Smoke Test (automated)"
const STATE_PATH := "user://smoke_state.json"
const TIMEOUT_SEC := 90.0

var _phase := "create"
var _shots_dir := ""
var _failures: PackedStringArray = PackedStringArray()
var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--phase="):
				_phase = arg.substr(8)
			elif arg.begins_with("--shots="):
				_shots_dir = arg.substr(8)
		_run.call_deferred()
	return false


func _run() -> void:
	var game: Node = root.get_node("Game")
	await _wait(func() -> bool: return game.content != null, "content boot")
	check(game.content.registries.blocks.has("example:ruby_block"), "example_mod block is registered")
	check(game.content.registries.items.has("example:ruby"), "example_mod item is registered")
	if _phase == "create":
		await _phase_create(game)
	else:
		await _phase_verify(game)
	_finish(game)


func _phase_create(game: Node) -> void:
	for world in SaveManager.list_worlds():
		if world.name == WORLD_NAME:
			SaveManager.delete_world(world.directory)
	var created: Dictionary = game.create_world(WORLD_NAME, "424242", GameConfig.DEFAULT_GENERATOR, false)
	check(created.save != null, "world created")
	if created.save == null:
		return
	game.start_session(created.save)
	await _wait(func() -> bool: return game.session != null and game.session.is_playing, "spawn area ready")
	var session = game.session
	var player: Player = session.player
	var world: World = session.world
	await _frames(10)
	await _shot("01_spawn")
	check(player.is_on_floor(), "player stands on the ground after spawn")

	# Walk
	var start := player.global_position
	Input.action_press(InputActions.MOVE_FORWARD)
	await _seconds(1.5)
	Input.action_release(InputActions.MOVE_FORWARD)
	await _seconds(0.3)
	var walked := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	check(walked > 2.0 or player.is_on_wall(), "player walks (moved %.2f blocks)" % walked)
	check(player.global_position.y > 2.0, "player did not fall through the world")

	# Jump
	await _wait(func() -> bool: return player.is_on_floor(), "landed before jump")
	var ground_y := player.global_position.y
	Input.action_press(InputActions.JUMP)
	await _frames(3)
	Input.action_release(InputActions.JUMP)
	var peak := ground_y
	for i in 30:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
	check(peak > ground_y + 0.8, "player jumps (rose %.2f)" % (peak - ground_y))
	await _wait(func() -> bool: return player.is_on_floor(), "landed after jump")

	# Look down and break the block under the player's feet
	player.head.rotation.x = deg_to_rad(-89.0)
	await _frames(3)
	var target := player.interaction.target
	check(target != null, "raycast finds a block below")
	if target == null:
		return
	var broken_pos := target.position
	var broken_def := world.get_block_definition(broken_pos)
	var before_items := player.inventory.count_item(broken_def.drops[0].item if not broken_def.drops.is_empty() else broken_def.id)
	check(player.interaction.break_target(), "break_target succeeds on %s" % broken_def.id)
	check(world.get_block(broken_pos) == BlockRegistry.AIR, "broken block is air")
	var drop_id: String = broken_def.drops[0].item if not broken_def.drops.is_empty() else broken_def.id
	check(player.inventory.count_item(drop_id) > before_items, "drop %s added to inventory" % drop_id)
	await _wait(func() -> bool: return player.is_on_floor(), "fell into the hole")

	# Placement inside the player must be refused
	var feet := VoxelCoords.position_to_block(player.global_position)
	var stone := world.content.registries.blocks.get_runtime_id("blockyworld:stone")
	check(not world.place_block(feet, stone, player), "cannot place a block inside the player")

	# Hotbar selection + placing via interaction (stand on a fresh spot)
	player.head.rotation.x = deg_to_rad(-50.0)
	await _frames(3)
	player.select_slot(2)
	check(player.get_selected_stack() != null and player.get_selected_stack().item_id == "blockyworld:stone", "hotbar slot 3 holds stone")
	var placed_pos := Vector3i.ZERO
	var placed_ok := false
	if player.interaction.target != null:
		placed_pos = player.interaction.target.adjacent()
		var stack_before := player.get_selected_stack().amount
		placed_ok = player.interaction.try_place()
		check(placed_ok, "try_place places a block at %s" % placed_pos)
		if placed_ok:
			check(world.get_block(placed_pos) == stone, "placed block is stone")
			check(player.inventory.get_slot(2).amount == stack_before - 1, "placing consumes one item")
	else:
		check(false, "a block is targeted for placement")

	# example_mod block through the console
	var console_result: String = session.console.run("/give example:ruby_block 5")
	check(console_result.contains("Gave"), "/give example:ruby_block works (%s)" % console_result)
	var ruby_pos := VoxelCoords.position_to_block(player.global_position) + Vector3i(3, 1, 0)
	var ruby := world.content.registries.blocks.get_runtime_id("example:ruby_block")
	world.set_block(ruby_pos, BlockRegistry.AIR)
	check(world.place_block(ruby_pos, ruby, player), "example:ruby_block can be placed")
	session.console.run("/setblock %d %d %d example:ruby_block" % [ruby_pos.x, ruby_pos.y + 1, ruby_pos.z])
	check(world.get_block(ruby_pos + Vector3i(0, 1, 0)) == ruby, "/setblock with the mod block works")
	for command in ["/help", "/chunks", "/fps", "/pos", "/seed", "/assets", "/mods"]:
		var output: String = session.console.run(command)
		check(not output.is_empty() and not output.begins_with("Unknown"), "%s answers" % command)
	var spawned: String = session.console.run("/spawn blockyworld:test_dummy")
	check(spawned.begins_with("Spawned"), "/spawn test dummy (%s)" % spawned)

	# Hot reload keeps runtime ids and placed blocks valid
	var reload_result: String = session.console.run("/reload")
	check(reload_result.begins_with("Reloaded"), "/reload works (%s)" % reload_result)
	check(world.content.registries.blocks.get_runtime_id("example:ruby_block") == ruby, "runtime ids stable after reload")
	check(world.get_block(ruby_pos) == ruby, "placed mod block intact after reload")
	await _wait(func() -> bool: return world.chunks.stats().jobs == 0, "remesh after reload")

	player.head.rotation.x = 0.0
	player.rotation.y = 0.0
	await _frames(5)
	await _shot("02_edits")

	# Travel across chunk borders and let new chunks generate
	var start_chunk := VoxelCoords.position_to_chunk(player.global_position)
	var meshed_before: int = world.chunks.stats().meshed
	player.toggle_fly()
	player.global_position.y += 20.0
	Input.action_press(InputActions.MOVE_RIGHT)
	Input.action_press(InputActions.SPRINT)
	await _seconds(4.0)
	Input.action_release(InputActions.MOVE_RIGHT)
	Input.action_release(InputActions.SPRINT)
	var end_chunk := VoxelCoords.position_to_chunk(player.global_position)
	check(VoxelCoords.chunk_distance(start_chunk, end_chunk) >= 2, "crossed chunk borders (%s -> %s)" % [start_chunk, end_chunk])
	await _wait(func() -> bool: return world.chunks.is_area_ready(end_chunk, 1), "new chunks generated around %s" % end_chunk)
	check(world.chunks.stats().meshed > 0, "chunks meshed after travel (before %d)" % meshed_before)
	await _shot("03_travel")
	player.teleport(Vector3(ruby_pos) + Vector3(-2.5, 0.05, 0.5))
	player.toggle_fly()
	await _wait(func() -> bool: return not player.frozen, "back near edits")
	await _frames(10)

	var state := {
		"broken": [broken_pos.x, broken_pos.y, broken_pos.z],
		"placed": [placed_pos.x, placed_pos.y, placed_pos.z] if placed_ok else [],
		"ruby": [ruby_pos.x, ruby_pos.y, ruby_pos.z],
		"player": [player.global_position.x, player.global_position.y, player.global_position.z],
		"ruby_items": player.inventory.count_item("example:ruby_block"),
	}
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()
	session.save_game()


func _phase_verify(game: Node) -> void:
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	check(state is Dictionary, "state from the create phase exists")
	if not state is Dictionary:
		return
	var directory := ""
	for world in SaveManager.list_worlds():
		if world.name == WORLD_NAME:
			directory = world.directory
	check(not directory.is_empty(), "saved world is listed")
	if directory.is_empty():
		return
	var opened: Dictionary = game.open_world(directory)
	check(opened.save != null, "saved world opens")
	if opened.save == null:
		return
	game.start_session(opened.save)
	await _wait(func() -> bool: return game.session != null and game.session.is_playing, "spawn area ready on reload")
	var session = game.session
	var world: World = session.world
	var player: Player = session.player
	var saved_player: Vector3 = Vector3(state.player[0], state.player[1], state.player[2])
	check(player.global_position.distance_to(saved_player) < 1.0, "player position restored (%s vs %s)" % [player.global_position, saved_player])
	check(player.inventory.count_item("example:ruby_block") == int(state.ruby_items), "inventory restored")
	var broken := Vector3i(state.broken[0], state.broken[1], state.broken[2])
	check(world.get_block(broken) == BlockRegistry.AIR, "broken block is still air after reload")
	if not state.placed.is_empty():
		var placed := Vector3i(state.placed[0], state.placed[1], state.placed[2])
		check(world.get_block_definition(placed).id == "blockyworld:stone", "placed stone persisted")
	var ruby_pos := Vector3i(state.ruby[0], state.ruby[1], state.ruby[2])
	check(world.get_block_definition(ruby_pos).id == "example:ruby_block", "example:ruby_block persisted")
	check(world.get_block_definition(ruby_pos + Vector3i(0, 1, 0)).id == "example:ruby_block", "/setblock ruby persisted")
	await _frames(10)
	await _shot("04_reloaded")
	if _failures.is_empty() and not OS.get_cmdline_user_args().has("--keep"):
		game.session.close_session()
		SaveManager.delete_world(directory)
		DirAccess.remove_absolute(STATE_PATH)


func check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS ", label)
	else:
		print("  FAIL ", label)
		_failures.append(label)


func _finish(game: Node) -> void:
	Input.action_release(InputActions.MOVE_FORWARD)
	if game.session != null:
		game.session.close_session()
	print("SMOKE %s: %s (%d failure(s))" % [_phase, "PASSED" if _failures.is_empty() else "FAILED", _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _wait(condition: Callable, label: String) -> void:
	var deadline := Time.get_ticks_msec() + int(TIMEOUT_SEC * 1000)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			check(false, "timed out waiting for " + label)
			return
		await process_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	var image := root.get_texture().get_image()
	if image != null:
		DirAccess.make_dir_recursive_absolute(_shots_dir)
		image.save_png(_shots_dir.path_join(shot_name + ".png"))
