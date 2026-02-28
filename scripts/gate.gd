extends Node2D

const LOCKED_SPRITE_REGION = Rect2(1408, 128, 128, 128)
const UNLOCKED_SPRITE_REGION = Rect2(1280, 128, 128, 128)
const QUADRANT_TEXT = "You are in: Level 0 - Quadrant "
const LOCKED_TEXT = "This gate is locked, only authorized personnel may proceed at this moment."

@onready var area_2d: Area2D = $Area2D 
@onready var left_area_2d: Area2D = $LeftArea2D 
@onready var right_area_2d: Area2D = $RightArea2D 
@export var subtitle_priority: int = 999
@export var left_quadrant_number: String = ""
@export var right_quadrant_number: String = ""
@export var keycard_id: int = 0 # An identifier that defines what numbered key this gate accepts
@export_flags_2d_physics var collision_mask = 1:
	set(value):
		collision_mask = value
		if area_2d:
			area_2d.collision_mask = collision_mask

var game: Game
var subtitles: SubtitleLabel

var is_unlocked: bool = false:
	set(value):
		is_unlocked = value
		$Sprite2D.region_rect = UNLOCKED_SPRITE_REGION if is_unlocked else LOCKED_SPRITE_REGION
		$StaticBody2D.process_mode = PROCESS_MODE_DISABLED if is_unlocked else PROCESS_MODE_INHERIT

var key_actor: Node = null
var sign_actor: Node = null
var in_left_quadrant: bool = false
var in_right_quadrant: bool = false
var text_progress: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game = get_tree().get_first_node_in_group("GameScene")
	subtitles = game.get_node("%Subtitles")
	
	area_2d.connect("body_entered", _on_body_entered_key)
	area_2d.connect("body_exited", _on_body_exited_key)
	area_2d.collision_mask = collision_mask
	
	left_area_2d.connect("body_entered", _on_body_entered_sign.bind(true))
	left_area_2d.connect("body_exited", _on_body_exited_sign)
	left_area_2d.collision_mask = collision_mask
	
	right_area_2d.connect("body_entered", _on_body_entered_sign.bind(false))
	right_area_2d.connect("body_exited", _on_body_exited_sign)
	right_area_2d.collision_mask = collision_mask

# Door Key Interaction
func _on_body_entered_key(body: Node2D) -> void:
	if body is Player:
		key_actor = body
		if key_actor.has_item("key", keycard_id):
			body.interactable = self

func _on_body_exited_key(body: Node2D) -> void:
	if body == key_actor:
		body.interactable = null
		key_actor = null

# Door Sign Interaction
func _on_body_entered_sign(body: Node2D, is_left: bool) -> void:
	if body is Player:
		sign_actor = body
		in_left_quadrant = is_left
		in_right_quadrant = !is_left
		body.interactable = self

func _on_body_exited_sign(body: Node2D) -> void:
	if body == sign_actor:
		if text_progress == 1:
			subtitles.remove_text(_quadrant_text(), true)
		elif text_progress == 2:
			subtitles.remove_text(LOCKED_TEXT, true)
		
		text_progress = 0
		in_left_quadrant = false
		in_right_quadrant = false
		body.interactable = null
		sign_actor = null

# Quadrant Text
func _quadrant_text() -> String:
	var final_text: String
	
	final_text = QUADRANT_TEXT
	if in_left_quadrant:
		final_text += left_quadrant_number
	elif in_right_quadrant:
		final_text += right_quadrant_number
	
	return final_text

func interact() -> void:
	if key_actor:
		if key_actor.has_item("key", keycard_id):
			key_actor.remove_item("key", keycard_id)
			
			var inventory_overlay = get_tree().get_first_node_in_group("InventoryOverlay")
			inventory_overlay.remove_item("Key")
			
			is_unlocked = true
			
			return
	
	if sign_actor and !subtitles.is_animation_playing() and (in_left_quadrant or in_right_quadrant):
		var final_text: String = ""
		
		if text_progress == 0:
			final_text = _quadrant_text()
			subtitles.add_text(final_text, subtitle_priority, true, is_unlocked)
			text_progress = 1
		elif text_progress == 1:
			if !is_unlocked:
				final_text = LOCKED_TEXT
				subtitles.add_text(final_text, subtitle_priority + 1, true, true)
				subtitles.remove_text(_quadrant_text())
				text_progress = 2
			else:
				# If already unlocked, dismiss
				subtitles.remove_text(_quadrant_text(), true)
				text_progress = 0
		elif text_progress == 2:
			subtitles.remove_text(LOCKED_TEXT, true)
			text_progress = 0
		return
