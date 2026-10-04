class_name ContentParsers
extends RefCounted
## JSON -> definition converters for every declarative content type. The
## accepted fields are documented in docs/ContentPacks.md. Each parser returns
## null when the definition has errors (reported through `fields`).

const BLOCK_KEYS := ["id", "display_name", "texture", "textures", "placeholder_color", "hardness",
	"solid", "transparent", "collision", "light", "render", "cull_same", "replaceable", "tags",
	"drops", "item", "comment"]
const ITEM_KEYS := ["id", "display_name", "icon", "placeholder_color", "max_stack", "places_block",
	"tags", "properties", "comment"]
const ATTRIBUTE_KEYS := ["id", "display_name", "default", "min", "max", "comment"]
const BIOME_KEYS := ["id", "display_name", "temperature", "humidity", "surface_block",
	"subsurface_block", "subsurface_depth", "stone_block", "height_offset", "height_variation",
	"features", "comment"]
const MODEL_KEYS := ["id", "scene", "scale", "placeholder", "attachment_bones", "animations", "comment"]
const ENTITY_KEYS := ["id", "display_name", "model", "width", "height", "eye_height", "attributes",
	"components", "tags", "comment"]
const FACE_KEYS := ["all", "side", "top", "bottom", "east", "west", "south", "north"]
const RENDER_MODES := {
	"opaque": BlockDefinition.RenderLayer.OPAQUE,
	"cutout": BlockDefinition.RenderLayer.CUTOUT,
	"none": BlockDefinition.RenderLayer.NONE,
}


static func parse_block(data: Dictionary, fields: JsonFields, ns: String) -> BlockDefinition:
	fields.check_keys(data, BLOCK_KEYS)
	var block := BlockDefinition.new()
	block.id = fields.get_id(data, "id", ns, true)
	block.display_name = fields.get_string(data, "display_name", _default_name(block.id))
	if data.has("texture"):
		block.textures["all"] = fields.get_id(data, "texture", ns)
	for face in fields.get_dict(data, "textures"):
		if not FACE_KEYS.has(face):
			fields.error("unknown texture face '%s' (use %s)" % [face, ", ".join(FACE_KEYS)])
			continue
		var value: Variant = data["textures"][face]
		if typeof(value) != TYPE_STRING:
			fields.error("texture for face '%s' must be a string id" % face)
			continue
		block.textures[face] = fields.qualify_id(value, ns, "textures." + face)
	if data.get("placeholder_color") is Dictionary:
		for face in data["placeholder_color"]:
			if FACE_KEYS.has(face):
				block.placeholder_colors[face] = fields.parse_color(data["placeholder_color"][face], "placeholder_color." + face, Color.MAGENTA)
			else:
				fields.error("unknown placeholder_color face '%s'" % face)
	else:
		block.placeholder_color = fields.get_color(data, "placeholder_color", Color(0.8, 0.2, 0.8))
	block.hardness = fields.get_float(data, "hardness", 1.0)
	block.solid = fields.get_bool(data, "solid", true)
	block.transparent = fields.get_bool(data, "transparent", false)
	block.collision = fields.get_bool(data, "collision", block.solid)
	block.light = clampi(fields.get_int(data, "light", 0), 0, 15)
	block.cull_same = fields.get_bool(data, "cull_same", true)
	block.replaceable = fields.get_bool(data, "replaceable", false)
	block.tags = _qualified_list(fields.get_string_array(data, "tags"), ns, fields, "tags")
	var render := fields.get_string(data, "render", "cutout" if block.transparent else "opaque")
	if not RENDER_MODES.has(render):
		fields.error("'render' must be one of %s" % ", ".join(RENDER_MODES.keys()))
	else:
		block.render_layer = RENDER_MODES[render]
	if block.render_layer == BlockDefinition.RenderLayer.CUTOUT:
		block.transparent = true
	for drop in fields.get_array(data, "drops"):
		if not drop is Dictionary or typeof(drop.get("item")) != TYPE_STRING:
			fields.error("each drop must be {\"item\": id, \"count\": n}")
			continue
		var item_id := fields.qualify_id(drop["item"], ns, "drops.item")
		if not item_id.is_empty():
			block.drops.append({"item": item_id, "count": maxi(int(drop.get("count", 1)), 1)})
	if data.has("item"):
		var item: Variant = data["item"]
		if typeof(item) == TYPE_BOOL:
			block.has_item = item
		elif item is Dictionary:
			block.item_overrides = item
		else:
			fields.error("'item' must be false or an object of item fields")
	return block if fields.errors.is_empty() else null


