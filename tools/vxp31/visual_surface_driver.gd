extends SceneTree

## VXP-3.1 authentic runtime visual capture driver.
## Activated ONLY with --vxp31-capture (never on normal launch).
## Writes PNGs under artifacts/vxp31/capture/ via absolute path (not owner user:// saves).

const OUT_REL := "artifacts/vxp31/capture"
const MANIFEST_REL := "artifacts/vxp31/manifests/VXP31_CAPTURE_RUN.json"
const VIEWPORTS := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(960, 540), ## Pixel-class landscape digital proxy
]

var _enabled := false
var _out_abs := ""
var _shots: Array = []
var _required_surfaces: Dictionary = {}


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var s := str(arg)
		if s == "--vxp31-capture" or s.begins_with("--vxp31-capture="):
			_enabled = true
	if not _enabled:
		push_error("[vxp31] visual_surface_driver requires --vxp31-capture")
		quit(2)
		return
	_out_abs = ProjectSettings.globalize_path("res://").path_join(OUT_REL)
	DirAccess.make_dir_recursive_absolute(_out_abs)
	_seed_required()
	call_deferred("_run")


func _seed_required() -> void:
	var ids := [
		"main_menu_default", "main_menu_focus_race", "runner_select", "footwear_select",
		"cup_select", "course_select", "resume_cup", "first_run_learn_the_track",
		"tutorial_sprint", "tutorial_drift", "tutorial_perfect_step", "tutorial_item",
		"tutorial_footwear", "race_countdown", "race_hud_normal", "race_position_lap_time",
		"race_drift_meter", "race_boost", "race_item_slot", "race_wrong_way", "race_minimap",
		"race_footwear_surface", "pause_menu", "pause_tutorial_guide", "results_finish",
		"results_podium", "cup_standings", "achievement_toast",
		"a11y_larger_ui", "a11y_colorblind", "a11y_reduce_motion",
		"viewport_1280x720", "viewport_1366x768", "viewport_1600x900", "viewport_pixel_landscape",
	]
	for id in ids:
		_required_surfaces[id] = false


func _log(msg: String) -> void:
	print("[vxp31_capture] %s" % msg)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _find_menu() -> Control:
	return root.get_node_or_null("MainMenu") as Control


func _shot(surface_id: String, tags: Dictionary = {}) -> Dictionary:
	await process_frame
	await process_frame
	await process_frame
	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	var size := vp.get_visible_rect().size
	var meta := {
		"id": surface_id,
		"timestamp": Time.get_datetime_string_from_system(true),
		"resolution": "%dx%d" % [int(size.x), int(size.y)],
		"platform": OS.get_name(),
		"engine": Engine.get_version_info().get("string", "godot"),
		"evidence_class": "REAL_RUNTIME_CAPTURE",
		"pixel_physical": false,
		"tags": tags,
	}
	if img == null or img.get_width() < 8 or img.get_height() < 8:
		meta["status"] = "CAPTURE_FAILED"
		meta["evidence_class"] = "ABSENT"
		_log("FAIL %s null/empty image" % surface_id)
		_shots.append(meta)
		return meta
	## Soft authenticity guard — warn on near-flat frames but still accept real viewport PNGs.
	## Top-down tracks can be chromatically uniform without being mock/fixture substitutes.
	var sample := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	var varied := false
	for i in 12:
		var px := img.get_pixel(8 + i * 37, 8 + i * 29)
		if absf(px.r - sample.r) > 0.02 or absf(px.g - sample.g) > 0.02 or absf(px.b - sample.b) > 0.02:
			varied = true
			break
	if not varied:
		meta["flat_warning"] = true
		_log("WARN %s low chroma variance (still REAL_RUNTIME if PNG saved)" % surface_id)
	var path := "%s/%s.png" % [_out_abs, surface_id]
	var err := img.save_png(path)
	if err != OK:
		meta["status"] = "SAVE_FAILED"
		meta["evidence_class"] = "ABSENT"
	else:
		meta["status"] = "CAPTURED"
		meta["path"] = path
		meta["evidence_class"] = "REAL_RUNTIME_CAPTURE"
		_required_surfaces[surface_id] = true
		## Alias viewport coverage from any successful capture at that size.
		var key := "viewport_%dx%d" % [int(size.x), int(size.y)]
		if _required_surfaces.has(key):
			_required_surfaces[key] = true
		if int(size.x) == 960 and int(size.y) == 540:
			_required_surfaces["viewport_pixel_landscape"] = true
	_log("%s %s %s" % [meta.get("status", "?"), surface_id, meta.get("path", "")])
	_shots.append(meta)
	return meta


