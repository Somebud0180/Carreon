extends Resource
class_name Inventory

@export var item_name: String = ""
@export var item_value: int = 0

func _init(_item_name:= "", _item_value:= 0) -> void:
	item_name = _item_name
	item_value = _item_value
