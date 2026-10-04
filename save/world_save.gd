class_name WorldSave
extends RefCounted
## One world folder on disk:
##
##   <world>/world.json   metadata + block palette (JSON, human readable)
##   <world>/player.json  player state
##   <world>/chunks/      modified chunks (binary, see ChunkSerializer)
##
## The block palette maps stable "world ids" (used inside chunk files) to
## namespaced block ids. Runtime ids are remapped on load, so a world keeps
## working when mods are added, removed or load in a different order.

const FORMAT := "blockyworld.world"
const METADATA_FILE := "world.json"
const PLAYER_FILE := "player.json"
const CHUNKS_DIR := "chunks"

var directory: String = ""
var metadata: Dictionary = {}
var palette: PackedStringArray = PackedStringArray()
var runtime_to_world := PackedInt32Array()
var world_to_runtime := PackedInt32Array()
var storage: ChunkStorage
## Block ids in the palette that no loaded mod provides.
var missing_blocks: PackedStringArray = PackedStringArray()


static func create(world_directory: String, world_name: String, world_seed: int, generator_id: String,
		generator_version: int, mods: Array, creative: bool) -> WorldSave:
	var save := WorldSave.new()
	save.directory = world_directory
	var now := Time.get_datetime_string_from_system(true)
	save.metadata = {
		"format": FORMAT,
		"save_version": GameInfo.SAVE_VERSION,
		"game_version": GameInfo.GAME_VERSION,
		"name": world_name,
		"seed": world_seed,
		"generator": generator_id,
		"generator_version": generator_version,
		"creative": creative,
		"created_at": now,
		"last_played": now,
		"mods": mods,
	}
	save.palette = PackedStringArray([BlockRegistry.AIR_ID])
	DirAccess.make_dir_recursive_absolute(world_directory)
	save.storage = ChunkStorage.new(world_directory.path_join(CHUNKS_DIR))
	return save


## Returns {"save": WorldSave or null, "error": String}.
static func open(world_directory: String) -> Dictionary:
	var path := world_directory.path_join(METADATA_FILE)
	if not SafeFile.exists(path):
		return {"save": null, "error": "%s not found" % path}
	var json := JSON.new()
	if json.parse(SafeFile.read_text(path)) != OK:
		return {"save": null, "error": "%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()]}
	if not json.data is Dictionary or json.data.get("format") != FORMAT:
		return {"save": null, "error": "%s is not a Blocky World save" % path}
	var migrated := SaveMigrations.migrate_world(json.data)
	if not migrated.ok:
		return {"save": null, "error": migrated.error}
	var data: Dictionary = migrated.data
	var save := WorldSave.new()
	save.directory = world_directory
	save.metadata = data
	for id in data.get("block_palette", [BlockRegistry.AIR_ID]):
		save.palette.append(str(id))
	if save.palette.is_empty() or save.palette[0] != BlockRegistry.AIR_ID:
		return {"save": null, "error": "block palette is corrupt (entry 0 must be %s)" % BlockRegistry.AIR_ID}
	save.storage = ChunkStorage.new(world_directory.path_join(CHUNKS_DIR))
	return {"save": save, "error": ""}


func get_name() -> String:
	return str(metadata.get("name", directory.get_file()))


func get_seed() -> int:
	return int(metadata.get("seed", 0))


func get_generator() -> String:
	return str(metadata.get("generator", GameConfig.DEFAULT_GENERATOR))


func is_creative() -> bool:
	return bool(metadata.get("creative", false))


## Mods recorded in the save that are not loaded now: [{id, version}].
func find_missing_mods(content: GameContent) -> Array:
	var missing: Array = []
	for mod in metadata.get("mods", []):
		var loaded := content.get_mod(str(mod.get("id", "")))
		if loaded == null or loaded.state != ModEntry.State.LOADED:
			missing.append(mod)
	return missing


## Connects the palette to the block registry: every registered block gets a
## world id, and palette entries without a registered block get a "missing"
## placeholder that preserves their id. Main thread, before chunks load.
func bind_blocks(blocks: BlockRegistry) -> void:
	missing_blocks.clear()
	for id in palette:
		if not blocks.has(id):
			blocks.create_missing_placeholder(id)
			missing_blocks.append(id)
	for entry in blocks.entries():
		var definition := entry as BlockDefinition
		# Placeholders created for another world are not part of this one.
		if not definition.missing and not palette.has(definition.id):
			palette.append(definition.id)
	runtime_to_world = PackedInt32Array()
	runtime_to_world.resize(blocks.runtime_count())
	runtime_to_world.fill(-1)
	world_to_runtime = PackedInt32Array()
	world_to_runtime.resize(palette.size())
	for world_id in palette.size():
		var runtime_id := blocks.get_runtime_id(palette[world_id])
		world_to_runtime[world_id] = runtime_id
		if runtime_id >= 0:
			runtime_to_world[runtime_id] = world_id
	if not missing_blocks.is_empty():
		Log.warn("SAVE", "World uses %d block type(s) from missing mods, kept as placeholders: %s" % [missing_blocks.size(), ", ".join(missing_blocks)])


func save_metadata(content: GameContent) -> Error:
	metadata["save_version"] = GameInfo.SAVE_VERSION
	metadata["game_version"] = GameInfo.GAME_VERSION
	metadata["last_played"] = Time.get_datetime_string_from_system(true)
	metadata["block_palette"] = Array(palette)
	var mods: Array = content.active_mod_list()
	# Keep entries of missing mods so their content is still flagged next time.
	for previous in metadata.get("mods", []):
		var known := false
		for mod in mods:
			if mod.id == previous.get("id"):
				known = true
				break
		if not known:
			mods.append(previous)
	metadata["mods"] = mods
	var err := SafeFile.write_text(directory.path_join(METADATA_FILE), JSON.stringify(metadata, "\t"))
	if err != OK:
		Log.error("SAVE", "Could not write %s (error %d)" % [METADATA_FILE, err])
	return err


func load_player_data() -> Dictionary:
	var path := directory.path_join(PLAYER_FILE)
	if not SafeFile.exists(path):
		return {}
	var json := JSON.new()
	if json.parse(SafeFile.read_text(path)) != OK or not json.data is Dictionary:
		Log.error("SAVE", "%s is corrupt (line %d: %s); player starts at spawn" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data


func save_player_data(data: Dictionary) -> Error:
	var err := SafeFile.write_text(directory.path_join(PLAYER_FILE), JSON.stringify(data, "\t"))
	if err != OK:
		Log.error("SAVE", "Could not write %s (error %d)" % [PLAYER_FILE, err])
	return err
