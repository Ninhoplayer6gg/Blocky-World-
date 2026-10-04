class_name SaveMigrations
extends RefCounted
## Upgrades world metadata written by older save versions, one version step
## at a time. Add a `_v<N>_to_v<N+1>` step whenever GameInfo.SAVE_VERSION is
## bumped; never edit old steps.


## Returns {"ok": bool, "data": Dictionary, "error": String}.
static func migrate_world(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_version", 0))
	if version > GameInfo.SAVE_VERSION:
		return {"ok": false, "data": data, "error": "saved by a newer Blocky World (save version %d, this build supports %d)" % [version, GameInfo.SAVE_VERSION]}
	if version < 1:
		return {"ok": false, "data": data, "error": "unknown save version %d" % version}
	var migrated := data.duplicate(true)
	while version < GameInfo.SAVE_VERSION:
		match version:
			_:
				return {"ok": false, "data": data, "error": "no migration from save version %d" % version}
	migrated["save_version"] = version
	return {"ok": true, "data": migrated, "error": ""}
