class_name ContentPipeline
extends RefCounted
## The fixed content lifecycle. Content can only enter registries during
## REGISTER_CONTENT; registries are frozen in FINALIZE_REGISTRIES, before any
## world exists.
##
##   ENGINE_START -> LOAD_CORE -> DISCOVER_MODS -> VALIDATE_MODS
##   -> RESOLVE_DEPENDENCIES -> REGISTER_CONTENT -> FINALIZE_REGISTRIES -> READY

enum Phase {
	ENGINE_START, LOAD_CORE, DISCOVER_MODS, VALIDATE_MODS,
	RESOLVE_DEPENDENCIES, REGISTER_CONTENT, FINALIZE_REGISTRIES, READY,
}

## [{"path": String, "source": ModEntry.Source}], highest priority first.
var search_paths: Array = []
var disabled_mods: PackedStringArray = PackedStringArray()
var phase: Phase = Phase.ENGINE_START


static func default_search_paths() -> Array:
	var paths: Array = [
		{"path": "res://packs", "source": ModEntry.Source.BUILTIN},
		{"path": "res://mods", "source": ModEntry.Source.BUNDLED},
		{"path": "user://mods", "source": ModEntry.Source.USER},
	]
	if not OS.has_feature("editor") and not OS.has_feature("mobile"):
		paths.append({"path": OS.get_executable_path().get_base_dir().path_join("mods"), "source": ModEntry.Source.EXTERNAL})
	return paths


func run() -> GameContent:
	var content := GameContent.new()
	var loader := ModLoader.new()

	_enter(Phase.LOAD_CORE)
	CoreRegistration.register_code_types(content.registries)

	_enter(Phase.DISCOVER_MODS)
	var discovered := loader.discover(search_paths)
	content.mods = discovered
	Log.info("MOD", "Discovered %d mod folder(s)" % discovered.size())

	_enter(Phase.VALIDATE_MODS)
	for mod in discovered:
		if mod.state == ModEntry.State.ERROR:
			Log.error("MOD", "%s (%s): %s" % [mod.get_id(), mod.path, "; ".join(mod.errors)])

	_enter(Phase.RESOLVE_DEPENDENCIES)
	var ordered := loader.resolve(discovered, disabled_mods)
	for mod in discovered:
		if mod.state == ModEntry.State.ERROR and not ordered.has(mod):
			if not mod.errors.is_empty():
				Log.error("MOD", "Not loading %s: %s" % [mod.get_id(), mod.errors[mod.errors.size() - 1]])
		elif mod.state == ModEntry.State.DISABLED:
			Log.info("MOD", "%s is disabled" % mod.get_id())
		for warning in mod.warnings:
			Log.warn("MOD", "%s: %s" % [mod.get_id(), warning])
	if ordered.is_empty() or not ordered[0].is_builtin() or ordered[0].get_id() != GameInfo.CORE_NAMESPACE:
		Log.error("MOD", "Base content pack '%s' is missing or broken; the game will have no blocks" % GameInfo.CORE_NAMESPACE)

	_enter(Phase.REGISTER_CONTENT)
	for mod in ordered:
		content.resources.register_namespace_root(mod.manifest.content_namespace, mod.path)
	var content_loader := ContentLoader.new(content.registries)
	content_loader.load_mods(ordered)
	content.load_order = ordered

	_enter(Phase.FINALIZE_REGISTRIES)
	content_loader.validate_references(ordered)
	content.registries.freeze_all()
	for mod in ordered:
		Log.info("MOD", "Loaded %s %s %s" % [mod.get_id(), mod.manifest.version, _counts(mod.content_counts)])

	_enter(Phase.READY)
	Log.info("CORE", "Content ready: %d blocks, %d items, %d biomes, %d entities" % [
		content.registries.blocks.size(), content.registries.items.size(),
		content.registries.biomes.size(), content.registries.entities.size()])
	return content


func _enter(next: Phase) -> void:
	assert(next > phase, "content phases must advance in order")
	phase = next
	Log.debug("CORE", "Phase %s" % Phase.keys()[next])


static func _counts(counts: Dictionary) -> String:
	if counts.is_empty():
		return "(no content)"
	var parts := PackedStringArray()
	for type in counts:
		parts.append("%d %s" % [counts[type], type])
	return "(" + ", ".join(parts) + ")"