static func parse_item(data: Dictionary, fields: JsonFields, ns: String) -> ItemDefinition:
	fields.check_keys(data, ITEM_KEYS)
	var item := ItemDefinition.new()
	item.id = fields.get_id(data, "id", ns, true)
	item.display_name = fields.get_string(data, "display_name", _default_name(item.id))
	item.icon = fields.get_id(data, "icon", ns)
	item.placeholder_color = fields.get_color(data, "placeholder_color", Color(0.8, 0.2, 0.8))
	item.max_stack = clampi(fields.get_int(data, "max_stack", 64), 1, 9999)
	item.places_block = fields.get_id(data, "places_block", ns)
	item.tags = _qualified_list(fields.get_string_array(data, "tags"), ns, fields, "tags")
	item.properties = fields.get_dict(data, "properties")
	return item if fields.errors.is_empty() else null


## Item generated for a block, optionally customised by the block's "item".
static func block_item(block: BlockDefinition, fields: JsonFields, ns: String) -> ItemDefinition:
	var data := block.item_overrides.duplicate()
	data["id"] = block.id
	if not data.has("display_name"):
		data["display_name"] = block.display_name
	data["places_block"] = block.id
	var item := parse_item(data, fields, ns)
	if item != null and not block.item_overrides.has("placeholder_color"):
		item.placeholder_color = block.get_face_placeholder_color(BlockDefinition.Face.SOUTH)
	return item


static func parse_attribute(data: Dictionary, fields: JsonFields, ns: String) -> AttributeDefinition:
	fields.check_keys(data, ATTRIBUTE_KEYS)
	var attribute := AttributeDefinition.new()
	attribute.id = fields.get_id(data, "id", ns, true)
	attribute.display_name = fields.get_string(data, "display_name", _default_name(attribute.id))
	attribute.default_value = fields.get_float(data, "default", 0.0)
	attribute.min_value = fields.get_float(data, "min", -INF)
	attribute.max_value = fields.get_float(data, "max", INF)
	if attribute.min_value > attribute.max_value:
		fields.error("'min' is greater than 'max'")
	return attribute if fields.errors.is_empty() else null


static func parse_biome(data: Dictionary, fields: JsonFields, ns: String) -> BiomeDefinition:
	fields.check_keys(data, BIOME_KEYS)
	var biome := BiomeDefinition.new()
	biome.id = fields.get_id(data, "id", ns, true)
	biome.display_name = fields.get_string(data, "display_name", _default_name(biome.id))
	biome.temperature = clampf(fields.get_float(data, "temperature", 0.5), 0.0, 1.0)
	biome.humidity = clampf(fields.get_float(data, "humidity", 0.5), 0.0, 1.0)
	biome.surface_block = fields.get_id(data, "surface_block", ns)
	biome.subsurface_block = fields.get_id(data, "subsurface_block", ns)
	biome.stone_block = fields.get_id(data, "stone_block", ns)
	if biome.surface_block.is_empty():
		biome.surface_block = "blockyworld:grass"
	if biome.subsurface_block.is_empty():
		biome.subsurface_block = "blockyworld:dirt"
	if biome.stone_block.is_empty():
		biome.stone_block = "blockyworld:stone"
	biome.subsurface_depth = clampi(fields.get_int(data, "subsurface_depth", 3), 0, 16)
	biome.height_offset = fields.get_float(data, "height_offset", 0.0)
	biome.height_variation = maxf(fields.get_float(data, "height_variation", 1.0), 0.0)
	for feature in fields.get_array(data, "features"):
		if not feature is Dictionary or typeof(feature.get("type")) != TYPE_STRING:
			fields.error("each feature needs a \"type\"")
			continue
		var copy: Dictionary = feature.duplicate(true)
		copy["type"] = fields.qualify_id(feature["type"], GameInfo.CORE_NAMESPACE, "features.type")
		for key in copy:
			if (key == "block" or key.ends_with("_block")) and typeof(copy[key]) == TYPE_STRING:
				copy[key] = fields.qualify_id(copy[key], ns, "features." + key)
		biome.features.append(copy)
	return biome if fields.errors.is_empty() else null


