extends KinematicBody2D

export (int) var run_speed = 100
export (int) var jump_speed = -400
export (int) var gravity = 1200

var velocity = Vector2()
var jumping = false

export (float, 0, 1.0) var friction = 0.1
export (float, 0, 1.0) var acceleration = 0.25

var attack_reset = true
var timer

func _ready():
	timer = Timer.new()
	timer.connect("timeout",self,"_on_timer_timeout") 
	timer.set_wait_time(3) # this is based off equiped weapon
	add_child(timer) #to process
	timer.start() #to start

func get_input():
	### Movement Code
	var dir = 0
	if Input.is_action_pressed("ui_right"):
		dir += 1
	if Input.is_action_pressed("ui_left"):
		dir -= 1
	if dir != 0:
		velocity.x = lerp(velocity.x, dir * run_speed, acceleration)
	else:
		velocity.x = lerp(velocity.x, 0, friction)
		
	if Input.is_action_just_pressed("ui_select") and is_on_floor():
		jumping = true
		velocity.y = jump_speed
		
	### Combat Code (not yet implemented
	if Input.is_action_pressed("mouse_left") and attack_reset:
		print("attack")
		attack_reset = false
		timer.start()
		# will initiate attack animation and spawn hitbox, use a timer for delay
		#both melee strike and ranged, use same attack mouse point follower
		#melee determines where it stabs versus where it shoots
		#three strike combos

func _physics_process(delta):
	get_input()
	velocity.y += gravity * delta
	if jumping and is_on_floor():
		jumping = false
	velocity = move_and_slide(velocity, Vector2(0, -1))

func _on_timer_timeout():
   attack_reset = true
