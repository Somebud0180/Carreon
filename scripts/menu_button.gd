extends Button

var menu: Main

func _ready() -> void:
	menu = get_tree().get_first_node_in_group("MainScene")

func _on_pressed() -> void:
	menu.menu_state = menu.STATE.MENU
	menu.hide_and_show("", "main_game")
