class_name NamespacedId
extends RefCounted
## Helpers for "namespace:path" identifiers used by every registry, asset and
## event. The namespace is owned by one mod (or the base game, "blockyworld").
##
##   namespace: lowercase letter first, then [a-z0-9_], max 64 chars
##   path:      [a-z0-9_] segments separated by "/" or ".", e.g. "blocks/stone"

const SEPARATOR := ":"

static var _namespace_regex: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]{0,63}$")
static var _path_regex: RegEx = RegEx.create_from_string("^[a-z0-9_]+([./][a-z0-9_]+)*$")


static func is_valid(id: String) -> bool:
	var parts := id.split(SEPARATOR)
	if parts.size() != 2:
		return false
	return is_valid_namespace(parts[0]) and is_valid_path(parts[1])


static func is_valid_namespace(ns: String) -> bool:
	return _namespace_regex.search(ns) != null


static func is_valid_path(path: String) -> bool:
	return _path_regex.search(path) != null


static func make(ns: String, path: String) -> String:
	return ns + SEPARATOR + path


static func namespace_of(id: String) -> String:
	var index := id.find(SEPARATOR)
	return id.substr(0, index) if index >= 0 else ""


static func path_of(id: String) -> String:
	var index := id.find(SEPARATOR)
	return id.substr(index + 1) if index >= 0 else id


## Adds `default_namespace` when `id` has none ("stone" -> "mymod:stone").
static func qualify(id: String, default_namespace: String) -> String:
	if id.contains(SEPARATOR):
		return id
	return make(default_namespace, id)


## Human-readable reason why `id` is invalid, or "" when it is valid.
static func explain_invalid(id: String) -> String:
	if id.is_empty():
		return "id is empty"
	var parts := id.split(SEPARATOR)
	if parts.size() != 2:
		return "'%s' must have the form namespace:path" % id
	if not is_valid_namespace(parts[0]):
		return "namespace '%s' must be lowercase letters, digits or '_' and start with a letter" % parts[0]
	if not is_valid_path(parts[1]):
		return "path '%s' must be lowercase letters, digits or '_' separated by '/' or '.'" % parts[1]
	return ""
