class_name ChunkData
extends RefCounted
## Block storage for one chunk column: a flat PackedInt32Array of runtime block
## ids indexed x + z * SX + y * SX * SZ (see VoxelCoords.local_index).
##
## Ownership: a ChunkData is written by exactly one thread at a time. Worker
## jobs build it, then hand it to the main thread, which owns it afterwards.
## Background readers (meshing, saving) receive copies (ChunkSnapshot or
## blocks.duplicate()), never this object.

const SX := GameConfig.CHUNK_SIZE_X
const SY := GameConfig.CHUNK_SIZE_Y
const SZ := GameConfig.CHUNK_SIZE_Z
const LAYER := GameConfig.CHUNK_LAYER
const SECTION_HEIGHT := GameConfig.SECTION_HEIGHT

var position: Vector2i
var blocks: PackedInt32Array = PackedInt32Array()
## Non-air block count per section; 0 means the section needs no mesh.
var section_counts: PackedInt32Array = PackedInt32Array()
## Changed since generation/load and must be written on save.
var modified := false


func _init(chunk_position: Vector2i = Vector2i.ZERO) -> void:
	position = chunk_position
	blocks.resize(GameConfig.CHUNK_VOLUME)
	section_counts.resize(GameConfig.SECTION_COUNT)


func get_local(x: int, y: int, z: int) -> int:
	if y < 0 or y >= SY:
		return 0
	return blocks[x + z * SX + y * LAYER]


## Sets a block and returns the previous id. Keeps section counts in sync.
@warning_ignore("integer_division")
func set_local(x: int, y: int, z: int, block_id: int) -> int:
	if y < 0 or y >= SY:
		return 0
	var index := x + z * SX + y * LAYER
	var previous := blocks[index]
	if previous == block_id:
		return previous
	blocks[index] = block_id
	var section := y / SECTION_HEIGHT
	if previous == 0:
		section_counts[section] += 1
	elif block_id == 0:
		section_counts[section] -= 1
	return previous


## Recomputes section counts after bulk writes to `blocks`.
func recount_sections() -> void:
	var per_section := SECTION_HEIGHT * LAYER
	for section in GameConfig.SECTION_COUNT:
		var start := section * per_section
		var count := 0
		for i in range(start, start + per_section):
			if blocks[i] != 0:
				count += 1
		section_counts[section] = count


func is_section_empty(section: int) -> bool:
	return section_counts[section] == 0


func non_empty_sections() -> PackedInt32Array:
	var result := PackedInt32Array()
	for section in GameConfig.SECTION_COUNT:
		if section_counts[section] > 0:
			result.append(section)
	return result


## Height of the highest non-air block in a column, or -1.
func get_top_y(x: int, z: int) -> int:
	for y in range(SY - 1, -1, -1):
		if blocks[x + z * SX + y * LAYER] != 0:
			return y
	return -1
