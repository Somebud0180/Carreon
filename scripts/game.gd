extends Node2D
class_name Game

@onready var map = $LevelZero
@onready var player = %Gaff

var is_indoors: bool = false
var current_interior: Node = null
var outdoor_position: Vector2 = Vector2(0, 0)

func transition_to_interior(interior_scene: PackedScene) -> void:
	if is_indoors:
		return
	
	player.teleporting = true
	await _tween_transition(Color(1.0, 1.0, 1.0, 1.0))
	
	var new_scene: Node2D = interior_scene.instantiate()
	add_child(new_scene)
	current_interior = new_scene
	outdoor_position = player.global_position
	
	# Move player to a spawn marker inside the interior
	var spawn := new_scene.get_node_or_null("SpawnPoint")
	if spawn and spawn is Node2D:
		player.camera_smoothing = false
		player.global_position = (spawn as Node2D).global_position
	
	# Hide/disable outdoor
	var map_child = map.get_children()
	for tilemap in map_child:
		if tilemap is TileMapLayer:
			tilemap.visible = false
			tilemap.collision_enabled = false
			tilemap.process_mode = Node.PROCESS_MODE_DISABLED
	
	if player.has_method("_set_player_level"):
		player._set_player_level(0)

	player.teleporting = false
	is_indoors = true
	player.z_axis_enabled = true
	
	await _tween_transition(Color(1.0, 1.0, 1.0, 0.2))
	player.camera_smoothing = true

func transition_to_outdoor() -> void:
	if not is_indoors:
		return
	
	player.teleporting = true
	await _tween_transition(Color(1.0, 1.0, 1.0, 1.0))
	
	# Restore outdoor
	var map_child = map.get_children()
	for tilemap in map_child:
		tilemap.visible = true
		tilemap.collision_enabled = true
	
	player.camera_smoothing = false
	player.global_position = outdoor_position
	player.z_axis_enabled = false
	
	# Free interior
	if current_interior:
		current_interior.queue_free()
		current_interior = null
	
	for tilemap in map_child:
		tilemap.process_mode = Node.PROCESS_MODE_INHERIT
	player.teleporting = false
	is_indoors = false
	
	await _tween_transition(Color(1.0, 1.0, 1.0, 0.2))
	player.camera_smoothing = true

func _tween_transition(color: Color) -> void:
	var tween = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(%TransitionRect, "modulate", color, 0.5)
	await tween.finished
