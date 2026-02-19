extends Node2D

const KEYCARD_TEXTURE = preload("res://textures/game/keycard_still.png")

@onready var area_2d: Area2D = $Area2D 
@export var keycard_id: int = 0 # An identifier that defines what numbered gate this keycard unlocks
@export_flags_2d_physics var collision_mask = 1:
	set(value):
		collision_mask = value
		if area_2d:
			area_2d.collision_mask = collision_mask

var is_collected: bool = false
var _actor: Node = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.connect("body_entered", _on_body_entered)
	area_2d.connect("body_exited", _on_body_exited)
	area_2d.collision_mask = collision_mask

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
			var inventory_overlay = get_tree().get_first_node_in_group("InventoryOverlay")
			inventory_overlay.add_item("Key", KEYCARD_TEXTURE)
			
			is_collected = true
			visible = false
