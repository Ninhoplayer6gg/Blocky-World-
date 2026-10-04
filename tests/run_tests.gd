extends SceneTree
## Runs every tests/unit/test_*.gd. Use tools/run_tests.sh, which also fails
## the run if Godot printed any SCRIPT ERROR (GDScript has no exceptions, so a
## runtime error inside a test is detected from the log).
##
##   godot --headless --path . -s res://tests/run_tests.gd -- --bw-no-boot [--verbose] [filter]

const TEST_DIR := "res://tests/unit"

var _started := false


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			filter = arg
	# Tests provoke errors on purpose; pass --verbose to see the game log.
	Log.muted = not OS.get_cmdline_user_args().has("--verbose")
	var files := Array(DirAccess.get_files_at(TEST_DIR))
	files.sort()
	var total_tests := 0
	var total_assertions := 0
	var failed: PackedStringArray = PackedStringArray()
	for file in files:
		if not file.begins_with("test_") or file.get_extension() != "gd":
			continue
		if not filter.is_empty() and not file.contains(filter):
			continue
		var script := load(TEST_DIR.path_join(file)) as GDScript
		if script == null or not script.can_instantiate():
			failed.append("%s: failed to load" % file)
			continue
		var methods: Array = []
		for method in script.get_script_method_list():
			if str(method.name).begins_with("test_") and not methods.has(method.name):
				methods.append(method.name)
		var file_failures := 0
		for method in methods:
			var test: TestCase = script.new()
			test.current_test = "%s.%s" % [file.get_basename(), method]
			test.before_each()
			test.call(method)
			test.after_each()
			total_tests += 1
			total_assertions += test.assertions
			if not test.failures.is_empty():
				file_failures += 1
				failed.append_array(test.failures)
		print("%s %s (%d tests)" % ["FAIL" if file_failures > 0 else "ok  ", file, methods.size()])
	print("")
	for failure in failed:
		print("  FAILED ", failure)
	print("%d tests, %d assertions, %d failure(s)" % [total_tests, total_assertions, failed.size()])
	quit(1 if not failed.is_empty() else 0)
	return false
