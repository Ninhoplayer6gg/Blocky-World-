extends TerrainFeature
## Vertical column of one block (cacti, pillars).
## Params: block, min_height (1), max_height (3).

var _block := 0
var _min_height := 1
var _max_height := 3


func _configure(params: Dictionary, generator: WorldGenerator) -> bool:
	_block = generator.block_id(str(params.get("block", "blockyworld:cactus")))
	_min_height = clampi(int(params.get("min_height", 1)), 1, 16)
	_max_height = clampi(int(params.get("max_height", 3)), _min_height, 16)
	return true


func place(data: ChunkData, x: int, y: int, z: int, random: int) -> void:
	var height := _min_height + random % (_max_height - _min_height + 1)
	for dy in height:
		set_inside(data, x, y + dy, z, _block, true)