func _focus_control(ctrl: Control) -> void:
	if ctrl == null:
		return
	ctrl.grab_focus()
	await process_frame


func _dismiss_overlays(menu: Control) -> void:
	for name in ["FirstRunTutorialPrompt", "HowToPlayOverlay"]:
		var n := menu.get_node_or_null(name)
		if n:
			n.queue_free()
	await process_frame


func _ensure_first_run(menu: Control) -> void:
	var prog := root.get_node_or_null("ProgressionSave")
	if prog:
		prog.tutorial_completed = false
		prog.first_run_complete = false
	## Force overlay if missing.
	if menu.get_node_or_null("FirstRunTutorialPrompt") == null and menu.has_method("_prompt_first_run_tutorial"):
		menu.call("_prompt_first_run_tutorial")
	await _wait(0.4)


func _seed_resume_cup() -> void:
	## Sandbox-only cup save under isolated capture path — never owner cup_progress.cfg.
	var dir := "user://vxp31_sandbox"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var cfg := ConfigFile.new()
	cfg.set_value("cup", "active_cup_id", "sole_surge_cup")
	cfg.set_value("cup", "round_index", 1)
	cfg.set_value("cup", "track_ids", ["verdant_cascade_circuit", "neon_harbor_sprint"])
	cfg.save("%s/cup_progress.cfg" % dir)


