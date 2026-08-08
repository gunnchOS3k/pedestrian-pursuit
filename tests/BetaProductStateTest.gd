extends SceneTree
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _CourseTrack = preload("res://scripts/tracks/CourseTrack.gd")
const _OnlineArchitecture = preload("res://scripts/net/OnlineArchitecture.gd")
const _PerfBudget = preload("res://scripts/core/PerfBudget.gd")

## Beta / Digital RC product-state smoke.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var gm := root.get_node_or_null("GameManager")
	if gm == null:
		gm = preload("res://scripts/core/GameManager.gd").new()
		gm.name = "GameManager"
		root.add_child(gm)

	_test_roster_stats(failures)
	_test_footwear_materials(failures)
	_test_grammar_and_challenges(failures)
	_test_modes(gm, failures)
	_test_progression_save(failures)
	_test_online_arch(failures)
	_test_perf_budget(failures)
	_test_tracks_digital(failures)
	_test_main_menu(failures)

	if failures.is_empty():
		print("BetaProductStateTest PASS — roster/materials/grammar/modes/progression/RC scaffolds.")
		print("PEDESTRIAN_BETA_CONTENT_COMPLETE_DIGITAL")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_roster_stats(failures: PackedStringArray) -> void:
	var ids := RacerData.all_launch_ids()
	if ids.size() < 8:
		failures.append("launch roster < 8")
		return
	var speeds := {}
	for rid in ids:
		if not RacerData.has_gameplay_stats(rid):
			failures.append("runner '%s' missing gameplay stats (palette-only)" % rid)
			continue
		var data := RacerData.load_by_id(rid)
		speeds[rid] = float(data.get("top_speed", 0.0))
	# Not all identical — roster must differentiate mechanically.
	var unique := {}
	for v in speeds.values():
		unique[str(snappedf(float(v), 0.1))] = true
	if unique.size() < 4:
		failures.append("runner top_speed diversity too low (palette-only risk)")


func _test_footwear_materials(failures: PackedStringArray) -> void:
	for shoe_id in ShoeData.all_ids():
		var shoe := ShoeData.load_by_id(shoe_id)
		if str(shoe.get("material_family", "")).is_empty():
			failures.append("shoe '%s' missing material_family" % shoe_id)
		var aff: Dictionary = shoe.get("surface_affinities", {})
		if aff.size() < 6:
			failures.append("shoe '%s' affinities incomplete" % shoe_id)
		var mud := ShoeData.surface_affinity(shoe_id, "mud")
		var asphalt := ShoeData.surface_affinity(shoe_id, "asphalt")
		if shoe_id == "grip_soles" and mud <= asphalt:
			failures.append("grip_soles should prefer mud over asphalt")
		if shoe_id == "speed_sneakers" and asphalt <= mud:
			failures.append("speed_sneakers should prefer asphalt over mud")


