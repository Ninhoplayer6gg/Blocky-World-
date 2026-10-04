class_name ChunkNode
extends Node3D
## Scene representation of one chunk: one MeshInstance3D and one collision
## shape per non-empty section, all under a single StaticBody3D. Never one
## node per block.

var chunk_position: Vector2i
var _meshes: Array = []
var _shapes: Array = []
var _body: StaticBody3D


func setup(position_in_chunks: Vector2i) -> void:
	chunk_position = position_in_chunks
	name = "Chunk_%d_%d" % [chunk_position.x, chunk_position.y]
	position = VoxelCoords.chunk_origin(chunk_position)
	_meshes.resize(GameConfig.SECTION_COUNT)
	_shapes.resize(GameConfig.SECTION_COUNT)
	_body = StaticBody3D.new()
	_body.name = "Collision"
	_body.collision_layer = 1 << (GameConfig.LAYER_WORLD - 1)
	_body.collision_mask = 0
	add_child(_body)


## Main thread: uploads a section mesh produced by ChunkMesher.
func apply_section(data: SectionMeshData, opaque_material: Material, cutout_material: Material) -> void:
	var section := data.section
	var section_offset := Vector3(0, section * GameConfig.SECTION_HEIGHT, 0)
	var mesh_instance: MeshInstance3D = _meshes[section]
	if data.opaque.is_empty() and data.cutout.is_empty():
		if mesh_instance != null:
			mesh_instance.queue_free()
			_meshes[section] = null
	else:
		var mesh := ArrayMesh.new()
		if not data.opaque.is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.opaque)
			mesh.surface_set_material(mesh.get_surface_count() - 1, opaque_material)
		if not data.cutout.is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.cutout)
			mesh.surface_set_material(mesh.get_surface_count() - 1, cutout_material)
		if mesh_instance == null:
			mesh_instance = MeshInstance3D.new()
			mesh_instance.name = "Section%d" % section
			mesh_instance.position = section_offset
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh_instance)
			_meshes[section] = mesh_instance
		mesh_instance.mesh = mesh

	var shape_node: CollisionShape3D = _shapes[section]
	if data.collision.is_empty():
		if shape_node != null:
			shape_node.queue_free()
			_shapes[section] = null
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(data.collision)
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "Section%d" % section
		shape_node.position = section_offset
		_body.add_child(shape_node)
		_shapes[section] = shape_node
	shape_node.shape = shape


func section_mesh_count() -> int:
	var count := 0
	for mesh_instance in _meshes:
		if mesh_instance != null:
			count += 1
	return count
