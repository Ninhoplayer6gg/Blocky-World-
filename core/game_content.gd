class_name GameContent
extends RefCounted
## Result of the boot pipeline: frozen registries, the mod list with their
## states, asset resolution and the render resources derived from content.

var registries := ContentRegistries.new()
var resources := ResourceManager.new()
## Every discovered mod/pack, including disabled and failed ones.
var mods: Array[ModEntry] = []
## Successfully loaded mods in load order.
var load_order: Array[ModEntry] = []
var block_textures: BlockTextures
var meshing_context: MeshingContext
var item_icons: ItemIcons


func get_mod(mod_id: String) -> ModEntry:
	for mod in mods:
		if mod.get_id() == mod_id:
			return mod
	return null


func failed_mods() -> Array[ModEntry]:
	var result: Array[ModEntry] = []
	for mod in mods:
		if mod.state == ModEntry.State.ERROR or not mod.errors.is_empty():
			result.append(mod)
	return result


## [{id, version}] of loaded mods, stored in world metadata.
func active_mod_list() -> Array:
	var result: Array = []
	for mod in load_order:
		result.append({"id": mod.get_id(), "version": mod.manifest.version})
	return result


## Builds textures, materials and lookup tables. Main thread only; requires
## a rendering server (works with the headless dummy renderer too).
func build_render_resources() -> void:
	block_textures = BlockTextures.new()
	block_textures.build(registries.blocks, resources)
	meshing_context = block_textures.build_meshing_context()
	item_icons = ItemIcons.new(registries.items, registries.blocks, block_textures, resources)


## Call after the block registry grew (missing-block placeholders).
func refresh_block_tables() -> void:
	if block_textures != null:
		block_textures.build(registries.blocks, resources)
		meshing_context = block_textures.build_meshing_context()
		item_icons.clear()
