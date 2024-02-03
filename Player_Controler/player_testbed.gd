extends CharacterBody3D

#@onready var ray := $Raycast3D
@onready var state_chart := $StateChart
@onready var label3d_debug := $ Label3D

# Settings
#@export_category("Settings")
@onready var ground_settings 	= Movement_Settings.new(12, 6, 5)
@onready var arial_settings 	= Movement_Settings.new(12, 6, 0) # Change deceleration?
@onready var jump_settings 		= Movement_Settings.new(15, 15, 0)
@onready var dodge_settings 	= Movement_Settings.new(20, 20, 0)
@onready var snapback_settings 	= Movement_Settings.new(25, 6, 0)

# Controler joy
var controller_id = 0
var deadzone_joyleft := 0.25
var deadzone_joyright := 0.25
var input_x := 0.0
var input_x_vel := 0.0
var input_y := 0.0

# Facing Direction
var facing := 1

# Run
var is_running := false
var run_speed := 25
# Dodge
var dodge := false
var dodge_dir := Vector2.ZERO
var dodge_count := 0
var dodge_max := 1
# Jump stuff
var jump_pressed := false
var jump_released := false
var jump_held := false
var jump_active = false
var jump_phy_count := 0
#psudo physics here
var gravity := 50
var friction := 0.0 # Debug readout


#func _ready():
	#pass


#func _physics_process(delta):
	#pass


func player_input(delta):
# is called every physics frame
	var vel_x = input_x
	var d = 0.5
	input_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_y = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")

	vel_x = input_x - vel_x # acceleration
	input_x = remap(clamp(input_x, -d, d), -d, d, -1, 1)

	if abs(vel_x) > 0.6 and is_on_floor():
		is_running = true
	if abs(input_x) <= 0.5:
		is_running = false

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
	if target_dir.x:
		if add_speed_x:
			if accel_speed > add_speed_x:
				accel_speed = add_speed_x
			velocity.x += accel_speed * target_dir.x

	if target_dir.y:
		var current_speed_y = velocity.y / target_dir.y
		var add_speed_y = target_speed - current_speed_y
		if add_speed_y:
			if accel_speed > add_speed_y:
				accel_speed = add_speed_y
			velocity.y += accel_speed * target_dir.y

	if target_dir.z:
		var current_speed_z = velocity.z / target_dir.z
		var add_speed_z = target_speed - current_speed_z
		if add_speed_z:
			if accel_speed > add_speed_z:
				accel_speed = add_speed_z
			velocity.z += accel_speed * target_dir.z


func apply_friction(t: float, delta: float, move_setting: Movement_Settings):
	#friction = move_setting.Deceleration * sign(velocity.x) * .1
	friction = move_setting.Deceleration  * delta * velocity.x
	#friction = sign(friction) * clampf(abs(friction), 0, 2.5) # Clamping for less drag
	velocity.x -= friction


func player_gravity(delta):
	velocity.y -= gravity * delta
	velocity.y = maxf(velocity.y, -30)


func face_direction():
# if you are on ground
#	-if in air, DON'T turn around
	pass


func do_dodge() -> bool:
	if dodge and dodge_count < dodge_max:
		jump_active = false
		jump_phy_count = 0
		state_chart.send_event(&"to_dodge")
		return true
	return false


#func do_running():
	## Not attatched or running atm.
	#var threshold = 0.6



func debug_text():
	if true: # TODO: Debug bool here
		var text = [
			str("(x:", input_x, " y:", input_y,") Len: ", sqrt(input_x * input_x + input_y * input_y)),
			str("jumping: ", jump_active,", jump_count: ", jump_phy_count, ", on_floor: ", is_on_floor()),
			str("dodge_count: ", dodge_count),
			str("vel: ", snappedf(velocity.x, 0.01), ", ", snappedf(velocity.y, 0.01)),
			str("Running: ", is_running, ", friction: ", snappedf(friction, 0.1))
		]
		label3d_debug.text = ''
		for item in text:
			label3d_debug.text += item + "\n"
		#print(label3d_debug.text)


func _on_movement_state_physics_processing(delta):
	state_chart.set_expression_property(&"can_dodge", dodge_count <= 0)
	state_chart.set_expression_property(&"is_on_floor", is_on_floor())

	player_input(delta)
	move_and_slide()
	debug_text()


func _on_grounded_state_entered():
	dodge_count = 0


