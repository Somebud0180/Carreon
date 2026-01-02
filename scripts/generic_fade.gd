extends Area2D

@export var sprite_texture: Sprite2D
var _actor: Node = null

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_actor = body
		sprite_texture.modulate = Color(1.0, 1.0, 1.0, 0.95)

func _on_body_exited(body: Node) -> void:
	if body == _actor:
		_actor = null
		sprite_texture.modulate = Color(1.0, 1.0, 1.0, 1.0)
