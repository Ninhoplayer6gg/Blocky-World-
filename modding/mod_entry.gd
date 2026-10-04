class_name ModEntry
extends RefCounted
## A discovered mod (or built-in pack) and what happened to it during loading.

enum State { DISCOVERED, LOADED, DISABLED, ERROR }
enum Source { BUILTIN, BUNDLED, USER, EXTERNAL }

var manifest: ModManifest
## Folder containing mod.json.
var path: String = ""
var source: Source = Source.USER
var state: State = State.DISCOVERED
## Problems that prevented loading, in plain language.
var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()
## Counts of registered content, e.g. {"blocks": 3, "items": 1}.
var content_counts: Dictionary = {}


func get_id() -> String:
	return manifest.id if manifest != null and not manifest.id.is_empty() else path.get_file()


func get_display_name() -> String:
	return manifest.name if manifest != null and not manifest.name.is_empty() else get_id()


func is_builtin() -> bool:
	return source == Source.BUILTIN


func is_loadable() -> bool:
	return state == State.DISCOVERED or state == State.LOADED


func fail(message: String) -> void:
	state = State.ERROR
	errors.append(message)


func state_label() -> String:
	match state:
		State.LOADED:
			return "Built-in" if is_builtin() else "Loaded"
		State.DISABLED:
			return "Disabled"
		State.ERROR:
			return "Error"
	return "Pending"
