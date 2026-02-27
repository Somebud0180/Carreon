extends Area2D
class_name TextArea

## Text to show player when inside area
@export var subtitle_text: String

## Text priority, higher value means it is shown even when the player is already inside another TextArea
@export var subtitle_priority: int = 0

var game: Game = null
var subtitles: SubtitleLabel = null

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	game = get_tree().get_first_node_in_group("GameScene")
	subtitles = game.get_node("%Subtitles")

func _on_body_entered(body: Node) -> void:
	if body is Player:
		subtitles.add_text(subtitle_text, subtitle_priority)

func _on_body_exited(body: Node) -> void:
	if body is Player:
		subtitles.remove_text(subtitle_text)
