class_name World
extends Node3D
## A loaded world: block access API, chunk streaming, entities and saving.
## Gameplay code changes blocks through break_block/place_block (which emit
## events); set_block is the raw, event-free primitive used by commands and
## tools.

signal spawn_area_ready

var content: GameContent
var save: WorldSave
var generator: WorldGenerator
var events: EventBus
var chunks: ChunkManager
var entities: EntityManager
var creative := false
## Chunks stream around this point (normally the player).
var focus_position := Vector3.ZERO
var _autosave_timer := 0.0
var _spawn_ready_emitted := false


## Returns "" on success or a human-readable error.
func setup(game_content: GameContent, world_save: WorldSave, event_bus: EventBus, render_distance: int) -> String:
	name = "World"
	content = game_content
	save = world_save
	events = event_bus
	creative = save.is_creative()
	var registry_size := content.registries.blocks.runtime_count()
	save.bind_blocks(content.registries.blocks)
	if content.registries.blocks.runtime_count() != registry_size:
		content.refresh_block_tables()
	generator = content.registries.generators.create(save.get_generator()) as WorldGenerator
	if generator == null:
		return "world generator '%s' is not available (missing mod?)" % save.get_generator()
	generator.setup(save.get_seed(), content)
	chunks = ChunkManager.new(self, content, generator, save)
	chunks.set_render_distance(render_distance)
	chunks.chunk_loaded.connect(func(position: Vector2i) -> void: events.emit(Events.CHUNK_LOADED, {"chunk": position}))
	chunks.chunk_unloaded.connect(func(position: Vector2i) -> void: events.emit(Events.CHUNK_UNLOADED, {"chunk": position}))
	entities = EntityManager.new()
	entities.setup(self, content)
	add_child(entities)
	return ""


func _process(delta: float) -> void:
	if chunks == null:
		return
	chunks.update(focus_position)
	if not _spawn_ready_emitted and chunks.is_area_ready(VoxelCoords.position_to_chunk(focus_position), 1):
		_spawn_ready_emitted = true
		spawn_area_ready.emit()
	_autosave_timer += delta
	if _autosave_timer >= GameConfig.AUTOSAVE_INTERVAL_SEC:
		_autosave_timer = 0.0
		save_world(false)


# --- Block access --------------------------------------------------------------

## Runtime block id at `block`; 0 (air) when outside the world or not loaded.
func get_block(block: Vector3i) -> int:
	if not VoxelCoords.is_valid_height(block.y):
		return BlockRegistry.AIR
	var data := chunks.get_chunk_data(VoxelCoords.block_to_chunk(block))
	if data == null:
		return BlockRegistry.AIR
	var local := VoxelCoords.block_to_local(block)
	return data.get_local(local.x, local.y, local.z)


func get_block_definition(block: Vector3i) -> BlockDefinition:
	return content.registries.blocks.get_by_runtime(get_block(block))


func is_block_loaded(block: Vector3i) -> bool:
	return VoxelCoords.is_valid_height(block.y) and chunks.get_chunk_data(VoxelCoords.block_to_chunk(block)) != null


## Raw block write without events. Returns false when the chunk is not loaded.
func set_block(block: Vector3i, runtime_id: int) -> bool:
	if not VoxelCoords.is_valid_height(block.y) or content.registries.blocks.get_by_runtime(runtime_id) == null:
		return false
	var data := chunks.get_chunk_data(VoxelCoords.block_to_chunk(block))
	if data == null:
		return false
	var local := VoxelCoords.block_to_local(block)
	if data.set_local(local.x, local.y, local.z, runtime_id) == runtime_id:
		return true
	data.modified = true
	chunks.notify_block_changed(block)
	return true


