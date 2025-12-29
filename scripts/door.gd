extends Area2D

@export var id: int = 0                                # Optional: fallback/registry ID
@export var interior_scene: PackedScene                 # Per-door destination scene

signal ready_to_interact(door)
signal left_interact(door)

var _actor: Node = null

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_current_interactable"):
		_actor = body
		body.set_current_interactable(self)
		emit_signal("ready_to_interact", self)

func _on_body_exited(body: Node) -> void:
	if body == _actor and body.has_method("clear_current_interactable"):
		body.clear_current_interactable(self)
		emit_signal("left_interact", self)
		_actor = null

# Called by Player on "Interact" (e.g., key E)
func interact() -> void:
	if interior_scene:
		TransitionService.transition_to_interior(interior_scene)
	else:
		TransitionService.transition_by_id(id)
