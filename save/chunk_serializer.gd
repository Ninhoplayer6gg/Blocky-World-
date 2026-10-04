class_name ChunkSerializer
extends RefCounted
## Binary chunk format (little endian). See docs/SaveFormat.md.
##
##   "BWCK"            magic
##   u16 format        FORMAT_VERSION
##   i32 cx, i32 cz    chunk coordinates
##   u16 sx, sy, sz    dimensions the chunk was saved with
##   u8  compression   1 = zstd
##   u32 raw_size      size of the uncompressed payload
##   u32 data_size     size of the compressed payload
##   payload: u32 run_count, then run_count * (u16 length, u16 world_block_id)
##
## Block ids are *world palette* ids (world.json "block_palette"), never
## runtime ids, so saves survive mods being added, removed or reordered.

const MAGIC := "BWCK"
const FORMAT_VERSION := 1
const COMPRESSION_ZSTD := 1
const MAX_RUN := 65535


static func encode(chunk_position: Vector2i, blocks: PackedInt32Array, runtime_to_world: PackedInt32Array) -> PackedByteArray:
	var payload := StreamPeerBuffer.new()
	payload.put_u32(0)
	var count := blocks.size()
	var mapped := runtime_to_world.size()
	var runs := 0
	var i := 0
	while i < count:
		var value := blocks[i]
		var j := i + 1
		while j < count and blocks[j] == value and j - i < MAX_RUN:
			j += 1
		var world_id := runtime_to_world[value] if value >= 0 and value < mapped else -1
		if world_id < 0:
			Log.error("SAVE", "Chunk %s contains runtime block %d without a palette entry; saved as air" % [chunk_position, value])
			world_id = 0
		payload.put_u16(j - i)
		payload.put_u16(world_id)
		runs += 1
		i = j
	payload.seek(0)
	payload.put_u32(runs)
	var raw := payload.data_array
	var compressed := raw.compress(FileAccess.COMPRESSION_ZSTD)

	var out := StreamPeerBuffer.new()
	out.put_data(MAGIC.to_ascii_buffer())
	out.put_u16(FORMAT_VERSION)
	out.put_32(chunk_position.x)
	out.put_32(chunk_position.y)
	out.put_u16(GameConfig.CHUNK_SIZE_X)
	out.put_u16(GameConfig.CHUNK_SIZE_Y)
	out.put_u16(GameConfig.CHUNK_SIZE_Z)
	out.put_u8(COMPRESSION_ZSTD)
	out.put_u32(raw.size())
	out.put_u32(compressed.size())
	out.put_data(compressed)
	return out.data_array


## Returns {"ok": bool, "error": String, "position": Vector2i, "blocks": PackedInt32Array}.
static func decode(bytes: PackedByteArray, world_to_runtime: PackedInt32Array) -> Dictionary:
	var result := {"ok": false, "error": "", "position": Vector2i.ZERO, "blocks": PackedInt32Array()}
	if bytes.size() < 27:
		result.error = "file too small (%d bytes)" % bytes.size()
		return result
	var reader := StreamPeerBuffer.new()
	reader.data_array = bytes
	var magic := reader.get_data(4)[1] as PackedByteArray
	if magic.get_string_from_ascii() != MAGIC:
		result.error = "not a chunk file (bad magic)"
		return result
	var version := reader.get_u16()
	if version > FORMAT_VERSION:
		result.error = "chunk format %d is newer than supported %d" % [version, FORMAT_VERSION]
		return result
	result.position = Vector2i(reader.get_32(), reader.get_32())
	var sx := reader.get_u16()
	var sy := reader.get_u16()
	var sz := reader.get_u16()
	if sx != GameConfig.CHUNK_SIZE_X or sy != GameConfig.CHUNK_SIZE_Y or sz != GameConfig.CHUNK_SIZE_Z:
		result.error = "chunk size %dx%dx%d does not match %dx%dx%d" % [sx, sy, sz,
			GameConfig.CHUNK_SIZE_X, GameConfig.CHUNK_SIZE_Y, GameConfig.CHUNK_SIZE_Z]
		return result
	var compression := reader.get_u8()
	if compression != COMPRESSION_ZSTD:
		result.error = "unknown compression %d" % compression
		return result
	var raw_size := reader.get_u32()
	var data_size := reader.get_u32()
	if data_size > reader.get_available_bytes():
		result.error = "truncated payload (%d of %d bytes)" % [reader.get_available_bytes(), data_size]
		return result
	var compressed := reader.get_data(data_size)[1] as PackedByteArray
	var raw := compressed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		result.error = "payload failed to decompress"
		return result

	var payload := StreamPeerBuffer.new()
	payload.data_array = raw
	var runs := payload.get_u32()
	if runs * 4 + 4 != raw_size:
		result.error = "payload size does not match run count"
		return result
	var blocks := PackedInt32Array()
	blocks.resize(GameConfig.CHUNK_VOLUME)
	var palette_size := world_to_runtime.size()
	var index := 0
	for r in runs:
		var length := payload.get_u16()
		var world_id := payload.get_u16()
		if world_id >= palette_size:
			result.error = "block palette id %d out of range (%d entries)" % [world_id, palette_size]
			return result
		if index + length > GameConfig.CHUNK_VOLUME:
			result.error = "runs exceed chunk volume"
			return result
		var runtime_id := world_to_runtime[world_id]
		if runtime_id != 0:
			for k in length:
				blocks[index + k] = runtime_id
		index += length
	if index != GameConfig.CHUNK_VOLUME:
		result.error = "runs cover %d of %d blocks" % [index, GameConfig.CHUNK_VOLUME]
		return result
	result.blocks = blocks
	result.ok = true
	return result