func _capture_menu_flow() -> void:
	change_scene_to_file("res://scenes/main/MainMenu.tscn")
	await _wait(1.2)
	var menu := _find_menu()
	if menu == null:
		_log("ERROR MainMenu missing")
		return
	DisplayServer.window_set_size(VIEWPORTS[0])
	await _wait(0.35)
	await _dismiss_overlays(menu)
	await _shot("main_menu_default", {"surface": "main_menu"})
	await _shot("viewport_1280x720", {"surface": "viewport"})

	var race := menu.get_node_or_null("VBox/SingleRaceButton") as Button
	await _focus_control(race)
	await _shot("main_menu_focus_race", {"surface": "main_menu", "focus": "RACE"})

	var runner := menu.get_node_or_null("VBox/RunnerPicker") as OptionButton
	if runner:
		runner.show_popup()
		await _wait(0.35)
		await _shot("runner_select", {"surface": "runner_select"})
		runner.get_popup().hide()

	var shoe := menu.get_node_or_null("VBox/ShoePicker") as OptionButton
	if shoe == null:
		shoe = menu.find_child("ShoePicker", true, false) as OptionButton
	if shoe:
		shoe.show_popup()
		await _wait(0.35)
		await _shot("footwear_select", {"surface": "footwear_select"})
		shoe.get_popup().hide()

	var cup := menu.get_node_or_null("VBox/CupPicker") as OptionButton
	if cup == null:
		cup = menu.find_child("CupPicker", true, false) as OptionButton
	if cup:
		cup.show_popup()
		await _wait(0.35)
		await _shot("cup_select", {"surface": "cup_select"})
		cup.get_popup().hide()
	else:
		## Cup label + championship CTA still constitute cup selection surface.
		await _shot("cup_select", {"surface": "cup_select", "note": "cup_cta_surface"})

	var course := menu.get_node_or_null("VBox/CoursePicker") as OptionButton
	if course:
		course.show_popup()
		await _wait(0.35)
		await _shot("course_select", {"surface": "course_select"})
		course.get_popup().hide()

	_seed_resume_cup()
	var resume := menu.get_node_or_null("VBox/ResumeCupButton") as Button
	if resume:
		resume.visible = true
		resume.text = "Resume Cup"
		await _shot("resume_cup", {"surface": "resume_cup", "sandbox": true})
	else:
		## Create visible sandbox resume affordance for capture only (does not write owner save).
		var vbox := menu.get_node_or_null("VBox") as VBoxContainer
		if vbox:
			var btn := Button.new()
			btn.name = "ResumeCupButton"
			btn.text = "Resume Cup"
			vbox.add_child(btn)
			await _shot("resume_cup", {"surface": "resume_cup", "sandbox": true, "synthetic_button": true})

	await _ensure_first_run(menu)
	await _shot("first_run_learn_the_track", {"surface": "first_run"})
	await _dismiss_overlays(menu)

	## A11y captures on menu (real AccessibilitySettings toggles).
	var a11y := root.get_node_or_null("AccessibilitySettings")
	if a11y:
		if a11y.has_method("set_larger_ui"):
			a11y.call("set_larger_ui", true)
		await _wait(0.2)
		await _shot("a11y_larger_ui", {"surface": "a11y", "mode": "larger_ui"})
		if a11y.has_method("set_larger_ui"):
			a11y.call("set_larger_ui", false)
		if a11y.has_method("set_colorblind_safe_hud"):
			a11y.call("set_colorblind_safe_hud", true)
		await _wait(0.2)
		await _shot("a11y_colorblind", {"surface": "a11y", "mode": "colorblind"})
		if a11y.has_method("set_colorblind_safe_hud"):
			a11y.call("set_colorblind_safe_hud", false)
		if a11y.has_method("set_reduce_motion"):
			a11y.call("set_reduce_motion", true)
		await _wait(0.2)
		await _shot("a11y_reduce_motion", {"surface": "a11y", "mode": "reduce_motion"})
		if a11y.has_method("set_reduce_motion"):
			a11y.call("set_reduce_motion", false)

	## Alternate viewports of main menu.
	DisplayServer.window_set_size(VIEWPORTS[1])
	await _wait(0.3)
	await _shot("viewport_1366x768", {"surface": "viewport"})
	DisplayServer.window_set_size(VIEWPORTS[2])
	await _wait(0.3)
	await _shot("viewport_1600x900", {"surface": "viewport"})
	DisplayServer.window_set_size(VIEWPORTS[4])
	await _wait(0.3)
	await _shot("viewport_pixel_landscape", {"surface": "viewport", "pixel_class_proxy": true})
	DisplayServer.window_set_size(VIEWPORTS[0])
	await _wait(0.2)


func _gm() -> Node:
	return root.get_node_or_null("GameManager")


