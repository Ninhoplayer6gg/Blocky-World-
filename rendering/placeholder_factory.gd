class_name PlaceholderFactory
extends RefCounted
## Every stand-in asset is generated here and nowhere else, so placeholders
## are easy to find and never mistaken for final art. When the real file is
## dropped in place (see docs/Assets.md) the placeholder stops being used.


## Flat colour tile with deterministic noise and a darker rim so individual
## blocks remain readable.
static func block_texture(color: Color, size: int, variant_seed: int, transparent: bool = false) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = variant_seed
	for y in size:
		for x in size:
			var shade := 1.0 + rng.randf_range(-0.07, 0.07)
			if x == 0 or y == 0 or x == size - 1 or y == size - 1:
				shade *= 0.82
			var pixel := Color(color.r * shade, color.g * shade, color.b * shade, color.a)
			if transparent:
				var rim := x == 0 or y == 0 or x == size - 1 or y == size - 1
				pixel.a = 1.0 if rim or rng.randf() < color.a else 0.0
			image.set_pixel(x, y, pixel)
	return image


## Magenta/black checker used for blocks whose mod is missing.
@warning_ignore("integer_division")
static func missing_texture(size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := maxi(size / 2, 1)
	for y in size:
		for x in size:
			var checker := (x / half + y / half) % 2 == 0
			image.set_pixel(x, y, Color(1, 0, 1) if checker else Color(0.05, 0.05, 0.05))
	return image


## Diamond-shaped icon for items without an icon texture.
static func item_icon(color: Color, size: int = 32) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := absf(x - center) + absf(y - center)
			if d <= center * 0.8:
				var light := 1.15 - 0.35 * (float(x + y) / float(size * 2))
				image.set_pixel(x, y, Color(color.r * light, color.g * light, color.b * light, 1.0))
			elif d <= center * 0.9:
				image.set_pixel(x, y, color.darkened(0.5))
	return image


## Blocky humanoid made of boxes, used until a character .glb exists.
## Pivot nodes are named like the bones a real rig is expected to have.
static func humanoid(colors: Dictionary, height: float = 1.8) -> Node3D:
	var root := Node3D.new()
	root.name = "PlaceholderHumanoid"
	var unit := height / 32.0
	var skin: Color = colors.get("skin", Color(0.86, 0.68, 0.52))
	var shirt: Color = colors.get("body", Color(0.25, 0.55, 0.75))
	var pants: Color = colors.get("legs", Color(0.25, 0.25, 0.4))
	var legs := 12.0 * unit
	var torso := 12.0 * unit
	_limb(root, "Body", Vector3(0, legs, 0), Vector3(8, 12, 4) * unit, shirt, Vector3(0, torso / 2.0, 0))
	_limb(root, "Head", Vector3(0, legs + torso, 0), Vector3(8, 8, 8) * unit, skin, Vector3(0, 4 * unit, 0))
	_limb(root, "LeftArm", Vector3(6 * unit, legs + torso, 0), Vector3(4, 12, 4) * unit, skin, Vector3(0, -6 * unit, 0))
	_limb(root, "RightArm", Vector3(-6 * unit, legs + torso, 0), Vector3(4, 12, 4) * unit, skin, Vector3(0, -6 * unit, 0))
	_limb(root, "LeftLeg", Vector3(2 * unit, legs, 0), Vector3(4, 12, 4) * unit, pants, Vector3(0, -6 * unit, 0))
	_limb(root, "RightLeg", Vector3(-2 * unit, legs, 0), Vector3(4, 12, 4) * unit, pants, Vector3(0, -6 * unit, 0))
	var face := MeshInstance3D.new()
	face.name = "FaceMark"
	var mark := BoxMesh.new()
	mark.size = Vector3(4 * unit, 1 * unit, 0.2 * unit)
	face.mesh = mark
	face.material_override = _material(Color(0.1, 0.1, 0.12))
	face.position = Vector3(0, 5 * unit, 4.05 * unit)
	root.get_node("Head").add_child(face)
	return root


## Plain box for non-humanoid placeholder entities.
static func box_model(size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "PlaceholderBox"
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material(color)
	mesh_instance.position = Vector3(0, size.y / 2.0, 0)
	root.add_child(mesh_instance)
	return root


static func _limb(parent: Node3D, limb_name: String, pivot: Vector3, size: Vector3, color: Color, mesh_offset: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = limb_name
	joint.position = pivot
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material(color)
	mesh_instance.position = mesh_offset
	joint.add_child(mesh_instance)
	parent.add_child(joint)
	return joint


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
