extends TestCase
## World metadata, palette binding (incl. missing mods) and migrations.


func _registry(ids: Array) -> BlockRegistry:
	var blocks := BlockRegistry.new()
	for id in ids:
		var block := BlockDefinition.new()
		block.id = id
		blocks.register(block)
	return blocks


func _content_with(blocks_ids: Array) -> GameContent:
	var content := GameContent.new()
	content.registries.blocks = _registry(blocks_ids)
	return content


func test_create_save_and_open() -> void:
	var dir := temp_dir("world_a")
	var content := _content_with(["blockyworld:stone"])
	var save := WorldSave.create(dir, "My World", 987654321, "blockyworld:default", 1, [{"id": "example_mod", "version": "0.1.0"}], false)
	save.bind_blocks(content.registries.blocks)
	assert_eq(save.save_metadata(content), OK)
	var opened := WorldSave.open(dir)
	assert_eq(opened.error, "")
	var loaded: WorldSave = opened.save
	assert_eq(loaded.get_name(), "My World")
	assert_eq(loaded.get_seed(), 987654321)
	assert_eq(loaded.get_generator(), "blockyworld:default")
	assert_eq(int(loaded.metadata.save_version), GameInfo.SAVE_VERSION)
	assert_eq(loaded.metadata.game_version, GameInfo.GAME_VERSION)
	assert_eq(loaded.palette[0], BlockRegistry.AIR_ID)
	assert_contains(loaded.palette, "blockyworld:stone")
	assert_contains(str(loaded.metadata.mods), "example_mod", "missing mods stay listed")


func test_palette_survives_registration_order_changes() -> void:
	var dir := temp_dir("world_b")
	var first := _content_with(["a:one", "b:two"])
	var save := WorldSave.create(dir, "Order", 1, "blockyworld:default", 1, [], false)
	save.bind_blocks(first.registries.blocks)
	var data := ChunkData.new(Vector2i(0, 0))
	data.set_local(0, 0, 0, first.registries.blocks.get_runtime_id("b:two"))
	save.storage.write_queued(data.position, save.storage.queue_save(data, save.runtime_to_world))
	save.save_metadata(first)
	# Same blocks registered in another order: runtime ids differ.
	var second := _content_with(["b:two", "a:one"])
	var reopened: WorldSave = WorldSave.open(dir).save
	reopened.bind_blocks(second.registries.blocks)
	var loaded := reopened.storage.load_chunk(Vector2i(0, 0), reopened.world_to_runtime)
	assert_eq(second.registries.blocks.get_by_runtime(loaded.get_local(0, 0, 0)).id, "b:two")


func test_missing_mod_blocks_are_preserved() -> void:
	var dir := temp_dir("world_c")
	var with_mod := _content_with(["blockyworld:stone", "gem:ruby"])
	var save := WorldSave.create(dir, "Mods", 1, "blockyworld:default", 1, [{"id": "gem", "version": "1.0.0"}], false)
	save.bind_blocks(with_mod.registries.blocks)
	var data := ChunkData.new(Vector2i(0, 0))
	data.set_local(1, 1, 1, with_mod.registries.blocks.get_runtime_id("gem:ruby"))
	save.storage.write_queued(data.position, save.storage.queue_save(data, save.runtime_to_world))
	save.save_metadata(with_mod)

	Log.muted = true
	var without_mod := _content_with(["blockyworld:stone"])
	var reopened: WorldSave = WorldSave.open(dir).save
	reopened.bind_blocks(without_mod.registries.blocks)
	assert_eq(reopened.missing_blocks, PackedStringArray(["gem:ruby"]))
	var placeholder := without_mod.registries.blocks.get_block("gem:ruby")
	assert_true(placeholder != null and placeholder.missing, "placeholder created")
	var loaded := reopened.storage.load_chunk(Vector2i(0, 0), reopened.world_to_runtime)
	assert_eq(loaded.get_local(1, 1, 1), placeholder.runtime_id)
	# Saving again keeps the original id.
	reopened.storage.write_queued(loaded.position, reopened.storage.queue_save(loaded, reopened.runtime_to_world))
	reopened.save_metadata(without_mod)
	var again := _content_with(["blockyworld:stone", "gem:ruby"])
	var restored: WorldSave = WorldSave.open(dir).save
	restored.bind_blocks(again.registries.blocks)
	var final_data := restored.storage.load_chunk(Vector2i(0, 0), restored.world_to_runtime)
	assert_eq(again.registries.blocks.get_by_runtime(final_data.get_local(1, 1, 1)).id, "gem:ruby", "block restored when the mod returns")
	assert_eq(restored.find_missing_mods(again).size(), 1, "mod list still mentions gem (content has no mod entries)")


func test_newer_and_corrupt_saves_are_refused() -> void:
	var dir := temp_dir("world_d")
	write_file(dir.path_join("world.json"), JSON.stringify({"format": WorldSave.FORMAT, "save_version": GameInfo.SAVE_VERSION + 1, "block_palette": ["blockyworld:air"]}))
	assert_contains(WorldSave.open(dir).error, "newer")
	write_file(dir.path_join("world.json"), "{ broken")
	assert_contains(WorldSave.open(dir).error, "line")
	write_file(dir.path_join("world.json"), JSON.stringify({"format": "something_else"}))
	assert_contains(WorldSave.open(dir).error, "not a Blocky World save")


func test_save_manager_folders_and_delete() -> void:
	var root := temp_dir("saves_root")
	assert_eq(SaveManager.make_folder_name("My Cool World!", root), "my_cool_world")
	DirAccess.make_dir_recursive_absolute(root.path_join("my_cool_world"))
	assert_eq(SaveManager.make_folder_name("My Cool World!", root), "my_cool_world_2")
	assert_eq(SaveManager.make_folder_name("???", root), "world")
	write_file(root.path_join("my_cool_world/chunks/c.0.0.bwc"), "x")
	assert_eq(SaveManager.delete_world(root.path_join("my_cool_world"), root), OK)
	assert_false(DirAccess.dir_exists_absolute(root.path_join("my_cool_world")))
	Log.muted = true
	assert_eq(SaveManager.delete_world("user://elsewhere", root), ERR_UNAUTHORIZED, "refuses paths outside saves")


func test_safe_file_recovers_tmp() -> void:
	var dir := temp_dir("safe")
	var path := dir.path_join("data.json")
	assert_eq(SafeFile.write_text(path, "one"), OK)
	assert_eq(SafeFile.write_text(path, "two"), OK)
	assert_eq(SafeFile.read_text(path), "two", "overwrite works")
	DirAccess.rename_absolute(path, path + SafeFile.TMP_SUFFIX)
	assert_eq(SafeFile.read_text(path), "two", "falls back to leftover .tmp")