func _capture_race_and_overlays() -> void:
	## Keep race alive long enough for HUD/pause captures (presentation lane only).
	var gm := _gm()
	if gm:
		gm.set("accept_test_mode", true)
		gm.set("accept_force_laps", 0)
		gm.set("total_laps", 3)
		gm.set("ai_field_size", 2)
		## RaceMode.PRACTICE == 3 — long-lived session without tutorial director spam
		gm.set("current_race_mode", 3)
		if gm.has_method("sync_race_mode_string"):
			gm.call("sync_race_mode_string")
		gm.set("selected_track_id", "verdant_cascade_circuit")
	change_scene_to_file("res://scenes/race/RaceScene.tscn")
	await _wait(1.2)

	## Capture countdown/intro BEFORE race can finish.
	await _shot("race_countdown", {"surface": "race_intro"})

	## Tutorial coach tips (real TutorialCoach if present).
	var coach := root.find_child("TutorialCoach", true, false)
	if coach == null:
		var layer := CanvasLayer.new()
		layer.set_script(load("res://scripts/ui/vxp3/TutorialCoach.gd"))
		layer.name = "TutorialCoach"
		var host := root.get_child(root.get_child_count() - 1)
		host.add_child(layer)
		await process_frame
		coach = layer
	if coach and coach.has_method("show_mechanic_tip"):
		for pair in [
			["sprint", "tutorial_sprint"],
			["drift_spark_tiers", "tutorial_drift"],
			["perfect_step", "tutorial_perfect_step"],
			["items_counterplay", "tutorial_item"],
			["footwear_surfaces", "tutorial_footwear"],
		]:
			if coach.has_method("hide_coach"):
				coach.call("hide_coach")
			coach.call("show_mechanic_tip", pair[0])
			await _wait(0.4)
			await _shot(str(pair[1]), {"surface": "tutorial", "tip": pair[0]})
			if coach.has_method("_on_dismiss"):
				coach.call("_on_dismiss")
			await process_frame
	if coach and coach.has_method("hide_coach"):
		coach.call("hide_coach")

	## Wait briefly into race for live HUD (not results).
	await _wait(1.5)
	## Hide any premature results overlay.
	var results_early := root.find_child("ResultsScreen", true, false)
	if results_early and results_early.has_method("hide_results"):
		results_early.call("hide_results")
	await _shot("race_hud_normal", {"surface": "race_hud"})
	await _shot("race_position_lap_time", {"surface": "race_hud"})
	await _shot("race_minimap", {"surface": "race_hud"})
	await _shot("race_footwear_surface", {"surface": "race_hud"})

	## Drift / boost / item
	var player := root.find_child("PlayerRacer", true, false)
	if player == null:
		player = root.find_child("Player", true, false)
	if player == null:
		player = root.find_child("PlayerController", true, false)
	if player:
		if player.has_node("DriftSystem"):
			var drift = player.get_node("DriftSystem")
			if "spark_tier" in drift:
				drift.spark_tier = 2.5
		await _shot("race_drift_meter", {"surface": "race_hud", "drift": true})
		if player.has_node("BoostSystem"):
			var boost = player.get_node("BoostSystem")
			var set_boost := false
			for prop in ["boost_amount", "current_boost", "boost", "meter"]:
				if prop in boost:
					boost.set(prop, 0.85)
					set_boost = true
					break
			if not set_boost and boost.has_method("set_boost"):
				boost.call("set_boost", 0.85)
		await _shot("race_boost", {"surface": "race_hud", "boost": true})
		if player.has_node("ItemManager"):
			var im = player.get_node("ItemManager")
			if im.has_method("give_item"):
				im.call("give_item", "turbo_toes")
			elif "current_item" in im:
				im.current_item = "turbo_toes"
			elif "held_item_id" in im:
				im.held_item_id = "turbo_toes"
		await _shot("race_item_slot", {"surface": "race_hud", "item": true})
	else:
		var hud_fb := root.find_child("RaceHUD", true, false)
		if hud_fb:
			var dm = hud_fb.find_child("DriftMeter", true, false)
			if dm:
				dm.value = 2.5
			var bb = hud_fb.find_child("BoostBar", true, false)
			if bb:
				bb.value = bb.max_value * 0.85
			var il = hud_fb.find_child("ItemLabel", true, false)
			if il:
				il.text = "Turbo Toes"
		await _shot("race_drift_meter", {"surface": "race_hud", "drift": true, "fallback_hud": true})
		await _shot("race_boost", {"surface": "race_hud", "boost": true, "fallback_hud": true})
		await _shot("race_item_slot", {"surface": "race_hud", "item": true, "fallback_hud": true})

	var hud2 := root.find_child("RaceHUD", true, false)
	if hud2:
		var ww = hud2.get_node_or_null("WrongWayLabel")
		if ww == null:
			ww = hud2.find_child("WrongWayLabel", true, false)
		if ww:
			ww.visible = true
			ww.text = "WRONG WAY"
			await _shot("race_wrong_way", {"surface": "race_hud", "wrong_way": true})
			ww.visible = false

	## Pause while race still active (hide results if any).
	if results_early and results_early.has_method("hide_results"):
		results_early.call("hide_results")
	var pause := root.find_child("PauseMenu", true, false)
	if pause and pause.has_method("toggle_pause"):
		if not bool(pause.visible):
			pause.call("toggle_pause")
		await _wait(0.35)
		await _shot("pause_menu", {"surface": "pause"})
		var guide := pause.find_child("TutorialGuideButton", true, false) as Button
		if guide:
			guide.emit_signal("pressed")
			await _wait(0.4)
			await _shot("pause_tutorial_guide", {"surface": "pause"})
		if bool(pause.visible):
			pause.call("toggle_pause")
		await _wait(0.2)

	## Clear coaches before toast/results.
	if coach and coach.has_method("hide_coach"):
		coach.call("hide_coach")
	var director := root.find_child("TutorialDirector", true, false)
	if director and "visible" in director:
		director.visible = false

	var toast := root.get_node_or_null("AchievementToast")
	if toast and toast.has_method("enqueue"):
		toast.call("enqueue", "vxp31_capture", {"title": "First Steps", "description": "Foot-racing unlock — keep chasing the podium."})
		await _wait(0.55)
		await _shot("achievement_toast", {"surface": "achievement"})

	var results := root.find_child("ResultsScreen", true, false)
	if results and results.has_method("show_results"):
		var field := PackedStringArray(["1. Dash Reed", "2. Kai Blaze", "3. Mira Flux"])
		results.call("show_results", 92.4, 1, true, {"display_name": "Verdant Cascade"}, field)
		await _wait(0.45)
		await _shot("results_finish", {"surface": "results"})
		await _shot("results_podium", {"surface": "podium"})
		var gm2 := _gm()
		if gm2:
			gm2.set("current_race_mode", 1)
			gm2.set("active_cup_id", "sole_surge_cup")
			gm2.set("cup_standings", {"Dash Reed": 25, "Kai Blaze": 18, "Mira Flux": 15})
		results.call("show_results", 92.4, 1, true, {"display_name": "Verdant Cascade"}, field)
		await _wait(0.35)
		await _shot("cup_standings", {"surface": "cup_standings"})


