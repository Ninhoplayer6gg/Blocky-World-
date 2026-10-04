class_name ChunkMesher
extends RefCounted
## Turns block data into section meshes.
##
## Strategy (0.1): per-block hidden-face culling. A face is emitted only when
## the neighbour in that direction does not occlude it. Each vertex gets
## ambient occlusion from its 3 neighbours in the face plane.
##
## The output format (per-face quads with UV in block units and the texture
## array layer in UV2.x) is already compatible with greedy meshing: merging
## quads only needs UVs scaled by the quad size, which the texture array
## shader repeats correctly. See docs/Architecture.md.
##
## Thread-safety: runs on worker threads. Only reads its arguments and the
## immutable tables built in _init().

const SX := GameConfig.CHUNK_SIZE_X
const SY := GameConfig.CHUNK_SIZE_Y
const SZ := GameConfig.CHUNK_SIZE_Z
const SH := GameConfig.SECTION_HEIGHT
const LAYER := GameConfig.CHUNK_LAYER
const PX := SX + 2
const PZ := SZ + 2
const PY := SH + 2
const PXZ := PX * PZ

const OPAQUE := BlockDefinition.RenderLayer.OPAQUE
const CUTOUT := BlockDefinition.RenderLayer.CUTOUT

## Face order matches BlockDefinition.Face: east, west, top, bottom, south, north.
const FACE_DIRS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
## Quad corners as seen from outside the block: top-left, top-right,
## bottom-right, bottom-left (clockwise = front face in Godot).
const FACE_CORNERS := [
	[Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)],
	[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1), Vector3(0, 0, 0)],
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0)],
	[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(1, 0, 0)],
]
const CORNER_UVS: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
## Brightness for 0..3 unoccluded neighbours.
const AO_CURVE: Array[float] = [0.45, 0.65, 0.82, 1.0]

var _face_offsets := PackedInt32Array()
## 6 faces * 4 corners * 3 neighbours (side, side, diagonal), as padded-index offsets.
var _ao_offsets := PackedInt32Array()
var _face_normals: Array[Vector3] = []
var _air_layer := PackedInt32Array()
var _air_row := PackedInt32Array()


func _init() -> void:
	_air_layer.resize(PXZ)
	_air_row.resize(SX)
	for face in 6:
		var dir := FACE_DIRS[face]
		_face_offsets.append(_offset(dir))
		_face_normals.append(Vector3(dir))
		var axes := _tangent_axes(face)
		for corner in 4:
			var position: Vector3 = FACE_CORNERS[face][corner]
			var side_a := axes[0] * (1 if position[_axis_index(axes[0])] > 0.5 else -1)
			var side_b := axes[1] * (1 if position[_axis_index(axes[1])] > 0.5 else -1)
			_ao_offsets.append(_offset(dir + side_a))
			_ao_offsets.append(_offset(dir + side_b))
			_ao_offsets.append(_offset(dir + side_a + side_b))


