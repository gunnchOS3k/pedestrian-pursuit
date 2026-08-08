extends SceneTree
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _CourseTrack = preload("res://scripts/tracks/CourseTrack.gd")

## Headless product-state smoke for post-merge main:
## modes, both cups / 8 tracks, items, AI tiers, ghost save/load, local MP, a11y save.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var gm := root.get_node_or_null("GameManager")
	if gm == null:
		gm = preload("res://scripts/core/GameManager.gd").new()
		gm.name = "GameManager"
		root.add_child(gm)

	_test_modes(gm, failures)
	_test_both_cups_and_tracks(failures)
	_test_items(failures)
	_test_ai_tiers(failures)
	_test_ghost_save_load(failures)
	_test_local_mp_race_scene(gm, failures)
	_test_time_trial_race_scene(gm, failures)
	_test_a11y_persist(failures)
	_test_main_menu_scene(failures)

	if failures.is_empty():
		print("AlphaProductStateTest PASS — modes/cups/tracks/items/AI/ghost/local-MP/a11y.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_modes(gm: Node, failures: PackedStringArray) -> void:
	gm.start_quick_race("verdant_cascade_circuit")
	if str(gm.mode_label()) != "Quick Race" or int(gm.ai_field_size) != 3:
		failures.append("Quick Race mode state invalid")
	gm.start_time_trial("tideglass_harbor")
	if not bool(gm.is_time_trial()) or int(gm.ai_field_size) != 0:
		failures.append("Time Trial mode should clear AI field")
	gm.start_local_mp("neon_switchyard", 2)
	if not bool(gm.is_local_mp()) or int(gm.local_mp_players) != 2 or int(gm.ai_field_size) != 2:
		failures.append("Local MP mode state invalid")
	var cup := _TrackCatalog.load_cup("sole_surge_cup")
	if not gm.start_cup("sole_surge_cup", cup.get("track_ids", [])):
		failures.append("Cup mode failed to start")
	elif str(gm.mode_label()) != "Cup":
		failures.append("Cup mode label wrong")


func _test_both_cups_and_tracks(failures: PackedStringArray) -> void:
	var cup_ids := _TrackCatalog.list_cup_ids()
	if cup_ids.size() < 2:
		failures.append("expected >=2 cups, got %d" % cup_ids.size())
	var seen := {}
	for cup_id in cup_ids:
		var cup := _TrackCatalog.load_cup(str(cup_id))
		if cup.is_empty():
			failures.append("cup '%s' empty" % cup_id)
			continue
		var tracks: Array = cup.get("track_ids", [])
		if tracks.size() != 4:
			failures.append("cup '%s' expected 4 tracks, got %d" % [cup_id, tracks.size()])
		for track_id in tracks:
			var tid := str(track_id)
			seen[tid] = true
			var data := _TrackCatalog.load_track(tid)
			if data.is_empty():
				failures.append("track '%s' failed to load" % tid)
				continue
			var course: Node = _CourseTrack.new()
			course.configure(data)
			root.add_child(course)
			if not course.build():
				failures.append("track '%s' failed to build" % tid)
			course.queue_free()
	if seen.size() < 8:
		failures.append("unique track count %d < 8" % seen.size())


func _test_items(failures: PackedStringArray) -> void:
	var ids := ItemData.all_alpha_ids()
	if ids.size() < 6:
		failures.append("item catalog below Alpha floor")
		return
	for item_id in ids:
		var def := ItemData.load_by_id(item_id)
		if def.is_empty() or str(def.get("id", "")) != item_id:
			failures.append("item '%s' failed to load" % item_id)
			continue
		if not def.has("counterplay") and not def.has("warning_seconds"):
			failures.append("item '%s' missing counterplay/warning metadata" % item_id)
	var mgr: Node = preload("res://scripts/items/ItemManager.gd").new()
	root.add_child(mgr)
	# Wait one frame so _ready loads defs.
	await process_frame
	mgr.grant_random_item()
	if str(mgr.held_item_id).is_empty():
		failures.append("ItemManager.grant_random_item produced empty hold")
	var held := str(mgr.held_item_id)
	# turbo_toes path does not require current_scene; force a known safe id.
	mgr.held_item_id = "turbo_toes"
	var dummy := CharacterBody3D.new()
	root.add_child(dummy)
	var boost := Node.new()
	boost.name = "BoostSystem"
	boost.set_script(load("res://scripts/player/BoostSystem.gd"))
	dummy.add_child(boost)
	mgr.use_held_item(dummy)
	if not str(mgr.held_item_id).is_empty():
		failures.append("use_held_item did not clear held item (%s -> %s)" % [held, mgr.held_item_id])
	dummy.queue_free()
	mgr.queue_free()


func _test_ai_tiers(failures: PackedStringArray) -> void:
	var follower: Node = preload("res://scripts/ai/AIPathFollower.gd").new()
	root.add_child(follower)
	for tier_name in ["rookie", "standard", "ace"]:
		var tier_enum = follower.Tier.STANDARD
		match tier_name:
			"rookie":
				tier_enum = follower.Tier.ROOKIE
			"ace":
				tier_enum = follower.Tier.ACE
			_:
				tier_enum = follower.Tier.STANDARD
		follower.set_tier(tier_enum)
		follower.configure_route_plan(tier_name == "ace", -1.2 if tier_name == "ace" else 0.0)
		var look := float(follower.look_ahead)
		var speed := float(follower.speed_multiplier)
		var magnet := float(follower.magnet_strength)
		match tier_name:
			"rookie":
				if look >= 10.0 or speed >= 0.85 or magnet <= 0.0:
					failures.append("rookie tier defaults look wrong")
			"standard":
				if magnet != 0.0 or speed < 0.85:
					failures.append("standard tier defaults look wrong")
			"ace":
				if look < 12.0 or speed < 0.9 or magnet != 0.0:
					failures.append("ace tier defaults look wrong")
	follower.queue_free()


func _test_ghost_save_load(failures: PackedStringArray) -> void:
	var recorder: Node = preload("res://scripts/race/GhostRecorder.gd").new()
	root.add_child(recorder)
	var body := Node3D.new()
	root.add_child(body)
	body.global_position = Vector3(1.0, 1.0, 2.0)
	var track_id := "verdant_cascade_circuit"
	# Clear prior ghost so save is deterministic.
	var path := "user://time_trial_ghost_%s.json" % track_id
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	recorder.begin(track_id)
	for _i in 5:
		recorder.tick(0.05, body)
		body.global_position.x += 0.5
	if not bool(recorder.finish_and_save(12.5)):
		failures.append("ghost finish_and_save failed")
	var samples: Array = recorder.load_samples(track_id)
	if samples.size() < 3:
		failures.append("ghost load_samples returned %d samples" % samples.size())
	var player: Node3D = preload("res://scripts/race/GhostPlayer.gd").new()
	root.add_child(player)
	player.start(samples)
	if not player.visible:
		failures.append("GhostPlayer should be visible when samples exist")
	player.queue_free()
	body.queue_free()
	recorder.queue_free()


func _test_local_mp_race_scene(gm: Node, failures: PackedStringArray) -> void:
	gm.start_local_mp("verdant_cascade_circuit", 2)
	var packed := load("res://scenes/race/RaceScene.tscn")
	if packed == null:
		failures.append("RaceScene.tscn failed to load")
		return
	var race: Node = packed.instantiate()
	root.add_child(race)
	await create_timer(0.35).timeout
	if not is_instance_valid(race):
		failures.append("Local MP RaceScene died during boot")
		return
	var p2 := race.get_node_or_null("Player2Racer")
	if p2 == null:
		failures.append("Local MP missing Player2Racer")
	var racers := race.get_tree().get_nodes_in_group("racers")
	# Player + P2 + up to 2 AI.
	if racers.size() < 2:
		failures.append("Local MP expected >=2 racers, got %d" % racers.size())
	race.queue_free()
	await process_frame


func _test_time_trial_race_scene(gm: Node, failures: PackedStringArray) -> void:
	gm.start_time_trial("verdant_cascade_circuit")
	var packed := load("res://scenes/race/RaceScene.tscn")
	if packed == null:
		failures.append("RaceScene.tscn failed to load for TT")
		return
	var race: Node = packed.instantiate()
	root.add_child(race)
	await create_timer(0.35).timeout
	if not is_instance_valid(race):
		failures.append("Time Trial RaceScene died during boot")
		return
	if race.get_node_or_null("GhostRecorder") == null:
		failures.append("Time Trial missing GhostRecorder")
	if race.get_node_or_null("GhostPlayer") == null:
		failures.append("Time Trial missing GhostPlayer")
	race.queue_free()
	await process_frame


func _test_a11y_persist(failures: PackedStringArray) -> void:
	var a11y := root.get_node_or_null("AccessibilitySettings")
	if a11y == null:
		a11y = preload("res://scripts/core/AccessibilitySettings.gd").new()
		a11y.name = "AccessibilitySettings"
		root.add_child(a11y)
		await process_frame
	a11y.set_reduce_motion(true)
	a11y.set_larger_ui(true)
	a11y.set_colorblind_safe_hud(true)
	if a11y.camera_shake_allowed():
		failures.append("reduce_motion should block camera shake")
	if a11y.get_ui_scale_multiplier() < 1.2:
		failures.append("larger_ui scale too small")
	# Reload from disk.
	var a11y2: Node = preload("res://scripts/core/AccessibilitySettings.gd").new()
	root.add_child(a11y2)
	await process_frame
	if not bool(a11y2.reduce_motion) or not bool(a11y2.larger_ui) or not bool(a11y2.colorblind_safe_hud):
		failures.append("accessibility settings did not persist")
	a11y.set_reduce_motion(false)
	a11y.set_larger_ui(false)
	a11y.set_colorblind_safe_hud(false)
	a11y2.queue_free()


func _test_main_menu_scene(failures: PackedStringArray) -> void:
	var packed := load("res://scenes/main/MainMenu.tscn")
	if packed == null:
		failures.append("MainMenu.tscn failed to load")
		return
	var menu: Node = packed.instantiate()
	root.add_child(menu)
	await process_frame
	if not is_instance_valid(menu):
		failures.append("MainMenu died on instantiate")
	else:
		menu.queue_free()
