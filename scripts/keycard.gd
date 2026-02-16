extends Node2D

@onready var area_2d: Area2D = $Area2D 
@export var keycard_id: int = 0 # An identifier that defines what numbered door this keycard unlocks

var is_collected: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and !is_collected:
		if body.add_item("key", keycard_id):
			is_collected = true
			visible = false
