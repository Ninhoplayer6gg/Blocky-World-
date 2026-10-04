class_name SemVer
extends RefCounted
## Minimal semantic version handling for mod versions and dependency
## constraints. Supported constraints: "" or "*" (any), "1.2.3" or "=1.2.3",
## ">=1.2.3", ">1.2.3", "<=1.2.3", "<1.2.3", "^1.2.3" (same major).

static var _regex: RegEx = RegEx.create_from_string("^(\\d+)\\.(\\d+)\\.(\\d+)(?:[-+][0-9A-Za-z.-]+)?$")


## [major, minor, patch] or [] when invalid.
static func parse(version: String) -> Array:
	var found := _regex.search(version.strip_edges())
	if found == null:
		return []
	return [int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3))]


static func compare(a: String, b: String) -> int:
	var va := parse(a)
	var vb := parse(b)
	for i in 3:
		if va[i] != vb[i]:
			return -1 if va[i] < vb[i] else 1
	return 0


static func is_valid_constraint(constraint: String) -> bool:
	var split := _split(constraint)
	return split[0] == "*" or not parse(split[1]).is_empty()


static func satisfies(version: String, constraint: String) -> bool:
	if parse(version).is_empty():
		return false
	var split := _split(constraint)
	var op: String = split[0]
	if op == "*":
		return true
	var target: String = split[1]
	var cmp := compare(version, target)
	match op:
		"=":
			return cmp == 0
		">=":
			return cmp >= 0
		">":
			return cmp > 0
		"<=":
			return cmp <= 0
		"<":
			return cmp < 0
		"^":
			return cmp >= 0 and parse(version)[0] == parse(target)[0]
	return false


static func _split(constraint: String) -> Array:
	var c := constraint.strip_edges()
	if c.is_empty() or c == "*":
		return ["*", ""]
	for op in [">=", "<=", ">", "<", "^", "="]:
		if c.begins_with(op):
			return [op, c.substr(op.length()).strip_edges()]
	return ["=", c]