## Gameplay break: emits BLOCK_BREAKING (cancellable) and BLOCK_BROKEN.
## Returns the dropped stacks, or null when the block was not broken.
func break_block(block: Vector3i, breaker: Entity = null) -> Variant:
	var definition := get_block_definition(block)
	if definition == null or definition.runtime_id == BlockRegistry.AIR or not definition.is_breakable():
		return null
	var payload := {"position": block, "block": definition.id, "entity": breaker}
	if not events.emit_cancellable(Events.BLOCK_BREAKING, payload):
		return null
	if not set_block(block, BlockRegistry.AIR):
		return null
	var drops: Array = []
	if definition.drops.is_empty():
		if content.registries.items.has(definition.id):
			drops.append(ItemStack.create(definition.id, 1))
	else:
		for drop in definition.drops:
			drops.append(ItemStack.create(drop.item, drop.count))
	payload["drops"] = drops
	events.emit(Events.BLOCK_BROKEN, payload)
	return drops


## Gameplay placement: refuses occupied cells and cells intersecting entities.
func place_block(block: Vector3i, runtime_id: int, placer: Entity = null) -> bool:
	if not is_block_loaded(block):
		return false
	var current := get_block_definition(block)
	if current != null and current.runtime_id != BlockRegistry.AIR and not current.replaceable:
		return false
	var definition := content.registries.blocks.get_by_runtime(runtime_id)
	if definition == null or definition.runtime_id == BlockRegistry.AIR or definition.missing:
		return false
	if definition.collision and is_occupied_by_entity(block):
		return false
	var payload := {"position": block, "block": definition.id, "entity": placer}
	if not events.emit_cancellable(Events.BLOCK_PLACING, payload):
		return false
	if not set_block(block, runtime_id):
		return false
	events.emit(Events.BLOCK_PLACED, payload)
	return true


func is_occupied_by_entity(block: Vector3i) -> bool:
	var cell := AABB(Vector3(block), Vector3.ONE).grow(-0.001)
	for entity in entities.get_all():
		if entity.get_world_aabb().intersects(cell):
			return true
	return false


## Voxel raycast against blocks that can be targeted (anything but air).
func raycast_block(origin: Vector3, direction: Vector3, max_distance: float) -> VoxelRaycast.Hit:
	return VoxelRaycast.cast(origin, direction, max_distance, _target_at)


func _target_at(cell: Vector3i) -> int:
	var block_id := get_block(cell)
	if block_id == BlockRegistry.AIR:
		return 0
	var definition := content.registries.blocks.get_by_runtime(block_id)
	return block_id if definition != null and definition.render_layer != BlockDefinition.RenderLayer.NONE else 0


## True when the chunk containing `position` has its collision built.
func has_collision_at(position: Vector3) -> bool:
	return chunks.is_meshed(VoxelCoords.position_to_chunk(position))


## Lowest Y above the terrain at (x, z) with two free blocks, using loaded
## data; -1 if the chunk is not loaded.
func find_standing_y(x: int, z: int) -> int:
	var data := chunks.get_chunk_data(VoxelCoords.block_to_chunk(Vector3i(x, 0, z)))
	if data == null:
		return -1
	var local := VoxelCoords.block_to_local(Vector3i(x, 0, z))
	var top := data.get_top_y(local.x, local.z)
	return top + 1


func get_biome_name(block: Vector3i) -> String:
	return generator.get_biome_name(block.x, block.z) if generator != null else "-"


# --- Saving ------------------------------------------------------------------

## Writes modified chunks and metadata. Player data is saved by the session.
func save_world(wait: bool) -> void:
	var count := chunks.save_modified(wait)
	save.save_metadata(content)
	events.emit(Events.WORLD_SAVED, {"chunks": count})
	Log.info("SAVE", "Saved world '%s' (%d modified chunk(s))" % [save.get_name(), count])


## Saves everything and stops background work. Call before freeing.
func shutdown() -> void:
	events.emit(Events.WORLD_UNLOADING, {"world": self})
	if chunks != null:
		chunks.shutdown()
	save.save_metadata(content)
	Log.info("WORLD", "World '%s' closed" % save.get_name())
