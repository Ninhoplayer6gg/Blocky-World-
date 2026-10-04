class_name MeshingContext
extends RefCounted
## Flat per-runtime-id lookup tables the mesher reads in its hot loop. Built on
## the main thread whenever the block registry or textures change; jobs keep a
## reference to the context they were started with, so rebuilding never races.

var render_layer := PackedByteArray()
var occludes := PackedByteArray()
var collides := PackedByteArray()
var cull_same := PackedByteArray()
## Texture-array layer per (runtime_id * 6 + face).
var face_layers := PackedInt32Array()
var ambient_occlusion := GameConfig.ENABLE_AMBIENT_OCCLUSION


## `layer_of` is Callable(block: BlockDefinition, face: int) -> int returning
## the texture-array layer for that face.
static func build(blocks: BlockRegistry, layer_of: Callable) -> MeshingContext:
	var context := MeshingContext.new()
	var count := blocks.runtime_count()
	context.render_layer.resize(count)
	context.occludes.resize(count)
	context.collides.resize(count)
	context.cull_same.resize(count)
	context.face_layers.resize(count * 6)
	for runtime_id in count:
		var definition := blocks.get_by_runtime(runtime_id)
		context.render_layer[runtime_id] = definition.render_layer
		context.occludes[runtime_id] = 1 if definition.is_opaque_cube() else 0
		context.collides[runtime_id] = 1 if definition.collision else 0
		context.cull_same[runtime_id] = 1 if definition.cull_same else 0
		for face in 6:
			context.face_layers[runtime_id * 6 + face] = layer_of.call(definition, face)
	return context


func block_count() -> int:
	return render_layer.size()
