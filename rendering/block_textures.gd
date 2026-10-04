class_name BlockTextures
extends RefCounted
## Builds the Texture2DArray containing every block face texture, the two
## block materials (opaque, cutout) and block icons. Main thread only.
##
## Texture resolution: real PNGs from ResourceManager when present, otherwise
## a generated placeholder in the block's placeholder colour. All layers share
## one size: the largest real texture found (default 16x16).

const OPAQUE_SHADER := preload("res://rendering/shaders/block_opaque.gdshader")
const CUTOUT_SHADER := preload("res://rendering/shaders/block_cutout.gdshader")
const MISSING_KEY := "@missing"

var texture_array: Texture2DArray
var opaque_material: ShaderMaterial
var cutout_material: ShaderMaterial
var tile_size := GameConfig.BLOCK_TEXTURE_SIZE
var _layers: Dictionary = {}
var _layer_images: Array[Image] = []
var _icons: Dictionary = {}
var _blocks: BlockRegistry


func build(blocks: BlockRegistry, resources: ResourceManager) -> void:
	_blocks = blocks
	_layers.clear()
	_icons.clear()
	var order: PackedStringArray = [MISSING_KEY]
	var real: Dictionary = {}
	var generated: Dictionary = {}
	for entry in blocks.entries():
		var definition := entry as BlockDefinition
		if definition.render_layer == BlockDefinition.RenderLayer.NONE:
			continue
		for face in 6:
			var key := face_key(definition, face)
			if key == MISSING_KEY or real.has(key) or generated.has(key):
				continue
			order.append(key)
			var image: Image = null
			if not key.begins_with("@"):
				image = resources.load_image(key)
				if image == null:
					resources.note_placeholder(ResourceManager.TEXTURES, key)
			else:
				resources.note_placeholder(ResourceManager.TEXTURES, "%s (no texture declared)" % definition.id)
			if image != null:
				real[key] = image
			else:
				generated[key] = [definition.get_face_placeholder_color(face),
					definition.render_layer == BlockDefinition.RenderLayer.CUTOUT]

	tile_size = GameConfig.BLOCK_TEXTURE_SIZE
	for key in real:
		var image: Image = real[key]
		tile_size = maxi(tile_size, maxi(image.get_width(), image.get_height()))

	_layer_images.clear()
	for i in order.size():
		var key := order[i]
		var image: Image
		if key == MISSING_KEY:
			image = PlaceholderFactory.missing_texture(tile_size)
		elif real.has(key):
			image = (real[key] as Image).duplicate()
			if image.get_width() != tile_size or image.get_height() != tile_size:
				Log.warn("RENDER", "Texture %s is %dx%d; resized to %dx%d (all block textures share the largest size, keep them square and equal)" % [
					key, image.get_width(), image.get_height(), tile_size, tile_size])
				image.resize(tile_size, tile_size, Image.INTERPOLATE_NEAREST)
		else:
			var spec: Array = generated[key]
			image = PlaceholderFactory.block_texture(spec[0], tile_size, key.hash(), spec[1])
		_layers[key] = i
		_layer_images.append(image)

	var gpu_images: Array[Image] = []
	for image in _layer_images:
		var copy := image.duplicate() as Image
		copy.generate_mipmaps()
		gpu_images.append(copy)
	texture_array = Texture2DArray.new()
	var err := texture_array.create_from_images(gpu_images)
	if err != OK:
		Log.error("RENDER", "Could not create block texture array (error %d)" % err)
	opaque_material = _make_material(OPAQUE_SHADER)
	cutout_material = _make_material(CUTOUT_SHADER)
	Log.info("RENDER", "Block textures: %d layers at %dx%d (%d from files, %d placeholders)" % [
		order.size(), tile_size, tile_size, real.size(), generated.size()])


## Key identifying the image used by a block face.
func face_key(definition: BlockDefinition, face: int) -> String:
	if definition.missing:
		return MISSING_KEY
	var texture_id := definition.get_face_texture(face)
	if not texture_id.is_empty():
		return texture_id
	return "@placeholder:%s:%s" % [definition.id, definition.get_face_placeholder_color(face).to_html()]


func layer_for(definition: BlockDefinition, face: int) -> int:
	return _layers.get(face_key(definition, face), 0)


func layer_count() -> int:
	return _layer_images.size()


func get_face_image(definition: BlockDefinition, face: int) -> Image:
	return _layer_images[layer_for(definition, face)]


func build_meshing_context() -> MeshingContext:
	return MeshingContext.build(_blocks, layer_for)


func get_block_icon(runtime_id: int) -> Texture2D:
	if _icons.has(runtime_id):
		return _icons[runtime_id]
	var definition := _blocks.get_by_runtime(runtime_id)
	if definition == null or definition.render_layer == BlockDefinition.RenderLayer.NONE or _layer_images.is_empty():
		return null
	var image := IconRenderer.block_icon(
		get_face_image(definition, BlockDefinition.Face.TOP),
		get_face_image(definition, BlockDefinition.Face.SOUTH),
		get_face_image(definition, BlockDefinition.Face.EAST))
	var texture := ImageTexture.create_from_image(image)
	_icons[runtime_id] = texture
	return texture


func _make_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("block_textures", texture_array)
	return material
