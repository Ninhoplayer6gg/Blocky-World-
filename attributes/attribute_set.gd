class_name AttributeSet
extends RefCounted
## Per-entity attribute values: a base value plus stackable modifiers.
##
## final = clamp((base + sum(ADD)) * product(1 + MULTIPLY))
## Modifiers are keyed by a namespaced source id so equipment, effects or
## abilities from different mods can add/remove theirs independently.

signal value_changed(attribute_id: String)

enum Operation { ADD, MULTIPLY }

var _registry: AttributeRegistry
var _base: Dictionary = {}
var _modifiers: Dictionary = {}


func _init(registry: AttributeRegistry) -> void:
	_registry = registry


func has(attribute_id: String) -> bool:
	return _base.has(attribute_id)


## Unknown attributes are refused so typos surface as errors.
func set_base(attribute_id: String, value: float) -> bool:
	var definition := _registry.get_attribute(attribute_id)
	if definition == null:
		Log.error("ENTITY", "Unknown attribute '%s'" % attribute_id)
		return false
	_base[attribute_id] = definition.clamp_value(value)
	value_changed.emit(attribute_id)
	return true


func get_base(attribute_id: String) -> float:
	if _base.has(attribute_id):
		return _base[attribute_id]
	var definition := _registry.get_attribute(attribute_id)
	return definition.default_value if definition != null else 0.0


func get_value(attribute_id: String) -> float:
	var value := get_base(attribute_id)
	var multiplier := 1.0
	for modifier in _modifiers.get(attribute_id, {}).values():
		if modifier.operation == Operation.ADD:
			value += modifier.amount
		else:
			multiplier *= 1.0 + modifier.amount
	value *= multiplier
	var definition := _registry.get_attribute(attribute_id)
	return definition.clamp_value(value) if definition != null else value


func add_modifier(attribute_id: String, source_id: String, operation: Operation, amount: float) -> void:
	var list: Dictionary = _modifiers.get(attribute_id, {})
	list[source_id] = {"operation": operation, "amount": amount}
	_modifiers[attribute_id] = list
	value_changed.emit(attribute_id)


func remove_modifier(attribute_id: String, source_id: String) -> void:
	var list: Dictionary = _modifiers.get(attribute_id, {})
	if list.erase(source_id):
		value_changed.emit(attribute_id)


func ids() -> Array:
	return _base.keys()


func to_dict() -> Dictionary:
	return _base.duplicate()
