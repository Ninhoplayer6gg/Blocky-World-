class_name BlockRegistry
extends Registry
## Registry of block types. Assigns compact runtime ids (air is always 0) used
## by chunk storage and meshing.

const AIR_ID := "blockyworld:air"
const AIR := 0

var _by_runtime: Array[BlockDefinition] = []


func _init() -> void:
	super("blockyworld:blocks")
	var air := BlockDefinition.new()
	air.id = AIR_ID
	air.display_name = "Air"
	air.solid = false
	air.collision = false
	air.transparent = true
	air.render_layer = BlockDefinition.RenderLayer.NONE
	air.hardness = -1.0
	air.has_item = false
	air.replaceable = true
	air.source_mod = GameInfo.CORE_NAMESPACE
	register(air)


func _on_registered(entry: Object) -> void:
	var definition := entry as BlockDefinition
	definition.runtime_id = _by_runtime.size()
	_by_runtime.append(definition)


func get_block(id: String) -> BlockDefinition:
	return get_entry(id) as BlockDefinition


func get_by_runtime(runtime_id: int) -> BlockDefinition:
	if runtime_id < 0 or runtime_id >= _by_runtime.size():
		return null
	return _by_runtime[runtime_id]


## Runtime id for a namespaced id, or -1 when unknown.
func get_runtime_id(id: String) -> int:
	var definition := get_block(id)
	return definition.runtime_id if definition != null else -1


func runtime_count() -> int:
	return _by_runtime.size()


## Creates a stand-in for a block saved in a world whose mod is not loaded.
## Allowed after freezing because it is part of binding a world, not content
## registration. The placeholder keeps the original id so it is saved back.
func create_missing_placeholder(original_id: String) -> BlockDefinition:
	var existing := get_block(original_id)
	if existing != null:
		return existing
	var definition := BlockDefinition.new()
	definition.id = original_id
	definition.display_name = "Missing: %s" % original_id
	definition.missing = true
	definition.hardness = 1.0
	definition.has_item = false
	definition.source_mod = NamespacedId.namespace_of(original_id)
	definition.textures = {}
	_entries[original_id] = definition
	_ordered.append(definition)
	_on_registered(definition)
	return definition


## Hot reload: update existing definitions in place (runtime ids stay valid)
## and append new ones. Returns {"updated": n, "added": [ids], "removed": [ids]}.
func merge_reload(staged: BlockRegistry) -> Dictionary:
	var added: PackedStringArray = []
	var updated := 0
	for entry in staged.entries():
		var incoming := entry as BlockDefinition
		var current := get_block(incoming.id)
		if current != null:
			current.copy_data_from(incoming)
			current.source_mod = incoming.source_mod
			updated += 1
		else:
			_entries[incoming.id] = incoming
			_ordered.append(incoming)
			_on_registered(incoming)
			added.append(incoming.id)
	var removed: PackedStringArray = []
	for definition in _by_runtime:
		if not definition.missing and not staged.has(definition.id):
			removed.append(definition.id)
	return {"updated": updated, "added": added, "removed": removed}
