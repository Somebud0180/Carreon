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
@export var TURN_SPEED = 150.0      ## How fast player snaps to the opposite direction
@export var AIR_TURN_SPEED = 350.0  ## How fast player snaps to the opposite direction in the air
@export var COYOTE_FRAMES = 7          ## How long the player can jump after leaving the floor
@export var SPRINT_COYOTE_FRAMES = 12  ## How long the player can jump after leaving the floor while sprinting

# Miscallenous Variables
@export_group("Camera")
@export var CAMERA_ZOOM = 1.5      ## Base camera zoom
@export var MIN_CAMERA_ZOOM = 0.8  ## Farthest the camera can zoom out
@export var MAX_CAMERA_ZOOM = 3.0  ## Closest the camera can zoom in
@export var CTRL_ZOOM_OUT = -0.5   ## Zoom out amount when pressing "zoom_out" input
@export var SPEED_ZOOM_OUT = -0.5  ## Zoom out amount when player is moving fast

# Z-axis / interior layering
@export_group("Z Axis")
@export var Z_INDEX_BASE: int = 0
@export var Z_INDEX_STEP: int = 1
@export var z_level_layers: Array[int] = [0, 1, 2]  # collision bits per level
@export var Z_STEP_PIXELS: float = 32.0              # vertical nudge when stepping up a level

# Charge value for super jump/sprint
var charge_value = 0.0:
	set(value):
		charge_value = snapped(min(MAX_CHARGE_VALUE, max(0, value)), 0.01)
		$ChargeBar.value = charge_value

# Internal variables
var camera_zoom_modifier = 0.0 # Any zoom effects applied to camera (other than charge zoom)
var speed_zoom_modifier = 0.0
var is_charging = false      # Induces the increase of the charge value
var is_charged = false       # Enables charged stats
var is_discharging = false   # Maintains charged stats for awhile (while sprinting)
var is_jumping = false
var is_sprinting = false
var is_coyote_time = false
var was_on_floor = false

var z_axis_enabled: bool:
	get:
		return z_axis_enabled
	set(value):
		z_axis_enabled = value
		if !z_axis_enabled:
			_set_player_level(0)
		else:
			_apply_player_level()
var player_level: int = 0
var spawn_point: Vector2 = Vector2(0, 0)
var interactable: Area2D = null
var teleporting: bool = false:
	set(value):
		teleporting = value
		set_process_input(!teleporting)
var camera_smoothing = true:
	set(value):
		camera_smoothing = value
		$Camera2D.position_smoothing_enabled = camera_smoothing

func _ready() -> void:
	$CoyoteTimer.wait_time = COYOTE_FRAMES / 60.0
	spawn_point = position
	_apply_player_level()

func _physics_process(delta: float) -> void:
	# Handle charge
	if charge_value == MAX_CHARGE_VALUE:
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
	if Input.is_action_just_pressed("interact") and !teleporting and abs(velocity.x) < 50:
		if interactable and interactable.has_method("interact"):
			interactable.interact()
	
	# Handle zoom out.
	var zoom_out_modifier = 0.0
	if Input.is_action_pressed("zoom_out"):
		var target_zoom_value = clamp(CAMERA_ZOOM + CTRL_ZOOM_OUT, MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
		zoom_out_modifier = target_zoom_value - CAMERA_ZOOM
	var speed_start = SPRINT_SPEED * 0.75
	var max_speed_for_zoom = max(CHARGED_SPEED, speed_start + 0.001)
	var denom = max_speed_for_zoom - speed_start
	var speed_ratio = clamp((abs(velocity.x) - speed_start) / denom, 0.0, 1.0)
	speed_zoom_modifier = SPEED_ZOOM_OUT * speed_ratio
	camera_zoom_modifier = zoom_out_modifier + speed_zoom_modifier
	
	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0 and !teleporting:
		# Check if moving opposite to current velocity
		var is_turning = sign(direction) != sign(velocity.x) and velocity.x != 0
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
		else:
			is_charging = false
	
	if z_axis_enabled and !teleporting:
		if Input.is_action_just_pressed("move_up"):
			_set_player_level(player_level + 1)
		elif Input.is_action_just_pressed("move_down"):
			_set_player_level(player_level - 1)
	was_on_floor = is_on_floor()
	
	if is_charging:
		$ChargeBar.visible = true
		$ChargeEmitter.emitting = true
		charge_value += CHARGE_SPEED * delta
		
		# Smoothly zoom in based on charge progress
		var charge_progress = charge_value / MAX_CHARGE_VALUE
		var adjusted_progress = charge_progress if charge_progress > 0.15 else 0
		var base_zoom = CAMERA_ZOOM + camera_zoom_modifier
		var target_zoom = clamp(lerp(base_zoom, (MAX_CAMERA_ZOOM * 0.8) + camera_zoom_modifier, adjusted_progress), MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
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

func _process(_delta: float) -> void:
	# Scale animation speed proportionally to velocity
	if abs(velocity.x) >= SPRINT_SPEED:
		$AnimatedSprite2D.play("run")
		$AnimatedSprite2D.speed_scale = abs(velocity.x) / SPRINT_SPEED
	elif abs(velocity.x) > 0:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.speed_scale = abs(velocity.x) / SPEED
	else:
		$AnimatedSprite2D.play("default")
		$AnimatedSprite2D.speed_scale = 1
	
	if velocity.x > 0:
		$LightOccluder2D.scale.x = 1
		$AnimatedSprite2D.flip_h = false
	elif velocity.x < 0:
		$LightOccluder2D.scale.x = -1
		$AnimatedSprite2D.flip_h = true

func _on_kill_player() -> void:
	camera_smoothing = false
	velocity = Vector2(0, 0)
	position = spawn_point
	camera_smoothing = true

func _on_coyote_timer_timeout() -> void:
	is_coyote_time = false

func _on_charged_timer_timeout() -> void:
	_reset_charge()

func _set_player_level(level: int) -> void:
	var previous_level := player_level
	var max_level = _get_max_player_level()
	var clamped = clamp(level, 0, max_level)
	if clamped == player_level:
		return
	player_level = clamped
	_apply_player_level()

	# When stepping upward, nudge the player upward to feel like a stair/ladder climb.
	if player_level > previous_level:
		position.y -= Z_STEP_PIXELS

func _get_max_player_level() -> int:
	if z_level_layers.is_empty():
		return 0
	return z_level_layers.size() - 1

func _apply_player_level() -> void:
	# Update render ordering
	z_index = Z_INDEX_BASE + player_level * Z_INDEX_STEP

	# Update collision layer/mask based on configured bits per level
	var bit_index := 0
	if !z_level_layers.is_empty():
		bit_index = z_level_layers[min(player_level, z_level_layers.size() - 1)]
	bit_index = clamp(bit_index, 0, 19)  # Godot exposes 20 physics layers (0-19)
	var bit_value := 1 << bit_index
	collision_layer = bit_value
	collision_mask = bit_value

func _reset_charge() -> void:
	is_charged = false
	is_discharging = false
	$ChargeEmitter.process_material.color = CHARGING_PARTICLE_COLOR

func _reset_camera_zoom(delta: float, quick_reset: bool = false) -> void:
	var reset_time = 4.0 if quick_reset else 2.0
	var target_zoom = clamp(CAMERA_ZOOM + camera_zoom_modifier, MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
	$Camera2D.zoom = $Camera2D.zoom.lerp(Vector2(target_zoom, target_zoom), reset_time * delta)
