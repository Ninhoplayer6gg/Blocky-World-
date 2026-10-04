class_name ModManifest
extends RefCounted
## Parsed and validated mod.json.
##
## Required: id, name, version. Optional: author, description, namespace,
## api_version, dependencies, optional_dependencies.
## Dependencies are "mod_id" or {"id": "mod_id", "version": ">=1.2.0"}.

var id: String = ""
var name: String = ""
var version: String = ""
var author: String = ""
var description: String = ""
## Namespace for the mod's content ids. Defaults to the mod id.
var content_namespace: String = ""
var api_version: int = GameInfo.MOD_API_VERSION
## [{id: String, version: String}] — version is a constraint, "" = any.
var dependencies: Array = []
var optional_dependencies: Array = []
var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()

static var _id_regex: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]{1,63}$")


static func is_valid_mod_id(mod_id: String) -> bool:
	return _id_regex.search(mod_id) != null


static func from_dict(data: Variant) -> ModManifest:
	var manifest := ModManifest.new()
	if not data is Dictionary:
		manifest.errors.append("mod.json must contain a JSON object")
		return manifest
	manifest.id = _string_field(manifest, data, "id", true)
	manifest.name = _string_field(manifest, data, "name", true)
	manifest.version = _string_field(manifest, data, "version", true)
	manifest.author = _string_field(manifest, data, "author", false)
	manifest.description = _string_field(manifest, data, "description", false)

	if not manifest.id.is_empty() and not is_valid_mod_id(manifest.id):
		manifest.errors.append("invalid id '%s': use 2-64 lowercase letters, digits or '_', starting with a letter" % manifest.id)
	if not manifest.version.is_empty() and SemVer.parse(manifest.version).is_empty():
		manifest.errors.append("invalid version '%s': expected MAJOR.MINOR.PATCH (e.g. 0.1.0)" % manifest.version)

	manifest.content_namespace = _string_field(manifest, data, "namespace", false)
	if manifest.content_namespace.is_empty():
		manifest.content_namespace = manifest.id
	elif not NamespacedId.is_valid_namespace(manifest.content_namespace):
		manifest.errors.append("invalid namespace '%s'" % manifest.content_namespace)

	if data.has("api_version"):
		var api: Variant = data["api_version"]
		if typeof(api) != TYPE_INT and typeof(api) != TYPE_FLOAT:
			manifest.errors.append("'api_version' must be a number")
		else:
			manifest.api_version = int(api)
			if manifest.api_version > GameInfo.MOD_API_VERSION:
				manifest.errors.append("requires mod API %d but this game provides %d; update Blocky World" % [manifest.api_version, GameInfo.MOD_API_VERSION])
			elif manifest.api_version < GameInfo.MOD_API_VERSION:
				manifest.warnings.append("targets older mod API %d (current %d)" % [manifest.api_version, GameInfo.MOD_API_VERSION])

	manifest.dependencies = _parse_dependencies(manifest, data, "dependencies")
	manifest.optional_dependencies = _parse_dependencies(manifest, data, "optional_dependencies")
	return manifest


func is_valid() -> bool:
	return errors.is_empty()


func dependency_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for dependency in dependencies:
		result.append(dependency.id)
	return result


static func _string_field(manifest: ModManifest, data: Dictionary, key: String, required: bool) -> String:
	if not data.has(key):
		if required:
			manifest.errors.append("missing required field '%s'" % key)
		return ""
	var value: Variant = data[key]
	if typeof(value) != TYPE_STRING:
		manifest.errors.append("field '%s' must be a string" % key)
		return ""
	if required and (value as String).strip_edges().is_empty():
		manifest.errors.append("field '%s' must not be empty" % key)
	return (value as String).strip_edges()


static func _parse_dependencies(manifest: ModManifest, data: Dictionary, key: String) -> Array:
	var result: Array = []
	if not data.has(key):
		return result
	var list: Variant = data[key]
	if not list is Array:
		manifest.errors.append("'%s' must be an array" % key)
		return result
	for entry in list:
		var dep_id := ""
		var constraint := ""
		if entry is String:
			dep_id = entry
		elif entry is Dictionary and entry.get("id") is String:
			dep_id = entry["id"]
			constraint = str(entry.get("version", ""))
		else:
			manifest.errors.append("'%s' entries must be a mod id or {\"id\": ..., \"version\": ...}" % key)
			continue
		if not is_valid_mod_id(dep_id):
			manifest.errors.append("'%s' has invalid mod id '%s'" % [key, dep_id])
			continue
		if not constraint.is_empty() and not SemVer.is_valid_constraint(constraint):
			manifest.errors.append("dependency '%s' has invalid version constraint '%s'" % [dep_id, constraint])
			continue
		result.append({"id": dep_id, "version": constraint})
	return result