func _test_grammar_and_challenges(failures: PackedStringArray) -> void:
	if not FileAccess.file_exists("res://data/mechanics/foot_racing_grammar.json"):
		failures.append("missing foot_racing_grammar.json")
	else:
		var f := FileAccess.open("res://data/mechanics/foot_racing_grammar.json", FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY or parsed.get("mechanics", []).size() < 10:
			failures.append("grammar incomplete")
	if not FileAccess.file_exists("res://data/challenges/launch_challenges.json"):
		failures.append("missing launch_challenges.json")
	if not FileAccess.file_exists("res://data/art/REQUIRES_ART_PRODUCTION_INVENTORY.json"):
		failures.append("missing art production inventory")


func _test_modes(gm: Node, failures: PackedStringArray) -> void:
	gm.start_quick_race("verdant_cascade_circuit")
	if str(gm.mode_label()) != "Quick Race":
		failures.append("Quick Race label")
	gm.start_time_trial("tideglass_harbor")
	if not bool(gm.is_time_trial()):
		failures.append("Time Trial")
	gm.start_local_mp("neon_switchyard", 2)
	if not bool(gm.is_local_mp()):
		failures.append("Local MP")
	# Local MP polish smoke: split director script loads.
	var split_script = load("res://scripts/race/LocalMPSplitDirector.gd")
	if split_script == null:
		failures.append("LocalMPSplitDirector missing")
	gm.start_tutorial("verdant_cascade_circuit")
	if not bool(gm.is_tutorial()) or str(gm.mode_label()) != "Tutorial":
		failures.append("Tutorial mode")
	gm.start_challenge("rail_runner", "neon_switchyard", "bounce_boots")
	if not bool(gm.is_challenge()) or str(gm.selected_shoe_id) != "bounce_boots":
		failures.append("Challenge mode")
	var cup := _TrackCatalog.load_cup("sole_surge_cup")
	if not gm.start_cup("sole_surge_cup", cup.get("track_ids", [])):
		failures.append("Cup mode")


func _test_progression_save(failures: PackedStringArray) -> void:
	var prog := root.get_node_or_null("ProgressionSave")
	if prog == null:
		prog = preload("res://scripts/core/ProgressionSave.gd").new()
		prog.name = "ProgressionSave"
		root.add_child(prog)
		await process_frame
	prog.add_xp(10)
	prog.unlock("mode:challenges")
	prog.save()
	if not bool(prog.is_unlocked("mode:challenges")):
		failures.append("progression unlock failed")
	if int(prog.level) < 1:
		failures.append("progression level invalid")


func _test_online_arch(failures: PackedStringArray) -> void:
	var desc: Dictionary = _OnlineArchitecture.describe()
	if str(desc.get("scope", "")).find("private") < 0:
		failures.append("online arch must stay private/dev scoped")
	if bool(desc.get("public_matchmaking", true)):
		failures.append("public matchmaking must be false")
	var path := "res://gate1/evidence/out/pp_online_architecture.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	if _OnlineArchitecture.write_evidence(path).is_empty():
		failures.append("failed to write online arch evidence")


func _test_perf_budget(failures: PackedStringArray) -> void:
	var path := "res://gate1/evidence/out/pp_perf_budget.json"
	if _PerfBudget.write_evidence(path).is_empty():
		failures.append("perf budget write failed")
	var budgets: Dictionary = _PerfBudget.as_dict().get("budgets", {})
	if int(budgets.get("target_fps_desktop", 0)) < 60:
		failures.append("desktop fps budget")


func _test_tracks_digital(failures: PackedStringArray) -> void:
	for track_id in _TrackCatalog.list_all_track_ids():
		var data := _TrackCatalog.load_track(str(track_id))
		if data.is_empty():
			failures.append("track load %s" % track_id)
			continue
		if str(data.get("art_status", "")) != "REQUIRES_ART_PRODUCTION":
			failures.append("track %s must keep art_status until final art" % track_id)
		if data.get("shortcut_routes", []).is_empty() and not bool(data.get("has_shortcut", false)):
			failures.append("track %s missing shortcut metadata" % track_id)
		var course: Node = _CourseTrack.new()
		course.configure(data)
		root.add_child(course)
		if not course.build():
			failures.append("track build %s" % track_id)
		elif course.get_race_path() == null:
			failures.append("track ai path %s" % track_id)
		course.queue_free()


func _test_main_menu(failures: PackedStringArray) -> void:
	var packed := load("res://scenes/main/MainMenu.tscn")
	if packed == null:
		failures.append("MainMenu missing")
		return
	var menu: Node = packed.instantiate()
	root.add_child(menu)
	await process_frame
	if menu.get_node_or_null("VBox/TutorialButton") == null and menu.get_node_or_null("VBox").get_node_or_null("TutorialButton") == null:
		# Buttons are created in _ready; allow a frame.
		await process_frame
	var vbox = menu.get_node_or_null("VBox")
	if vbox == null or vbox.get_node_or_null("TutorialButton") == null:
		failures.append("MainMenu missing TutorialButton")
	if vbox == null or vbox.get_node_or_null("ChallengesButton") == null:
		failures.append("MainMenu missing ChallengesButton")
	if vbox == null or vbox.get_node_or_null("ProgressionButton") == null:
		failures.append("MainMenu missing ProgressionButton")
	menu.queue_free()
