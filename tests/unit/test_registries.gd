extends TestCase


func _block(id: String) -> BlockDefinition:
	var block := BlockDefinition.new()
	block.id = id
	return block


func test_air_is_runtime_zero() -> void:
	var blocks := BlockRegistry.new()
	assert_eq(blocks.get_runtime_id(BlockRegistry.AIR_ID), 0)
	assert_true(blocks.get_by_runtime(0).is_air())


func test_runtime_ids_follow_registration_order() -> void:
	var blocks := BlockRegistry.new()
	assert_eq(blocks.register(_block("blockyworld:stone")), OK)
	assert_eq(blocks.register(_block("mymod:ruby_block")), OK)
	assert_eq(blocks.get_runtime_id("blockyworld:stone"), 1)
	assert_eq(blocks.get_runtime_id("mymod:ruby_block"), 2)
	assert_eq(blocks.get_by_runtime(2).id, "mymod:ruby_block")
	assert_eq(blocks.get_runtime_id("nope:nothing"), -1)
	assert_null(blocks.get_by_runtime(99))


func test_rejects_duplicates_and_invalid_ids() -> void:
	var blocks := BlockRegistry.new()
	assert_eq(blocks.register(_block("blockyworld:stone")), OK)
	assert_eq(blocks.register(_block("blockyworld:stone")), ERR_ALREADY_EXISTS)
	assert_contains(blocks.last_error, "duplicate")
	assert_eq(blocks.register(_block("Stone")), ERR_INVALID_PARAMETER)


func test_frozen_registry_refuses_registration() -> void:
	var blocks := BlockRegistry.new()
	blocks.freeze()
	assert_eq(blocks.register(_block("blockyworld:late")), ERR_LOCKED)
	assert_contains(blocks.last_error, "frozen")


func test_missing_placeholder_allowed_after_freeze() -> void:
	var blocks := BlockRegistry.new()
	blocks.freeze()
	var placeholder := blocks.create_missing_placeholder("gone:block")
	assert_true(placeholder.missing)
	assert_eq(blocks.get_runtime_id("gone:block"), placeholder.runtime_id)
	assert_eq(blocks.create_missing_placeholder("gone:block"), placeholder, "idempotent")


func test_merge_reload_keeps_runtime_ids() -> void:
	var live := BlockRegistry.new()
	var stone := _block("blockyworld:stone")
	stone.hardness = 1.0
	live.register(stone)
	var staged := BlockRegistry.new()
	var stone2 := _block("blockyworld:stone")
	stone2.hardness = 9.0
	staged.register(_block("blockyworld:new_block"))
	staged.register(stone2)
	var report := live.merge_reload(staged)
	assert_eq(live.get_runtime_id("blockyworld:stone"), 1, "existing id unchanged")
	assert_eq(live.get_block("blockyworld:stone").hardness, 9.0, "data updated in place")
	assert_eq(live.get_runtime_id("blockyworld:new_block"), 2, "new block appended")
	assert_eq(report.added.size(), 1)


func test_item_registry_and_script_types() -> void:
	var items := ItemRegistry.new()
	var item := ItemDefinition.new()
	item.id = "example:ruby"
	item.max_stack = 16
	assert_eq(items.register(item), OK)
	assert_eq(items.max_stack_of("example:ruby"), 16)
	assert_eq(items.max_stack_of("unknown:item"), 64, "default stack size for unknown items")
	var components := ScriptTypeRegistry.new("test:components")
	assert_eq(components.register_type("test:health", HealthComponent), OK)
	var component := components.create("test:health")
	assert_true(component is HealthComponent)
	component.free()
	assert_null(components.create("test:nothing"))


func test_face_texture_resolution() -> void:
	var block := _block("blockyworld:grass")
	block.textures = {"top": "a:top", "side": "a:side", "all": "a:all"}
	assert_eq(block.get_face_texture(BlockDefinition.Face.TOP), "a:top")
	assert_eq(block.get_face_texture(BlockDefinition.Face.NORTH), "a:side")
	assert_eq(block.get_face_texture(BlockDefinition.Face.BOTTOM), "a:all")
	block.textures["north"] = "a:north"
	assert_eq(block.get_face_texture(BlockDefinition.Face.NORTH), "a:north")
