class_name JsonFields
extends RefCounted
## Typed, error-collecting accessors for content JSON. Every problem is
## reported with the file it came from instead of crashing or being ignored.

var source: String = ""
var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()


func _init(source_label: String = "") -> void:
	source = source_label


func error(message: String) -> void:
	errors.append("%s: %s" % [source, message])


func warn(message: String) -> void:
	warnings.append("%s: %s" % [source, message])


func check_keys(data: Dictionary, allowed: Array) -> void:
	for key in data:
		if not allowed.has(key):
			warn("unknown field '%s' (ignored)" % key)


func get_string(data: Dictionary, key: String, default: String = "", required: bool = false) -> String:
	if not data.has(key):
		if required:
			error("missing required field '%s'" % key)
		return default
	var value: Variant = data[key]
	if typeof(value) != TYPE_STRING:
		error("field '%s' must be a string" % key)
		return default
	return value


func get_float(data: Dictionary, key: String, default: float) -> float:
	if not data.has(key):
		return default
	var value: Variant = data[key]
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		error("field '%s' must be a number" % key)
		return default
	return float(value)


func get_int(data: Dictionary, key: String, default: int) -> int:
	return int(get_float(data, key, default))


func get_bool(data: Dictionary, key: String, default: bool) -> bool:
	if not data.has(key):
		return default
	var value: Variant = data[key]
	if typeof(value) != TYPE_BOOL:
		error("field '%s' must be true or false" % key)
		return default
	return value


func get_dict(data: Dictionary, key: String) -> Dictionary:
	if not data.has(key):
		return {}
	var value: Variant = data[key]
	if not value is Dictionary:
		error("field '%s' must be an object" % key)
		return {}
	return value


func get_array(data: Dictionary, key: String) -> Array:
	if not data.has(key):
		return []
	var value: Variant = data[key]
	if not value is Array:
		error("field '%s' must be an array" % key)
		return []
	return value


func get_string_array(data: Dictionary, key: String) -> PackedStringArray:
	var result := PackedStringArray()
	for value in get_array(data, key):
		if typeof(value) == TYPE_STRING:
			result.append(value)
		else:
			error("field '%s' must contain only strings" % key)
	return result


## Accepts "#rgb", "#rrggbb", "#rrggbbaa" or [r, g, b(, a)] in 0..1.
func parse_color(value: Variant, label: String, default: Color) -> Color:
	if typeof(value) == TYPE_STRING and Color.html_is_valid(value):
		return Color.html(value)
	if value is Array and (value.size() == 3 or value.size() == 4):
		var channels: Array = value
		return Color(float(channels[0]), float(channels[1]), float(channels[2]), float(channels[3]) if channels.size() == 4 else 1.0)
	error("'%s' must be a colour like \"#a1b2c3\"" % label)
	return default


func get_color(data: Dictionary, key: String, default: Color) -> Color:
	if not data.has(key):
		return default
	return parse_color(data[key], key, default)


## Namespaced id field; a bare path gets `default_namespace`.
func get_id(data: Dictionary, key: String, default_namespace: String, required: bool = false) -> String:
	var raw := get_string(data, key, "", required)
	if raw.is_empty():
		return ""
	return qualify_id(raw, default_namespace, key)


func qualify_id(raw: String, default_namespace: String, label: String) -> String:
	var id := NamespacedId.qualify(raw, default_namespace)
	var problem := NamespacedId.explain_invalid(id)
	if not problem.is_empty():
		error("'%s': %s" % [label, problem])
		return ""
	return id
