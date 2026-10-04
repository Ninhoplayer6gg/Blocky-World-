class_name HealthComponent
extends EntityComponent
## "blockyworld:health": current health bounded by blockyworld:max_health.
## Damage goes through the cancellable ENTITY_DAMAGING event so mods can
## modify or veto it. Params: remove_on_death (true).

signal health_changed(current: float, maximum: float)
signal died

var current := 0.0
var remove_on_death := true
var _events: EventBus


func configure(params: Dictionary) -> bool:
	remove_on_death = bool(params.get("remove_on_death", true))
	return true


func attached() -> void:
	current = get_max()
	_events = entity.world.events if entity.world != null else null


func get_max() -> float:
	return entity.attributes.get_value(AttributeRegistry.MAX_HEALTH)


func is_dead() -> bool:
	return current <= 0.0


## Returns the damage actually applied.
func damage(amount: float, source: String) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	if _events != null:
		var payload := {"entity": entity, "amount": amount, "source": source}
		if not _events.emit_cancellable(Events.ENTITY_DAMAGING, payload):
			return 0.0
		amount = float(payload.amount)
	var applied := minf(amount, current)
	current -= applied
	health_changed.emit(current, get_max())
	if is_dead():
		died.emit()
		if _events != null:
			_events.emit(Events.ENTITY_DIED, {"entity": entity, "source": source})
		if remove_on_death:
			entity.world.entities.despawn(entity)
	return applied


func heal(amount: float) -> void:
	current = minf(current + maxf(amount, 0.0), get_max())
	health_changed.emit(current, get_max())


func save_state() -> Dictionary:
	return {"current": current}


func load_state(state: Dictionary) -> void:
	current = clampf(float(state.get("current", get_max())), 0.0, get_max())
