extends TestCase
## Hidden-face culling and collision generation.

var blocks: BlockRegistry
var context: MeshingContext
var mesher := ChunkMesher.new()
var stone := 0
var glass := 0


func before_each() -> void:
	blocks = BlockRegistry.new()
	var s := BlockDefinition.new()
	s.id = "test:stone"
	blocks.register(s)
	var g := BlockDefinition.new()
	g.id = "test:glass"
	g.transparent = true
	g.render_layer = BlockDefinition.RenderLayer.CUTOUT
	blocks.register(g)
	stone = s.runtime_id
	glass = g.runtime_id
	context = MeshingContext.build(blocks, func(_block: BlockDefinition, face: int) -> int: return face)


func _mesh(data: ChunkData, section: int, neighbours: Array = []) -> SectionMeshData:
	if neighbours.is_empty():
		neighbours.resize(9)
	var snapshot := ChunkSnapshot.capture(data, neighbours, section * 16 - 1, section * 16 + 17)
	return mesher.mesh_section(snapshot, section, context)


func test_single_block_has_six_faces() -> void:
	var data := ChunkData.new()
	data.set_local(5, 20, 5, stone)
	var result := _mesh(data, 1)
	assert_eq(result.face_count, 6)
	assert_eq((result.opaque[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 24)
	assert_eq((result.opaque[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 36)
	assert_eq(result.collision.size(), 36, "two triangles per face for collision")
	assert_true(result.cutout.is_empty())


func test_adjacent_solid_faces_are_culled() -> void:
	var data := ChunkData.new()
	data.set_local(5, 20, 5, stone)
	data.set_local(6, 20, 5, stone)
	assert_eq(_mesh(data, 1).face_count, 10, "shared face removed from both blocks")


func test_full_cube_only_has_outer_faces() -> void:
	var data := ChunkData.new()
	for x in range(2, 5):
		for y in range(18, 21):
			for z in range(2, 5):
				data.set_local(x, y, z, stone)
	assert_eq(_mesh(data, 1).face_count, 6 * 9, "3x3x3 cube renders only its surface")


func test_culling_across_section_and_chunk_borders() -> void:
	var data := ChunkData.new()
	data.set_local(15, 15, 0, stone)
	data.set_local(15, 16, 0, stone)
	assert_eq(_mesh(data, 0).face_count, 5, "face toward the section above is culled")
	var east := ChunkData.new(Vector2i(1, 0))
	east.set_local(0, 15, 0, stone)
	var neighbours: Array = []
	neighbours.resize(9)
	neighbours[5] = east
	assert_eq(_mesh(data, 0, neighbours).face_count, 4, "face toward the neighbour chunk is culled")


func test_transparent_blocks_do_not_cull_neighbours() -> void:
	var data := ChunkData.new()
	data.set_local(5, 20, 5, stone)
	data.set_local(6, 20, 5, glass)
	data.set_local(7, 20, 5, glass)
	var result := _mesh(data, 1)
	# stone: 6 (its face toward glass stays); glass A: 4 (faces toward stone and glass culled); glass B: 5
	assert_eq(result.face_count, 6 + 4 + 5, "stone keeps its face toward glass; glass-glass face culled")
	assert_false(result.cutout.is_empty(), "glass goes to the cutout surface")


func test_bottom_of_world_is_not_rendered() -> void:
	var data := ChunkData.new()
	data.set_local(3, 0, 3, stone)
	assert_eq(_mesh(data, 0).face_count, 5)


func test_empty_section_produces_nothing() -> void:
	var result := _mesh(ChunkData.new(), 2)
	assert_true(result.is_empty())


func test_ambient_occlusion_darkens_corners() -> void:
	var data := ChunkData.new()
	data.set_local(5, 20, 5, stone)
	data.set_local(6, 21, 5, stone)
	var result := _mesh(data, 1)
	var colors: PackedColorArray = result.opaque[Mesh.ARRAY_COLOR]
	var darkest := 1.0
	for color in colors:
		darkest = minf(darkest, color.r)
	assert_true(darkest < 1.0, "a vertex next to the upper block is occluded")
