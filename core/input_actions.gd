class_name InputActions
extends RefCounted
## Abstract input actions. Gameplay code only ever asks for these names, never
## for physical keys, so touch controls and rebinding can be added later.
## Defaults are installed at startup unless the project already defines them.

const MOVE_FORWARD := &"move_forward"
const MOVE_BACKWARD := &"move_backward"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const JUMP := &"jump"
const SPRINT := &"sprint"
const CROUCH := &"crouch"
const ATTACK := &"attack"
const USE := &"use"
const PICK_BLOCK := &"pick_block"
## Reserved for the inventory screen (planned for 0.2).
const INVENTORY := &"inventory"
const HOTBAR_NEXT := &"hotbar_next"
const HOTBAR_PREV := &"hotbar_prev"
const TOGGLE_FLY := &"toggle_fly"
const TOGGLE_VIEW := &"toggle_view"
const TOGGLE_DEBUG := &"toggle_debug"
const TOGGLE_CONSOLE := &"toggle_console"
const OPEN_COMMAND := &"open_command"
const PAUSE := &"pause"

const HOTBAR_SLOT_COUNT := 9


static func hotbar_action(index: int) -> StringName:
	return StringName("hotbar_%d" % (index + 1))


static func install_defaults() -> void:
	_key(MOVE_FORWARD, KEY_W)
	_key(MOVE_BACKWARD, KEY_S)
	_key(MOVE_LEFT, KEY_A)
	_key(MOVE_RIGHT, KEY_D)
	_key(JUMP, KEY_SPACE)
	_key(SPRINT, KEY_SHIFT)
	_key(CROUCH, KEY_CTRL)
	_mouse(ATTACK, MOUSE_BUTTON_LEFT)
	_mouse(USE, MOUSE_BUTTON_RIGHT)
	_mouse(PICK_BLOCK, MOUSE_BUTTON_MIDDLE)
	_key(INVENTORY, KEY_E)
	_mouse(HOTBAR_NEXT, MOUSE_BUTTON_WHEEL_DOWN)
	_mouse(HOTBAR_PREV, MOUSE_BUTTON_WHEEL_UP)
	_key(TOGGLE_FLY, KEY_F)
	_key(TOGGLE_VIEW, KEY_F5)
	_key(TOGGLE_DEBUG, KEY_F3)
	_key(TOGGLE_CONSOLE, KEY_QUOTELEFT)
	_key(TOGGLE_CONSOLE, KEY_F1)
	_key(OPEN_COMMAND, KEY_SLASH)
	_key(PAUSE, KEY_ESCAPE)
	for i in HOTBAR_SLOT_COUNT:
		_key(hotbar_action(i), KEY_1 + i)


static func _ensure_action(action: StringName) -> bool:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		return true
	return false


static func _key(action: StringName, keycode: Key) -> void:
	_ensure_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


static func _mouse(action: StringName, button: MouseButton) -> void:
	_ensure_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventMouseButton and existing.button_index == button:
			return
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
