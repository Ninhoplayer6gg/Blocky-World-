class_name SectionMeshData
extends RefCounted
## Output of ChunkMesher for one section: raw arrays only (no Godot resources),
## so it can be produced on a worker thread and uploaded on the main thread.

var section := 0
## Mesh surface arrays (Mesh.ARRAY_MAX entries) or empty when no faces.
var opaque: Array = []
var cutout: Array = []
## Triangle soup for a ConcavePolygonShape3D; empty when nothing collides.
var collision := PackedVector3Array()
var face_count := 0


func is_empty() -> bool:
	return opaque.is_empty() and cutout.is_empty() and collision.is_empty()
