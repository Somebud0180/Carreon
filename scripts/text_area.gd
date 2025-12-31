extends Area2D
class_name TextArea

## Text to show player when inside area
@export var subtitle_text: String

var game: Game = null
var subtitles: SubtitleLabel = null
var _actor: Node = null

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	game = get_tree().root.get_node_or_null("Game")
	subtitles = game.get_node("%Subtitles")

func _on_body_entered(body: Node) -> void:
	if body is Player:
		body.subtitle.change_text(subtitle_text)

func _on_body_exited(body: Node) -> void:
	if body == _actor:
		body.interactable = null
		emit_signal("left_interact", self)
		_actor = null
