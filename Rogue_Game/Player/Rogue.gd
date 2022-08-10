###############################################################################
# PlayerInstance Script : #####################################################
###############################################################################

extends KinematicBody

###CONSTANTS###################################################################
const ACCEL = 4.5
const DEACCEL = 16
const SPRINT_ACCEL = 18
const MAX_SLOPE_ANGLE = 40
const MAX_SPEED = 8
const MAX_SPRINT_SPEED = 15
const JUMP_SPEED = 15 #9
const GRAVITY = -24.8


###ANIMATION###################################################################
var animation_player : AnimationPlayer
var current_animation : String

###PLAYER VARIABLES############################################################
######MOVEMENT#################################################################
var is_sprinting : bool
var vel : Vector3 = Vector3()
var dir : Vector3 = Vector3()
var sprint_energy : int
var sprint_recharge : bool

######FLASHLIGHT###############################################################
var flashlight : SpotLight

######CAMERA###################################################################
onready var camera = get_node("rotation_helper/player_camera")
export var x_range = 25

######ROTATION HELPER##########################################################
onready var rotation_helper = get_node("rotation_helper")
export var mouse_sensitivity = 0.05

######UI#######################################################################
var reticle : String #Not yet implemented

######PLAYER MODEL#############################################################
onready var player_model = get_node("player_model")

###HELPER VARIABLES FOR NETWORKING#############################################
var init : bool = false

###############################################################################
# Ready Function called on Scene creation and instancing, enables the camera ##
# and sets up UI for network master scene. ####################################
###############################################################################
func _ready():
	pass

###############################################################################
# Called once to initialize certain attributes of the player instance after ###
# it has loaded into and connected with the host, called after connection #####
# is established to load up model and certain ui elements #####################
###############################################################################
func initFunc():
	# Getting Animation Node from player_model child
	#animation_player = get_node("player_model/player_model/AnimationPlayer")

	# Set Initial Animation
	#animation_player.play("animationIdle")

	# Initial Mouse Mode
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Set Sprint Energy
	sprint_energy = 100
	sprint_recharge = false

	# Set Initialization Value
	init = true

###############################################################################
# Looping physics process to handle phyiscs simulation and movement updates ###
# for all entities in the world scene #########################################
###############################################################################
func _physics_process(delta):
	process_inputs(delta)
	process_movement(delta)

###############################################################################
# If instance in network master, track mouse input movements and handle #######
# rotational movements and commands ###########################################
###############################################################################
func _input(event):
	if event is InputEventMouseMotion and \
	Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(
				deg2rad(event.relative.y*mouse_sensitivity * 1))
				#change to 1 for inverted mouse up/dwn
		self.rotate_y(
				deg2rad(event.relative.x*mouse_sensitivity * -1))
				#change to 1 for inverted mouse left/right

		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -x_range, x_range)

		rotation_helper.rotation_degrees = camera_rot

###############################################################################
# Handles inputs that are related to movement and non rotational input ########
# Implements movement, and eventual killer/prey mechanics and commands ########
###############################################################################
func process_inputs(delta):
		# Handling Sprint Recharge Mechanic
		if sprint_recharge:
			if sprint_energy <= 50:
				is_sprinting = false
			else:
				sprint_recharge = false
		else:
			if sprint_energy <= 0:
				is_sprinting = false
				sprint_recharge = true
		if sprint_energy > 100:
			sprint_energy = 100
		

		#Check if Jumping
		if is_on_floor(): #keeps motion while in jump
			dir = Vector3()

		#Camera Transform
		var cam_xform = camera.get_global_transform()

		#Set Input Movement
		var input_movement_vector = Vector2()

		#Booleans for Movement
		var forward = false
		var backward = false
		var left = false
		var right = false

		if Input.is_action_pressed("movement_forward"):
			input_movement_vector.y += 1
			forward = true
		if Input.is_action_pressed("movement_backward"):
			input_movement_vector.y -= 1
			backward = true
		if Input.is_action_pressed("movement_left"):
			input_movement_vector.x -= 1
			left = true
		if Input.is_action_pressed("movement_right"):
			input_movement_vector.x += 1
			right = true

		if not is_sprinting:
			sprint_energy += 1
			if forward and is_on_floor():
				if left:
					animation_player.play("animationLeftStrafeWalk")
				elif right:
					animation_player.play("animationRightStrafeWalk")
				else:
					animation_player.play("animationWalk")
			elif backward and is_on_floor():
				if left:
					animation_player.play_backwards("animationRightStrafeWalk")
				elif right:
					animation_player.play_backwards("animationLeftStrafeWalk")
				else:
					animation_player.play_backwards("animationWalk")
			elif left and is_on_floor():
				animation_player.play("animationLeftStrafeWalk")
			elif right and is_on_floor():
				animation_player.play("animationRightStrafeWalk")
		elif is_sprinting:
			sprint_energy -= 1
			if forward and is_on_floor():
				if left:
					animation_player.play("animationLeftStrafeRun")
				elif right:
					animation_player.play("animationRightStrafeRun")
				else:
					animation_player.play("animationRun")
			elif backward and is_on_floor():
				if left:
					animation_player.play_backwards("animationRightStrafeRun")
				elif right:
					animation_player.play_backwards("animationLeftStrafeRun")
				else:
					animation_player.play_backwards("animationRun")
			elif left and is_on_floor():
				animation_player.play("animationLeftStrafeRun")
			elif right and is_on_floor():
				animation_player.play("animationRightStrafeRun")
		
		# Handle Idle Animation
		if abs(vel.x) < 1 and \
			abs(vel.y) < 1 and \
			abs(vel.z) < 1 and \
			is_on_floor():
			animation_player.play("animationIdle")
		
		if not is_on_floor():
			animation_player.play("animationFalling")
		
		input_movement_vector = input_movement_vector.normalized()
		
		dir += -cam_xform.basis.z * input_movement_vector.y
		dir += cam_xform.basis.x * input_movement_vector.x
		
		#Jump Movement
		if is_on_floor():
			if Input.is_action_just_pressed("movement_jump"):
				vel.y = JUMP_SPEED
				animation_player.play("animationFalling")
		
		#Cursor Freeing
		if Input.is_action_just_pressed("ui_cancel"):
			print("cursor freeing")
			if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		#Sprinting Movement
		if Input.is_action_pressed("movement_sprint"):
			is_sprinting = true
		else:
			is_sprinting = false

###############################################################################
# Process the movements based on input commands and apply those commands to ###
# the player instance #########################################################
###############################################################################
func process_movement(delta):
	dir.y = 0
	dir = dir.normalized()
	vel.y += delta * GRAVITY
	if is_network_master():
		var hvel = vel
		hvel.y = 0
		var target = dir
		#target *= MAX_SPEED
		if is_sprinting:
			target *= MAX_SPRINT_SPEED
		else:
			target *= MAX_SPEED
		var accel
		if dir.dot(hvel) > 0:
			if is_sprinting:
				accel = SPRINT_ACCEL
			else:
				accel = ACCEL
		else:
			accel = DEACCEL
		hvel = hvel.linear_interpolate(target, accel * delta)
		vel.x = hvel.x
		vel.z = hvel.z
	

