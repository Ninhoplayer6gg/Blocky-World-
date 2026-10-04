extends TestCase


func _identity(size: int) -> PackedInt32Array:
	var palette := PackedInt32Array()
	for i in size:
		palette.append(i)
	return palette


func _sample_chunk() -> ChunkData:
	var data := ChunkData.new(Vector2i(-4, 7))
	var blocks := data.blocks
	for i in GameConfig.CHUNK_LAYER * 40:
		blocks[i] = 1 + (i % 3 if i > GameConfig.CHUNK_LAYER * 30 else 0)
	data.set_local(5, 90, 5, 4)
	data.recount_sections()
	return data


func test_roundtrip_preserves_blocks() -> void:
	var data := _sample_chunk()
	var bytes := ChunkSerializer.encode(data.position, data.blocks, _identity(8))
	var decoded := ChunkSerializer.decode(bytes, _identity(8))
	assert_true(decoded.ok, decoded.error)
	assert_eq(decoded.position, Vector2i(-4, 7))
	assert_eq(decoded.blocks, data.blocks, "blocks identical after round trip")
	assert_true(bytes.size() < 20000, "compressed size reasonable (%d bytes)" % bytes.size())


func test_palette_remaps_ids() -> void:
	var data := ChunkData.new(Vector2i(0, 0))
	data.set_local(0, 0, 0, 2)
	# runtime 2 is stored as world id 5; on load world id 5 becomes runtime 3.
	var runtime_to_world := PackedInt32Array([0, 1, 5])
	var world_to_runtime := PackedInt32Array([0, 1, 0, 0, 0, 3])
	var decoded := ChunkSerializer.decode(ChunkSerializer.encode(data.position, data.blocks, runtime_to_world), world_to_runtime)
	assert_true(decoded.ok, decoded.error)
	assert_eq(decoded.blocks[0], 3)


func test_rejects_corrupt_data() -> void:
	var data := _sample_chunk()
	var bytes := ChunkSerializer.encode(data.position, data.blocks, _identity(8))
	assert_false(ChunkSerializer.decode(PackedByteArray([1, 2, 3]), _identity(8)).ok, "too small")
	var bad_magic := bytes.duplicate()
	bad_magic[0] = 88
	assert_contains(ChunkSerializer.decode(bad_magic, _identity(8)).error, "magic")
	var truncated := bytes.slice(0, bytes.size() - 10)
	assert_false(ChunkSerializer.decode(truncated, _identity(8)).ok, "truncated")
	var flipped := bytes.duplicate()
	flipped[flipped.size() - 5] = flipped[flipped.size() - 5] ^ 0xFF
	assert_false(ChunkSerializer.decode(flipped, _identity(8)).ok, "corrupted payload detected")
	assert_contains(ChunkSerializer.decode(bytes, _identity(2)).error, "out of range")


func test_storage_save_load_and_pending_reads() -> void:
	var storage := ChunkStorage.new(temp_dir("chunks"))
	var data := _sample_chunk()
	var palette := _identity(8)
	assert_false(storage.has_chunk(data.position))
	var serial := storage.queue_save(data, palette)
	data.set_local(0, 0, 0, 7)
	var pending := storage.load_chunk(data.position, palette)
	assert_ne(pending.get_local(0, 0, 0), 7, "queued snapshot is independent of later edits")
	assert_eq(storage.write_queued(data.position, serial), OK)
	assert_eq(storage.pending_count(), 0)
	var loaded := storage.load_chunk(data.position, palette)
	assert_not_null(loaded)
	assert_eq(loaded.get_local(5, 90, 5), 4)
	assert_eq(loaded.section_counts, _sample_chunk().section_counts, "section counts rebuilt")
	assert_null(storage.load_chunk(Vector2i(99, 99), palette), "unsaved chunk -> null (generate)")


func test_superseded_save_is_skipped() -> void:
	var storage := ChunkStorage.new(temp_dir("chunks_superseded"))
	var data := ChunkData.new(Vector2i(1, 1))
	var palette := _identity(4)
	data.set_local(0, 0, 0, 1)
	var old_serial := storage.queue_save(data, palette)
	data.set_local(0, 0, 0, 2)
	var new_serial := storage.queue_save(data, palette)
	storage.write_queued(data.position, new_serial)
	storage.write_queued(data.position, old_serial)
	assert_eq(storage.load_chunk(data.position, palette).get_local(0, 0, 0), 2, "older save never overwrites newer")


func test_corrupt_file_is_quarantined() -> void:
	var dir := temp_dir("chunks_corrupt")
	var storage := ChunkStorage.new(dir)
	write_file(storage.path_for(Vector2i(3, 3)), "garbage that is long enough to pass size checks....")
	Log.muted = true
	assert_null(storage.load_chunk(Vector2i(3, 3), _identity(2)))
	assert_true(FileAccess.file_exists(storage.path_for(Vector2i(3, 3)) + ".corrupt"), "bad file kept for recovery")
