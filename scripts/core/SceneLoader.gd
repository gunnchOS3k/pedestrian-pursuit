extends Node

## Simple scene transition helper.

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const RACE_SCENE := "res://scenes/race/RaceScene.tscn"


func go_to_main_menu() -> void:
	var tree := get_tree()
	if tree != null and tree.paused:
		tree.paused = false
	tree.change_scene_to_file(MAIN_MENU)


func go_to_race() -> void:
	var tree := get_tree()
	if tree != null and tree.paused:
		tree.paused = false
	tree.change_scene_to_file(RACE_SCENE)


func restart_race(reason: String = "rematch") -> void:
	GameManager.prepare_race_restart(reason)
	go_to_race()

