class_name ModelDefinition
extends RefCounted
## Declarative description of a character/creature model, registered from
## content/models/*.json. This is the hand-off point for externally produced
## art: point `scene` at a .glb and map its bones and animation clips to the
## engine's logical names. Until the file exists the placeholder is used.

## Logical attachment points every character model may expose.
const ATTACHMENT_POINTS: PackedStringArray = [
	"head", "face", "chest", "back", "left_hand", "right_hand", "waist", "feet",
]
## Logical animation names the engine requests.
const ANIMATIONS: PackedStringArray = ["idle", "walk", "run", "jump", "fall"]

var id: String = ""
## Model asset id (resolved under <pack>/models/, e.g. .glb).
var scene: String = ""
var scale: float = 1.0
## Placeholder used while `scene` is missing: {"type": "humanoid"|"box", ...}.
var placeholder: Dictionary = {"type": "box"}
## Attachment point -> bone name in the model's Skeleton3D.
var attachment_bones: Dictionary = {}
## Logical animation name -> clip name in the model's AnimationPlayer.
var animations: Dictionary = {}
var source_mod: String = ""