func _on_grounded_state_physics_processing(delta):
	if jump_pressed:
		jump_active = true
		state_chart.send_event(&"to_jump")
	elif !is_on_floor():
		state_chart.send_event(&"to_airborne")
	elif velocity.x > ground_settings.Max_Speed or !input_x:
		apply_friction(1.0, delta, ground_settings)

	var v3 = Vector3(input_x, 0, 0)
	var acc = ground_settings.Acceleration
	if is_running:
		acc = ground_settings.Max_Speed * 60
	accelerate(v3, ground_settings.Max_Speed, acc, delta)


func _on_airborn_state_physics_processing(delta):
# The basic stuff that is reused here please <3
	do_dodge()
	if !jump_active:
		player_gravity(delta)
	apply_friction(1.0, delta, arial_settings)
	var v3 = Vector3(input_x, 0, 0)
	accelerate(v3, arial_settings.Max_Speed, arial_settings.Acceleration, delta)


func _on_air_state_physics_processing(delta):
	if is_on_floor():
		state_chart.send_event(&"to_ground")


func _on_coyote_state_physics_processing(delta):

	if jump_pressed:
		jump_active = true
		state_chart.send_event(&"to_jump")
	else:
		state_chart.send_event(&"to_double_jump")


func _on_jump_state_physics_processing(delta):
	# FIXME: put the 'frame times' not here :(
	var frame_times = [2, 4, 12]

	if jump_active and not jump_held or jump_phy_count >= frame_times.back():
		for item in frame_times:
			if item == jump_phy_count:
				jump_active = false
				jump_phy_count = 0
				if !is_on_floor():
					state_chart.send_event(&"to_double_jump")
				else:
					state_chart.send_event(&"to_ground")
	if jump_active:
		jump_phy_count += 1
		accelerate(Vector3.UP, jump_settings.Max_Speed, jump_settings.Acceleration, delta)


func _on_double_jump_state_physics_processing(delta):
	if is_on_floor():
		state_chart.send_event(&"to_ground")

	if jump_pressed:
		velocity.y = 0
		jump_active = true
	if jump_active:
		jump_phy_count += 1
		accelerate(Vector3.UP, jump_settings.Max_Speed, jump_settings.Acceleration, delta)

	if jump_phy_count < 12:
		return
	jump_phy_count = 0
	jump_active = false
	if !is_on_floor():
		state_chart.send_event(&"to_air")
	else:
		state_chart.send_event(&"to_ground")


func _on_dodge_state_entered():
	dodge_count += 1
	#velocity.y = 0

var fucking_dodge_ground_counter = 15
var fucking_dodge_air_counter = 15
func _on_dodge_state_physics_processing(delta):
	accelerate(Vector3(dodge_dir.x, dodge_dir.y, 0), dodge_settings.Max_Speed, dodge_settings.Acceleration, delta)

	fucking_dodge_air_counter -= 1
	if fucking_dodge_air_counter <= 0 and !is_on_floor():
	# If not on floor go to air
		fucking_dodge_ground_counter = 15
		fucking_dodge_air_counter = 15
		state_chart.send_event(&"to_air")
		return

	if !is_on_floor():
		return
	#velocity.x = dodge_settings.Max_Speed * sign(dodge_dir.x)
	#velocity.y = 0

	fucking_dodge_ground_counter -= 1
	fucking_dodge_air_counter = 0

	if jump_held and fucking_dodge_ground_counter <= 15:
		fucking_dodge_ground_counter = 15
		fucking_dodge_air_counter = 15
		jump_active = true
		state_chart.send_event(&"to_jump")
		return

	if sign(velocity.x) != sign(input_x) and velocity.x != 0 and input_x != 0 and abs(input_x) == 1:
		# FIXME: Don't just invert. Accelerate() in the opposing direction.
		velocity.x = 0
		fucking_dodge_ground_counter = 15
		fucking_dodge_air_counter = 15
		state_chart.send_event(&"to_snapback")
	if fucking_dodge_ground_counter <= 0 and is_on_floor():
		velocity.x = velocity.length() * sign(dodge_dir.x)
		fucking_dodge_ground_counter = 15
		fucking_dodge_air_counter = 15
		state_chart.send_event(&"to_ground")
	elif fucking_dodge_ground_counter <= 0:
		fucking_dodge_ground_counter = 15
		fucking_dodge_air_counter = 15
		state_chart.send_event(&"to_air")


func _on_snapback_movement_state_physics_processing(delta):
	pass # Replace with function body.


func _on_snap_back_state_physics_processing(delta):
	accelerate(Vector3(-sign(dodge_dir.x), 0, 0), snapback_settings.Max_Speed, snapback_settings.Acceleration, delta)

