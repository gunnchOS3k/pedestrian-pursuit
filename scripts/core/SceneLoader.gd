extends Node

## Simple scene transition helper.

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const RACE_SCENE := "res://scenes/race/RaceScene.tscn"
const GUEST_RUNNER_REVIEW := "res://scenes/labs/GuestRunnerReview.tscn"
const BUILD_INFO := "res://scenes/menus/BuildInfo.tscn"


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


func go_to_guest_runner_review() -> void:
	var tree := get_tree()
	if tree != null and tree.paused:
		tree.paused = false
	tree.change_scene_to_file(GUEST_RUNNER_REVIEW)


func go_to_build_info(from_guest_review: bool = false) -> void:
	var identity := get_node_or_null("/root/BuildIdentity")
	if identity != null:
		identity.return_to_guest_review = from_guest_review
	var tree := get_tree()
	if tree != null and tree.paused:
		tree.paused = false
	tree.change_scene_to_file(BUILD_INFO)


func restart_race(reason: String = "rematch") -> void:
	GameManager.prepare_race_restart(reason)
	go_to_race()

