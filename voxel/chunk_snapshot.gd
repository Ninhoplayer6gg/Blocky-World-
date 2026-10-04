class_name ChunkSnapshot
extends RefCounted
## Immutable copy of a chunk and its 8 neighbours over a range of layers,
## captured on the main thread and handed to a meshing job. Copying keeps
## workers from racing with block edits on the main thread.

const LAYER := GameConfig.CHUNK_LAYER

var chunk_position: Vector2i
## First layer (y) contained in each column array.
var y_start := 0
## One past the last layer contained.
var y_end := 0
## 9 arrays indexed (dz + 1) * 3 + (dx + 1); empty array = missing neighbour.
var columns: Array[PackedInt32Array] = []


static func capture(center: ChunkData, neighbours: Array, first_y: int, end_y: int) -> ChunkSnapshot:
	var snapshot := ChunkSnapshot.new()
	snapshot.chunk_position = center.position
	snapshot.y_start = clampi(first_y, 0, GameConfig.CHUNK_SIZE_Y)
	snapshot.y_end = clampi(end_y, snapshot.y_start, GameConfig.CHUNK_SIZE_Y)
	var from := snapshot.y_start * LAYER
	var to := snapshot.y_end * LAYER
	snapshot.columns.resize(9)
	for i in 9:
		var data: ChunkData = center if i == 4 else neighbours[i]
		snapshot.columns[i] = data.blocks.slice(from, to) if data != null else PackedInt32Array()
	return snapshot


## Block at chunk-local coordinates; x/z may extend one block into neighbours.
func get_block(x: int, y: int, z: int) -> int:
	var dx := -1 if x < 0 else (1 if x >= GameConfig.CHUNK_SIZE_X else 0)
	var dz := -1 if z < 0 else (1 if z >= GameConfig.CHUNK_SIZE_Z else 0)
	var column := columns[(dz + 1) * 3 + dx + 1]
	if column.is_empty() or y < y_start or y >= y_end:
		return 0
	var lx := x - dx * GameConfig.CHUNK_SIZE_X
	var lz := z - dz * GameConfig.CHUNK_SIZE_Z
	return column[(y - y_start) * LAYER + lz * GameConfig.CHUNK_SIZE_X + lx]
