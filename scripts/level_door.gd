extends Node2D

@export var destination_scene: PackedScene ## The scene where the door leads to.
@export var player_text: String ## A text to show to the player when in the area of the door. Does nothing if empty.

signal ready_to_interact(door)
signal left_interact(door)

var game: Game = null
var subtitles: SubtitleLabel = null
var _actor: Node = null

func _ready() -> void:
	game = get_tree().root.get_node_or_null("Game")
	subtitles = game.get_node("%Subtitles")

func _on_body_entered(body: Node) -> void:
	if body is Player:
		if player_text:
			subtitles.add_text(player_text, 1)
		
		_actor = body
		body.interactable = self
		emit_signal("ready_to_interact", self)

func _on_body_exited(body: Node) -> void:
	if body == _actor:
		if player_text:
			subtitles.remove_text(player_text)
		
		body.interactable = null
		emit_signal("left_interact", self)
		_actor = null

func interact() -> void:
	game.transition_to_interior(destination_scene)
