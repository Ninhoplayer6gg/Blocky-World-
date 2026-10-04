class_name ContentLoader
extends RefCounted
## Registers declarative content (JSON content packs) from every loaded mod,
## base game included.
##
## Layout inside a mod:  content/<type>/*.json
## A file holds one definition object or an array of them. Types are loaded
## type by type across all mods (attributes, blocks, items, ...) so a mod's
## item can reference another mod's block regardless of file order.

const CONTENT_DIR := "content"
const TYPE_ORDER: PackedStringArray = ["attributes", "blocks", "items", "biomes", "models", "entities"]

var _registries: ContentRegistries


func _init(registries: ContentRegistries) -> void:
	_registries = registries


func load_mods(mods: Array[ModEntry]) -> void:
	for type in TYPE_ORDER:
		for mod in mods:
			if mod.is_loadable():
				_load_type(mod, type)
	for mod in mods:
		if mod.is_loadable():
			mod.state = ModEntry.State.LOADED


## Checks cross references once everything is registered. Problems are
## reported as warnings and the offending reference is dropped/replaced, so
## one bad reference does not take the whole mod down.
func validate_references(mods: Array[ModEntry]) -> void:
	var mod_by_ns := {}
	for mod in mods:
		mod_by_ns[mod.manifest.content_namespace] = mod
	for entry in _registries.blocks.entries():
		var block := entry as BlockDefinition
		var valid_drops: Array = []
		for drop in block.drops:
			if _registries.items.has(drop.item):
				valid_drops.append(drop)
			else:
				_warn(mod_by_ns, block.id, "block %s drops unknown item %s (drop ignored)" % [block.id, drop.item])
		block.drops = valid_drops
	for entry in _registries.items.entries():
		var item := entry as ItemDefinition
		if item.is_placeable() and not _registries.blocks.has(item.places_block):
			_warn(mod_by_ns, item.id, "item %s places unknown block %s (made non-placeable)" % [item.id, item.places_block])
			item.places_block = ""
	for entry in _registries.biomes.entries():
		var biome := entry as BiomeDefinition
		for key in ["surface_block", "subsurface_block", "stone_block"]:
			var block_id: String = biome.get(key)
			if not _registries.blocks.has(block_id):
				_warn(mod_by_ns, biome.id, "biome %s uses unknown block %s for %s (using blockyworld:stone)" % [biome.id, block_id, key])
				biome.set(key, "blockyworld:stone")
		var features: Array = []
		for feature in biome.features:
			if _registries.features.has(feature.type):
				features.append(feature)
			else:
				_warn(mod_by_ns, biome.id, "biome %s uses unknown feature type %s (feature ignored)" % [biome.id, feature.type])
		biome.features = features
	for entry in _registries.entities.entries():
		var entity := entry as EntityDefinition
		if not entity.model.is_empty() and not _registries.models.has(entity.model):
			_warn(mod_by_ns, entity.id, "entity %s uses unknown model %s (box placeholder used)" % [entity.id, entity.model])
			entity.model = ""
		for attribute_id in entity.attributes.keys():
			if not _registries.attributes.has(attribute_id):
				_warn(mod_by_ns, entity.id, "entity %s sets unknown attribute %s (ignored)" % [entity.id, attribute_id])
				entity.attributes.erase(attribute_id)
		var components: Array = []
		for component in entity.components:
			if _registries.components.has(component.type):
				components.append(component)
			else:
				_warn(mod_by_ns, entity.id, "entity %s uses unknown component %s (ignored)" % [entity.id, component.type])
		entity.components = components


func _load_type(mod: ModEntry, type: String) -> void:
	var dir := mod.path.path_join(CONTENT_DIR).path_join(type)
	if not DirAccess.dir_exists_absolute(dir):
		return
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	var ns := mod.manifest.content_namespace
	for file in files:
		if file.get_extension().to_lower() != "json":
			continue
		var label := "%s/%s/%s/%s" % [mod.get_id(), CONTENT_DIR, type, file]
		var text := FileAccess.get_file_as_string(dir.path_join(file))
		var json := JSON.new()
		if json.parse(text) != OK:
			_mod_error(mod, "%s line %d: %s" % [label, json.get_error_line(), json.get_error_message()])
			continue
		var definitions: Array = json.data if json.data is Array else [json.data]
		for data in definitions:
			if not data is Dictionary:
				_mod_error(mod, "%s: each definition must be a JSON object" % label)
				continue
			_register(mod, type, data, label, ns)


func _register(mod: ModEntry, type: String, data: Dictionary, label: String, ns: String) -> void:
	var fields := JsonFields.new(label)
	var definition: Object = null
	var registry: Registry = null
	match type:
		"attributes":
			definition = ContentParsers.parse_attribute(data, fields, ns)
			registry = _registries.attributes
		"blocks":
			definition = ContentParsers.parse_block(data, fields, ns)
			registry = _registries.blocks
		"items":
			definition = ContentParsers.parse_item(data, fields, ns)
			registry = _registries.items
		"biomes":
			definition = ContentParsers.parse_biome(data, fields, ns)
			registry = _registries.biomes
		"models":
			definition = ContentParsers.parse_model(data, fields, ns)
			registry = _registries.models
		"entities":
			definition = ContentParsers.parse_entity(data, fields, ns)
			registry = _registries.entities
	for warning in fields.warnings:
		mod.warnings.append(warning)
		Log.warn("CONTENT", warning)
	if definition == null:
		for message in fields.errors:
			_mod_error(mod, message)
		return
	var id: String = definition.get("id")
	if NamespacedId.get_namespace(id) != ns:
		_mod_error(mod, "%s: id '%s' must use the mod namespace '%s:'" % [label, id, ns])
		return
	definition.set("source_mod", mod.get_id())
	if registry.register(definition) != OK:
		_mod_error(mod, "%s: %s" % [label, registry.last_error])
		return
	mod.content_counts[type] = int(mod.content_counts.get(type, 0)) + 1
	if type == "blocks":
		_register_block_item(mod, definition as BlockDefinition, label, ns)


func _register_block_item(mod: ModEntry, block: BlockDefinition, label: String, ns: String) -> void:
	if not block.has_item or block.render_layer == BlockDefinition.RenderLayer.NONE:
		return
	var fields := JsonFields.new(label + " (item)")
	var item := ContentParsers.block_item(block, fields, ns)
	if item == null:
		for message in fields.errors:
			_mod_error(mod, message)
		return
	item.source_mod = mod.get_id()
	if _registries.items.register(item) != OK:
		_mod_error(mod, "%s: block item: %s" % [label, _registries.items.last_error])


func _mod_error(mod: ModEntry, message: String) -> void:
	mod.errors.append(message)
	Log.error("CONTENT", message)


func _warn(mod_by_ns: Dictionary, id: String, message: String) -> void:
	var mod: ModEntry = mod_by_ns.get(NamespacedId.get_namespace(id))
	if mod != null:
		mod.warnings.append(message)
	Log.warn("CONTENT", message)
