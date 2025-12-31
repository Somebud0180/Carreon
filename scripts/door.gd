extends Area2D
class_name Door

## If door leads to interior. If true, teleports to interior scene
@export var is_interior: bool            # Check if door is to inside or outside

## Destination interior scene if door is outdoor
@export var interior_scene: PackedScene  # Per-door destination scene

signal ready_to_interact(door)
signal left_interact(door)

var game: Game = null
var _actor: Node = null

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	game = get_tree().root.get_node_or_null("Game")

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_actor = body
		body.interactable = self
		emit_signal("ready_to_interact", self)

func _on_body_exited(body: Node) -> void:
	if body == _actor:
		body.interactable = null
		emit_signal("left_interact", self)
		_actor = null

func interact() -> void:
	if is_interior:
		game.transition_to_outdoor()
	elif interior_scene:
		game.transition_to_interior(interior_scene)
