class_name Player
extends CharacterBody2D

signal kill_player

# Player Constants
const SPEED = 150.0
const JUMP_VELOCITY = -400.0
const ACCELERATION = 250
const FRICTION = 550

# Sprint Constants
const SPRINT_SPEED = 250.0
const SPRINT_ACCELERATION = 750
const AIR_FRICTION = 100

# Juice Constants
const TURN_SPEED = 400   # How fast player snaps to the opposite direction
const AIR_TURN_SPEED = 600   # How fast player snaps to the opposite direction
const COYOTE_FRAMES = 6

var is_jumping = false
var is_sprinting = false
var is_coyote_time = false
var was_on_floor = false
var spawn_point = Vector2(0, 0)

func _ready() -> void:
	$CoyoteTimer.wait_time = COYOTE_FRAMES / 60.0
	spawn_point = position

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle coyote time.
	if !is_on_floor() and was_on_floor and !is_jumping:
		is_coyote_time = true
		$CoyoteTimer.start()
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and (is_on_floor() or is_coyote_time):
		velocity.y = JUMP_VELOCITY
		is_jumping = true
	
	# Handle sprint.
	if Input.is_action_pressed("sprint"):
		is_sprinting = true
	else:
		is_sprinting = false
		
	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		# Check if moving opposite to current velocity
		var is_turning = sign(direction) != sign(velocity.x) and velocity.x != 0
		
		var current_accel = SPRINT_ACCELERATION if is_sprinting else ACCELERATION
		var turn_accel = AIR_TURN_SPEED if !is_on_floor() else TURN_SPEED
		var final_accel = turn_accel if is_turning else current_accel
		var current_speed = SPRINT_SPEED if is_sprinting else SPEED
		
		velocity.x = move_toward(velocity.x, direction * current_speed, final_accel * delta)
	else:
		var current_friction = AIR_FRICTION if !is_on_floor() else FRICTION
		velocity.x = move_toward(velocity.x, 0, current_friction * delta)
	
	move_and_slide()
	was_on_floor = is_on_floor()

func _process(_delta: float) -> void:
	if velocity.x > 0:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = false
	elif velocity.x < 0:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = true
	elif velocity.x == 0:
		$AnimatedSprite2D.play("default")

func _on_kill_player() -> void:
	velocity = Vector2(0, 0)
	position = spawn_point

func _on_coyote_timer_timeout() -> void:
	is_coyote_time = false
