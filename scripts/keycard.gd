extends Node2D

@onready var area_2d: Area2D = $Area2D 
@export var keycard_id: int = 0 # An identifier that defines what numbered door this keycard unlocks


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.add_item()