## Meshes one section. `snapshot` must cover layers section*SH-1 .. section*SH+SH.
func mesh_section(snapshot: ChunkSnapshot, section: int, context: MeshingContext) -> SectionMeshData:
	var result := SectionMeshData.new()
	result.section = section
	var pad := _build_padded(snapshot, section)

	var render_layer := context.render_layer
	var occludes := context.occludes
	var collides := context.collides
	var cull_same := context.cull_same
	var face_layers := context.face_layers
	var use_ao := context.ambient_occlusion
	var face_offsets := _face_offsets
	var ao_offsets := _ao_offsets
	var block_count := render_layer.size()

	var o_verts := PackedVector3Array()
	var o_normals := PackedVector3Array()
	var o_uvs := PackedVector2Array()
	var o_uv2s := PackedVector2Array()
	var o_colors := PackedColorArray()
	var o_indices := PackedInt32Array()
	var c_verts := PackedVector3Array()
	var c_normals := PackedVector3Array()
	var c_uvs := PackedVector2Array()
	var c_uv2s := PackedVector2Array()
	var c_colors := PackedColorArray()
	var c_indices := PackedInt32Array()
	var collision := PackedVector3Array()
	var faces := 0

	for y in SH:
		for z in SZ:
			var pi := 1 + (z + 1) * PX + (y + 1) * PXZ - 1
			for x in SX:
				pi += 1
				var id := pad[pi]
				if id <= 0 or id >= block_count:
					continue
				var layer := render_layer[id]
				if layer != OPAQUE and layer != CUTOUT:
					continue
				var visible := 0
				for face in 6:
					var neighbour := pad[pi + face_offsets[face]]
					if neighbour > 0 and neighbour < block_count:
						if occludes[neighbour] == 1 or (neighbour == id and cull_same[id] == 1):
							continue
					visible |= 1 << face
				if visible == 0:
					continue
				var opaque := layer == OPAQUE
				var verts := o_verts if opaque else c_verts
				var normals := o_normals if opaque else c_normals
				var uvs := o_uvs if opaque else c_uvs
				var uv2s := o_uv2s if opaque else c_uv2s
				var colors := o_colors if opaque else c_colors
				var indices := o_indices if opaque else c_indices
				var solid := collides[id] == 1
				var origin := Vector3(x, y, z)
				for face in 6:
					if visible & (1 << face) == 0:
						continue
					var a0 := 3
					var a1 := 3
					var a2 := 3
					var a3 := 3
					if use_ao:
						var o := face * 12
						a0 = _ao(occludes, block_count, pad[pi + ao_offsets[o]], pad[pi + ao_offsets[o + 1]], pad[pi + ao_offsets[o + 2]])
						a1 = _ao(occludes, block_count, pad[pi + ao_offsets[o + 3]], pad[pi + ao_offsets[o + 4]], pad[pi + ao_offsets[o + 5]])
						a2 = _ao(occludes, block_count, pad[pi + ao_offsets[o + 6]], pad[pi + ao_offsets[o + 7]], pad[pi + ao_offsets[o + 8]])
						a3 = _ao(occludes, block_count, pad[pi + ao_offsets[o + 9]], pad[pi + ao_offsets[o + 10]], pad[pi + ao_offsets[o + 11]])
					var corners: Array = FACE_CORNERS[face]
					var v0: Vector3 = origin + corners[0]
					var v1: Vector3 = origin + corners[1]
					var v2: Vector3 = origin + corners[2]
					var v3: Vector3 = origin + corners[3]
					var base := verts.size()
					verts.append(v0)
					verts.append(v1)
					verts.append(v2)
					verts.append(v3)
					var normal := _face_normals[face]
					normals.append(normal)
					normals.append(normal)
					normals.append(normal)
					normals.append(normal)
					uvs.append(CORNER_UVS[0])
					uvs.append(CORNER_UVS[1])
					uvs.append(CORNER_UVS[2])
					uvs.append(CORNER_UVS[3])
					var texture_layer := Vector2(face_layers[id * 6 + face], 0)
					uv2s.append(texture_layer)
					uv2s.append(texture_layer)
					uv2s.append(texture_layer)
					uv2s.append(texture_layer)
					colors.append(_shade(a0))
					colors.append(_shade(a1))
					colors.append(_shade(a2))
					colors.append(_shade(a3))
					# Split the quad along the darker diagonal so AO gradients
					# stay symmetric instead of forming a visible crease.
					if a0 + a2 > a1 + a3:
						indices.append(base + 1)
						indices.append(base + 2)
						indices.append(base + 3)
						indices.append(base + 1)
						indices.append(base + 3)
						indices.append(base)
					else:
						indices.append(base)
						indices.append(base + 1)
						indices.append(base + 2)
						indices.append(base)
						indices.append(base + 2)
						indices.append(base + 3)
					if solid:
						collision.append(v0)
						collision.append(v1)
						collision.append(v2)
						collision.append(v0)
						collision.append(v2)
						collision.append(v3)
					faces += 1

	result.opaque = _to_arrays(o_verts, o_normals, o_uvs, o_uv2s, o_colors, o_indices)
	result.cutout = _to_arrays(c_verts, c_normals, c_uvs, c_uv2s, c_colors, c_indices)
	result.collision = collision
	result.face_count = faces
	return result


## Copies the section plus a one-block border from neighbours into a
## (SX+2) x (SH+2) x (SZ+2) array indexed px + pz * PX + py * PXZ.
func _build_padded(snapshot: ChunkSnapshot, section: int) -> PackedInt32Array:
	var pad := PackedInt32Array()
	var y0 := section * SH
	var columns := snapshot.columns
	for py in PY:
		var y := y0 + py - 1
		if y >= SY:
			pad.append_array(_air_layer)
			continue
		# Below the world: repeat layer 0 so bottom faces are culled.
		var ys := maxi(y, 0)
		if ys < snapshot.y_start or ys >= snapshot.y_end:
			pad.append_array(_air_layer)
			continue
		var layer_offset := (ys - snapshot.y_start) * LAYER
		for pz in PZ:
			var z := pz - 1
			var dz := -1 if z < 0 else (1 if z >= SZ else 0)
			var row := layer_offset + (z - dz * SZ) * SX
			var band := (dz + 1) * 3
			var west := columns[band]
			var middle := columns[band + 1]
			var east := columns[band + 2]
			pad.append(west[row + SX - 1] if not west.is_empty() else 0)
			if middle.is_empty():
				pad.append_array(_air_row)
			else:
				pad.append_array(middle.slice(row, row + SX))
			pad.append(east[row] if not east.is_empty() else 0)
	return pad


static func _ao(occludes: PackedByteArray, count: int, side_a: int, side_b: int, diagonal: int) -> int:
	var a := 1 if side_a > 0 and side_a < count and occludes[side_a] == 1 else 0
	var b := 1 if side_b > 0 and side_b < count and occludes[side_b] == 1 else 0
	if a == 1 and b == 1:
		return 0
	var c := 1 if diagonal > 0 and diagonal < count and occludes[diagonal] == 1 else 0
	return 3 - a - b - c


static func _shade(ao: int) -> Color:
	var value := AO_CURVE[ao]
	return Color(value, value, value, 1.0)


static func _to_arrays(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		uv2s: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> Array:
	if verts.is_empty():
		return []
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


static func _offset(delta: Vector3i) -> int:
	return delta.x + delta.z * PX + delta.y * PXZ


static func _axis_index(axis: Vector3i) -> int:
	if axis.x != 0:
		return 0
	if axis.y != 0:
		return 1
	return 2


static func _tangent_axes(face: int) -> Array[Vector3i]:
	var dir := FACE_DIRS[face]
	if dir.x != 0:
		return [Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
	if dir.y != 0:
		return [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]
	return [Vector3i(1, 0, 0), Vector3i(0, 1, 0)]
