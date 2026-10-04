class_name VoxelCoords
extends RefCounted
## Conversions between world block positions, chunk coordinates and
## chunk-local positions. Negative coordinates use floor semantics, so block
## x = -1 lives in chunk -1 at local x = 15.

const SX := GameConfig.CHUNK_SIZE_X
const SY := GameConfig.CHUNK_SIZE_Y
const SZ := GameConfig.CHUNK_SIZE_Z
const LAYER := GameConfig.CHUNK_LAYER


@warning_ignore("integer_division")
static func floor_div(a: int, b: int) -> int:
	return (a - posmod(a, b)) / b


static func block_to_chunk(block: Vector3i) -> Vector2i:
	return Vector2i(floor_div(block.x, SX), floor_div(block.z, SZ))


static func block_to_local(block: Vector3i) -> Vector3i:
	return Vector3i(posmod(block.x, SX), block.y, posmod(block.z, SZ))


static func local_to_block(chunk: Vector2i, local: Vector3i) -> Vector3i:
	return Vector3i(chunk.x * SX + local.x, local.y, chunk.y * SZ + local.z)


static func position_to_block(position: Vector3) -> Vector3i:
	return Vector3i(floori(position.x), floori(position.y), floori(position.z))


static func position_to_chunk(position: Vector3) -> Vector2i:
	return block_to_chunk(position_to_block(position))


static func chunk_origin(chunk: Vector2i) -> Vector3:
	return Vector3(chunk.x * SX, 0, chunk.y * SZ)


static func local_index(x: int, y: int, z: int) -> int:
	return x + z * SX + y * LAYER


@warning_ignore("integer_division")
static func index_to_local(index: int) -> Vector3i:
	var y := index / LAYER
	var rest := index - y * LAYER
	var z := rest / SX
	return Vector3i(rest - z * SX, y, z)


@warning_ignore("integer_division")
static func section_of(y: int) -> int:
	return y / GameConfig.SECTION_HEIGHT


static func is_valid_height(y: int) -> bool:
	return y >= 0 and y < SY


## Chebyshev distance in chunks (square render area).
static func chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
