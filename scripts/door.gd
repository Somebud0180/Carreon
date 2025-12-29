extends Area2D
class_name Door

@export var id: int = 0                    # Optional: fallback/registry ID
@export var interior_scene: PackedScene    # Per-door destination scene

signal ready_to_interact(door)
signal left_interact(door)

var game: Node = null
var _actor: Node = null

func _ready() -> void:
	game = get_tree().root.get_node_or_null("Game")

func _on_body_entered(body: Node) -> void:
	if body.has_meta("interactable"):
		_actor = body
		body.interactable = self
		emit_signal("ready_to_interact", self)

func _on_body_exited(body: Node) -> void:
	if body == _actor and body.has_method("clear_current_interactable"):
		body.interactable = null
		emit_signal("left_interact", self)
		_actor = null

# Called by Player on "Interact" (e.g., key E)
func interact() -> void:
	if interior_scene:
		pass
		game.transition_to_interior(interior_scene)
	else:
		pass
		game.transition_by_id(id)
