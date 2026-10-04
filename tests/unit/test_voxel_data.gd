extends TestCase


func test_block_to_chunk_handles_negatives() -> void:
	assert_eq(VoxelCoords.block_to_chunk(Vector3i(0, 10, 0)), Vector2i(0, 0))
	assert_eq(VoxelCoords.block_to_chunk(Vector3i(15, 0, 15)), Vector2i(0, 0))
	assert_eq(VoxelCoords.block_to_chunk(Vector3i(16, 0, -1)), Vector2i(1, -1))
	assert_eq(VoxelCoords.block_to_chunk(Vector3i(-16, 0, -17)), Vector2i(-1, -2))
	assert_eq(VoxelCoords.block_to_local(Vector3i(-1, 5, -16)), Vector3i(15, 5, 0))


func test_local_world_roundtrip() -> void:
	for block in [Vector3i(-33, 7, 50), Vector3i(0, 0, 0), Vector3i(-1, 127, -1), Vector3i(1000, 64, -999)]:
		var chunk := VoxelCoords.block_to_chunk(block)
		var local := VoxelCoords.block_to_local(block)
		assert_eq(VoxelCoords.local_to_block(chunk, local), block, "roundtrip %s" % block)


func test_position_to_block_floors() -> void:
	assert_eq(VoxelCoords.position_to_block(Vector3(-0.1, 1.9, 0.0)), Vector3i(-1, 1, 0))
	assert_eq(VoxelCoords.position_to_chunk(Vector3(-0.5, 0, 16.2)), Vector2i(-1, 1))


func test_index_roundtrip_and_distance() -> void:
	for local in [Vector3i(0, 0, 0), Vector3i(15, 127, 15), Vector3i(3, 40, 9)]:
		assert_eq(VoxelCoords.index_to_local(VoxelCoords.local_index(local.x, local.y, local.z)), local)
	assert_eq(VoxelCoords.chunk_distance(Vector2i(0, 0), Vector2i(-3, 2)), 3)


func test_config_is_consistent() -> void:
	assert_eq(GameConfig.SECTION_COUNT * GameConfig.SECTION_HEIGHT, GameConfig.CHUNK_SIZE_Y, "sections cover the column")
	assert_eq(GameConfig.CHUNK_VOLUME, GameConfig.CHUNK_SIZE_X * GameConfig.CHUNK_SIZE_Y * GameConfig.CHUNK_SIZE_Z)


func test_chunk_data_get_set_and_counts() -> void:
	var data := ChunkData.new(Vector2i(2, -3))
	assert_eq(data.get_local(1, 2, 3), 0)
	assert_eq(data.set_local(1, 2, 3, 5), 0, "returns previous id")
	assert_eq(data.get_local(1, 2, 3), 5)
	assert_eq(data.section_counts[0], 1)
	data.set_local(1, 20, 3, 7)
	assert_eq(data.non_empty_sections(), PackedInt32Array([0, 1]))
	data.set_local(1, 2, 3, 0)
	assert_true(data.is_section_empty(0))
	assert_eq(data.get_local(0, -1, 0), 0, "below world is air")
	assert_eq(data.get_local(0, 500, 0), 0, "above world is air")
	assert_eq(data.set_local(0, 500, 0, 3), 0, "out of range writes ignored")
	assert_eq(data.get_top_y(1, 3), 20)


func test_recount_after_bulk_writes() -> void:
	var data := ChunkData.new()
	var blocks := data.blocks
	for i in GameConfig.CHUNK_LAYER * 3:
		blocks[i] = 1
	data.recount_sections()
	assert_eq(data.section_counts[0], GameConfig.CHUNK_LAYER * 3)
	assert_eq(data.section_counts[1], 0)


func test_snapshot_reads_neighbours() -> void:
	var center := ChunkData.new(Vector2i(0, 0))
	var east := ChunkData.new(Vector2i(1, 0))
	east.set_local(0, 10, 4, 9)
	var neighbours: Array = []
	neighbours.resize(9)
	neighbours[5] = east
	var snapshot := ChunkSnapshot.capture(center, neighbours, 0, 32)
	assert_eq(snapshot.get_block(16, 10, 4), 9, "x = 16 reads the east neighbour")
	assert_eq(snapshot.get_block(-1, 10, 4), 0, "missing neighbour reads as air")
	east.set_local(0, 10, 4, 2)
	assert_eq(snapshot.get_block(16, 10, 4), 9, "snapshot is a copy")
