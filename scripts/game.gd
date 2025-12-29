extends Node2D

@onready var map = $Map
@onready var player = %Gaff

var is_in_interior: bool = false
var current_interior: Node = null
var _pending_path: String = ""
var _pending_progress: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

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
	if is_in_interior:
		return
	var new_scene := interior_scene.instantiate()
	add_child(new_scene)
	current_interior = new_scene
	map.visible = false
	map.collision_enabled = false
	is_in_interior = true

func transition_to_exterior() -> void:
	if not is_in_interior:
		return
	map.visible = true
	map.collision_enabled = true
	if current_interior:
		current_interior.queue_free()
		current_interior = null
	is_in_interior = false

# Async load by path
func transition_to_interior_path(scene_path: String) -> void:
	if is_in_interior:
		return
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return # already loading
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("Scene not found: %s" % scene_path)
		return
	_pending_path = scene_path
	_pending_progress = []
	ResourceLoader.load_threaded_request(scene_path, "PackedScene")
