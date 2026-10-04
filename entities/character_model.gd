class_name CharacterModel
extends Node3D
## Visual representation of an entity, decoupled from gameplay.
##
## Loads the model scene declared by a ModelDefinition (.glb from the asset
## pipeline). Attachment points (head, right_hand, ...) become
## BoneAttachment3D nodes on the mapped skeleton bones, so equipment, hair or
## weapons follow animations. Logical animations (idle, walk, ...) map to the
## model's AnimationPlayer clips.
##
## When the model file does not exist yet, a placeholder is generated with the
## same attachment points, so gameplay code never depends on the placeholder.

const PLACEHOLDER_POINTS := {
	"head": ["Head", Vector3(0, 0.5, 0)],
	"face": ["Head", Vector3(0, 0.25, 0.26)],
	"chest": ["Body", Vector3(0, 0.45, 0.14)],
	"back": ["Body", Vector3(0, 0.45, -0.14)],
	"left_hand": ["LeftArm", Vector3(0, -0.66, 0)],
	"right_hand": ["RightArm", Vector3(0, -0.66, 0)],
	"waist": ["Body", Vector3(0, 0.0, 0)],
	"feet": ["", Vector3(0, 0, 0)],
}

var definition: ModelDefinition
var is_placeholder := true
var _points: Dictionary = {}
var _animation_player: AnimationPlayer
var _current_animation := ""
var _swing := 0.0


## `size` is the entity collision box, used to scale placeholders.
func build(model_definition: ModelDefinition, resources: ResourceManager, size: Vector3) -> void:
	definition = model_definition
	var scene: Node3D = null
	if definition != null and not definition.scene.is_empty():
		scene = resources.instantiate_model(definition.scene)
		if scene == null:
			resources.note_placeholder(ResourceManager.MODELS, definition.scene)
	if scene != null:
		is_placeholder = false
		scene.scale = Vector3.ONE * definition.scale
		add_child(scene)
		_setup_from_scene(scene, size)
	else:
		is_placeholder = true
		_setup_placeholder(size)


func get_attachment_point(point: String) -> Node3D:
	return _points.get(point)


func attachment_points() -> PackedStringArray:
	return PackedStringArray(_points.keys())


## Parents `node` to an attachment point. Returns false if the point is unknown.
func attach(point: String, node: Node3D) -> bool:
	var target := get_attachment_point(point)
	if target == null:
		Log.warn("ENTITY", "Model has no attachment point '%s'" % point)
		return false
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	target.add_child(node)
	return true


func detach_all(point: String) -> void:
	var target := get_attachment_point(point)
	if target == null:
		return
	for child in target.get_children():
		child.queue_free()


## Plays a logical animation ("idle", "walk", ...) if the model provides it.
func play(animation: String) -> void:
	if animation == _current_animation:
		return
	_current_animation = animation
	if _animation_player == null:
		return
	var clip: String = definition.animations.get(animation, animation) if definition != null else animation
	if _animation_player.has_animation(clip):
		_animation_player.play(clip, 0.15)


func update_locomotion(horizontal_speed: float, on_floor: bool, vertical_speed: float, delta: float) -> void:
	if not on_floor:
		play("jump" if vertical_speed > 0.0 else "fall")
	elif horizontal_speed > 4.8:
		play("run")
	elif horizontal_speed > 0.2:
		play("walk")
	else:
		play("idle")
	if is_placeholder:
		_animate_placeholder(horizontal_speed, delta)


func _setup_from_scene(scene: Node3D, size: Vector3) -> void:
	_animation_player = _find_first(scene, "AnimationPlayer") as AnimationPlayer
	var skeleton := _find_first(scene, "Skeleton3D") as Skeleton3D
	for point in ModelDefinition.ATTACHMENT_POINTS:
		var bone_name: String = definition.attachment_bones.get(point, "")
		if skeleton != null and not bone_name.is_empty():
			if skeleton.find_bone(bone_name) < 0:
				Log.warn("ENTITY", "Model %s: bone '%s' for attachment '%s' not found" % [definition.id, bone_name, point])
			else:
				var attachment := BoneAttachment3D.new()
				attachment.name = "Attach_" + point
				attachment.bone_name = bone_name
				skeleton.add_child(attachment)
				_points[point] = attachment
				continue
		_points[point] = _marker(self, point, _default_offset(point, size))


func _setup_placeholder(size: Vector3) -> void:
	var placeholder: Dictionary = definition.placeholder if definition != null else {"type": "box"}
	var colors := {}
	for key in placeholder.get("colors", {}):
		var value: Variant = placeholder["colors"][key]
		if typeof(value) == TYPE_STRING and Color.html_is_valid(value):
			colors[key] = Color.html(value)
	var root: Node3D
	if placeholder.get("type", "box") == "humanoid":
		root = PlaceholderFactory.humanoid(colors, size.y)
		add_child(root)
		var scale_factor := size.y / 1.8
		for point in PLACEHOLDER_POINTS:
			var spec: Array = PLACEHOLDER_POINTS[point]
			var parent: Node3D = root.get_node_or_null(spec[0]) if not str(spec[0]).is_empty() else root
			_points[point] = _marker(parent if parent != null else root, point, spec[1] * scale_factor)
	else:
		root = PlaceholderFactory.box_model(size, colors.get("body", Color(0.8, 0.4, 0.2)))
		add_child(root)
		for point in ModelDefinition.ATTACHMENT_POINTS:
			_points[point] = _marker(root, point, _default_offset(point, size))


func _animate_placeholder(horizontal_speed: float, delta: float) -> void:
	var root := get_node_or_null("PlaceholderHumanoid")
	if root == null:
		return
	var amount := clampf(horizontal_speed / 4.3, 0.0, 1.4)
	_swing += delta * (4.0 + horizontal_speed * 1.6)
	var angle := sin(_swing) * 0.7 * amount
	for limb in [["LeftArm", -1.0], ["RightArm", 1.0], ["LeftLeg", 1.0], ["RightLeg", -1.0]]:
		var node := root.get_node_or_null(limb[0]) as Node3D
		if node != null:
			node.rotation.x = angle * limb[1]


static func _marker(parent: Node3D, point: String, offset: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = "Attach_" + point
	marker.position = offset
	parent.add_child(marker)
	return marker


static func _default_offset(point: String, size: Vector3) -> Vector3:
	match point:
		"head":
			return Vector3(0, size.y, 0)
		"face":
			return Vector3(0, size.y * 0.85, size.z * 0.5)
		"chest":
			return Vector3(0, size.y * 0.65, size.z * 0.5)
		"back":
			return Vector3(0, size.y * 0.65, -size.z * 0.5)
		"left_hand":
			return Vector3(size.x * 0.6, size.y * 0.45, 0)
		"right_hand":
			return Vector3(-size.x * 0.6, size.y * 0.45, 0)
		"waist":
			return Vector3(0, size.y * 0.45, 0)
	return Vector3.ZERO


static func _find_first(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_first(child, type_name)
		if found != null:
			return found
	return null
