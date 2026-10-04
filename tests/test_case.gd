class_name TestCase
extends RefCounted
## Minimal test base class (no external framework). Methods named test_*
## are run by tests/run_tests.gd; before_each/after_each wrap every test.

var failures: PackedStringArray = PackedStringArray()
var assertions := 0
var current_test := ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	assertions += 1
	if not condition:
		_fail("expected true" if message.is_empty() else message)


func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, "expected false" if message.is_empty() else message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		_fail("%s: expected %s (%s), got %s (%s)" % [message, expected, type_string(typeof(expected)), actual, type_string(typeof(actual))])
	elif actual != expected:
		_fail("%s: expected %s, got %s" % [message, expected, actual])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	assertions += 1
	if actual == unexpected:
		_fail("%s: did not expect %s" % [message, unexpected])


func assert_null(value: Variant, message: String = "") -> void:
	assert_true(value == null, "%s: expected null, got %s" % [message, value])


func assert_not_null(value: Variant, message: String = "") -> void:
	assert_true(value != null, "%s: expected a value, got null" % message)


func assert_contains(haystack: Variant, needle: Variant, message: String = "") -> void:
	assertions += 1
	var found := false
	if haystack is String:
		found = (haystack as String).contains(str(needle))
	elif haystack is Array or haystack is PackedStringArray or haystack is Dictionary:
		found = haystack.has(needle)
	if not found:
		_fail("%s: %s does not contain %s" % [message, haystack, needle])


## Fresh, empty directory under user://test_tmp for this test class.
func temp_dir(sub: String = "") -> String:
	var path := "user://test_tmp".path_join(get_script().resource_path.get_file().get_basename())
	if not sub.is_empty():
		path = path.path_join(sub)
	if DirAccess.dir_exists_absolute(path):
		_remove_recursive(path)
	DirAccess.make_dir_recursive_absolute(path)
	return path


func write_file(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _fail(message: String) -> void:
	failures.append("%s: %s" % [current_test, message])


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _remove_recursive(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_recursive(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