static func parse_model(data: Dictionary, fields: JsonFields, ns: String) -> ModelDefinition:
	fields.check_keys(data, MODEL_KEYS)
	var model := ModelDefinition.new()
	model.id = fields.get_id(data, "id", ns, true)
	model.scene = fields.get_id(data, "scene", ns)
	model.scale = fields.get_float(data, "scale", 1.0)
	model.placeholder = fields.get_dict(data, "placeholder")
	if model.placeholder.is_empty():
		model.placeholder = {"type": "box"}
	var bones := fields.get_dict(data, "attachment_bones")
	for point in bones:
		if not ModelDefinition.ATTACHMENT_POINTS.has(point):
			fields.warn("unknown attachment point '%s' (known: %s)" % [point, ", ".join(ModelDefinition.ATTACHMENT_POINTS)])
		model.attachment_bones[point] = str(bones[point])
	var animations := fields.get_dict(data, "animations")
	for logical in animations:
		model.animations[logical] = str(animations[logical])
	return model if fields.errors.is_empty() else null


static func parse_entity(data: Dictionary, fields: JsonFields, ns: String) -> EntityDefinition:
	fields.check_keys(data, ENTITY_KEYS)
	var entity := EntityDefinition.new()
	entity.id = fields.get_id(data, "id", ns, true)
	entity.display_name = fields.get_string(data, "display_name", _default_name(entity.id))
	entity.model = fields.get_id(data, "model", ns)
	entity.width = maxf(fields.get_float(data, "width", 0.6), 0.1)
	entity.height = maxf(fields.get_float(data, "height", 1.8), 0.1)
	entity.eye_height = clampf(fields.get_float(data, "eye_height", entity.height * 0.9), 0.0, entity.height)
	var attributes := fields.get_dict(data, "attributes")
	for attribute_id in attributes:
		var qualified := fields.qualify_id(attribute_id, ns, "attributes")
		var value: Variant = attributes[attribute_id]
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			fields.error("attribute '%s' must be a number" % attribute_id)
			continue
		entity.attributes[qualified] = float(value)
	for component in fields.get_array(data, "components"):
		if not component is Dictionary or typeof(component.get("type")) != TYPE_STRING:
			fields.error("each component needs a \"type\"")
			continue
		var copy: Dictionary = component.duplicate(true)
		copy["type"] = fields.qualify_id(component["type"], GameInfo.CORE_NAMESPACE, "components.type")
		entity.components.append(copy)
	entity.tags = _qualified_list(fields.get_string_array(data, "tags"), ns, fields, "tags")
	return entity if fields.errors.is_empty() else null


static func _qualified_list(values: PackedStringArray, ns: String, fields: JsonFields, label: String) -> PackedStringArray:
	var result := PackedStringArray()
	for value in values:
		var id := fields.qualify_id(value, ns, label)
		if not id.is_empty():
			result.append(id)
	return result


static func _default_name(id: String) -> String:
	return NamespacedId.path_of(id).get_file().replace("_", " ").capitalize()
