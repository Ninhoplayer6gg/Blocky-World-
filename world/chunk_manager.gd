class_name ChunkManager
extends RefCounted
## Streams chunks around a focus point.
##
## Pipeline per chunk:
##   queued -> [worker] load from disk or generate -> data on main thread
##   -> (all 8 neighbours have data) -> [worker] mesh sections from a
##   ChunkSnapshot -> [main] upload meshes + collision within a time budget.
##
## Data is kept for render_distance + 1 (the outer ring feeds culling/AO of
## the meshed area); chunks beyond that + UNLOAD_MARGIN are saved if modified
## and freed. Workers never touch nodes; they only receive copies.

signal chunk_loaded(chunk_position: Vector2i)
signal chunk_unloaded(chunk_position: Vector2i)

class ChunkEntry:
	extends RefCounted
	var position: Vector2i
	var data: ChunkData
	var node: ChunkNode
	var epoch := 0
	var load_submitted := false
	var mesh_queued := false
	var initial_mesh_pending := false
	var meshed := false
	## Latest requested / applied mesh revision per section.
	var requested := PackedInt32Array()
	var applied := PackedInt32Array()

	func _init(chunk_position: Vector2i, chunk_epoch: int) -> void:
		position = chunk_position
		epoch = chunk_epoch
		requested.resize(GameConfig.SECTION_COUNT)
		applied.resize(GameConfig.SECTION_COUNT)
		applied.fill(-1)

const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var render_distance := GameConfig.DEFAULT_RENDER_DISTANCE
var max_jobs := clampi(OS.get_processor_count() - 1, 1, GameConfig.MAX_CHUNK_JOBS)

var _parent: Node3D
var _content: GameContent
var _generator: WorldGenerator
var _save: WorldSave
var _jobs := JobRunner.new()
var _mesher := ChunkMesher.new()
var _chunks: Dictionary = {}
var _load_queue: Array[Vector2i] = []
var _mesh_queue: Array[Vector2i] = []
var _results: Array = []
var _results_mutex := Mutex.new()
var _backlog: Array = []
var _center := Vector2i(2147483647, 2147483647)
var _needs_recenter := true
var _epoch := 0
var _in_flight := 0
var _shutting_down := false


func _init(parent: Node3D, content: GameContent, generator: WorldGenerator, save: WorldSave) -> void:
	_parent = parent
	_content = content
	_generator = generator
	_save = save


## Main thread, once per frame.
func update(focus: Vector3) -> void:
	_jobs.poll()
	var center := VoxelCoords.position_to_chunk(focus)
	if center != _center or _needs_recenter:
		_center = center
		_needs_recenter = false
		_recenter()
	_collect_results()
	_integrate(Time.get_ticks_usec() + GameConfig.MAIN_THREAD_BUDGET_USEC)
	_dispatch()


func set_render_distance(distance: int) -> void:
	render_distance = clampi(distance, 1, 32)
	_needs_recenter = true


## New chunks use `generator`; already loaded chunks are kept as they are.
func set_generator(generator: WorldGenerator) -> void:
	_generator = generator


func get_chunk_data(chunk_position: Vector2i) -> ChunkData:
	var entry: ChunkEntry = _chunks.get(chunk_position)
	return entry.data if entry != null else null


func is_meshed(chunk_position: Vector2i) -> bool:
	var entry: ChunkEntry = _chunks.get(chunk_position)
	return entry != null and entry.meshed


## True when every chunk within `radius` of `center` has its meshes/collision.
func is_area_ready(center: Vector2i, radius: int) -> bool:
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if not is_meshed(center + Vector2i(dx, dz)):
				return false
	return true


## Schedules remeshing after a block change at `block` (main thread).
func notify_block_changed(block: Vector3i) -> void:
	var local := VoxelCoords.block_to_local(block)
	var chunk := VoxelCoords.block_to_chunk(block)
	var section := VoxelCoords.section_of(block.y)
	var sections := PackedInt32Array([section])
	var in_section := block.y - section * GameConfig.SECTION_HEIGHT
	if in_section == 0 and section > 0:
		sections.append(section - 1)
	if in_section == GameConfig.SECTION_HEIGHT - 1 and section < GameConfig.SECTION_COUNT - 1:
		sections.append(section + 1)
	for offset in NEIGHBOUR_OFFSETS:
		if offset.x == -1 and local.x != 0:
			continue
		if offset.x == 1 and local.x != GameConfig.CHUNK_SIZE_X - 1:
			continue
		if offset.y == -1 and local.z != 0:
			continue
		if offset.y == 1 and local.z != GameConfig.CHUNK_SIZE_Z - 1:
			continue
		_request_remesh(chunk + offset, sections)


