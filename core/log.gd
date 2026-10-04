class_name Log
extends RefCounted
## Central logger. Every subsystem logs with a category tag ([CORE], [MOD],
## [CHUNK], ...) so problems are diagnosable. Thread-safe: worker threads may log.
##
## Warnings and errors also go through push_warning/push_error so they show up
## in the editor debugger with a stack trace.

enum Level { DEBUG, INFO, WARN, ERROR }

const MAX_HISTORY := 600

static var min_level: Level = Level.INFO
## When true, lines are recorded but not printed (tests that provoke errors).
static var muted := false
static var _mutex: Mutex = Mutex.new()
static var _history: PackedStringArray = PackedStringArray()
## Total lines ever written; lets UI poll for new lines without callbacks
## (callbacks would run on worker threads).
static var _written: int = 0


static func debug(category: String, message: String) -> void:
	_write(Level.DEBUG, category, message)


static func info(category: String, message: String) -> void:
	_write(Level.INFO, category, message)


static func warn(category: String, message: String) -> void:
	_write(Level.WARN, category, message)


static func error(category: String, message: String) -> void:
	_write(Level.ERROR, category, message)


## Returns lines written after `since` (a value previously returned in
## "next"), as {"lines": PackedStringArray, "next": int}.
static func read_since(since: int) -> Dictionary:
	_mutex.lock()
	var available := _history.size()
	var first_index := _written - available
	var start := maxi(since, first_index)
	var lines := _history.slice(start - first_index)
	var next := _written
	_mutex.unlock()
	return {"lines": lines, "next": next}


static func format_line(level: Level, category: String, message: String) -> String:
	match level:
		Level.WARN:
			return "[WARN][%s] %s" % [category, message]
		Level.ERROR:
			return "[ERROR][%s] %s" % [category, message]
		Level.DEBUG:
			return "[DEBUG][%s] %s" % [category, message]
	return "[%s] %s" % [category, message]


static func _write(level: Level, category: String, message: String) -> void:
	if level < min_level:
		return
	var line := format_line(level, category, message)
	if not muted:
		_print(level, line)
	_mutex.lock()
	_history.append(line)
	_written += 1
	if _history.size() > MAX_HISTORY:
		_history = _history.slice(_history.size() - MAX_HISTORY)
	_mutex.unlock()


static func _print(level: Level, line: String) -> void:
	match level:
		Level.ERROR:
			push_error(line)
		Level.WARN:
			push_warning(line)
		_:
			print(line)
