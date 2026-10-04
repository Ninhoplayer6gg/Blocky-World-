class_name JobRunner
extends RefCounted
## Thin wrapper over WorkerThreadPool that tracks task ids so every task is
## waited on (required by Godot to release task resources) and so shutdown can
## block until background work has finished.
##
## Jobs must only touch data passed to them (snapshots) and thread-safe
## objects; never the SceneTree, Nodes or RenderingServer resources.

var _active: Dictionary = {}


func submit(job: Callable, description: String = "") -> int:
	var task_id := WorkerThreadPool.add_task(job, false, description)
	_active[task_id] = true
	return task_id


## Releases finished tasks. Call once per frame from the main thread.
func poll() -> void:
	if _active.is_empty():
		return
	var finished: Array = []
	for task_id in _active:
		if WorkerThreadPool.is_task_completed(task_id):
			finished.append(task_id)
	for task_id in finished:
		WorkerThreadPool.wait_for_task_completion(task_id)
		_active.erase(task_id)


func wait_all() -> void:
	for task_id in _active.keys():
		WorkerThreadPool.wait_for_task_completion(task_id)
	_active.clear()


func active_count() -> int:
	return _active.size()
