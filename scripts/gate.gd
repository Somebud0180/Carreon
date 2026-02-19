extends Node2D

const LOCKED_SPRITE_REGION = Rect2(1408, 128, 128, 128)
const UNLOCKED_SPRITE_REGION = Rect2(1280, 128, 128, 128)

@onready var area_2d: Area2D = $Area2D 
@export var keycard_id: int = 0 # An identifier that defines what numbered key this gate accepts
@export_flags_2d_physics var collision_mask = 1:
	set(value):
		collision_mask = value
		if area_2d:
			area_2d.collision_mask = collision_mask

var is_unlocked: bool = false:
	set(value):
		is_unlocked = value
		$Sprite2D.region_rect = UNLOCKED_SPRITE_REGION if is_unlocked else LOCKED_SPRITE_REGION
		$StaticBody2D.process_mode = PROCESS_MODE_DISABLED if is_unlocked else PROCESS_MODE_INHERIT
var _actor: Node = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.connect("body_entered", _on_body_entered)
	area_2d.connect("body_exited", _on_body_exited)
	area_2d.collision_mask = collision_mask

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_actor = body
		if _actor.has_item("key", keycard_id):
			body.interactable = self

func _on_body_exited(body: Node2D) -> void:
	if body == _actor:
		body.interactable = null
		_actor = null

func interact() -> void:
	if _actor.has_item("key", keycard_id):
		_actor.remove_item("key", keycard_id)
		
		var inventory_overlay = get_tree().get_first_node_in_group("InventoryOverlay")
		inventory_overlay.remove_item("Key")
		
		is_unlocked = true
