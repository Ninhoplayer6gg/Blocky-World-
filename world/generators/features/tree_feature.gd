extends TerrainFeature
## Simple deciduous tree: straight trunk and a rounded leaf crown.
## Params: log_block, leaves_block, min_height (4), max_height (6).

var _log := 0
var _leaves := 0
var _min_height := 4
var _max_height := 6


func _configure(params: Dictionary, generator: WorldGenerator) -> bool:
	_log = generator.block_id(str(params.get("log_block", "blockyworld:log")))
	_leaves = generator.block_id(str(params.get("leaves_block", "blockyworld:leaves")))
	_min_height = clampi(int(params.get("min_height", 4)), 3, 12)
	_max_height = clampi(int(params.get("max_height", 6)), _min_height, 12)
	return true


func place(data: ChunkData, x: int, y: int, z: int, random: int) -> void:
	var height := _min_height + random % (_max_height - _min_height + 1)
	var top := y + height - 1
	for dy in range(-2, 2):
		var radius := 2 if dy < 0 else 1
		var layer_y := top + dy + 1
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				# Trim corners pseudo-randomly for a less boxy crown.
				if absi(dx) == radius and absi(dz) == radius and (random >> (dx + dz + 8)) & 1 == 0:
					continue
				set_inside(data, x + dx, layer_y, z + dz, _leaves, true)
	for dy in height:
		set_inside(data, x, y + dy, z, _log, false)
