extends TestCase
## JSON content packs: parsing, namespace rules, block items, references.

var root := ""


func before_each() -> void:
	root = temp_dir("packs")


func _pack(folder: String, namespace_id: String, files: Dictionary) -> ModEntry:
	var mod_dir := root.path_join(folder)
	write_file(mod_dir.path_join("mod.json"), JSON.stringify({"id": folder, "name": folder, "version": "1.0.0", "namespace": namespace_id}))
	for path in files:
		var content: Variant = files[path]
		write_file(mod_dir.path_join("content").path_join(path), content if content is String else JSON.stringify(content))
	return ModLoader.new().read_entry(mod_dir, ModEntry.Source.USER)


func _load(mods: Array[ModEntry]) -> ContentRegistries:
	var registries := ContentRegistries.new()
	CoreRegistration.register_code_types(registries)
	var loader := ContentLoader.new(registries)
	loader.load_mods(mods)
	loader.validate_references(mods)
	return registries


func test_block_and_item_from_json() -> void:
	var mod := _pack("example_mod", "example", {
		"blocks/ruby_block.json": {"id": "example:ruby_block", "display_name": "Ruby Block", "hardness": 4,
			"solid": true, "texture": "blocks/ruby_block", "drops": [{"item": "ruby", "count": 2}]},
		"items/ruby.json": {"id": "ruby", "display_name": "Ruby", "max_stack": 16},
	})
	var mods: Array[ModEntry] = [mod]
	var registries := _load(mods)
	assert_true(mod.errors.is_empty(), str(mod.errors))
	var block := registries.blocks.get_block("example:ruby_block")
	assert_not_null(block)
	assert_eq(block.hardness, 4.0)
	assert_eq(block.get_face_texture(BlockDefinition.Face.TOP), "example:blocks/ruby_block", "texture ids are qualified")
	assert_eq(block.drops[0].item, "example:ruby", "bare ids get the mod namespace")
	assert_eq(block.source_mod, "example_mod")
	var block_item := registries.items.get_item("example:ruby_block")
	assert_not_null(block_item, "blocks get an item automatically")
	assert_eq(block_item.places_block, "example:ruby_block")
	assert_eq(registries.items.get_item("example:ruby").max_stack, 16)
	assert_eq(mod.state, ModEntry.State.LOADED)
	assert_eq(mod.content_counts, {"blocks": 1, "items": 1})


func test_array_files_and_render_modes() -> void:
	var mod := _pack("multi", "multi", {"blocks/many.json": [
		{"id": "glass", "render": "cutout", "item": false},
		{"id": "light", "light": 99, "placeholder_color": {"top": "#ff0000", "side": "#00ff00"}},
	]})
	var mods: Array[ModEntry] = [mod]
	var registries := _load(mods)
	var glass := registries.blocks.get_block("multi:glass")
	assert_eq(glass.render_layer, BlockDefinition.RenderLayer.CUTOUT)
	assert_true(glass.transparent, "cutout implies transparent")
	assert_false(registries.items.has("multi:glass"), "\"item\": false skips the block item")
	var light := registries.blocks.get_block("multi:light")
	assert_eq(light.light, 15, "light is clamped to 0..15")
	assert_eq(light.get_face_placeholder_color(BlockDefinition.Face.EAST), Color.html("#00ff00"))


func test_errors_are_reported_not_fatal() -> void:
	Log.muted = true
	var mod := _pack("messy", "messy", {
		"blocks/good.json": {"id": "good"},
		"blocks/bad_json.json": "{ nope",
		"blocks/bad_type.json": {"id": "typed", "hardness": "very"},
		"blocks/foreign.json": {"id": "othermod:stolen"},
		"blocks/dup.json": {"id": "good"},
		"items/broken_ref.json": {"id": "thing", "places_block": "missing_block"},
	})
	var mods: Array[ModEntry] = [mod]
	var registries := _load(mods)
	assert_true(registries.blocks.has("messy:good"), "valid definitions still load")
	assert_false(registries.blocks.has("messy:typed"))
	assert_false(registries.blocks.has("othermod:stolen"))
	var text := "\n".join(mod.errors)
	assert_contains(text, "bad_json.json line")
	assert_contains(text, "'hardness' must be a number")
	assert_contains(text, "must use the mod namespace")
	assert_contains(text, "duplicate id")
	assert_eq(registries.items.get_item("messy:thing").places_block, "", "dangling reference removed")
	assert_contains("\n".join(mod.warnings), "places unknown block")


func test_cross_mod_reference_resolves_by_type_order() -> void:
	var a := _pack("a_items", "aitems", {"items/gem.json": {"id": "gem", "places_block": "bblocks:gem_block"}})
	var b := _pack("b_blocks", "bblocks", {"blocks/gem_block.json": {"id": "gem_block", "item": false}})
	var mods: Array[ModEntry] = [a, b]
	var registries := _load(mods)
	assert_eq(registries.items.get_item("aitems:gem").places_block, "bblocks:gem_block", "blocks load before items across mods")


func test_entities_biomes_attributes() -> void:
	var mod := _pack("zoo", "zoo", {
		"attributes/mana.json": {"id": "mana", "default": 50, "min": 0, "max": 100},
		"blocks/moss.json": {"id": "moss"},
		"biomes/swamp.json": {"id": "swamp", "surface_block": "moss", "features": [{"type": "tree", "chance": 0.1}, {"type": "zoo:unknown"}]},
		"models/beast.json": {"id": "beast", "scene": "entities/beast", "placeholder": {"type": "box"}},
		"entities/beast.json": {"id": "beast", "model": "beast", "attributes": {"zoo:mana": 70, "blockyworld:nonexistent": 1},
			"components": [{"type": "movement"}, {"type": "zoo:fly_to_moon"}]},
	})
	var mods: Array[ModEntry] = [mod]
	Log.muted = true
	var registries := _load(mods)
	assert_eq(registries.attributes.get_attribute("zoo:mana").max_value, 100.0)
	var biome := registries.biomes.get_biome("zoo:swamp")
	assert_eq(biome.surface_block, "zoo:moss")
	assert_eq(biome.features.size(), 1, "unknown feature type dropped")
	assert_eq(biome.features[0].type, "blockyworld:tree", "feature types default to core namespace")
	var entity := registries.entities.get_entity("zoo:beast")
	assert_eq(entity.model, "zoo:beast")
	assert_eq(entity.attributes.keys(), ["zoo:mana"], "unknown attribute dropped")
	assert_eq(entity.components.size(), 1, "unknown component dropped")
	assert_eq(registries.models.get_model("zoo:beast").scene, "zoo:entities/beast")


func test_real_packs_load_through_pipeline() -> void:
	var pipeline := ContentPipeline.new()
	pipeline.search_paths = [
		{"path": "res://packs", "source": ModEntry.Source.BUILTIN},
		{"path": "res://mods", "source": ModEntry.Source.BUNDLED},
	]
	var content := pipeline.run()
	assert_eq(pipeline.phase, ContentPipeline.Phase.READY)
	assert_eq(content.load_order[0].get_id(), "blockyworld", "base pack loads first")
	assert_true(content.registries.blocks.has("blockyworld:stone"))
	assert_true(content.registries.blocks.has("example:ruby_block"), "example_mod block registered without engine changes")
	assert_true(content.registries.items.has("example:ruby"), "example_mod item registered")
	assert_true(content.registries.blocks.is_frozen(), "registries frozen after finalize")
	for mod in content.mods:
		assert_true(mod.errors.is_empty(), "%s has no errors: %s" % [mod.get_id(), mod.errors])
		assert_eq(mod.state, ModEntry.State.LOADED)
