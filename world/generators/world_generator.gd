class_name WorldGenerator
extends RefCounted
## Base class for world generators, registered by id in
## ContentRegistries.generators and chosen per world (world.json "generator").
##
## setup() runs on the main thread (resolve block ids, build noise). After
## that the generator is read-only and generate() is called concurrently from
## worker threads, so it must not mutate shared state.

var world_seed: int = 0
var content: GameContent


func setup(seed_value: int, game_content: GameContent) -> void:
	world_seed = seed_value
	content = game_content
	_setup()


## Bump when the algorithm changes so old worlds can be detected.
func get_version() -> int:
	return 1


## Fills `data` (chunk position already set). Worker thread.
func generate(_data: ChunkData) -> void:
	pass


## Approximate spawn; the world refines Y once the chunk exists.
func get_spawn_position() -> Vector3:
	return Vector3(0.5, GameConfig.CHUNK_SIZE_Y * 0.5, 0.5)


func get_biome_name(_x: int, _z: int) -> String:
	return "-"


func _setup() -> void:
	pass


func block_id(id: String, fallback: String = "blockyworld:stone") -> int:
	var runtime_id := content.registries.blocks.get_runtime_id(id)
	if runtime_id < 0:
		Log.warn("GEN", "Generator block %s is not registered; using %s" % [id, fallback])
		runtime_id = maxi(content.registries.blocks.get_runtime_id(fallback), 0)
	return runtime_id
