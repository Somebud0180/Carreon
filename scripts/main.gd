extends Control
class_name Main

const GAME_SCENE = preload("res://scenes/game.tscn")

enum STATE { MENU, GAME, SETTINGS }
var menu_state: STATE = STATE.MENU

var in_game: bool = false

func hide_and_show(hide_string: String, show_string: String) -> void:
	if hide_string and show_string.is_empty():
		%TransitionAnimationPlayer.play("hide_" + hide_string)
	elif (hide_string.is_empty() and show_string):
		%TransitionAnimationPlayer.play("show_" + show_string)
	else:
		var tree_root = %AnimationTree.tree_root
		tree_root.get_node("Animation In").animation = ("hide_" + hide_string)
		tree_root.get_node("Animation Out").animation = ("show_" + show_string)
		
		%AnimationTree.active = true
		await %AnimationTree.animation_finished
		%AnimationTree.active = false

func _ready() -> void:
	_platform_checks()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not (%AnimationTree.active or %TransitionAnimationPlayer.is_playing()):
		print("Pressed menu")
		match menu_state:
			STATE.MENU:
				if in_game:
					menu_state = STATE.GAME
					hide_and_show("main_game", "")
			STATE.GAME:
				menu_state = STATE.MENU
				hide_and_show("", "main_game")
			STATE.SETTINGS:
				menu_state = STATE.SETTINGS
				hide_and_show("settings", "main_left")

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
		$GameLayer/Game.process_mode = Node.PROCESS_MODE_INHERIT
		in_game = true
	
	menu_state = STATE.GAME
	await get_tree().process_frame
	hide_and_show("main_game", "game" if !$GameLayer/Game.visible else "")

func _on_settings_button_pressed() -> void:
	hide_and_show("main_left", "settings")
	menu_state = STATE.SETTINGS

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed(from: String, to: String) -> void:
	hide_and_show(from, to)
	if to.contains("menu"):
		menu_state = STATE.MENU
