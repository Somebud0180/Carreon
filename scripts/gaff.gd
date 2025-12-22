class_name Player
extends CharacterBody2D

## Player Controls
#	The player (currently) has 3 mechanics
#	- Friction
#		When the player attempts to stop or counteract their movement, the player has momentum
#	- Sprint
#		When holding the sprint button, the player has improved speed, acceleration and less air friction
#	- Charge
#		While holding the sprint button standing still, the player charges. When fully charged, the player can 
#		A. Super Jump, consume their charge and jump really high
#		B. Super Sprint, accelerate to speed near instantly and move faster for 1 second

@warning_ignore("unused_signal")
signal kill_player

# Debug Variables
enum DEBUG_STATES { STANDING, MOVING, SPRINTING, CHARGING, CHARGED, JUMPING, COYOTE, FALLING }
var debug_state = []

# Player Constants
const SPEED = 150.0
const JUMP_VELOCITY = -400.0
const ACCELERATION = 250.0
const FRICTION = 550.0

# Sprint Constants
const SPRINT_SPEED = 250.0
const SPRINT_ACCELERATION = 750.0
const AIR_FRICTION = 100.0

# Charged Constansts
const CHARGE_SPEED = 25
const MAX_CHARGE_VALUE = 50.0
const CHARGED_SPEED = 450.0
const CHARGED_ACCELERATION = 750.0
const CHARGED_JUMP_VELOCITY = -600.0

# Juice Constants
const TURN_SPEED = 150.0      # How fast player snaps to the opposite direction
const AIR_TURN_SPEED = 350.0  # How fast player snaps to the opposite direction in the air
const COYOTE_FRAMES = 7          # How long the player can jump after leaving the floor
const SPRINT_COYOTE_FRAMES = 12  # How long the player can jump after leaving the floor while sprinting

# Charge value for super jump/sprint
var charge_value = 0.0:
	set(value):
		charge_value = snapped(min(MAX_CHARGE_VALUE, max(0, value)), 0.01)
		$ChargeBar.value = charge_value

var is_charging = false    # Induces the increase of the charge value
var is_charged = false     # Enables charged stats
var is_decharging = false  # Maintains charged stats for awhile (while sprinting)
var is_jumping = false
var is_sprinting = false
var is_coyote_time = false
var was_on_floor = false
var spawn_point = Vector2(0, 0)

func _ready() -> void:
	$Label.visible = true
	$CoyoteTimer.wait_time = COYOTE_FRAMES / 60.0
	spawn_point = position

func _physics_process(delta: float) -> void:
	debug_state.clear()
	
	# Handle charge
	if charge_value == MAX_CHARGE_VALUE:
		debug_state.append(DEBUG_STATES.CHARGED)
		is_charged = true
		is_decharging = true
		$ChargedTimer.start()
	
	# Add the gravity.
	if !is_on_floor():
		# Handle coyote time.
		if was_on_floor and !is_jumping:
			is_coyote_time = true
			$CoyoteTimer.start()
		
		# Apply gravity
		velocity += get_gravity() * delta
	else:
		# Reset jump
		is_jumping = false
	
	# Handle sprint.
	if Input.is_action_pressed("sprint"):
		is_sprinting = true
		$CoyoteTimer.wait_time = SPRINT_COYOTE_FRAMES / 60.0
	else:
		is_sprinting = false
		$CoyoteTimer.wait_time = COYOTE_FRAMES / 60.0
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and (is_on_floor() or is_coyote_time):
		velocity.y = CHARGED_JUMP_VELOCITY if is_charged else JUMP_VELOCITY
		is_jumping = true
		is_coyote_time = false
		is_charging = false    # Stop charging if the player jumps
		if is_charged:
			is_charged = false     # Consume charge
			is_decharging = false  # Consume charge to block charged sprint
	
	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		# Check if moving opposite to current velocity
		var is_turning = sign(direction) != sign(velocity.x) and velocity.x != 0
		
		if is_sprinting:
			debug_state.append(DEBUG_STATES.SPRINTING)
		
		var current_accel = CHARGED_ACCELERATION if is_decharging else SPRINT_ACCELERATION if is_sprinting else ACCELERATION
		var turn_accel = AIR_TURN_SPEED if !is_on_floor() else TURN_SPEED
		var final_accel = (current_accel + turn_accel) if is_turning else current_accel
		var current_speed = CHARGED_SPEED if is_decharging else SPRINT_SPEED if is_sprinting else SPEED
		
		is_charging = false  # Stop charging if the player moves
		is_charged = false   # Consume charge
		velocity.x = move_toward(velocity.x, direction * current_speed, final_accel * delta)
	else:
		var current_friction = AIR_FRICTION if !is_on_floor() else FRICTION
		velocity.x = move_toward(velocity.x, 0, current_friction * delta)
		
		if is_sprinting and is_on_floor():
			is_charging = true
			debug_state.append(DEBUG_STATES.CHARGING)
		else:
			is_charging = false
	
	if is_coyote_time:
		debug_state.append(DEBUG_STATES.COYOTE)
	
	if velocity.y < 0:
		debug_state.append(DEBUG_STATES.JUMPING)
	elif velocity.y > 0:
		debug_state.append(DEBUG_STATES.FALLING)
	
	if velocity.x != 0:
		debug_state.append(DEBUG_STATES.MOVING)
	elif velocity == Vector2(0, 0):
		debug_state.append(DEBUG_STATES.STANDING)
	
	was_on_floor = is_on_floor()
	
	if is_charging:
		$ChargeBar.visible = true
		charge_value += CHARGE_SPEED * delta
	else:
		charge_value -= CHARGE_SPEED * 2 * delta
		if charge_value == 0:
			$ChargeBar.visible = false
	
	move_and_slide()
	
	var names := debug_state.map(func(s): return DEBUG_STATES.find_key(s))
	$Label.text = ", ".join(names)
	$Label.text += ", Charge Value: " + str(charge_value)

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


func _on_charged_timer_timeout() -> void:
	is_charged = false
	is_decharging = false
