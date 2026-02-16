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
@export var INDOOR_JUMP_MULT = 0.65
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

# Wall Leap Constants
@export_group("Wall Leap")
@export var WALL_LEAP_PROBE_MARGIN: float = 6.0
@export var WALL_LEAP_CLEARANCE: float = 6.0
@export var WALL_LEAP_HORIZONTAL_IMPULSE: float = 320.0

# Miscallenous Variables
@export_group("Camera")
@export var CAMERA_ZOOM_STEP = 1               ## Base camera zoom
@export var CAMERA_ZOOMS = [1.0, 1.5, 2.0]     ## Zoom settings
@export var MIN_CAMERA_ZOOM = 0.25             ## Farthest the camera can zoom out
@export var MAX_CAMERA_ZOOM = 3.5              ## Closest the camera can zoom in
@export var CTRL_ZOOM_OUT = -0.8               ## Zoom out amount when pressing "zoom_out" input
@export var SPEED_ZOOM_OUT = -0.5              ## Zoom out amount when player is moving fast

# Visual offsets
@export_group("Visual")
@export var ROTATION_LERP_SPEED = 10.0  ## How quickly to align to floor normal when grounded

# Z-axis / interior layering
@export_group("Z Axis")
@export var Z_INDEX_BASE: int = 0
@export var Z_INDEX_STEP: int = 1
@export var max_z_levels: int = 20                   # maximum number of z-levels (auto-detected via floor)
@export var Z_STEP_PIXELS: float = 24.0              # vertical nudge when stepping up a level
@export var Z_PROBE_LEEWAY: float = 8.0              # extra clearance for level change probe
@export var Z_FLOOR_DETECT_RANGE: float = 64.0       # how far to raycast for floor detection

# Charge value for super jump/sprint
var charge_value = 0.0:
	set(value):
		charge_value = snapped(min(MAX_CHARGE_VALUE, max(0, value)), 0.01)
		$ChargeBar.value = charge_value

# Internal variables
var camera_zoom_modifier = 0.0 # Total of zoom modifiers applied to camera
var ctrl_zoom_modifier = 0.0   # Smooth modifier for manual zoom control
var is_charging = false        # Induces the increase of the charge value
var is_charged = false         # Enables charged stats
var is_discharging = false     # Maintains charged stats for awhile (while sprinting)
var is_jumping = false
var is_sprinting = false
var is_coyote_time = false
var was_on_floor = false

var z_axis_enabled: bool = false:
	set(value):
		z_axis_enabled = value
		if !z_axis_enabled:
			_set_player_level(0)
			%LeftRight.visible = true
			%AllControls.visible = false
		else:
			_apply_player_level()
			%LeftRight.visible = false
			%AllControls.visible = true
var player_level: int = 0
var spawn_point: Vector2 = Vector2(0, 0)
var interactable: Node = null
var teleporting: bool = false:
	set(value):
		teleporting = value
		set_process_input(!teleporting)
var camera_smoothing = true:
	set(value):
		camera_smoothing = value
		$Camera2D.position_smoothing_enabled = camera_smoothing

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

var wall_leap_available: bool = false
var wall_leap_direction: int = 0
var wall_leap_target: Vector2 = Vector2.ZERO

var inventory: Array[Inventory] = []

func _ready() -> void:
	spawn_point = position
	_apply_player_level()
	$CoyoteTimer.wait_time = COYOTE_FRAMES / 60.0

