class_name Events
extends RefCounted
## Event ids emitted by the base game. Mods subscribe through Game.events and
## may emit their own events using their own namespace.
##
## Events ending in "_ing" are emitted before the action and are cancellable:
## a listener sets payload["cancelled"] = true to veto it.

const CONTENT_LOADED := &"blockyworld:content_loaded"
const CONTENT_RELOADED := &"blockyworld:content_reloaded"

const WORLD_LOADED := &"blockyworld:world_loaded"
const WORLD_SAVED := &"blockyworld:world_saved"
const WORLD_UNLOADING := &"blockyworld:world_unloading"
const CHUNK_LOADED := &"blockyworld:chunk_loaded"
const CHUNK_UNLOADED := &"blockyworld:chunk_unloaded"

## payload: position (Vector3i), block (String id), entity (Entity or null)
const BLOCK_BREAKING := &"blockyworld:block_breaking"
const BLOCK_BROKEN := &"blockyworld:block_broken"
## payload: position (Vector3i), block (String id), entity (Entity or null)
const BLOCK_PLACING := &"blockyworld:block_placing"
const BLOCK_PLACED := &"blockyworld:block_placed"

## payload: player (Player)
const PLAYER_SPAWNED := &"blockyworld:player_spawned"
## Emitted when the player enters a different block cell.
## payload: player, from (Vector3i), to (Vector3i)
const PLAYER_MOVED := &"blockyworld:player_moved"

## payload: entity (Entity)
const ENTITY_SPAWNED := &"blockyworld:entity_spawned"
const ENTITY_REMOVED := &"blockyworld:entity_removed"
## payload: entity, amount (float), source (String); cancellable
const ENTITY_DAMAGING := &"blockyworld:entity_damaging"
const ENTITY_DIED := &"blockyworld:entity_died"
