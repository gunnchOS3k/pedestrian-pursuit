extends SceneTree

## Real-condition achievement tests. No cheat unlock path.


const _Runtime := preload("res://scripts/core/AchievementRuntime.gd")
const CATALOG := "res://release/ACHIEVEMENTS.json"
const SAVE := "user://pp_achievements_test.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_wipe()
	var rt = _Runtime.new()
	root.add_child(rt)
	rt.configure_isolated(SAVE, CATALOG)

	if rt.catalog_count() != 12:
		failures.append("catalog count %d" % rt.catalog_count())
	if rt.completion_percent() != 0.0:
		failures.append("start percent")

	var hidden_masked := false
	for entry in rt.browser_entries():
		if str(entry.get("id", "")) == "pp.hidden_hat_trick":
			hidden_masked = str(entry.get("title", "")) == "???" and not bool(entry.get("unlocked", false))
	if not hidden_masked:
		failures.append("hidden achievement not masked")

	rt.set_flag("tutorial_completed", true)
	if not rt.is_unlocked("pp.first_stride"):
		failures.append("tutorial unlock")
	var stamp := rt.unlocked_at("pp.first_stride")
	rt.set_flag("tutorial_completed", true)
	if rt.unlocked_at("pp.first_stride") != stamp:
		failures.append("duplicate prevention failed")
	if rt.unlocked_count() != 1:
		failures.append("duplicate counted twice")

	rt.report_event("race_finished", 1)
	if not rt.is_unlocked("pp.finish_line"):
		failures.append("finish line")
	rt.report_event("podium_finish", 1)
	if not rt.is_unlocked("pp.podium"):
		failures.append("podium")
	rt.report_event("pause_resume", 1)
	if not rt.is_unlocked("pp.pause_and_breathe"):
		failures.append("pause/resume")
	rt.report_event("time_trial_pb", 1)
	if not rt.is_unlocked("pp.time_trialist"):
		failures.append("time trial")

	rt.set_flag("cup_complete", true)
	if not rt.is_unlocked("pp.cup_complete"):
		failures.append("cup complete")
	rt.set_flag("cup:stride_circuit_cup", true)
	if not rt.is_unlocked("pp.stride_circuit"):
		failures.append("stride circuit")
	rt.set_flag("challenge:rail_runner", true)
	rt.report_event("challenge_complete", 1)
	if not rt.is_unlocked("pp.rail_runner"):
		failures.append("rail runner")
	rt.set_flag("challenge:mud_grip_mastery", true)
	rt.report_event("challenge_complete", 1)
	rt.report_event("challenge_complete", 1)
	if not rt.is_unlocked("pp.mud_grip"):
		failures.append("mud grip")
	if not rt.is_unlocked("pp.challenge_set"):
		failures.append("challenge set")

	rt.report_event("race_finished", 4)
	if not rt.is_unlocked("pp.mileage"):
		failures.append("mileage")
	rt.report_event("podium_finish", 2)
	if not rt.is_unlocked("pp.hidden_hat_trick"):
		failures.append("hidden hat trick")

	if rt.unlocked_count() != 12:
		failures.append("unlocked_count %d" % rt.unlocked_count())
	if not is_equal_approx(rt.completion_percent(), 100.0):
		failures.append("percent %s" % str(rt.completion_percent()))
	var notes: Array = rt.drain_notifications()
	if notes.size() < 12:
		failures.append("notifications %d" % notes.size())

	var rt2 = _Runtime.new()
	root.add_child(rt2)
	rt2.configure_isolated(SAVE, CATALOG)
	if not rt2.is_unlocked("pp.first_stride"):
		failures.append("persist reload")
	if rt2.unlocked_at("pp.first_stride") != stamp:
		failures.append("timestamp persist")
	if not FileAccess.file_exists(SAVE):
		failures.append("offline save missing")

	_wipe()
	if failures.is_empty():
		print("AchievementRuntimeTest PASS — 12/12 real-condition unlocks, persist, duplicates, hidden, percent, notifications")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		print("AchievementRuntimeTest FAIL count=%d" % failures.size())
		quit(1)


func _wipe() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