func _physics_process(delta: float) -> void:
	if teleporting:
		return
	
	# Handle charge
	if charge_value == MAX_CHARGE_VALUE:
		is_charged = true
		is_discharging = true
		$ChargedTimer.start()
		$ChargeEmitter.color = CHARGED_PARTICLE_COLOR
		
	
	# Add the gravity.
	if !is_on_floor():
		# Handle coyote time.
		if was_on_floor and !is_jumping:
			is_coyote_time = true
			$CoyoteTimer.start()
		
		# Apply gravity
		velocity += get_gravity() * delta
		rotation = lerp_angle(rotation, 0, ROTATION_LERP_SPEED * delta)
	else:
		# Reset jump
		is_jumping = false
		var target_rotation = get_floor_normal().angle() + PI/2
		rotation = lerp_angle(rotation, target_rotation, ROTATION_LERP_SPEED * delta)
	
	# Handle sprint.
	if Input.is_action_pressed("sprint"):
		is_sprinting = true
		$CoyoteTimer.wait_time = SPRINT_COYOTE_FRAMES / 60.0
	else:
		is_sprinting = false
		$CoyoteTimer.wait_time = COYOTE_FRAMES / 60.0
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and (is_on_floor() or is_coyote_time):
		velocity.y = (CHARGED_JUMP_VELOCITY if is_charged else JUMP_VELOCITY) * (INDOOR_JUMP_MULT if z_axis_enabled else 1.0)
		is_jumping = true
		is_coyote_time = false
		is_charging = false
		if is_charged:
			_reset_charge()
			charge_value -= CHARGE_SPEED * 2 * delta
	
	# Handle interact prompt and wall leap input.
	if interactable or wall_leap_available:
		%InteractControls.visible = true
	else:
		%InteractControls.visible = false
	
	if Input.is_action_just_pressed("interact") and !teleporting:
		if _try_wall_leap():
			pass
		elif abs(velocity.x) < 50 and interactable and interactable.has_method("interact"):
			interactable.interact()
	
	# Get the input direction and handle the movement/deceleration.
	var direction = Input.get_axis("move_left", "move_right")
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
	else:
		charge_value -= CHARGE_SPEED * 2 * delta
		if !is_discharging:
			$ChargeEmitter.emitting = false
			# Smoothly zoom back to default
		if charge_value == 0:
			$ChargeBar.visible = false

	_update_zoom_modifiers(delta, true if is_jumping else false)
	move_and_slide()
	_check_leapable_wall()

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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			CAMERA_ZOOM_STEP = min(CAMERA_ZOOM_STEP + 1, CAMERA_ZOOMS.size() - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			CAMERA_ZOOM_STEP = max(CAMERA_ZOOM_STEP - 1, 0)
		
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			Engine.time_scale = 2
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_released():
			Engine.time_scale = 1


## Miscallenous functions
func _try_wall_leap() -> bool:
	if !wall_leap_available or wall_leap_direction == 0 or is_jumping:
		return false
	velocity.y = CHARGED_JUMP_VELOCITY
	var horizontal_dir = wall_leap_direction
	if wall_leap_target != Vector2.ZERO:
		var delta_x = wall_leap_target.x - global_position.x
		if delta_x != 0:
			horizontal_dir = sign(delta_x)
	velocity.x = horizontal_dir * WALL_LEAP_HORIZONTAL_IMPULSE
	is_jumping = true
	is_coyote_time = false
	is_charging = false
	is_charged = false
	wall_leap_available = false
	wall_leap_target = Vector2.ZERO
	return true

func _check_leapable_wall() -> void:
	_reset_wall_leap_state()
	var shape := _collision_shape.shape as RectangleShape2D
	if shape == null:
		return
	var bottom_offset = _collision_shape.position.y + (shape.size.y * 0.5)
	var max_jump_height = _get_max_jump_height()
	if max_jump_height <= 0:
		return
	var standard_jump_height = _get_standard_jump_height()
	var feet_y = global_position.y + bottom_offset
	var space_state = get_world_2d().direct_space_state
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var normal := col.get_normal()
		if !_is_valid_wall_normal(normal):
			continue
		var side = -sign(normal.x)
		var probe_x = col.get_position().x + side * WALL_LEAP_PROBE_MARGIN
		var hit = _cast_wall_top(space_state, col.get_collider_rid(), probe_x, feet_y, max_jump_height)
		if hit == null:
			continue
		var height_needed = feet_y - hit.position.y
		if !_can_reach_wall_top(height_needed, max_jump_height, standard_jump_height):
			continue
		var target_origin = Vector2(probe_x, hit.position.y - bottom_offset)
		if !_has_stand_clearance(space_state, target_origin):
			continue
		wall_leap_available = true
		wall_leap_direction = side
		wall_leap_target = target_origin
		break

func _reset_wall_leap_state() -> void:
	wall_leap_available = false
	wall_leap_direction = 0
	wall_leap_target = Vector2.ZERO

func _is_valid_wall_normal(normal: Vector2) -> bool:
	return abs(normal.x) >= 0.7

func _cast_wall_top(space_state: PhysicsDirectSpaceState2D, collider_rid: RID, probe_x: float, feet_y: float, max_jump_height: float) -> Variant:
	var top_probe_start = Vector2(probe_x, feet_y - max_jump_height)
	var top_probe_end = Vector2(probe_x, feet_y + 2.0)
	var ray_params := PhysicsRayQueryParameters2D.create(top_probe_start, top_probe_end)
	ray_params.collision_mask = collision_mask
	ray_params.collide_with_areas = false
	ray_params.exclude = [get_rid()]
	var hit = space_state.intersect_ray(ray_params)
	if hit.is_empty():
		return null
	if hit.has("rid") and collider_rid != hit.rid:
		return null
	return hit

func _can_reach_wall_top(height_needed: float, max_jump_height: float, standard_jump_height: float) -> bool:
	if height_needed < 0 or height_needed > max_jump_height:
		return false
	return height_needed > standard_jump_height

func _has_stand_clearance(space_state: PhysicsDirectSpaceState2D, target_origin: Vector2) -> bool:
	var stand_params := PhysicsShapeQueryParameters2D.new()
	stand_params.shape = _collision_shape.shape
	stand_params.transform = Transform2D(transform.get_rotation(), target_origin)
	stand_params.collision_mask = collision_mask
	stand_params.collide_with_areas = false
	stand_params.exclude = [get_rid()]
	if space_state.intersect_shape(stand_params, 1).size() > 0:
		return false
	var headroom_params := PhysicsShapeQueryParameters2D.new()
	headroom_params.shape = _collision_shape.shape
	headroom_params.transform = Transform2D(transform.get_rotation(), target_origin + Vector2(0, -WALL_LEAP_CLEARANCE))
	headroom_params.collision_mask = collision_mask
	headroom_params.collide_with_areas = false
	headroom_params.exclude = [get_rid()]
	return space_state.intersect_shape(headroom_params, 1).size() == 0

func _get_max_jump_height() -> float:
	var gravity = abs(get_gravity().y)
	if gravity == 0:
		return 0.0
	var jump_speed = abs(CHARGED_JUMP_VELOCITY)
	return (jump_speed * jump_speed) / (gravity)

func _get_standard_jump_height() -> float:
	var gravity = abs(get_gravity().y)
	if gravity == 0:
		return 0.0
	var jump_speed = abs(JUMP_VELOCITY * (INDOOR_JUMP_MULT if z_axis_enabled else 1.0))
	return (jump_speed * jump_speed) / (2.0 * gravity)

func _on_kill_player() -> void:
	camera_smoothing = false
	velocity = Vector2(0, 0)
	position = spawn_point
	camera_smoothing = true

func _on_coyote_timer_timeout() -> void:
	is_coyote_time = false

func _on_charged_timer_timeout() -> void:
	_reset_charge()

func _reset_charge() -> void:
	is_charged = false
	is_discharging = false
	$ChargeEmitter.color = CHARGING_PARTICLE_COLOR


## Camera zoom functions
func _update_zoom_modifiers(delta: float, quick_reset: bool) -> void:
	# Manual zoom-out via input with smooth release
	var ctrl_target_offset = 0.0
	if Input.is_action_pressed("zoom_out"):
		var ctrl_target = clamp(CAMERA_ZOOMS[CAMERA_ZOOM_STEP] + CTRL_ZOOM_OUT, MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
		ctrl_target_offset = ctrl_target - CAMERA_ZOOMS[CAMERA_ZOOM_STEP]
	# Smoothly lerp the ctrl modifier toward the target (or back to 0 when released)
	ctrl_zoom_modifier = lerp(ctrl_zoom_modifier, ctrl_target_offset, 8.0 * delta)
	
	var base_modifier = ctrl_zoom_modifier

	# Speed-based zoom: start after 75% sprint speed, ramp to max at charged speed
	var speed_start = SPRINT_SPEED * 0.75
	var max_speed_for_zoom = max(CHARGED_SPEED, speed_start + 0.001)
	var denom = max_speed_for_zoom - speed_start
	var speed_ratio = clamp((abs(velocity.x) - speed_start) / denom, 0.0, 1.0)
	base_modifier += SPEED_ZOOM_OUT * speed_ratio

	camera_zoom_modifier = base_modifier
	var target_zoom = CAMERA_ZOOMS[CAMERA_ZOOM_STEP] + camera_zoom_modifier

	if is_charging:
		var charge_progress = charge_value / MAX_CHARGE_VALUE
		var adjusted_progress = charge_progress if charge_progress > 0.15 else 0
		# Clamp the maximum zoom-in to half of the current target zoom (prevents over-zoom)
		var max_zoom_in = min(target_zoom * 2.0, (MAX_CAMERA_ZOOM * 0.8) + camera_zoom_modifier)
		var charged_target = lerp(target_zoom, max_zoom_in, adjusted_progress)
		_lerp_camera_zoom(charged_target, 5.0, delta)
	else:
		var reset_time = 4.0 if quick_reset else 2.0
		_lerp_camera_zoom(target_zoom, reset_time, delta)

func _lerp_camera_zoom(target_zoom: float, speed: float, delta: float) -> void:
	var clamped = clamp(target_zoom, MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
	$Camera2D.zoom = $Camera2D.zoom.lerp(Vector2(clamped, clamped), speed * delta)


## Z-axis movement functions
func _set_player_level(level: int) -> void:
	var max_level = _get_max_player_level()
	var clamped = clamp(level, 0, max_level)
	if clamped == player_level:
		return
	var going_up = clamped > player_level
	var target_offset = -Z_STEP_PIXELS if going_up else 0.0
	if !_can_change_level(clamped, target_offset):
		return  # blocked by ceiling on the target level
	
	# Require a floor to exist on the target level (unless going down to level 0)
	var floor_y = _find_floor_height(clamped, going_up)
	if floor_y == null:
		return  # no floor found on target level
	
	player_level = clamped
	_apply_player_level()
	
	# Snap to actual floor height on target level
	if floor_y != null:
		position.y = floor_y

func _get_max_player_level() -> int:
	return max_z_levels - 1

func _apply_player_level() -> void:
	# Update render ordering
	z_index = Z_INDEX_BASE + player_level * Z_INDEX_STEP

	# Auto-map level N to collision bit N (level 0 -> bit 0, level 1 -> bit 1, etc.)
	var bit_index = clamp(player_level, 0, 32)  # Godot exposes 20 physics layers (1-32)
	var bit_value = 1 << bit_index
	collision_layer = bit_value
	collision_mask = bit_value

func _can_change_level(target_level: int, y_offset: float) -> bool:
	var bit_index = clamp(target_level, 0, 19)
	var target_bits = 1 << bit_index

	var prev_layer = collision_layer
	var prev_mask = collision_mask
	collision_layer = target_bits
	collision_mask = target_bits

	# Probe with extra leeway above to make level changes more forgiving
	var probe_offset = y_offset - Z_PROBE_LEEWAY
	var target_transform = transform.translated(Vector2(0, probe_offset))
	var blocked = test_move(target_transform, Vector2.ZERO)

	collision_layer = prev_layer
	collision_mask = prev_mask
	return !blocked

func _find_floor_height(level: int, going_up: bool) -> Variant:
	var bit_index = clamp(level, 0, 19)
	var target_bits = 1 << bit_index
	
	# Create a raycast from above the player downward (or upward if going up)
	var space_state = get_world_2d().direct_space_state
	var ray_direction = Vector2(0, -Z_FLOOR_DETECT_RANGE) if going_up else Vector2(0, Z_FLOOR_DETECT_RANGE)
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + ray_direction
	)
	query.collision_mask = target_bits
	query.collide_with_areas = false
	
	var result = space_state.intersect_ray(query)
	if result:
		# Position player just above the detected floor
		return result.position.y - 4
	return null
	
func add_item(item_name: String = "", item_id = 0) -> bool:
	for item in inventory:
		if item.name == item_name and item.id == item_id:
			return false
	
	inventory.append(Inventory.new(item_name, item_id))
	return true
