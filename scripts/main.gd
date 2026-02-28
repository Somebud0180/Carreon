extends Control

const GAME_SCENE = preload("res://scenes/game.tscn")

enum STATE { MENU, GAME, SETTINGS }
var menu_state: STATE = STATE.MENU

var in_game: bool = false

func _ready() -> void:
	_platform_checks()

func hide_and_show(hide_string: String = "", show_string: String = "") -> void:
	var tree_root = %AnimationTree.tree_root
	tree_root.get_node("Animation In").animation = ("hide_" + hide_string) if hide_string else ""
	tree_root.get_node("Animation Out").animation = ("show_" + show_string) if show_string else ""
	
	%AnimationTree.active = true
	await %AnimationTree.animation_finished
	%AnimationTree.active = false

## Does platform specific checks and changes
## Optionally accepts an OS string to use for debugging
func _platform_checks(defined_platform: String = "") -> void:
	var platform_name = OS.get_name() if defined_platform.is_empty() else defined_platform
	
	# Hide Quit on applicable platforms
	if platform_name in ["iOS", "Android", "Web"]:
		$MenuLayer/MainMenu/Margin/ButtonContainer/QuitButton.visible = false

# On Button Pressed
func _on_play_button_pressed() -> void:
	if !$GameLayer/Game.visible:
		hide_and_show("main_game", "game")
		$GameLayer/Game.process_mode = Node.PROCESS_MODE_INHERIT

func _on_settings_button_pressed() -> void:
	hide_and_show("main_left", "settings")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed(from: String, to: String) -> void:
	hide_and_show(from, to)