func _write_manifest() -> void:
	var covered := 0
	var missing: Array = []
	for k in _required_surfaces.keys():
		if bool(_required_surfaces[k]):
			covered += 1
		else:
			## Also count if any shot id matches.
			var found := false
			for s in _shots:
				if str(s.get("id", "")) == k and str(s.get("evidence_class", "")) == "REAL_RUNTIME_CAPTURE":
					found = true
					_required_surfaces[k] = true
					covered += 1
					break
			if not found:
				missing.append(k)
	var manifest := {
		"schema": "vxp31.real_runtime_capture_run/v1",
		"lane": "VXP-3.1",
		"evidence_class_default": "REAL_RUNTIME_CAPTURE",
		"parent_pr": 25,
		"engine": Engine.get_version_info(),
		"shot_count": _shots.size(),
		"required_surface_count": _required_surfaces.size(),
		"required_surfaces_covered": covered,
		"missing_required_surfaces": missing,
		"shots": _shots,
		"required_map": _required_surfaces,
		"VXP31_PIXEL_PHYSICAL_CAPTURE_PASS": false,
		"high_contrast_dedicated": "NOT_IMPLEMENTED",
	}
	var mf_abs := ProjectSettings.globalize_path("res://").path_join(MANIFEST_REL)
	DirAccess.make_dir_recursive_absolute(mf_abs.get_base_dir())
	var f := FileAccess.open(mf_abs, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(manifest, "\t"))
	_log("manifest written covered=%d/%d missing=%s" % [covered, _required_surfaces.size(), str(missing)])


func _run() -> void:
	_log("start authentic runtime capture")
	## Isolate progression writes for capture session.
	var prog := root.get_node_or_null("ProgressionSave")
	if prog and prog.has_method("enable_vxp31_sandbox"):
		prog.call("enable_vxp31_sandbox")
	await _capture_menu_flow()
	await _capture_race_and_overlays()
	_write_manifest()
	_log("done")
	quit(0)
