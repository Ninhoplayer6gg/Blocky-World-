class_name AttributeDefinition
extends RefCounted
## A numeric stat any entity can carry (health, speed, mana, ki, energy...).
## Registered from content/attributes/*.json so mods can add their own.

var id: String = ""
var display_name: String = ""
var default_value: float = 0.0
var min_value: float = -INF
var max_value: float = INF
var source_mod: String = ""


func clamp_value(value: float) -> float:
	return clampf(value, min_value, max_value)
