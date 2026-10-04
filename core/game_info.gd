class_name GameInfo
extends RefCounted
## Version identity of the game. Bump these deliberately:
## - GAME_VERSION: player-facing release version (semver).
## - SAVE_VERSION: world save layout version. Increment when world.json or the
##   save folder layout changes, and add a migration in SaveMigrations.
## - MOD_API_VERSION: contract offered to mods (manifest fields, content JSON
##   schema, events). Mods declare the API they target in mod.json.

const GAME_NAME := "Blocky World"
const GAME_VERSION := "0.1.0"
const SAVE_VERSION := 1
const MOD_API_VERSION := 1

## Namespace owned by the base game. Mods may not register content in it.
const CORE_NAMESPACE := "blockyworld"
