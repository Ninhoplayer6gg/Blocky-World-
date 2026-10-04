extends WorldGenerator
## Default world generator ("blockyworld:default").
##
## - Height: fractal simplex noise around BASE_HEIGHT, shaped by biomes.
## - Biomes: nearest climate point (temperature/humidity noise), with height
##   parameters blended across borders to avoid cliffs.
## - Caves: 3D noise carving below the surface.
## - Features (trees, cacti): placed per column from a positional hash and
##   evaluated in a margin around the chunk so they cross borders seamlessly.

const BASE_HEIGHT := 56.0
const HEIGHT_AMPLITUDE := 16.0
const DETAIL_AMPLITUDE := 3.0
const BLEND_SHARPNESS := 0.012
const CAVE_THRESHOLD := 0.62
const CAVE_MIN_Y := 4
const CAVE_SURFACE_MARGIN := 5
const MARGIN := TerrainFeature.MAX_RADIUS
const SX := GameConfig.CHUNK_SIZE_X
const SY := GameConfig.CHUNK_SIZE_Y
const SZ := GameConfig.CHUNK_SIZE_Z
const LAYER := GameConfig.CHUNK_LAYER

var _height_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _temperature_noise: FastNoiseLite
var _humidity_noise: FastNoiseLite
var _cave_noise: FastNoiseLite
var _baserock := 0
## [{name, temperature, humidity, offset, variation, surface, subsurface,
##   depth, stone, features: [TerrainFeature]}]
var _biomes: Array = []


func get_version() -> int:
	return 1


func _setup() -> void:
	_height_noise = _noise(1, 0.0055, 4)
	_detail_noise = _noise(2, 0.04, 2)
	_temperature_noise = _noise(3, 0.0016, 2)
	_humidity_noise = _noise(4, 0.0016, 2)
	_cave_noise = _noise(5, 0.045, 2)
	_baserock = block_id("blockyworld:baserock")
	_biomes.clear()
	for entry in content.registries.biomes.entries():
		var biome := entry as BiomeDefinition
		var features: Array = []
		for params in biome.features:
			var feature := content.registries.features.create(params.type) as TerrainFeature
			if feature != null and feature.configure(params, self):
				features.append(feature)
		_biomes.append({
			"name": biome.display_name,
			"temperature": biome.temperature,
			"humidity": biome.humidity,
			"offset": biome.height_offset,
			"variation": biome.height_variation,
			"surface": block_id(biome.surface_block),
			"subsurface": block_id(biome.subsurface_block),
			"depth": biome.subsurface_depth,
			"stone": block_id(biome.stone_block),
			"features": features,
		})
	if _biomes.is_empty():
		Log.warn("GEN", "No biomes registered; using a bare stone fallback biome")
		var stone := block_id("blockyworld:stone")
		_biomes.append({"name": "Fallback", "temperature": 0.5, "humidity": 0.5, "offset": 0.0,
			"variation": 1.0, "surface": stone, "subsurface": stone, "depth": 0, "stone": stone, "features": []})


func generate(data: ChunkData) -> void:
	var origin_x := data.position.x * SX
	var origin_z := data.position.y * SZ
	var width := SX + MARGIN * 2
	var depth := SZ + MARGIN * 2
	var heights := PackedInt32Array()
	var biome_ids := PackedInt32Array()
	heights.resize(width * depth)
	biome_ids.resize(width * depth)
	var column_info := Vector2i.ZERO
	for lz in depth:
		for lx in width:
			column_info = _column(origin_x - MARGIN + lx, origin_z - MARGIN + lz)
			heights[lz * width + lx] = column_info.x
			biome_ids[lz * width + lx] = column_info.y

	var blocks := data.blocks
	for z in SZ:
		for x in SX:
			var column := (z + MARGIN) * width + x + MARGIN
			var height := heights[column]
			var biome: Dictionary = _biomes[biome_ids[column]]
			var surface: int = biome.surface
			var subsurface: int = biome.subsurface
			var stone: int = biome.stone
			var subsurface_start: int = height - int(biome.depth)
			var index := x + z * SX
			blocks[index] = _baserock
			for y in range(1, height + 1):
				var block := stone
				if y == height:
					block = surface
				elif y >= subsurface_start:
					block = subsurface
				blocks[index + y * LAYER] = block
			var world_x := origin_x + x
			var world_z := origin_z + z
			for y in range(CAVE_MIN_Y, height - CAVE_SURFACE_MARGIN):
				if _cave_noise.get_noise_3d(world_x, y * 1.6, world_z) > CAVE_THRESHOLD:
					blocks[index + y * LAYER] = 0
	data.recount_sections()

	for lz in depth:
		for lx in width:
			var column := lz * width + lx
			var features: Array = _biomes[biome_ids[column]].features
			if features.is_empty():
				continue
			var world_x := origin_x - MARGIN + lx
			var world_z := origin_z - MARGIN + lz
			for i in features.size():
				var feature: TerrainFeature = features[i]
				var random := WorldHash.hash3(world_seed, world_x, 1000 + i, world_z)
				if float(random & 0xFFFF) / 65536.0 < feature.chance:
					feature.place(data, lx - MARGIN, heights[column] + 1, lz - MARGIN, random >> 16)
					break


func get_spawn_position() -> Vector3:
	var height := _column(0, 0).x
	return Vector3(0.5, height + 1.05, 0.5)


func get_biome_name(x: int, z: int) -> String:
	return _biomes[_column(x, z).y].name


func surface_height(x: int, z: int) -> int:
	return _column(x, z).x


## Returns Vector2i(surface height, biome index).
func _column(x: int, z: int) -> Vector2i:
	var temperature := (_temperature_noise.get_noise_2d(x, z) + 1.0) * 0.5
	var humidity := (_humidity_noise.get_noise_2d(x, z) + 1.0) * 0.5
	var total := 0.0
	var offset := 0.0
	var variation := 0.0
	var best := 0
	var best_distance := INF
	for i in _biomes.size():
		var biome: Dictionary = _biomes[i]
		var dt: float = temperature - biome.temperature
		var dh: float = humidity - biome.humidity
		var distance := dt * dt + dh * dh
		if distance < best_distance:
			best_distance = distance
			best = i
		var weight := exp(-distance / BLEND_SHARPNESS)
		total += weight
		offset += weight * biome.offset
		variation += weight * biome.variation
	if total > 0.000001:
		offset /= total
		variation /= total
	else:
		offset = _biomes[best].offset
		variation = _biomes[best].variation
	var height := BASE_HEIGHT + offset
	height += _height_noise.get_noise_2d(x, z) * HEIGHT_AMPLITUDE * variation
	height += _detail_noise.get_noise_2d(x, z) * DETAIL_AMPLITUDE * variation
	return Vector2i(clampi(int(round(height)), 2, SY - 12), best)


func _noise(salt: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = WorldHash.sub_seed(world_seed, salt) & 0x7FFFFFFF
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	return noise
