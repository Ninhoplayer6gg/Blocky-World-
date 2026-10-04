class_name ScriptTypeRegistry
extends Registry
## Registry mapping namespaced ids to code implementations (GDScript classes):
## entity components, world generators, terrain features. Content JSON refers
## to them by id. The future Lua API will register script-backed types here.

class ScriptType:
	extends RefCounted
	var id: String
	var implementation: Script
	var description: String


func register_type(id: String, implementation: Script, description: String = "") -> Error:
	var entry := ScriptType.new()
	entry.id = id
	entry.implementation = implementation
	entry.description = description
	var err := register(entry)
	if err != OK:
		Log.error("CORE", "Cannot register %s '%s': %s" % [registry_id, id, last_error])
	return err


func get_script_type(id: String) -> Script:
	var entry := get_entry(id) as ScriptType
	return entry.implementation if entry != null else null


## Instantiates the implementation for `id`, or returns null if unknown.
func create(id: String) -> Object:
	var implementation := get_script_type(id)
	if implementation == null:
		return null
	return implementation.new()
