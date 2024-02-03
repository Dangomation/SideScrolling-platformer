extends Node
class_name Movement_Settings

var Max_Speed : float
var Acceleration : float
var Deceleration : float

## Constructor.
func _init(maxspeed: float, accel: float, decel: float):
	Max_Speed = maxspeed
	Acceleration = accel
	Deceleration = decel
