class_name ChunkStorage
extends RefCounted
## Reads and writes chunk files for one world: <world>/chunks/c.<x>.<z>.bwc.
## Only modified chunks are ever written; untouched chunks are regenerated
## from the seed.
##
## Thread-safety: queue_save() runs on the main thread and copies the block
## array. write_queued() and load_chunk() run on workers. A chunk waiting in
## the queue is served from memory by load_chunk(), so unloading and quickly
## reloading a chunk can never read a stale file. Writes are serialized.

const EXTENSION := "bwc"

var directory: String
var _mutex := Mutex.new()
var _write_mutex := Mutex.new()
var _pending: Dictionary = {}
var _serial := 0


func _init(chunks_directory: String) -> void:
	directory = chunks_directory
	DirAccess.make_dir_recursive_absolute(directory)


func path_for(chunk_position: Vector2i) -> String:
	return directory.path_join("c.%d.%d.%s" % [chunk_position.x, chunk_position.y, EXTENSION])


func has_chunk(chunk_position: Vector2i) -> bool:
	_mutex.lock()
	var pending := _pending.has(chunk_position)
	_mutex.unlock()
	return pending or SafeFile.exists(path_for(chunk_position))


## Main thread. Snapshots the chunk; returns a serial for write_queued().
func queue_save(data: ChunkData, runtime_to_world: PackedInt32Array) -> int:
	_mutex.lock()
	_serial += 1
	var serial := _serial
	_pending[data.position] = {"blocks": data.blocks.duplicate(), "palette": runtime_to_world, "serial": serial}
	_mutex.unlock()
	return serial


## Worker thread (or main thread on shutdown). Writes the queued snapshot if
## no newer save of the same chunk superseded it.
func write_queued(chunk_position: Vector2i, serial: int) -> Error:
	_write_mutex.lock()
	_mutex.lock()
	var entry: Dictionary = _pending.get(chunk_position, {})
	_mutex.unlock()
	if entry.is_empty() or entry.serial != serial:
		_write_mutex.unlock()
		return OK
	var bytes := ChunkSerializer.encode(chunk_position, entry.blocks, entry.palette)
	var err := SafeFile.write_bytes(path_for(chunk_position), bytes)
	if err != OK:
		Log.error("SAVE", "Failed to write chunk %s to %s (error %d)" % [chunk_position, path_for(chunk_position), err])
	_mutex.lock()
	if _pending.has(chunk_position) and _pending[chunk_position].serial == serial:
		_pending.erase(chunk_position)
	_mutex.unlock()
	_write_mutex.unlock()
	return err


## Worker thread. Returns the stored chunk, or null when it was never saved.
## Corrupt files are renamed to *.corrupt (kept for recovery) and reported,
## then the chunk is regenerated.
func load_chunk(chunk_position: Vector2i, world_to_runtime: PackedInt32Array) -> ChunkData:
	_mutex.lock()
	var entry: Dictionary = _pending.get(chunk_position, {})
	_mutex.unlock()
	if not entry.is_empty():
		var cached := ChunkData.new(chunk_position)
		cached.blocks = (entry.blocks as PackedInt32Array).duplicate()
		cached.recount_sections()
		cached.modified = true
		return cached
	var path := path_for(chunk_position)
	if not SafeFile.exists(path):
		return null
	var decoded := ChunkSerializer.decode(SafeFile.read_bytes(path), world_to_runtime)
	if not decoded.ok:
		var backup := path + ".corrupt"
		DirAccess.rename_absolute(path, backup)
		Log.error("SAVE", "Chunk %s is unreadable (%s). Moved to %s and regenerating." % [chunk_position, decoded.error, backup])
		return null
	if decoded.position != chunk_position:
		Log.error("SAVE", "Chunk file %s claims position %s; regenerating" % [path, decoded.position])
		return null
	var data := ChunkData.new(chunk_position)
	data.blocks = decoded.blocks
	data.recount_sections()
	return data


func pending_count() -> int:
	_mutex.lock()
	var count := _pending.size()
	_mutex.unlock()
	return count
