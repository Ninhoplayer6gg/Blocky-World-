extends SceneTree
## Measures single-threaded generation and meshing cost per chunk.
##   godot --headless --path . -s res://tools/benchmark_chunks.gd -- --bw-no-boot

const CHUNKS := 5


func _process(_delta: float) -> bool:
	Log.muted = true
	var pipeline := ContentPipeline.new()
	pipeline.search_paths = ContentPipeline.default_search_paths()
	var content := pipeline.run()
	var blocks := content.registries.blocks
	var context := MeshingContext.build(blocks, func(_b: BlockDefinition, face: int) -> int: return face)
	var generator := content.registries.generators.create("blockyworld:default") as WorldGenerator
	generator.setup(GameConfig.DEFAULT_WORLD_SEED, content)

	var grid: Dictionary = {}
	var start := Time.get_ticks_usec()
	for z in range(-1, CHUNKS + 1):
		for x in range(-1, CHUNKS + 1):
			var data := ChunkData.new(Vector2i(x, z))
			generator.generate(data)
			grid[Vector2i(x, z)] = data
	var generated := grid.size()
	var gen_ms := (Time.get_ticks_usec() - start) / 1000.0

	var mesher := ChunkMesher.new()
	var faces := 0
	var sections := 0
	start = Time.get_ticks_usec()
	for z in CHUNKS:
		for x in CHUNKS:
			var center: ChunkData = grid[Vector2i(x, z)]
			var neighbours: Array = []
			for offset in ChunkManager.NEIGHBOUR_OFFSETS:
				neighbours.append(grid.get(Vector2i(x, z) + offset))
			var snapshot := ChunkSnapshot.capture(center, neighbours, 0, GameConfig.CHUNK_SIZE_Y)
			for section in center.non_empty_sections():
				faces += mesher.mesh_section(snapshot, section, context).face_count
				sections += 1
	var mesh_ms := (Time.get_ticks_usec() - start) / 1000.0
	var meshed := CHUNKS * CHUNKS
	print("Generation: %.2f ms/chunk (%d chunks)" % [gen_ms / generated, generated])
	print("Meshing:    %.2f ms/chunk, %.2f ms/section, %d faces/chunk (%d chunks)" % [
		mesh_ms / meshed, mesh_ms / maxi(sections, 1), faces / meshed, meshed])
	quit()
	return false
