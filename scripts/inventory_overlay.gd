extends Control

const ITEM_CONTAINER_SCENE = preload("res://scenes/item_container.tscn")

func add_item(item_name: String, item_sprite: Texture2D) -> void:
	var panel_container = ITEM_CONTAINER_SCENE.instantiate()
	panel_container.item_name = item_name
	
	var texture_rect = TextureRect.new()
	texture_rect.texture = item_sprite
	
	panel_container.add_child(texture_rect)
	
	%GridContainer.add_child(panel_container)

func remove_item(item_name) -> void:
	for child in %GridContainer.get_children():
		if child.item_name == item_name:
			child.queue_free()
			return
