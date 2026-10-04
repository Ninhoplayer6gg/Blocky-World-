class_name EventBus
extends RefCounted
## Decoupled publish/subscribe channel between systems and (later) mods.
##
## Listeners run synchronously on the main thread in priority order (higher
## first, ties in subscription order). Payloads are Dictionaries so new fields
## can be added without breaking listeners. Emitting from worker threads is a
## programming error and is reported.

var _listeners: Dictionary = {}
var _sequence := 0


func subscribe(event_id: StringName, callable: Callable, priority: int = 0) -> void:
	if not NamespacedId.is_valid(event_id):
		Log.error("EVENT", "Cannot subscribe to '%s': %s" % [event_id, NamespacedId.explain_invalid(event_id)])
		return
	var list: Array = _listeners.get(event_id, [])
	for listener in list:
		if listener.callable == callable:
			return
	_sequence += 1
	list.append({"callable": callable, "priority": priority, "order": _sequence})
	list.sort_custom(_sort_listeners)
	_listeners[event_id] = list


func unsubscribe(event_id: StringName, callable: Callable) -> void:
	var list: Array = _listeners.get(event_id, [])
	for i in range(list.size() - 1, -1, -1):
		if list[i].callable == callable:
			list.remove_at(i)


## Removes every listener bound to `owner` (call when a node/mod goes away).
func unsubscribe_owner(owner: Object) -> void:
	for event_id in _listeners:
		var list: Array = _listeners[event_id]
		for i in range(list.size() - 1, -1, -1):
			if list[i].callable.get_object() == owner:
				list.remove_at(i)


## Emits `event_id` and returns the payload (listeners may have modified it).
func emit(event_id: StringName, payload: Dictionary = {}) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		Log.error("EVENT", "Event '%s' emitted from a worker thread; events are main-thread only" % event_id)
		return payload
	payload["event"] = event_id
	var list: Array = _listeners.get(event_id, [])
	if list.is_empty():
		return payload
	for listener in list.duplicate():
		var callable: Callable = listener.callable
		if not callable.is_valid():
			unsubscribe(event_id, callable)
			continue
		callable.call(payload)
		if payload.get("stop_propagation", false):
			break
	return payload


## Convenience for cancellable "*_ing" events.
func emit_cancellable(event_id: StringName, payload: Dictionary) -> bool:
	payload["cancelled"] = false
	emit(event_id, payload)
	return not payload.get("cancelled", false)


func listener_count(event_id: StringName) -> int:
	return _listeners.get(event_id, []).size()


func clear() -> void:
	_listeners.clear()


static func _sort_listeners(a: Dictionary, b: Dictionary) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.order < b.order
