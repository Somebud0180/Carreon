extends Node2D

@onready var area_2d: Area2D = $Area2D 
@export var keycard_id: int = 0 # An identifier that defines what numbered door this keycard unlocks

var is_collected: bool = false
var _actor: Node = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.connect("body_entered", _on_body_entered)
	area_2d.connect("body_exited", _on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_actor = body
		body.interactable = self

func _on_body_exited(body: Node2D) -> void:
	if body == _actor:
		body.interactable = null
		_actor = null

func interact() -> void:
	if _actor.add_item("key", keycard_id):
			is_collected = true
			visible = false
