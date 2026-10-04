class_name ModLoader
extends RefCounted
## Discovers mods, validates them and computes a load order.
##
## A broken mod never stops the game: it is marked ERROR with a readable
## message (shown in the Mods menu and the log) and everything that depends
## on it is skipped with an explanation.

const MANIFEST_FILE := "mod.json"


## `search_paths`: [{"path": String, "source": ModEntry.Source}], highest
## priority first (a duplicate id found later loses).
func discover(search_paths: Array) -> Array[ModEntry]:
	var found: Array[ModEntry] = []
	for search in search_paths:
		var root: String = search.path
		if not DirAccess.dir_exists_absolute(root):
			continue
		var folders := Array(DirAccess.get_directories_at(root))
		folders.sort()
		for folder in folders:
			if folder.begins_with("."):
				continue
			found.append(read_entry(root.path_join(folder), search.source))
	return found


func read_entry(mod_dir: String, source: ModEntry.Source) -> ModEntry:
	var entry := ModEntry.new()
	entry.path = mod_dir
	entry.source = source
	var manifest_path := mod_dir.path_join(MANIFEST_FILE)
	if not FileAccess.file_exists(manifest_path):
		entry.manifest = ModManifest.new()
		entry.fail("folder has no %s" % MANIFEST_FILE)
		return entry
	var text := FileAccess.get_file_as_string(manifest_path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		entry.manifest = ModManifest.new()
		entry.fail("cannot read %s (error %d)" % [MANIFEST_FILE, FileAccess.get_open_error()])
		return entry
	var json := JSON.new()
	if json.parse(text) != OK:
		entry.manifest = ModManifest.new()
		entry.fail("%s line %d: %s" % [MANIFEST_FILE, json.get_error_line(), json.get_error_message()])
		return entry
	entry.manifest = ModManifest.from_dict(json.data)
	for message in entry.manifest.errors:
		entry.fail(message)
	entry.warnings.append_array(entry.manifest.warnings)
	if entry.manifest.is_valid() and entry.manifest.id != mod_dir.get_file():
		entry.warnings.append("folder name '%s' differs from mod id '%s'" % [mod_dir.get_file(), entry.manifest.id])
	return entry


## Applies enable/disable choices, detects duplicates, reserved namespaces,
## missing or failed dependencies and cycles. Returns loadable mods in load
## order (built-in packs first, then dependency order, ties alphabetical).
func resolve(entries: Array[ModEntry], disabled_ids: PackedStringArray = PackedStringArray()) -> Array[ModEntry]:
	var by_id: Dictionary = {}
	var by_namespace: Dictionary = {}
	for entry in entries:
		if entry.state == ModEntry.State.ERROR:
			continue
		var mod_id := entry.get_id()
		if by_id.has(mod_id):
			entry.fail("duplicate mod id '%s' (already provided by %s)" % [mod_id, by_id[mod_id].path])
			continue
		var ns := entry.manifest.content_namespace
		if not entry.is_builtin() and (mod_id == GameInfo.CORE_NAMESPACE or ns == GameInfo.CORE_NAMESPACE):
			entry.fail("the id/namespace '%s' is reserved for the base game" % GameInfo.CORE_NAMESPACE)
			continue
		if by_namespace.has(ns):
			entry.fail("namespace '%s' is already used by mod '%s'" % [ns, by_namespace[ns].get_id()])
			continue
		by_id[mod_id] = entry
		by_namespace[ns] = entry
		if not entry.is_builtin() and disabled_ids.has(mod_id):
			entry.state = ModEntry.State.DISABLED

	# Propagate dependency failures until stable.
	var changed := true
	while changed:
		changed = false
		for entry in by_id.values():
			if entry.state != ModEntry.State.DISCOVERED:
				continue
			var problem := _dependency_problem(entry, by_id)
			if not problem.is_empty():
				entry.fail(problem)
				changed = true

	return _topological_order(by_id)


func _dependency_problem(entry: ModEntry, by_id: Dictionary) -> String:
	for dependency in entry.manifest.dependencies:
		var target: ModEntry = by_id.get(dependency.id)
		if target == null:
			return "requires mod '%s', which is not installed" % dependency.id
		if target.state == ModEntry.State.DISABLED:
			return "requires mod '%s', which is disabled" % dependency.id
		if target.state == ModEntry.State.ERROR:
			return "requires mod '%s', which failed to load" % dependency.id
		if not SemVer.satisfies(target.manifest.version, dependency.version):
			return "requires '%s' %s but version %s is installed" % [dependency.id, dependency.version, target.manifest.version]
	return ""


func _topological_order(by_id: Dictionary) -> Array[ModEntry]:
	var pending: Dictionary = {}
	for mod_id in by_id:
		if by_id[mod_id].state == ModEntry.State.DISCOVERED:
			pending[mod_id] = by_id[mod_id]
	var edges: Dictionary = {}
	for mod_id in pending:
		var entry: ModEntry = pending[mod_id]
		var requires: Array = []
		for dependency in entry.manifest.dependencies + entry.manifest.optional_dependencies:
			if pending.has(dependency.id) and not requires.has(dependency.id):
				requires.append(dependency.id)
		edges[mod_id] = requires

	var ordered: Array[ModEntry] = []
	var done: Dictionary = {}
	while not pending.is_empty():
		var ready: Array = []
		for mod_id in pending:
			var satisfied := true
			for required in edges[mod_id]:
				if not done.has(required):
					satisfied = false
					break
			if satisfied:
				ready.append(mod_id)
		if ready.is_empty():
			var cycle := PackedStringArray(pending.keys())
			for mod_id in pending:
				pending[mod_id].fail("dependency cycle between: %s" % ", ".join(cycle))
			break
		ready.sort_custom(func(a: String, b: String) -> bool:
			var builtin_a: bool = pending[a].is_builtin()
			var builtin_b: bool = pending[b].is_builtin()
			if builtin_a != builtin_b:
				return builtin_a
			return a < b)
		var next_id: String = ready[0]
		ordered.append(pending[next_id])
		done[next_id] = true
		pending.erase(next_id)
	return ordered
