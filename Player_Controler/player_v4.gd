extends CharacterBody3D

@onready var label_2D = $Label
@onready var state_chart = $StateChart

@onready var walk_settings = Movement_Settings.new(7, 120, 30)
var gravity = 50
var ground_friction = 0

#Controls
@onready var joystick_left := Vector3.ZERO
@onready var joystick_right := Vector3.ZERO
@onready var deadzone_left := .6
@onready var deadzone_right := .6
#Buttons
var jump_pressed = false
var jump_released = true

#Jumping
var jump_impulse = 13
var can_jump = false
var jump_frame_count = 0
var frame_times = [2, 6, 12]

func _ready():
	pass


func _physics_process(delta):
	input()
	debug()


func debug():
	var debug_this = str(
		"joystick_left: (", joystick_left.x, ", ", joystick_left.y, ")",
		"\n friction: ", ground_friction,
		"\n velocity_x: ", velocity.x,
		"\n velocity_y: ", velocity.y,
		"\n On Ground: ", is_on_floor(),
		"\n jumping?: ", can_jump,
		"\n jump_count?: ", jump_frame_count
		)
	label_2D.text = debug_this


#func _input(event):
### TODO: Descriminate between controller and keyboard inputs
	#pass
var counter = 0
func input():
	# Joystick inputs

	joystick_left.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	joystick_left.y = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")

	joystick_left.x = remap(
		clamp(joystick_left.x, -deadzone_left, deadzone_left), -deadzone_left, deadzone_left, -1, 1)
	# Button Inputs
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_released = Input.is_action_just_released("jump")

	if jump_pressed and !can_jump:
		can_jump = true
	if jump_released:
		can_jump = false


func apply_gravity(delta):
	velocity.y -= gravity * delta
	velocity.y = maxf(velocity.y, -30)


func apply_friction(friction: float, delta: float):
	var current_speed = velocity.x / -sign(velocity.x)
	var subtract_speed = 0 - current_speed
	var decel_speed = friction * delta

	if decel_speed > subtract_speed:
		decel_speed = subtract_speed
	ground_friction = decel_speed

	velocity.x += -sign(velocity.x) * decel_speed


func accelerate(direction: Vector3, accel: float, max_speed: float, delta):
## 	Accel: Units per sec added to player
## 	Max_speed (should), not exceed set limits
	if abs(direction.x) != 0:
## 	Don't Devide by Zero /\
		var current_speed_x = velocity.x / direction.x
		var add_speed_x = max_speed - current_speed_x
		var accel_speed_x = accel * delta

		if accel_speed_x > add_speed_x:
			accel_speed_x = add_speed_x
		velocity.x += direction.x * accel_speed_x

	if abs(direction.y) != 0:
		var current_speed_y = velocity.y / direction.y
		var add_speed_y = max_speed - current_speed_y
		var accel_speed_y = accel * delta

		if accel_speed_y > add_speed_y:
			accel_speed_y = add_speed_y
		velocity.y += direction.y * accel_speed_y


func move_player(delta):
	if abs(joystick_left.x) != 0:
		pass


func do_jump(delta):
	if !can_jump or jump_frame_count >= frame_times.back():
		for item in frame_times:
			if item == jump_frame_count:
				if !is_on_floor():
					state_chart.send_event(&"to_air")
					# FIXME: "to_double_jump" when its added
					#state_chart.send_event(&"to_double_jump")
				else:
					state_chart.send_event(&"to_ground")
				can_jump = false
				return
	jump_frame_count += 1
	accelerate(Vector3.UP, jump_impulse * 60, jump_impulse, delta)


func _grounded_physics(delta):
	if !is_on_floor():
		state_chart.send_event(&"to_air")
		return
	if jump_pressed:
		state_chart.send_event(&"to_jump")
		return

	if joystick_left.x:
		accelerate(Vector3(joystick_left.x,0,0), walk_settings.Acceleration, walk_settings.Max_Speed, delta)
	else:
		apply_friction(walk_settings.Deceleration, delta)
	move_and_slide()

#region Compound state Airborne
func _airborne_physics(delta):
	if abs(joystick_left.x) != 0:
		accelerate(Vector3(joystick_left.x,0,0), walk_settings.Acceleration, walk_settings.Max_Speed, delta)

func _jump_physics(delta):
	do_jump(delta)
	move_and_slide()


func _jump_entered():
	jump_frame_count = 0


func _air_physics(delta):
	if is_on_floor():
		state_chart.send_event(&"to_ground")
	apply_gravity(delta)
	move_and_slide()
#endregion




