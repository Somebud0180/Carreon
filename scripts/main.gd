extends Control

const GAME_SCENE = preload("res://scenes/game.tscn")

enum STATE { MENU, GAME, SETTINGS }
var menu_state: STATE = STATE.MENU

var in_game: bool = false
