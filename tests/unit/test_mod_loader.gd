extends TestCase
## Uses fixture mods written to a temp folder.

var root := ""


func before_each() -> void:
	root = temp_dir("mods")


func _mod(folder: String, manifest: Variant) -> void:
	var text: String = manifest if manifest is String else JSON.stringify(manifest)
	write_file(root.path_join(folder).path_join("mod.json"), text)


func _manifest(id: String, deps: Array = [], extra: Dictionary = {}) -> Dictionary:
	var data := {"id": id, "name": id.capitalize(), "version": "1.0.0", "dependencies": deps}
	data.merge(extra, true)
	return data


func _discover() -> Array[ModEntry]:
	return ModLoader.new().discover([{"path": root, "source": ModEntry.Source.USER}])


func _by_id(entries: Array[ModEntry], id: String) -> ModEntry:
	for entry in entries:
		if entry.get_id() == id:
			return entry
	return null


func test_valid_manifest() -> void:
	var manifest := ModManifest.from_dict(_manifest("example_mod", [], {"author": "Me", "description": "d"}))
	assert_true(manifest.is_valid(), str(manifest.errors))
	assert_eq(manifest.content_namespace, "example_mod")


func test_manifest_validation_errors() -> void:
	var missing := ModManifest.from_dict({"id": "abc"})
	assert_contains(" ".join(missing.errors), "missing required field 'name'")
	assert_contains(" ".join(missing.errors), "missing required field 'version'")
	var bad := ModManifest.from_dict({"id": "Bad Id", "name": "x", "version": "one"})
	assert_contains(" ".join(bad.errors), "invalid id")
	assert_contains(" ".join(bad.errors), "invalid version")
	var types := ModManifest.from_dict({"id": "abc", "name": 5, "version": "1.0.0", "dependencies": "core"})
	assert_contains(" ".join(types.errors), "must be a string")
	assert_contains(" ".join(types.errors), "must be an array")
	var future := ModManifest.from_dict(_manifest("abc", [], {"api_version": GameInfo.MOD_API_VERSION + 1}))
	assert_contains(" ".join(future.errors), "update Blocky World")


func test_broken_json_does_not_stop_others() -> void:
	_mod("good", _manifest("good"))
	_mod("broken", "{ \"id\": \"broken\", ")
	write_file(root.path_join("no_manifest/readme.txt"), "hi")
	var entries := _discover()
	var ordered := ModLoader.new().resolve(entries)
	assert_eq(ordered.size(), 1)
	assert_eq(ordered[0].get_id(), "good")
	var broken := _by_id(entries, "broken")
	assert_eq(broken.state, ModEntry.State.ERROR)
	assert_contains(broken.errors[0], "line")
	assert_contains(_by_id(entries, "no_manifest").errors[0], "no mod.json")


func test_dependency_order_and_missing_dependency() -> void:
	_mod("zeta", _manifest("zeta", ["core_library"]))
	_mod("core_library", _manifest("core_library"))
	_mod("addon", _manifest("addon", ["zeta"]))
	_mod("lonely", _manifest("lonely", ["not_installed"]))
	_mod("needs_lonely", _manifest("needs_lonely", ["lonely"]))
	var entries := _discover()
	var ordered := ModLoader.new().resolve(entries)
	var ids := PackedStringArray()
	for entry in ordered:
		ids.append(entry.get_id())
	assert_eq(ids, PackedStringArray(["core_library", "zeta", "addon"]))
	assert_contains(_by_id(entries, "lonely").errors[0], "'not_installed', which is not installed")
	assert_contains(_by_id(entries, "needs_lonely").errors[0], "failed to load")


func test_duplicate_ids_and_reserved_namespace() -> void:
	_mod("a_first", _manifest("dup"))
	_mod("b_second", _manifest("dup"))
	_mod("imposter", _manifest("blockyworld"))
	_mod("sneaky", _manifest("sneaky", [], {"namespace": "blockyworld"}))
	var entries := _discover()
	ModLoader.new().resolve(entries)
	var dup_errors := 0
	for entry in entries:
		if entry.get_id() == "dup" and entry.state == ModEntry.State.ERROR:
			dup_errors += 1
			assert_contains(entry.errors[0], "duplicate mod id")
	assert_eq(dup_errors, 1, "second copy rejected, first kept")
	assert_contains(_by_id(entries, "blockyworld").errors[0], "reserved")
	assert_contains(_by_id(entries, "sneaky").errors[0], "reserved")


func test_cycles_and_versions() -> void:
	_mod("cycle_a", _manifest("cycle_a", ["cycle_b"]))
	_mod("cycle_b", _manifest("cycle_b", ["cycle_a"]))
	_mod("old_lib", _manifest("old_lib"))
	_mod("wants_new", _manifest("wants_new", [{"id": "old_lib", "version": ">=2.0.0"}]))
	var entries := _discover()
	var ordered := ModLoader.new().resolve(entries)
	assert_eq(ordered.size(), 1, "only old_lib loads")
	assert_contains(_by_id(entries, "cycle_a").errors[0], "cycle")
	assert_contains(_by_id(entries, "wants_new").errors[0], ">=2.0.0")


func test_disabled_mods_and_dependents() -> void:
	_mod("base_mod", _manifest("base_mod"))
	_mod("child_mod", _manifest("child_mod", ["base_mod"]))
	var entries := _discover()
	var ordered := ModLoader.new().resolve(entries, PackedStringArray(["base_mod"]))
	assert_eq(ordered.size(), 0)
	assert_eq(_by_id(entries, "base_mod").state, ModEntry.State.DISABLED)
	assert_contains(_by_id(entries, "child_mod").errors[0], "disabled")


func test_sem_ver() -> void:
	assert_true(SemVer.satisfies("1.2.3", ""))
	assert_true(SemVer.satisfies("1.2.3", ">=1.2.0"))
	assert_false(SemVer.satisfies("1.2.3", ">1.2.3"))
	assert_true(SemVer.satisfies("1.9.0", "^1.2.0"))
	assert_false(SemVer.satisfies("2.0.0", "^1.2.0"))
	assert_true(SemVer.satisfies("1.0.0", "1.0.0"))
	assert_false(SemVer.is_valid_constraint(">=banana"))
	assert_eq(SemVer.compare("0.10.0", "0.9.9"), 1)
