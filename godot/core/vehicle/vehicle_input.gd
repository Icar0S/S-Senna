class_name VehicleInput
extends RefCounted
## What the driver asks the car to do this frame. Filled by [PlayerDriver]
## (controller/keyboard) or by the AIDriver (Etapa 11): the car never knows who drives.

## 0..1
var throttle: float = 0.0
## 0..1 (also reverse when stopped).
var brake: float = 0.0
## -1 (left) .. +1 (right).
var steer: float = 0.0
var handbrake: bool = false
var nitro: bool = false
## One-frame presses.
var shift_up: bool = false
var shift_down: bool = false
var camera_next: bool = false
var reset: bool = false
## Held.
var look_back: bool = false


func clear() -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	handbrake = false
	nitro = false
	shift_up = false
	shift_down = false
	camera_next = false
	reset = false
	look_back = false
