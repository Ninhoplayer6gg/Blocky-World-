class_name MovementIntent
extends RefCounted
## What an entity wants to do this physics tick. Written by a controller
## (player input, AI) and consumed by the movement component, so controllers
## and locomotion stay independent (swap AI for input, add vehicles later).

## Desired horizontal direction in world space (length 0..1).
var direction := Vector3.ZERO
var jump := false
var sprint := false
var crouch := false
## Vertical input for flying/swimming: -1 down, +1 up.
var vertical := 0.0


func clear() -> void:
	direction = Vector3.ZERO
	jump = false
	sprint = false
	crouch = false
	vertical = 0.0
