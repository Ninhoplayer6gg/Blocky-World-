extends SceneTree
## Loads every GDScript in the project and reports parse/compile failures.
## Usage: godot --headless --path . -s res://tools/check_scripts.gd -- --bw-no-boot
##
## Runs on the first frame (not in _init) so autoload singletons such as
## `Game` are registered before scripts that reference them are compiled.

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var failures := 0
	var scripts := _collect("res://")
	for path in scripts:
		var script: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if script == null or (script is GDScript and not (script as GDScript).can_instantiate()):
			printerr("FAILED: ", path)
			failures += 1
	print("Checked %d scripts, %d failed" % [scripts.size(), failures])
	quit(1 if failures > 0 else 0)
	return false


func _collect(dir: String) -> PackedStringArray:
	var result := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with("."):
			continue
		result.append_array(_collect(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			result.append(dir.path_join(file))
	return result
