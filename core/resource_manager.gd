class_name ResourceManager
extends RefCounted
## Single entry point for loading content assets by namespaced id.
## Code never builds asset paths itself; it asks for e.g. the texture
## "blockyworld:blocks/stone" and this class finds the file.
##
## Asset id -> file:  <root>/<type>/<path>.<ext>
##   "example:blocks/ruby_block" (texture) -> <example pack>/textures/blocks/ruby_block.png
##
## Lookup order for a namespace: resource packs (added with add_resource_pack,
## layout <pack>/<namespace>/<type>/...) first, then the mod/pack that owns the
## namespace. Missing assets are recorded so the caller can fall back to a
## placeholder and `/assets` can list what still needs to be produced.

const TEXTURES := "textures"
const MODELS := "models"
const SOUNDS := "sounds"
const ANIMATIONS := "animations"

const EXTENSIONS := {
	TEXTURES: ["png"],
	MODELS: ["glb", "gltf", "tscn", "scn"],
	SOUNDS: ["ogg", "wav", "mp3"],
	ANIMATIONS: ["res", "tres", "glb"],
}

var _namespace_roots: Dictionary = {}
var _resource_packs: PackedStringArray = PackedStringArray()
var _image_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _scene_cache: Dictionary = {}
var _placeholders: Dictionary = {}


func register_namespace_root(ns: String, root_dir: String) -> void:
	var roots: PackedStringArray = _namespace_roots.get(ns, PackedStringArray())
	if not roots.has(root_dir):
		roots.append(root_dir)
	_namespace_roots[ns] = roots


func add_resource_pack(root_dir: String) -> void:
	if not _resource_packs.has(root_dir):
		_resource_packs.insert(0, root_dir)


func has_namespace(ns: String) -> bool:
	return _namespace_roots.has(ns)


func get_namespace_roots(ns: String) -> PackedStringArray:
	return _namespace_roots.get(ns, PackedStringArray())


## Returns the existing file for an asset, or "" when none exists.
func resolve(type: String, asset_id: String) -> String:
	if not NamespacedId.is_valid(asset_id):
		return ""
	var ns := NamespacedId.get_namespace(asset_id)
	var rel := NamespacedId.get_path(asset_id)
	for candidate_root in _candidate_roots(ns):
		for ext in EXTENSIONS.get(type, []):
			var path := "%s/%s/%s.%s" % [candidate_root, type, rel, ext]
			if FileAccess.file_exists(path) or ResourceLoader.exists(path):
				return path
	return ""


## Where a modder/artist should place a file for this asset id.
func expected_path(type: String, asset_id: String) -> String:
	var ns := NamespacedId.get_namespace(asset_id)
	var roots := get_namespace_roots(ns)
	var root := roots[0] if not roots.is_empty() else "<pack of '%s'>" % ns
	var ext: String = EXTENSIONS.get(type, [""])[0]
	return "%s/%s/%s.%s" % [root, type, NamespacedId.get_path(asset_id), ext]


## Loads an Image (RGBA8, no mipmaps) or returns null when the asset is missing.
func load_image(asset_id: String) -> Image:
	if _image_cache.has(asset_id):
		return _image_cache[asset_id]
	var path := resolve(TEXTURES, asset_id)
	if path.is_empty():
		return null
	var image := _read_image(path)
	if image == null:
		Log.error("RES", "Texture %s exists at %s but could not be decoded" % [asset_id, path])
		return null
	_image_cache[asset_id] = image
	return image


func load_texture(asset_id: String) -> Texture2D:
	if _texture_cache.has(asset_id):
		return _texture_cache[asset_id]
	var image := load_image(asset_id)
	if image == null:
		return null
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[asset_id] = texture
	return texture


## Instantiates a model scene (.glb/.gltf/.tscn) or returns null when missing.
func instantiate_model(asset_id: String) -> Node3D:
	var scene: PackedScene = _scene_cache.get(asset_id)
	if scene == null:
		var path := resolve(MODELS, asset_id)
		if path.is_empty():
			return null
		scene = _load_scene(path)
		if scene == null:
			Log.error("RES", "Model %s exists at %s but could not be loaded" % [asset_id, path])
			return null
		_scene_cache[asset_id] = scene
	var node := scene.instantiate()
	if node is Node3D:
		return node
	Log.error("RES", "Model %s root is %s, expected a Node3D" % [asset_id, node.get_class()])
	node.free()
	return null


## Records that a placeholder stands in for a missing asset.
func note_placeholder(type: String, asset_id: String) -> void:
	var key := "%s|%s" % [type, asset_id]
	if _placeholders.has(key):
		return
	_placeholders[key] = {"type": type, "id": asset_id, "expected": expected_path(type, asset_id)}
	Log.debug("RES", "Placeholder used for %s %s (expected at %s)" % [type, asset_id, _placeholders[key].expected])


## [{type, id, expected}] for every asset currently replaced by a placeholder.
func get_placeholder_report() -> Array:
	return _placeholders.values()


func clear_cache() -> void:
	_image_cache.clear()
	_texture_cache.clear()
	_scene_cache.clear()
	_placeholders.clear()


func _candidate_roots(ns: String) -> PackedStringArray:
	var roots := PackedStringArray()
	for pack in _resource_packs:
		roots.append("%s/%s" % [pack, ns])
	roots.append_array(get_namespace_roots(ns))
	return roots


func _read_image(path: String) -> Image:
	var image: Image = null
	# Raw files first: works for external mods and picks up edited PNGs on
	# /reload without a reimport. Exported builds only contain the imported
	# version for res:// files, which is the fallback.
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		image = Image.new()
		if image.load_png_from_buffer(bytes) != OK:
			image = null
	if image == null and path.begins_with("res://") and ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			image = texture.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _load_scene(path: String) -> PackedScene:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var resource := load(path)
		if resource is PackedScene:
			return resource
	var ext := path.get_extension().to_lower()
	if ext != "glb" and ext != "gltf":
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(path, state)
	if err != OK:
		Log.error("RES", "glTF import of %s failed (error %d)" % [path, err])
		return null
	var root := document.generate_scene(state)
	if root == null:
		return null
	var packed := PackedScene.new()
	err = packed.pack(root)
	root.free()
	return packed if err == OK else null
