extends Node

## Simple scene transition helper.

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const RACE_SCENE := "res://scenes/race/RaceScene.tscn"


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func go_to_race() -> void:
	get_tree().change_scene_to_file(RACE_SCENE)
