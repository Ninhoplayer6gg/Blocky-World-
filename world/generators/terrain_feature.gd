class_name TerrainFeature
extends RefCounted
## A small decoration placed by the default generator on a surface column
## (trees, cacti, ...). Registered by id in ContentRegistries.features and
## configured per biome from JSON.
##
## place() is called on worker threads for every chunk the feature might
## overlap, with chunk-local coordinates that can lie outside the chunk. It
## must only write blocks inside the chunk and must be deterministic for a
## given `random`, so features crossing chunk borders line up.

## Max horizontal distance from the origin column that the feature writes.
const MAX_RADIUS := 3

var chance: float = 0.0


## Resolves parameters on the main thread. Return false if unusable.
func configure(params: Dictionary, generator: WorldGenerator) -> bool:
	chance = clampf(float(params.get("chance", 0.0)), 0.0, 1.0)
	return _configure(params, generator)


func _configure(_params: Dictionary, _generator: WorldGenerator) -> bool:
	return true


func place(_data: ChunkData, _x: int, _y: int, _z: int, _random: int) -> void:
	pass


static func set_inside(data: ChunkData, x: int, y: int, z: int, block: int, only_air: bool) -> void:
	if x < 0 or z < 0 or x >= GameConfig.CHUNK_SIZE_X or z >= GameConfig.CHUNK_SIZE_Z:
		return
	if y < 0 or y >= GameConfig.CHUNK_SIZE_Y:
		return
	if only_air and data.get_local(x, y, z) != 0:
		return
	data.set_local(x, y, z, block)
