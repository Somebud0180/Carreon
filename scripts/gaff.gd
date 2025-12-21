extends CharacterBody2D


const SPEED = 150.0
const SPRINT_SPEED = 250.0
const JUMP_VELOCITY = -400.0
const ACCELERATION = 250
const FRICTION = 550     # How fast player stops
const AIR_FRICTION = 100 # How fast player stops in air
const turn_speed = 400   # How fast player snaps to the opposite direction

var is_sprinting = false

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
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
		
		var current_accel = turn_speed if is_turning else ACCELERATION
		var current_speed = SPRINT_SPEED if is_sprinting else SPEED
		
		velocity.x = move_toward(velocity.x, direction * current_speed, current_accel * delta)
	else:
		var current_friction = AIR_FRICTION if !is_on_floor() else FRICTION
		velocity.x = move_toward(velocity.x, 0, current_friction * delta)
	
	move_and_slide()

func _process(_delta: float) -> void:
	if velocity.x > 0:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = false
	elif velocity.x < 0:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = true
	elif velocity.x == 0:
		$AnimatedSprite2D.play("default")
