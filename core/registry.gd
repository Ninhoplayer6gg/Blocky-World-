class_name Registry
extends RefCounted
## Generic namespaced registry. Content is added during the REGISTER_CONTENT
## boot phase only; once frozen, register() is refused so nothing can appear at
## a random point in time. Hot reload goes through a dedicated merge path.
##
## Entries are any Object with an `id` property. Registration order is kept and
## is deterministic (core first, then mods in dependency order).

var registry_id: String
var _entries: Dictionary = {}
var _ordered: Array = []
var _frozen := false
## Explains the most recent register() failure.
var last_error := ""


func _init(id: String) -> void:
	registry_id = id


## Returns OK or an error code; last_error explains failures.
func register(entry: Object) -> Error:
	last_error = ""
	if _frozen:
		last_error = "registry %s is frozen; '%s' must be registered during content loading" % [registry_id, entry.get("id")]
		return ERR_LOCKED
	var id: String = entry.get("id")
	var invalid := NamespacedId.explain_invalid(id)
	if not invalid.is_empty():
		last_error = invalid
		return ERR_INVALID_PARAMETER
	if _entries.has(id):
		last_error = "duplicate id '%s' in %s" % [id, registry_id]
		return ERR_ALREADY_EXISTS
	_entries[id] = entry
	_ordered.append(entry)
	_on_registered(entry)
	return OK


func has(id: String) -> bool:
	return _entries.has(id)


func get_entry(id: String) -> Object:
	return _entries.get(id)


func size() -> int:
	return _ordered.size()


func entries() -> Array:
	return _ordered


func ids() -> PackedStringArray:
	var result := PackedStringArray()
	for entry in _ordered:
		result.append(entry.get("id"))
	return result


func is_frozen() -> bool:
	return _frozen


func freeze() -> void:
	_frozen = true


## Hook for subclasses (e.g. assigning runtime numeric ids).
func _on_registered(_entry: Object) -> void:
	pass
