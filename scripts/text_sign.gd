extends Node2D

@export_multiline("A gloomy place.") var subtitle_text_primary: String = ""
@export_multiline("Fractures beneath and around.") var subtitle_text_secondary: String = ""
@export var subtitle_priority: int = 999 
@onready var area_2d = $Area2D

var text_progress: int = 0
var _actor: Node
var game: Game
var subtitles: SubtitleLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.connect("body_entered", _on_body_entered)
	area_2d.connect("body_exited", _on_body_exited)
	game = get_tree().root.get_node_or_null("Game")
	subtitles = game.get_node("%Subtitles")

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_actor = body
		text_progress = 0
		body.interactable = self

func _on_body_exited(body: Node2D) -> void:
	if body == _actor:
		var active_text: String = ""
		match text_progress:
			1:
				active_text = subtitle_text_primary
			2:
				active_text = subtitle_text_secondary
		
		body.interactable = null
		subtitles.left_text_area(active_text)
		text_progress = 0
		_actor = null

func interact() -> void:
	if _actor is Player:
		if text_progress == 0 and subtitle_text_primary:
			subtitles.add_text(subtitle_text_primary, subtitle_priority)
			text_progress = 1
		elif text_progress == 1 and subtitle_text_secondary:
			subtitles.add_text(subtitle_text_secondary, subtitle_priority + text_progress)
			subtitles.left_text_area(subtitle_text_primary)
			text_progress = 2
		elif text_progress == 2:
			subtitles.left_text_area(subtitle_text_secondary)
