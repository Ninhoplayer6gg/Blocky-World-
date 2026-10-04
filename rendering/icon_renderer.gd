class_name IconRenderer
extends RefCounted
## CPU-side icon generation for inventory slots.


## Isometric cube assembled from three face images (top, left=south,
## right=east) with simple face shading.
static func block_icon(top: Image, left: Image, right: Image, size: int = 32) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var s := float(size)
	var faces := [
		[top, Vector2(s * 0.5, 0), Vector2(s * 0.5, s * 0.25), Vector2(-s * 0.5, s * 0.25), 1.0],
		[left, Vector2(0, s * 0.25), Vector2(s * 0.5, s * 0.25), Vector2(0, s * 0.5), 0.8],
		[right, Vector2(s * 0.5, s * 0.5), Vector2(s * 0.5, -s * 0.25), Vector2(0, s * 0.5), 0.62],
	]
	for py in size:
		for px in size:
			var p := Vector2(px + 0.5, py + 0.5)
			for face in faces:
				var uv := _solve(p - face[1], face[2], face[3])
				if uv.x < 0.0 or uv.x >= 1.0 or uv.y < 0.0 or uv.y >= 1.0:
					continue
				var source: Image = face[0]
				var texel := source.get_pixel(int(uv.x * source.get_width()), int(uv.y * source.get_height()))
				if texel.a < 0.1:
					continue
				var shade: float = face[4]
				image.set_pixel(px, py, Color(texel.r * shade, texel.g * shade, texel.b * shade, 1.0))
				break
	return image


static func _solve(p: Vector2, axis_u: Vector2, axis_v: Vector2) -> Vector2:
	var det := axis_u.x * axis_v.y - axis_u.y * axis_v.x
	if is_zero_approx(det):
		return Vector2(-1, -1)
	return Vector2((p.x * axis_v.y - p.y * axis_v.x) / det, (axis_u.x * p.y - axis_u.y * p.x) / det)
