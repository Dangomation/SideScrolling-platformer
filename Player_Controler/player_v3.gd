extends CharacterBody3D

@onready var walk_settings = Movement_Settings.new(10, 10, 5)
@onready var run_settings = Movement_Settings.new(14, 14, 5)
@onready var current_setting = Movement_Settings.new(10, 10, 5)

@onready var state_chart = $StateChart
@onready var label = $Label3D

var gravity = 50
var friction = 0
# Kinda debug var?

var input_x = 0.0
var input_y = 0.0

var dash_dir = 0
var can_dash = false
var dash_time = 0
var dash_time_max = 15
var run_joy_threashold

var jump_pressed = false
var jump_released = false
var jump_held = false
var jump_active = false
var jump_frame_count = 0

var dodge = false
var dodge_dir = false

func _ready():
	pass

#region Player_Input
func player_input():
# is called every physics frame
	var vel_x = input_x
	var d = 0.5 # deadzone
	input_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_y = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")

	vel_x = input_x - vel_x # acceleration
	input_x = remap(clamp(input_x, -d, d), -d, d, -1, 1)

	if abs(vel_x) > 0.6 and is_on_floor():
		can_dash = true
	if abs(input_x) < 0.5:
		can_dash = false

	#if vel_x != 0:
		#prints(can_dash, vel_x)
	# a shoddy 'speed' check for sprinting/turning
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_released = Input.is_action_just_released("jump")
	dodge = Input.is_action_just_pressed("dodge")

	if jump_pressed:
		jump_held = true
	if jump_released:
		jump_held = false

	if dodge and ! is_on_floor():
		dodge_dir = Vector2(input_x, input_y).normalized()


func accelerate(target_dir: Vector3, target_speed: float, accel: float, delta: float):
	#var current_speed = velocity.dot(target_dir)
	#var add_speed = target_speed - current_speed
	var current_speed_x = velocity.x / target_dir.x
	var add_speed_x = target_speed - current_speed_x
	var accel_speed = accel * delta * target_speed
	#TODO: Check if the line above will break anything when interacting with all dimensions (X,Y,Z).
	# Can be reused for both X and Y
	if abs(target_dir.x):
		if add_speed_x:
			if accel_speed > add_speed_x:
				accel_speed = add_speed_x
			velocity.x += accel_speed * target_dir.x

	if abs(target_dir.y):
		var current_speed_y = velocity.y / target_dir.y
		var add_speed_y = target_speed - current_speed_y
		if add_speed_y:
			if accel_speed > add_speed_y:
				accel_speed = add_speed_y
			velocity.y += accel_speed * target_dir.y

	if abs(target_dir.z):
		var current_speed_z = velocity.z / target_dir.z
		var add_speed_z = target_speed - current_speed_z
		if add_speed_z:
			if accel_speed > add_speed_z:
				accel_speed = add_speed_z
			velocity.z += accel_speed * target_dir.z


func apply_friction(t: float, delta: float):
	friction = t * walk_settings.Deceleration * delta * velocity.x
	velocity.x -= friction
#endregion


func apply_gravity(delta):
	velocity.y -= gravity * delta
	velocity.y = maxf(velocity.y, -30)


func _on_movement_state_physics_processing(delta):
	player_input()
	move_and_slide()

	# DEBUG TEXT.
	label.text = str(
	"vel_x: ", snapped(velocity.x, 0.001),
	"\n real_Vel", get_real_velocity().length(),
	"\n friction: ", snapped(friction, 0.001),
	"\n can_dash: ", can_dash,
	"\n dash_time: ", snapped(dash_time, 0.01)
	)


func _on_grounded_state_physics_processing(delta):
	if !is_on_floor():
		state_chart.send_event(&"to_airborne"); return
	if jump_held:
		state_chart.send_event(&"to_jump"); return


func _on_walking_state_entered():
	current_setting = walk_settings


func _on_walking_state_physics_processing(delta):
	if abs(input_x) == 0:
		apply_friction(1.0, delta)
	else:
		accelerate(Vector3(input_x,0,0), walk_settings.Acceleration, walk_settings.Max_Speed, delta)

	if !is_on_floor():
		state_chart.send_event(&"to_airborne"); return
		##TODO: change to "2nd jump"
	if can_dash:
		state_chart.send_event(&"to_dash"); return
	if jump_held:
		state_chart.send_event(&"to_jump"); return


func _on_running_state_entered():
	current_setting = run_settings


func _on_running_state_physics_processing(delta):
	accelerate(Vector3(input_x,0,0), run_settings.Acceleration, run_settings.Max_Speed, delta)
	if sign(input_x) != sign(velocity.x) or abs(input_x) < 0.1:
		state_chart.send_event(&"to_slide")


func _on_dash_state_entered():
	velocity.x = 0
	dash_dir = sign(input_x)
	current_setting = run_settings


func _on_dash_state_physics_processing(delta):
	accelerate(Vector3(dash_dir, 0, 0), run_settings.Max_Speed, run_settings.Acceleration, delta)
	dash_time += 1

	if sign(velocity.x) != sign(input_x) and input_x != 0:
	## Redirect dash within the time.
		dash_time = 0
		velocity.x = 0
		dash_dir = sign(input_x)

	if dash_time < dash_time_max: return
	if dash_dir != sign(input_x):
		state_chart.send_event(&"to_slide")
		return
	state_chart.send_event(&"to_run")


func _on_dash_state_exited():
	can_dash = false
	dash_time = 0


func _on_slide_state_physics_processing(delta):
	if !is_on_floor():
		state_chart.send_event(&"to_airborne")
		return

	apply_friction(2, delta)
	if abs(velocity.x) < 2:
	## TODO: /\ Change to time /\
		if sign(velocity.x) != sign(input_x) and input_x != 0:
			state_chart.send_event(&"to_run")
		else:
			state_chart.send_event(&"to_walk")


func _on_airborn_state_physics_processing(delta):
	apply_gravity(delta) #FIXME: set valid condition for gravity.
	accelerate(Vector3(input_x,0,0), current_setting.Acceleration, current_setting.Max_Speed, delta)


func _on_air_state_physics_processing(delta):
	if is_on_floor():
		if current_setting == walk_settings:
			state_chart.send_event(&"to_walk")
		else:
			state_chart.send_event(&"to_run")


func _on_jump_state_physics_processing(delta):
	var frame_times = [2, 4, 12]

	if not jump_held or jump_frame_count >= frame_times.back():
		for item in frame_times:
			if item == jump_frame_count:
				jump_active = false
				jump_frame_count = 0
				if !is_on_floor():
					state_chart.send_event(&"to_air")
					# FIXME: "to_double_jump" when its added
					#state_chart.send_event(&"to_double_jump")
				else:
					if current_setting == walk_settings:
						state_chart.send_event(&"to_walk")
					else:
						state_chart.send_event(&"to_run")
				return
	jump_frame_count += 1
	accelerate(Vector3.UP, 13, 13 * 60, delta)




