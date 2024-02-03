extends CharacterBody3D

#@onready var ray := $Raycast3D
@onready var state_chart := $StateChart
@onready var label3d_debug := $ Label3D

# Settings
#@export_category("Settings")
@onready var ground_settings = Movement_Settings.new(20, 20, 5)
@onready var arial_settings = Movement_Settings.new(20, 7, 5)
@onready var dodge_settings = Movement_Settings.new(200, 40, 0)
# Controler joy
var controller_id = 0
var deadzone_joyleft := 0.25
var deadzone_joyright := 0.25
var input_vector := Vector2.ZERO
var input_x := 0.0
var input_y := 0.0
# Buttons
var dodge := false
var dodge_dir := Vector2.ZERO
var dodge_counter := 0
# Jump stuff
var jump_pressed := false
var jump_released := false
var jump_held := false
var jumping := false
var jump_queued := false
var jump_counter := 0
var jump_force := 15
var max_jumps := 2
#psudo physics here
var gravity := 50
var friction := 0.0 # Debug readout


#func _physics_process(delta):
#	player_input()


func player_input(delta):
	input_vector = Input.get_vector("move_left", "move_right", "move_down", "move_up", deadzone_joyleft)
	input_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_y = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")

	jump_pressed = Input.is_action_just_pressed("jump")
	jump_released = Input.is_action_just_released("jump")
	dodge = Input.is_action_just_pressed("dodge")

	if jump_pressed:
		jump_held = true
	if Input.is_action_just_released("jump"):
		jump_held = false
	# Que jump instead of auto-jumping
	if jump_pressed and !jump_queued:
		jump_queued = true
	if jump_released:
		jump_queued = false

	if dodge:
		dodge_dir = Vector2(input_x, input_y).normalized()
		this = velocity.length() + 40


func accelerate(target_dir: Vector3, target_speed: float, accel: float, delta: float):
	var current_speed = velocity.dot(target_dir)
	var add_speed = target_speed - current_speed
	if add_speed <= 0:
		return

	var accel_speed = accel * delta * target_speed
	if accel_speed > add_speed:
		accel_speed = add_speed

	velocity.x += accel_speed * target_dir.x
	velocity.y += accel_speed * target_dir.y
#	velocity.z += accel_speed *


func apply_friction(t: float, delta: float, move_setting: Movement_Settings):
# is player moving?
# is he moving
	pass
	#var speed = absf(velocity.x)
	#var drop = 0.0
	#var control : float
#
	#if speed < move_setting.Deceleration:
		#control = move_setting.Deceleration
	#else:
		#control = speed
	#drop = control * friction * delta * t
#
	#var new_speed = speed - drop
	#@warning_ignore("narrowing_conversion") # Designed as such.
	#friction = new_speed
#
	#if new_speed < 0:
		#new_speed = 0
	#if speed > 0:
		#new_speed /= speed
	#velocity.x *= new_speed
#	velocity.y *= new_speed #(REMOVE) or comment out
#	velocity.z *= new_speed


func player_gravity(delta):
	velocity.y -= gravity * delta
	velocity.y = maxf(velocity.y, -30)


var frame_count := 0
func on_jump(delta):
	if jump_queued and is_on_floor():
		jump_queued = false
		jumping = true

	var first = 1
	var seccond = 3
	var third = 12

	if frame_count	!= 0:
		#prints("vel.y", velocity.y, "global.pos", global_position, "frame_count:", frame_count)
		pass
	if not jump_held and frame_count == first or (not jump_held and frame_count == seccond) or frame_count >= third:
		jumping = false
		frame_count = 0
	# Jump gates to close on

	if jumping and (frame_count <= first or frame_count <= seccond or frame_count <= third):
		frame_count += 1
		velocity.y = jump_force


func debug_text():
	if true: # TODO: Debug bool here
		var text = [
			str("(x:", input_x, " y:", input_y,")"),
			str("jumping: ", jumping),
			str("dodge_counter: ", dodge_counter),
			str("vel: ", roundf(velocity.x), ", ", roundf(velocity.y)),
			str("friction: ", friction)
		]
		label3d_debug.text = ''
		for item in text:
			label3d_debug.text += item + "\n"
		#print(label3d_debug.text)



func _on_root_state_physics_processing(delta):
	player_input(delta)
	debug_text()


func _on_ground_state_physics_processing(delta):
	var v3 = Vector3(input_x, 0, 0)
	accelerate(v3, ground_settings.Max_Speed, ground_settings.Acceleration, delta)
	# Movement

	if !is_on_floor() or jump_queued:
		on_jump(delta)
		state_chart.send_event(&"to_air")
	apply_friction(1.0, delta, ground_settings)
	# Check if jumping
	move_and_slide()

	# Else keep doing grounded movment


func _on_air_state_physics_processing(delta):
	var v3 = Vector3(input_x, 0, 0)
	accelerate(v3, arial_settings.Max_Speed, arial_settings.Acceleration, delta)

	if !jumping:
		player_gravity(delta)
	else:
		on_jump(delta)
	if is_on_floor() and not jump_queued:
		state_chart.send_event(&"to_ground")
	if dodge:
		jumping = false
		state_chart.send_event(&"to_dodge")

	apply_friction(1.0, delta, arial_settings)
	move_and_slide()

var this = 0
func _on_dodge_state_physics_processing(delta):
		if !is_on_floor() and dodge_counter == 0:
			velocity.y = 0

		#if dodge:
			#this = velocity.length() + 20

		if is_on_floor():
			dodge_counter = 0
			state_chart.send_event(&"to_ground")
		elif dodge_counter >= 10:
			dodge_counter = 0
			state_chart.send_event(&"to_air")
		else:
			dodge_counter += 1

		accelerate(Vector3(dodge_dir.x, dodge_dir.y, 0), this, dodge_settings.Acceleration, delta)
		move_and_slide()
		# if still in air at dodge end:
		# state_chart.send_event(&"to_air")

