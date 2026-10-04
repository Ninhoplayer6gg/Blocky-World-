class_name ItemIcons
extends RefCounted
## Resolves inventory icons: explicit icon texture > block icon for block
## items > generated placeholder. Unknown items (missing mod) get the missing
## texture so they stay visible.

var _items: ItemRegistry
var _blocks: BlockRegistry
var _block_textures: BlockTextures
var _resources: ResourceManager
var _cache: Dictionary = {}


func _init(items: ItemRegistry, blocks: BlockRegistry, block_textures: BlockTextures, resources: ResourceManager) -> void:
	_items = items
	_blocks = blocks
	_block_textures = block_textures
	_resources = resources


func get_icon(item_id: String) -> Texture2D:
	if _cache.has(item_id):
		return _cache[item_id]
	var texture := _build(item_id)
	_cache[item_id] = texture
	return texture


func clear() -> void:
	_cache.clear()


func _build(item_id: String) -> Texture2D:
	var definition := _items.get_item(item_id)
	if definition == null:
		return ImageTexture.create_from_image(PlaceholderFactory.missing_texture(32))
	if not definition.icon.is_empty():
		var texture := _resources.load_texture(definition.icon)
		if texture != null:
			return texture
		_resources.note_placeholder(ResourceManager.TEXTURES, definition.icon)
	if definition.is_placeable():
		var runtime_id := _blocks.get_runtime_id(definition.places_block)
		if runtime_id > 0:
			var block_icon := _block_textures.get_block_icon(runtime_id)
			if block_icon != null:
				return block_icon
	return ImageTexture.create_from_image(PlaceholderFactory.item_icon(definition.placeholder_color))
