extends TestCase
## Asset resolution, resource-pack overrides, external PNG and glTF loading.


func _png(path: String, color: Color) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.save_png(path)


func test_resolve_and_expected_path() -> void:
	var root := temp_dir("mod_a")
	_png(root.path_join("textures/blocks/gem.png"), Color.RED)
	var resources := ResourceManager.new()
	resources.register_namespace_root("gem", root)
	assert_eq(resources.resolve(ResourceManager.TEXTURES, "gem:blocks/gem"), root.path_join("textures/blocks/gem.png"))
	assert_eq(resources.resolve(ResourceManager.TEXTURES, "gem:blocks/missing"), "")
	assert_eq(resources.resolve(ResourceManager.TEXTURES, "invalid id"), "")
	assert_eq(resources.expected_path(ResourceManager.MODELS, "gem:entities/golem"), root.path_join("models/entities/golem.glb"))


func test_external_png_loads_and_resource_pack_overrides() -> void:
	var root := temp_dir("mod_b")
	var pack := temp_dir("pack")
	_png(root.path_join("textures/blocks/gem.png"), Color.RED)
	var resources := ResourceManager.new()
	resources.register_namespace_root("gem", root)
	var image := resources.load_image("gem:blocks/gem")
	assert_not_null(image)
	assert_eq(image.get_format(), Image.FORMAT_RGBA8)
	assert_true(image.get_pixel(1, 1).is_equal_approx(Color.RED))
	_png(pack.path_join("gem/textures/blocks/gem.png"), Color.BLUE)
	resources.add_resource_pack(pack)
	resources.clear_cache()
	assert_true(resources.load_image("gem:blocks/gem").get_pixel(1, 1).is_equal_approx(Color.BLUE), "resource pack wins")


func test_placeholder_report() -> void:
	var resources := ResourceManager.new()
	resources.register_namespace_root("gem", "user://nowhere")
	assert_null(resources.load_image("gem:blocks/none"))
	resources.note_placeholder(ResourceManager.TEXTURES, "gem:blocks/none")
	resources.note_placeholder(ResourceManager.TEXTURES, "gem:blocks/none")
	var report := resources.get_placeholder_report()
	assert_eq(report.size(), 1)
	assert_eq(report[0].expected, "user://nowhere/textures/blocks/none.png")


func test_gltf_model_from_external_folder() -> void:
	var root := temp_dir("mod_c")
	DirAccess.make_dir_recursive_absolute(root.path_join("models/entities"))
	var scene := Node3D.new()
	scene.name = "Golem"
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Body"
	mesh_instance.mesh = BoxMesh.new()
	scene.add_child(mesh_instance)
	mesh_instance.owner = scene
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert_eq(document.append_from_scene(scene, state), OK)
	var path := root.path_join("models/entities/golem.glb")
	assert_eq(document.write_to_filesystem(state, path), OK)
	scene.free()
	var resources := ResourceManager.new()
	resources.register_namespace_root("gem", root)
	var model := resources.instantiate_model("gem:entities/golem")
	assert_not_null(model, "glb loaded at runtime from outside res://")
	if model != null:
		assert_true(model.find_child("Body*", true, false) != null or model.get_child_count() > 0)
		model.free()


func test_character_model_placeholder_and_attachments() -> void:
	var definition := ModelDefinition.new()
	definition.id = "test:hero"
	definition.scene = "test:entities/hero"
	definition.placeholder = {"type": "humanoid"}
	var resources := ResourceManager.new()
	resources.register_namespace_root("test", "user://nowhere")
	var model := CharacterModel.new()
	model.build(definition, resources, Vector3(0.6, 1.8, 0.6))
	assert_true(model.is_placeholder)
	for point in ModelDefinition.ATTACHMENT_POINTS:
		assert_not_null(model.get_attachment_point(point), "attachment point %s exists" % point)
	var sword := Node3D.new()
	assert_true(model.attach("right_hand", sword))
	assert_eq(sword.get_parent(), model.get_attachment_point("right_hand"))
	Log.muted = true
	var tail := Node3D.new()
	assert_false(model.attach("tail", tail), "unknown point refused")
	tail.free()
	assert_eq(resources.get_placeholder_report().size(), 1, "missing model recorded")
	model.free()
