extends SceneTree

## Regression: a fresh player can dismiss onboarding and enter a real race.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var progression := root.get_node_or_null("ProgressionSave")
	if progression == null:
		failures.append("ProgressionSave autoload missing")
		_finish(failures)
		return

	# Never write a test state into the player's normal progression save.
	progression.enable_vxp31_sandbox()
	progression.tutorial_completed = false
	progression.first_run_complete = false

	var load_error := change_scene_to_file("res://scenes/main/MainMenu.tscn")
	if load_error != OK:
		failures.append("MainMenu failed to load: %s" % error_string(load_error))
		_finish(failures)
		return
	await process_frame
	await process_frame
	await process_frame

	var menu := current_scene
	var prompt := menu.get_node_or_null("FirstRunTutorialPrompt") if menu != null else null
	if prompt == null:
		failures.append("first-run onboarding prompt did not appear")
		_finish(failures)
		return
	if _find_button(prompt, "Race Now") == null:
		failures.append("Race Now action missing")
	if _find_button(prompt, "Start Tutorial") == null:
		failures.append("Start Tutorial action missing")
	var not_now := _find_button(prompt, "Not now")
	if not_now == null:
		failures.append("Not now dismissal missing")
		_finish(failures)
		return

	not_now.pressed.emit()
	await process_frame
	if menu.get_node_or_null("FirstRunTutorialPrompt") != null:
		failures.append("Not now did not dismiss onboarding")
	if not bool(progression.first_run_complete):
		failures.append("onboarding acknowledgement was not persisted")
	if bool(progression.tutorial_completed):
		failures.append("dismissal incorrectly awarded tutorial completion")
	if menu.get_node_or_null("VBox/TutorialButton") == null:
		failures.append("tutorial cannot be reopened from the main menu")
	if menu.get_node_or_null("VBox/HowToPlayButton") == null:
		failures.append("How to Play entry point missing")

	var quick_race := menu.get_node_or_null("VBox/SingleRaceButton") as Button
	if quick_race == null:
		failures.append("Quick Race action missing after onboarding dismissal")
		_finish(failures)
		return
	quick_race.pressed.emit()
	await process_frame
	await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://scenes/race/RaceScene.tscn":
		failures.append("dismiss onboarding -> Quick Race did not reach RaceScene")

	_finish(failures)


func _find_button(parent: Node, label: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == label:
			return button
	return null


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("FirstRunOnboardingRaceFlowTest PASS")
		print("PEDESTRIAN_FIRST_RUN_DISMISS_TO_RACE_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FirstRunOnboardingRaceFlowTest FAIL count=%d" % failures.size())
	quit(1)