## Remeshes every loaded chunk (after textures or block definitions changed).
func remesh_all() -> void:
	for entry in _chunks.values():
		if entry.meshed:
			_request_remesh(entry.position, entry.data.non_empty_sections() if entry.data != null else PackedInt32Array(), true)


## Queues writes for every modified chunk. Returns the number queued.
func save_modified(write_now: bool = false) -> int:
	var count := 0
	for entry in _chunks.values():
		if entry.data != null and entry.data.modified:
			_save_entry(entry, write_now)
			count += 1
	return count


## Saves everything and waits for all background work. Main thread.
func shutdown() -> void:
	_shutting_down = true
	_jobs.wait_all()
	save_modified(true)
	_results.clear()
	_backlog.clear()


func stats() -> Dictionary:
	var meshed := 0
	var section_meshes := 0
	for entry in _chunks.values():
		if entry.meshed:
			meshed += 1
		if entry.node != null:
			section_meshes += entry.node.section_mesh_count()
	return {
		"loaded": _chunks.size(), "meshed": meshed, "load_queue": _load_queue.size(),
		"mesh_queue": _mesh_queue.size(), "jobs": _jobs.active_count(), "in_flight": _in_flight,
		"backlog": _backlog.size(), "section_meshes": section_meshes,
		"pending_saves": _save.storage.pending_count(), "render_distance": render_distance,
	}


# --- Streaming ---------------------------------------------------------------

func _recenter() -> void:
	var data_radius := render_distance + 1
	var unload_radius := data_radius + GameConfig.UNLOAD_MARGIN
	for position in _chunks.keys():
		if VoxelCoords.chunk_distance(position, _center) > unload_radius:
			_unload(position)
	for dz in range(-data_radius, data_radius + 1):
		for dx in range(-data_radius, data_radius + 1):
			var position := _center + Vector2i(dx, dz)
			if not _chunks.has(position):
				_epoch += 1
				_chunks[position] = ChunkEntry.new(position, _epoch)
	_load_queue.clear()
	_mesh_queue.clear()
	for entry in _chunks.values():
		entry.mesh_queued = false
		if entry.data == null and not entry.load_submitted:
			_load_queue.append(entry.position)
	for entry in _chunks.values():
		_queue_mesh_if_ready(entry.position)
	_load_queue.sort_custom(_closer_to_center)
	_mesh_queue.sort_custom(_closer_to_center)


func _unload(position: Vector2i) -> void:
	var entry: ChunkEntry = _chunks[position]
	if entry.data != null and entry.data.modified:
		_save_entry(entry, false)
	if entry.node != null:
		entry.node.queue_free()
	_chunks.erase(position)
	if entry.data != null:
		chunk_unloaded.emit(position)


func _queue_mesh_if_ready(position: Vector2i) -> void:
	var entry: ChunkEntry = _chunks.get(position)
	if entry == null or entry.data == null or entry.meshed or entry.mesh_queued or entry.initial_mesh_pending:
		return
	if VoxelCoords.chunk_distance(position, _center) > render_distance:
		return
	for offset in NEIGHBOUR_OFFSETS:
		var neighbour: ChunkEntry = _chunks.get(position + offset)
		if neighbour == null or neighbour.data == null:
			return
	entry.mesh_queued = true
	_mesh_queue.append(position)


func _dispatch() -> void:
	if _shutting_down:
		return
	while _in_flight < max_jobs and not _mesh_queue.is_empty():
		var position: Vector2i = _mesh_queue.pop_front()
		var entry: ChunkEntry = _chunks.get(position)
		if entry == null or not entry.mesh_queued:
			continue
		entry.mesh_queued = false
		entry.initial_mesh_pending = true
		_submit_mesh(entry, entry.data.non_empty_sections())
	while _in_flight < max_jobs and not _load_queue.is_empty():
		var position: Vector2i = _load_queue.pop_front()
		var entry: ChunkEntry = _chunks.get(position)
		if entry == null or entry.load_submitted:
			continue
		entry.load_submitted = true
		_in_flight += 1
		_jobs.submit(_job_load.bind(position, entry.epoch, _generator, _save.storage, _save.world_to_runtime), "load chunk")


func _request_remesh(position: Vector2i, sections: PackedInt32Array, force: bool = false) -> void:
	var entry: ChunkEntry = _chunks.get(position)
	if entry == null or entry.data == null:
		return
	if not entry.meshed and not entry.initial_mesh_pending:
		return
	if sections.is_empty() and not force:
		return
	_submit_mesh(entry, sections)


