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
@export_group("Player")
@export var SPEED = 250.0
@export var JUMP_VELOCITY = -400.0
@export var ACCELERATION = 250.0
@export var FRICTION = 550.0
@export var AIR_FRICTION = 100.0
@export var CHARGING_PARTICLE_COLOR = Color(0.9, 0.9, 0.4, 0.8)
@export var CHARGED_PARTICLE_COLOR = Color(0.9, 0.6, 0.4, 0.8)

# Sprint Constants
@export_group("Sprint")
@export var SPRINT_SPEED = 400.0
@export var SPRINT_ACCELERATION = 750.0

# Charged Constansts
@export_group("Charge")
@export var CHARGE_SPEED = 30
@export var MAX_CHARGE_VALUE = 50.0
@export var CHARGED_SPEED = 600.0
@export var CHARGED_ACCELERATION = 750.0
@export var CHARGED_JUMP_VELOCITY = -600.0

# Juice Constants
@export_group("Juice")
@export var TURN_SPEED = 150.0      # How fast player snaps to the opposite direction
@export var AIR_TURN_SPEED = 350.0  # How fast player snaps to the opposite direction in the air
@export var COYOTE_FRAMES = 7          # How long the player can jump after leaving the floor
@export var SPRINT_COYOTE_FRAMES = 12  # How long the player can jump after leaving the floor while sprinting

# Miscallenous Variables
@export_group("Miscallenous")
@export var CAMERA_ZOOM = 1.5
@export var MIN_CAMERA_ZOOM = 1.25
@export var MAX_CAMERA_ZOOM = 3.0

# Charge value for super jump/sprint
var charge_value = 0.0:
	set(value):
		charge_value = snapped(min(MAX_CHARGE_VALUE, max(0, value)), 0.01)
		$ChargeBar.value = charge_value

var is_charging = false     # Induces the increase of the charge value
var is_charged = false      # Enables charged stats
var is_discharging = false  # Maintains charged stats for awhile (while sprinting)
var is_jumping = false
var is_sprinting = false
var is_coyote_time = false
var was_on_floor = false

var spawn_point = Vector2(0, 0)
var interactable: Area2D

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
		is_discharging = true
		$ChargedTimer.start()
		$ChargeEmitter.process_material.color = CHARGED_PARTICLE_COLOR
	
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
		is_charging = false
		if is_charged:
			_reset_charge()
			charge_value -= CHARGE_SPEED * 2 * delta
	
	# Handle door interact.
	if Input.is_action_just_pressed("interact"):
		if interactable and interactable.has_method("interact"):
			interactable.interact()
	
	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		# Check if moving opposite to current velocity
		var is_turning = sign(direction) != sign(velocity.x) and velocity.x != 0
		
		if is_sprinting:
			debug_state.append(DEBUG_STATES.SPRINTING)
		
		var current_accel = CHARGED_ACCELERATION if is_discharging else SPRINT_ACCELERATION if is_sprinting else ACCELERATION
		var turn_accel = AIR_TURN_SPEED if !is_on_floor() else TURN_SPEED
		var final_accel = (current_accel + turn_accel) if is_turning else current_accel
		var current_speed = CHARGED_SPEED if is_discharging else SPRINT_SPEED if is_sprinting else SPEED
		
		if is_charged:
			velocity.x += 50
		
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
		$ChargeEmitter.emitting = true
		charge_value += CHARGE_SPEED * delta
		
		# Smoothly zoom in based on charge progress
		var charge_progress = charge_value / MAX_CHARGE_VALUE
		var adjusted_progress = charge_progress if charge_progress > 0.15 else 0
		var target_zoom = lerp(CAMERA_ZOOM, MAX_CAMERA_ZOOM * 0.8, adjusted_progress)
		$Camera2D.zoom = $Camera2D.zoom.lerp(Vector2(target_zoom, target_zoom), 5.0 * delta)
	else:
		charge_value -= CHARGE_SPEED * 2 * delta
		_reset_camera_zoom(delta, true if is_jumping else false)
		
		if !is_discharging:
			$ChargeEmitter.emitting = false
			# Smoothly zoom back to default
		
		if charge_value == 0:
			$ChargeBar.visible = false
	
	move_and_slide()
	
	var names := debug_state.map(func(s): return DEBUG_STATES.find_key(s))
	$Label.text = ", ".join(names)
	$Label.text += ", Charge Value: " + str(charge_value)

func _process(_delta: float) -> void:
	# Scale animation speed proportionally to velocity
	if abs(velocity.x) < 400:
		$AnimatedSprite2D.speed_scale = abs(velocity.x) / SPEED
	elif abs(velocity.x) > 400:
		$AnimatedSprite2D.speed_scale = abs(velocity.x) / SPRINT_SPEED
	
	if velocity.x > 0:
		# Use "run" animation at sprint speed and above, otherwise "walk"
		$AnimatedSprite2D.play("run" if abs(velocity.x) >= 400 else "walk")
		$LightOccluder2D.scale.x = 1
		$AnimatedSprite2D.flip_h = false
	elif velocity.x < 0:
		# Use "run" animation at sprint speed and above, otherwise "walk"
		$AnimatedSprite2D.play("run" if abs(velocity.x) >= 400 else "walk")
		$LightOccluder2D.scale.x = -1
		$AnimatedSprite2D.flip_h = true
	elif velocity.x == 0:
		$AnimatedSprite2D.play("default")

func _on_kill_player() -> void:
	velocity = Vector2(0, 0)
	position = spawn_point

func _on_coyote_timer_timeout() -> void:
	is_coyote_time = false

func _on_charged_timer_timeout() -> void:
	_reset_charge()

func _reset_charge() -> void:
	is_charged = false
	is_discharging = false
	$ChargeEmitter.process_material.color = CHARGING_PARTICLE_COLOR

func _reset_camera_zoom(delta: float, quick_reset: bool = false) -> void:
	var reset_time = 4.0 if quick_reset else 2.0
	$Camera2D.zoom = $Camera2D.zoom.lerp(Vector2(CAMERA_ZOOM, CAMERA_ZOOM), reset_time * delta)
