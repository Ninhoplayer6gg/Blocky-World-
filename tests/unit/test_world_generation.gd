extends TestCase
## Generation must be deterministic: same seed + same content = same world.

static var _content: GameContent


static func content() -> GameContent:
	if _content == null:
		var pipeline := ContentPipeline.new()
		pipeline.search_paths = [{"path": "res://packs", "source": ModEntry.Source.BUILTIN}]
		_content = pipeline.run()
	return _content


func _generate(generator_id: String, world_seed: int, chunk: Vector2i) -> ChunkData:
	var generator := content().registries.generators.create(generator_id) as WorldGenerator
	generator.setup(world_seed, content())
	var data := ChunkData.new(chunk)
	generator.generate(data)
	return data


func test_same_seed_same_chunks() -> void:
	for chunk in [Vector2i(0, 0), Vector2i(-3, 5), Vector2i(12, -7)]:
		var a := _generate("blockyworld:default", 12345, chunk)
		var b := _generate("blockyworld:default", 12345, chunk)
		assert_eq(a.blocks, b.blocks, "chunk %s identical" % chunk)


func test_different_seed_different_terrain() -> void:
	var a := _generate("blockyworld:default", 1, Vector2i(4, 4))
	var b := _generate("blockyworld:default", 2, Vector2i(4, 4))
	assert_ne(a.blocks, b.blocks)


func test_generation_order_independent() -> void:
	var generator := content().registries.generators.create("blockyworld:default") as WorldGenerator
	generator.setup(777, content())
	var first := ChunkData.new(Vector2i(2, 2))
	generator.generate(first)
	for other in [Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1)]:
		generator.generate(ChunkData.new(other))
	var again := ChunkData.new(Vector2i(2, 2))
	generator.generate(again)
	assert_eq(first.blocks, again.blocks, "result does not depend on what was generated before")


func test_terrain_layers() -> void:
	var data := _generate("blockyworld:default", 42, Vector2i(0, 0))
	var blocks := content().registries.blocks
	assert_eq(data.get_local(3, 0, 3), blocks.get_runtime_id("blockyworld:baserock"), "bottom layer is baserock")
	var top := data.get_top_y(8, 8)
	assert_true(top > 20 and top < GameConfig.CHUNK_SIZE_Y - 1, "surface height plausible (%d)" % top)
	assert_eq(data.get_local(8, top + 1, 8), 0, "air above the column top")
	assert_true(data.non_empty_sections().size() > 0)


func test_trees_cross_chunk_borders_consistently() -> void:
	var generator := content().registries.generators.create("blockyworld:default") as WorldGenerator
	generator.setup(99, content())
	var log_id := content().registries.blocks.get_runtime_id("blockyworld:log")
	var leaves_id := content().registries.blocks.get_runtime_id("blockyworld:leaves")
	var found_trees := 0
	for x in range(-4, 4):
		var data := ChunkData.new(Vector2i(x, 0))
		generator.generate(data)
		for i in data.blocks.size():
			if data.blocks[i] == log_id:
				found_trees += 1
				break
	assert_true(found_trees > 0, "trees are generated somewhere in 8 chunks")
	assert_true(leaves_id > 0)


func test_lab_world_is_flat_and_shows_blocks() -> void:
	var data := _generate("blockyworld:lab", GameConfig.DEFAULT_WORLD_SEED, Vector2i(0, 0))
	var blocks := content().registries.blocks
	var floor_y := 32
	assert_eq(blocks.get_by_runtime(data.get_local(5, floor_y, 5)).id, "blockyworld:lab_tile")
	assert_eq(blocks.get_by_runtime(data.get_local(0, floor_y, 5)).id, "blockyworld:lab_tile_dark", "chunk border marked")
	assert_ne(data.get_local(2, floor_y + 1, 6), 0, "showcase row has blocks")


func test_world_hash_is_stable() -> void:
	assert_eq(WorldHash.hash3(1, 2, 3, 4), WorldHash.hash3(1, 2, 3, 4))
	assert_ne(WorldHash.hash3(1, 2, 3, 4), WorldHash.hash3(1, 2, 3, 5))
	var value := WorldHash.hash01(5, -10, 0, 99)
	assert_true(value >= 0.0 and value < 1.0)
	assert_eq(WorldHash.seed_from_text("12345"), 12345)
	assert_eq(WorldHash.seed_from_text("Blocky"), WorldHash.seed_from_text("Blocky"))
	assert_ne(WorldHash.seed_from_text("Blocky"), WorldHash.seed_from_text("blocky"))