func _submit_mesh(entry: ChunkEntry, sections: PackedInt32Array) -> void:
	if sections.is_empty():
		entry.initial_mesh_pending = false
		_mark_meshed(entry)
		return
	var low := GameConfig.SECTION_COUNT
	var high := -1
	var revisions := PackedInt32Array()
	for section in sections:
		low = mini(low, section)
		high = maxi(high, section)
		entry.requested[section] += 1
		revisions.append(entry.requested[section])
	var neighbours: Array = []
	for offset in NEIGHBOUR_OFFSETS:
		var neighbour: ChunkEntry = _chunks.get(entry.position + offset)
		neighbours.append(neighbour.data if neighbour != null else null)
	var snapshot := ChunkSnapshot.capture(entry.data, neighbours,
		low * GameConfig.SECTION_HEIGHT - 1, (high + 1) * GameConfig.SECTION_HEIGHT + 1)
	_in_flight += 1
	_jobs.submit(_job_mesh.bind(entry.position, entry.epoch, snapshot, sections, revisions, _content.meshing_context), "mesh chunk")


func _save_entry(entry: ChunkEntry, write_now: bool) -> void:
	var serial := _save.storage.queue_save(entry.data, _save.runtime_to_world)
	entry.data.modified = false
	if write_now:
		_save.storage.write_queued(entry.position, serial)
	else:
		_jobs.submit(_save.storage.write_queued.bind(entry.position, serial), "save chunk")


# --- Worker jobs (no scene access!) ------------------------------------------

func _job_load(position: Vector2i, epoch: int, generator: WorldGenerator, storage: ChunkStorage, world_to_runtime: PackedInt32Array) -> void:
	var data := storage.load_chunk(position, world_to_runtime)
	var from_disk := data != null
	if data == null:
		data = ChunkData.new(position)
		generator.generate(data)
	_push_result({"kind": "load", "position": position, "epoch": epoch, "data": data, "from_disk": from_disk})


func _job_mesh(position: Vector2i, epoch: int, snapshot: ChunkSnapshot, sections: PackedInt32Array,
		revisions: PackedInt32Array, context: MeshingContext) -> void:
	var meshes: Array = []
	for section in sections:
		meshes.append(_mesher.mesh_section(snapshot, section, context))
	_push_result({"kind": "mesh", "position": position, "epoch": epoch, "meshes": meshes, "revisions": revisions})


func _push_result(result: Dictionary) -> void:
	_results_mutex.lock()
	_results.append(result)
	_results_mutex.unlock()


# --- Main-thread integration -------------------------------------------------

func _collect_results() -> void:
	_results_mutex.lock()
	var fresh := _results
	_results = []
	_results_mutex.unlock()
	_in_flight -= fresh.size()
	_backlog.append_array(fresh)


func _integrate(deadline_usec: int) -> void:
	while not _backlog.is_empty():
		if Time.get_ticks_usec() > deadline_usec:
			return
		var result: Dictionary = _backlog.pop_front()
		var entry: ChunkEntry = _chunks.get(result.position)
		if entry == null or entry.epoch != result.epoch:
			continue
		if result.kind == "load":
			_apply_load(entry, result.data)
		else:
			_apply_meshes(entry, result.meshes, result.revisions)


func _apply_load(entry: ChunkEntry, data: ChunkData) -> void:
	entry.data = data
	chunk_loaded.emit(entry.position)
	for offset in NEIGHBOUR_OFFSETS:
		_queue_mesh_if_ready(entry.position + offset)
	_mesh_queue.sort_custom(_closer_to_center)


func _apply_meshes(entry: ChunkEntry, meshes: Array, revisions: PackedInt32Array) -> void:
	if entry.node == null:
		entry.node = ChunkNode.new()
		entry.node.setup(entry.position)
		_parent.add_child(entry.node)
	var textures := _content.block_textures
	for i in meshes.size():
		var mesh: SectionMeshData = meshes[i]
		if revisions[i] < entry.applied[mesh.section]:
			continue
		entry.applied[mesh.section] = revisions[i]
		entry.node.apply_section(mesh, textures.opaque_material, textures.cutout_material)
	if entry.initial_mesh_pending:
		entry.initial_mesh_pending = false
		_mark_meshed(entry)


func _mark_meshed(entry: ChunkEntry) -> void:
	entry.meshed = true


func _closer_to_center(a: Vector2i, b: Vector2i) -> bool:
	return (a - _center).length_squared() < (b - _center).length_squared()
