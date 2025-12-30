extends Node2D

@onready var map = $Map
@onready var player = %Gaff

var is_indoors: bool = false
var current_interior: Node = null
var outdoor_position: Vector2 = Vector2(0, 0)
var _pending_path: String = ""
var _pending_progress: Array = []

func _process(_delta: float) -> void:
	if _pending_path == "":
		return
	var status := ResourceLoader.load_threaded_get_status(_pending_path, _pending_progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("Failed to load: %s" % _pending_path)
		_pending_path = ""
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var ps := ResourceLoader.load_threaded_get(_pending_path) as PackedScene
		_pending_path = ""
		if ps:
			transition_to_interior(ps)

func transition_to_interior(interior_scene: PackedScene) -> void:
	if is_indoors:
		return
	
	var new_scene: Node2D = interior_scene.instantiate()
	add_child(new_scene)
	current_interior = new_scene
	outdoor_position = player.global_position

	# Move player to a spawn marker inside the interior
	var spawn := new_scene.get_node_or_null("spawn")
	if spawn and spawn is Node2D:
		player.global_position = (spawn as Node2D).global_position

	# Hide/disable outdoor
	map.visible = false
	map.collision_enabled = false
	
	is_indoors = true

func transition_to_outdoor() -> void:
	if not is_indoors:
		return
	
	# Restore outdoor
	map.visible = true
	map.collision_enabled = true
	player.global_position = outdoor_position

	# Free interior
	if current_interior:
		current_interior.queue_free()
		current_interior = null

	is_indoors = false

# Async load by path
func transition_to_interior_path(scene_path: String) -> void:
	if is_indoors:
		return
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return # already loading
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("Scene not found: %s" % scene_path)
		return
	_pending_path = scene_path
	_pending_progress = []
	ResourceLoader.load_threaded_request(scene_path, "PackedScene")
