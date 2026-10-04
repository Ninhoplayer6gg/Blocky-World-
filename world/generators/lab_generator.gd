extends WorldGenerator
## Blocky Lab ("blockyworld:lab"): a flat development world.
##
## - Floor of lab tiles; darker tiles mark chunk borders.
## - Showcase row (z = 6): every registered block, base game and mods, in
##   registration order, spaced 2 blocks apart starting at x = 0.
## - Staircase and gap course (z = -6) for movement/collision checks.
## - Glass wall (x = -6) for transparency/culling checks.

const FLOOR_Y := 32
const SHOWCASE_Z := 6
const COURSE_Z := -6
const GLASS_X := -6
const SX := GameConfig.CHUNK_SIZE_X
const SZ := GameConfig.CHUNK_SIZE_Z
const LAYER := GameConfig.CHUNK_LAYER

var _baserock := 0
var _stone := 0
var _tile := 0
var _tile_border := 0
var _glass := 0
var _showcase := PackedInt32Array()


func _setup() -> void:
	_baserock = block_id("blockyworld:baserock")
	_stone = block_id("blockyworld:stone")
	_tile = block_id("blockyworld:lab_tile")
	_tile_border = block_id("blockyworld:lab_tile_dark", "blockyworld:lab_tile")
	_glass = block_id("blockyworld:glass")
	_showcase.clear()
	for entry in content.registries.blocks.entries():
		var block := entry as BlockDefinition
		if block.runtime_id != 0 and not block.missing and block.render_layer != BlockDefinition.RenderLayer.NONE:
			_showcase.append(block.runtime_id)


func generate(data: ChunkData) -> void:
	var blocks := data.blocks
	var origin_x := data.position.x * SX
	var origin_z := data.position.y * SZ
	for z in SZ:
		for x in SX:
			var index := x + z * SX
			blocks[index] = _baserock
			for y in range(1, FLOOR_Y):
				blocks[index + y * LAYER] = _stone
			var border := x == 0 or z == 0
			blocks[index + FLOOR_Y * LAYER] = _tile_border if border else _tile
	for i in _showcase.size():
		_set_world(data, origin_x, origin_z, i * 2, FLOOR_Y + 1, SHOWCASE_Z, _showcase[i])
	for step in 6:
		for dy in step + 1:
			_set_world(data, origin_x, origin_z, step, FLOOR_Y + 1 + dy, COURSE_Z, _stone)
	for gap in 4:
		var x := 8 + gap * (gap + 2)
		_set_world(data, origin_x, origin_z, x, FLOOR_Y + 1, COURSE_Z, _stone)
	for z in range(-3, 4):
		for dy in 3:
			_set_world(data, origin_x, origin_z, GLASS_X, FLOOR_Y + 1 + dy, z, _glass)
	data.recount_sections()


func get_spawn_position() -> Vector3:
	return Vector3(0.5, FLOOR_Y + 1.05, 0.5)


func get_biome_name(_x: int, _z: int) -> String:
	return "Blocky Lab"


func _set_world(data: ChunkData, origin_x: int, origin_z: int, x: int, y: int, z: int, block: int) -> void:
	var lx := x - origin_x
	var lz := z - origin_z
	if lx < 0 or lz < 0 or lx >= SX or lz >= SZ:
		return
	data.set_local(lx, y, lz, block)
