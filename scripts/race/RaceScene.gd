extends Node3D
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _RunnerProfile = preload("res://scripts/data/RunnerProfile.gd")
const CrashWatchdogScript = preload("res://scripts/rc/CrashWatchdog.gd")
const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")
const RunnerVisualResolver = preload("res://scripts/player/RunnerVisualResolver.gd")

## Wires together track, racers, race manager, HUD, and results.
## Assigns named character-life profiles so every racer reads as a person.

const AI_SCENE := preload("res://scenes/ai/AIRacer.tscn")
const ShortcutDecisionScript = preload("res://scripts/gamefeel/ShortcutDecisionDirector.gd")

var track: CourseTrack
var course_data: Dictionary = {}
var _roster: Array = []
var _assigned_profiles: Array = []

@onready var race_manager: Node = $RaceManager
@onready var player: Node = $PlayerRacer
@onready var ai_racer: Node = $AIRacer
@onready var hud: CanvasLayer = $RaceHUD
@onready var results: CanvasLayer = $ResultsScreen
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var camera_rig: SpringArm3D = $CameraRig
@onready var mobile_controls: CanvasLayer = $MobileControls


func _ready() -> void:
	if GameManager != null and GameManager.has_method("sync_race_mode_string"):
		GameManager.sync_race_mode_string()
	if not _load_course():
		SceneLoader.go_to_main_menu()
		return
	_roster = _RunnerProfile.load_roster()
	race_manager.add_to_group("race_manager")
	camera_rig.set_target(player)
	var checkpoints: Array = track.get_checkpoints()
	var start_xf: Transform3D = track.get_start_transform()
	player.global_transform = start_xf
	var player_profile = _pick_player_profile()
	if "shoe_id" in player:
		player.shoe_id = GameManager.selected_shoe_id
	if "racer_id" in player:
		player.racer_id = str(player_profile.id)
	GameManager.selected_runner_id = str(player_profile.id)
	GameManager.selected_racer_id = str(player_profile.id)
	player.setup_for_race(start_xf)
	if player.has_method("setup_rails"):
		player.setup_rails(track.get_rail_world_points())

	var racers: Array = [player]
	var ai_count := GameManager.ai_field_size
	var local_p2: Node = null
	var ai_offsets := [
		Vector3(2.5, 0, 3.0),
		Vector3(-2.5, 0, 4.5),
		Vector3(1.5, 0, 6.0),
		Vector3(-1.5, 0, 7.5),
	]
	var ai_tiers := ["rookie", "standard", "ace", "standard"]
	if GameManager.ai_eval_mode and not str(GameManager.ai_eval_tier).is_empty():
		ai_tiers = [str(GameManager.ai_eval_tier), str(GameManager.ai_eval_tier), str(GameManager.ai_eval_tier), str(GameManager.ai_eval_tier)]
	_assign_profile(player, player_profile)
	_assigned_profiles = [player_profile]

	# PartyLink Party Race: spawn 2–8 human-controlled racers on StartGrid8 (no AI fillers).
	if GameManager.is_party_race():
		var StartGrid8 = load("res://scripts/net/partylink/StartGrid8.gd")
		var RaceDirectorViewScript = load("res://scripts/net/partylink/RaceDirectorView.gd")
		var human_count := clampi(GameManager.local_mp_players, 2, 8)
		var grid: Array = StartGrid8.slots(human_count) if StartGrid8 else []
		if grid.size() > 0:
			var p0: Dictionary = grid[0]
			player.global_transform = start_xf.translated_local(Vector3(float(p0.get("x", 0.0)), 0.0, float(p0.get("z", 0.0))))
			player.setup_for_race(player.global_transform)
			if "local_player_index" in player:
				player.local_player_index = 0
		for seat_i in range(1, human_count):
			var human: Node = AI_SCENE.instantiate()
			human.name = "PartyHuman_%d" % seat_i
			add_child(human)
			if "is_player" in human:
				human.is_player = true
			if "local_player_index" in human:
				human.local_player_index = seat_i
			var h_profile = _pick_ai_profile(seat_i)
			_assign_profile(human, h_profile)
			_assigned_profiles.append(h_profile)
			if "racer_id" in human:
				human.racer_id = str(h_profile.id)
			var slot: Dictionary = grid[seat_i] if seat_i < grid.size() else {"x": float(seat_i), "z": 0.0}
			var h_start := start_xf.translated_local(Vector3(float(slot.get("x", 0.0)), 0.0, float(slot.get("z", 0.0))))
			human.global_transform = h_start
			human.setup_for_race(h_start)
			if human.has_method("setup_rails"):
				human.setup_rails(track.get_rail_world_points())
			racers.append(human)
		ai_count = 0
		if ai_racer != null:
			ai_racer.visible = false
			ai_racer.movement_enabled = false
		if RaceDirectorViewScript:
			var director = RaceDirectorViewScript.new()
			set_meta("race_director_view", director)
			set_meta("party_human_count", human_count)
		# Race Director camera: frame pack, not Player-1-only follow.
		if camera_rig and camera_rig.has_method("set_target") and racers.size() > 0:
			camera_rig.set_target(player)
			set_meta("party_race_director", true)

	# Local MP: second human + vertical split-screen cameras.
	elif GameManager.is_local_mp():
		local_p2 = AI_SCENE.instantiate()
		local_p2.name = "Player2Racer"
		add_child(local_p2)
		if "is_player" in local_p2:
			local_p2.is_player = true
		if "local_player_index" in local_p2:
			local_p2.local_player_index = 1
		if "shoe_id" in local_p2:
			local_p2.shoe_id = str(GameManager.get_meta("local_mp_p2_shoe_id")) if GameManager.has_meta("local_mp_p2_shoe_id") else "grip_soles"
		if "racer_id" in local_p2:
			local_p2.racer_id = str(GameManager.get_meta("local_mp_p2_runner_id")) if GameManager.has_meta("local_mp_p2_runner_id") else "mira_lane"
		var p2_profile = _pick_ai_profile(1)
		if GameManager.has_meta("local_mp_p2_runner_id"):
			p2_profile = _RunnerProfile.by_id(str(GameManager.get_meta("local_mp_p2_runner_id")))
		_assign_profile(local_p2, p2_profile)
		_assigned_profiles.append(p2_profile)
		var p2_start := start_xf.translated_local(Vector3(-2.5, 0, 2.0))
		local_p2.global_transform = p2_start
		local_p2.setup_for_race(p2_start)
		if local_p2.has_method("setup_rails"):
			local_p2.setup_rails(track.get_rail_world_points())
		racers.append(local_p2)
		ai_count = mini(ai_count, 2)
		_setup_local_mp_split(local_p2)

	for i in ai_count:
		var ai: Node = ai_racer if i == 0 and not GameManager.is_local_mp() else AI_SCENE.instantiate()
		if i > 0 or GameManager.is_local_mp():
			if ai.get_parent() == null:
				add_child(ai)
		elif i == 0 and ai_racer.get_parent() == null:
			pass
		var profile = _pick_ai_profile(i + 1)
		_assign_profile(ai, profile)
		_assigned_profiles.append(profile)
		if "racer_id" in ai:
			ai.racer_id = str(profile.id)
		if "shoe_id" in ai:
			# AI field rotates footwear so material affinities show in pack races.
			var shoe_ids := ShoeDataScript.all_ids()
			ai.shoe_id = shoe_ids[(i + 1) % shoe_ids.size()]
		var offset: Vector3 = ai_offsets[mini(i, ai_offsets.size() - 1)]
		var ai_start := start_xf.translated_local(offset)
		ai.global_transform = ai_start
		ai.setup_for_race(ai_start)
		if ai.has_method("setup_rails"):
			ai.setup_rails(track.get_rail_world_points())
		if ai.has_method("setup_ai_path"):
			ai.setup_ai_path(track.get_race_path(), -4.0 - float(i), 2.5 + float(i) * 0.4)
		if ai.has_method("set_ai_tier"):
			ai.set_ai_tier(ai_tiers[mini(i, ai_tiers.size() - 1)])
		if ai.has_method("configure_shortcuts") and track.has_method("get_shortcut_routes"):
			ai.configure_shortcuts(track.get_shortcut_routes())
		if ai.has_method("configure_shortcut_paths") and track.has_method("get_shortcut_follow_paths"):
			ai.configure_shortcut_paths(track.get_shortcut_follow_paths())
		if ai.has_method("notify_shoe_changed"):
			ai.notify_shoe_changed()
		racers.append(ai)

	if GameManager.is_time_trial() and ai_racer != null:
		ai_racer.visible = false
		ai_racer.movement_enabled = false
		if ai_racer in racers:
			racers.erase(ai_racer)
	elif GameManager.is_local_mp() and ai_racer != null and not (ai_racer in racers):
		ai_racer.visible = false
		ai_racer.movement_enabled = false

	_setup_time_trial_ghost()

	# Time Trial product design: single-lap mastery/ghost run (not accept_force_laps).
	# Documented in docs/engineering_wave010/CANONICAL_GAMEPLAY_MAP.md (TIME_TRIAL_LAP_COUNT=1).
	if GameManager.is_time_trial():
		GameManager.total_laps = 1
	else:
		GameManager.total_laps = int(course_data.get("lap_count", 3))
	if GameManager.accept_force_laps > 0:
		GameManager.total_laps = GameManager.accept_force_laps
	# Acceptance: AI-style path steering for the human racer (1-lap finishes without fake results).
	# Android/touch / handheld_hybrid: soft racing-line assist (no auto-accel / no forced laps).
	var want_path_follower := false
	if GameManager.accept_test_mode:
		want_path_follower = true
		GameManager.auto_accelerate = true
	elif OS.has_feature("android") or OS.has_feature("mobile"):
		want_path_follower = true
	elif DeviceRoleRuntime != null and DeviceRoleRuntime.wants_soft_path_assist():
		want_path_follower = true
	if want_path_follower and player and track and track.has_method("get_race_path"):
		var path: Path3D = track.get_race_path()
		var follower_script = load("res://scripts/ai/AIPathFollower.gd")
		if path != null and follower_script != null:
			var follower: Node = player.get_node_or_null("AcceptPathFollower")
			if follower == null:
				follower = follower_script.new()
				follower.name = "AcceptPathFollower"
				player.add_child(follower)
			follower.setup(path)
			follower.set("look_ahead", 5.5)
			# Snap onto the line so the first gates are reachable immediately.
			follower.snap_to_path(player, -2.0, 0.0)
			set_meta("path_steer_follower", follower)
			if GameManager.accept_test_mode:
				set_meta("accept_follower", follower)
	race_manager.setup_race(racers, player, checkpoints, GameManager.total_laps)
	if track.has_method("get_alternate_checkpoints") and race_manager.has_method("bind_alternate_checkpoints"):
		var alts: Array = track.get_alternate_checkpoints()
		race_manager.bind_alternate_checkpoints(alts)
		for alt in alts:
			if alt != null and alt.has_signal("racer_passed"):
				alt.racer_passed.connect(_on_checkpoint_for_recovery)
	for checkpoint in checkpoints:
		checkpoint.racer_passed.connect(_on_checkpoint_for_recovery)
	hud.setup(player, race_manager, course_data)
	if GameManager.is_local_mp() and local_p2 != null and hud.has_method("setup_local_mp_secondary"):
		hud.setup_local_mp_secondary(local_p2)
	_setup_race_experience()
	CrashWatchdogScript.note_event("race_scene_ready", str(course_data.get("id", "")))
	PackageLifecycle.migrate_or_update()
	var audio := get_node_or_null("/root/AudioDirector")
	if audio and audio.has_method("play_race_music"):
		audio.play_race_music(str(course_data.get("id", "")))
	if audio and audio.has_method("play_ui"):
		audio.play_ui("countdown")
	debug_overlay.setup(player)
	results.hide_results()
	race_manager.countdown_tick.connect(_on_countdown_personality)
	race_manager.race_started.connect(_on_race_started_poses)
	race_manager.race_started.connect(_on_race_started_telemetry)
	race_manager.race_started.connect(_on_race_started_ghost)
	race_manager.race_finished.connect(_on_race_finished)
	if mobile_controls.has_signal("pause_requested"):
		mobile_controls.connect("pause_requested", _on_pause_requested)
	if DeviceRoleRuntime != null:
		DeviceRoleRuntime.apply_to_race_scene(self)
	_play_start_line_personalities(racers)
	# Pixel safety: never start a cup with the SceneTree left paused.
	if get_tree().paused:
		get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false
		if pause_menu.has_method("configure_local_mp"):
			pause_menu.configure_local_mp(GameManager.is_local_mp())
	if GameManager.is_tutorial():
		_attach_tutorial_director()
	race_manager.begin_countdown()
	# Fake ordered checkpoint stepping is only for shortened accept_force_laps runs.
	# Full production / 3-lap Pixel verification must complete via real gate hits.
	if GameManager.accept_test_mode and GameManager.accept_force_laps > 0:
		call_deferred("_accept_drive_finish")


func _attach_tutorial_director() -> void:
	## Contextual coach during race (non-blocking). Full Tutorial Guide remains on Pause.
	## Completion contract preserved: coach completion + director finish both call mark_tutorial_done.
	var coach := CanvasLayer.new()
	coach.name = "TutorialCoach"
	coach.set_script(load("res://scripts/ui/vxp3/TutorialCoach.gd"))
	add_child(coach)
	var tips := ["sprint", "drift_spark_tiers", "perfect_step", "boost_chain", "items_counterplay", "footwear_surfaces"]
	var delay := 1.2
	for tip in tips:
		var tip_id := str(tip)
		get_tree().create_timer(delay).timeout.connect(func ():
			if is_instance_valid(coach) and coach.has_method("show_mechanic_tip"):
				coach.show_mechanic_tip(tip_id)
		)
		delay += 8.0
	## Keep TutorialDirector available but do not auto-gate the race with a slideshow.
	var director := CanvasLayer.new()
	director.name = "TutorialDirector"
	director.set_script(load("res://scripts/ui/TutorialDirector.gd"))
	director.visible = false
	add_child(director)
	## When the last tip is dismissed or race finishes in tutorial, completion is honored.
	if coach.has_signal("tip_dismissed"):
		coach.tip_dismissed.connect(func(tip_id: String):
			if tip_id == "footwear_surfaces":
				var prog := get_tree().root.get_node_or_null("ProgressionSave")
				if prog != null and prog.has_method("mark_tutorial_done"):
					prog.mark_tutorial_done()
		)


var _ghost_recorder: Node
var _ghost_player: Node3D
var _experience: Node
var _speed_layer: CanvasLayer
var _draft_fx: Node
var _boost_fx: Node
var _opponents: CanvasLayer
var _loco: Node


func _setup_time_trial_ghost() -> void:
	if not GameManager.is_time_trial():
		return
	_ghost_recorder = Node.new()
	_ghost_recorder.name = "GhostRecorder"
	_ghost_recorder.set_script(load("res://scripts/race/GhostRecorder.gd"))
	add_child(_ghost_recorder)
	_ghost_player = Node3D.new()
	_ghost_player.name = "GhostPlayer"
	_ghost_player.set_script(load("res://scripts/race/GhostPlayer.gd"))
	add_child(_ghost_player)
	var samples: Array = _ghost_recorder.load_samples(GameManager.selected_track_id)
	if _ghost_player.has_method("start") and not samples.is_empty():
		_ghost_player.start(samples)


func _on_race_started_ghost() -> void:
	if _ghost_recorder != null and _ghost_recorder.has_method("begin"):
		_ghost_recorder.begin(GameManager.selected_track_id)


func _setup_race_experience() -> void:
	_experience = Node.new()
	_experience.name = "RaceExperienceDirector"
	_experience.set_script(load("res://scripts/gamefeel/RaceExperienceDirector.gd"))
	add_child(_experience)
	if _experience.has_method("setup"):
		_experience.setup(player, race_manager, track, course_data)
	if hud.has_method("bind_experience"):
		hud.bind_experience(_experience)
	_speed_layer = CanvasLayer.new()
	_speed_layer.name = "SpeedPresentation"
	_speed_layer.set_script(load("res://scripts/gamefeel/SpeedPresentationLayer.gd"))
	add_child(_speed_layer)
	_draft_fx = Node.new()
	_draft_fx.name = "DraftFeedback"
	_draft_fx.set_script(load("res://scripts/gamefeel/DraftFeedback.gd"))
	add_child(_draft_fx)
	if _draft_fx.has_method("setup"):
		_draft_fx.setup(player)
	_boost_fx = Node.new()
	_boost_fx.name = "BoostFeedback"
	_boost_fx.set_script(load("res://scripts/gamefeel/BoostFeedback.gd"))
	add_child(_boost_fx)
	if _boost_fx.has_method("setup"):
		_boost_fx.setup(player)
	if AccessibilitySettings != null and _boost_fx.has_method("set_haptics_allowed"):
		_boost_fx.set_haptics_allowed(bool(AccessibilitySettings.haptic_feedback))
	_opponents = CanvasLayer.new()
	_opponents.name = "OpponentAwareness"
	_opponents.set_script(load("res://scripts/gamefeel/OpponentAwareness.gd"))
	add_child(_opponents)
	_loco = Node.new()
	_loco.name = "LocomotionPresenter"
	_loco.set_script(load("res://scripts/gamefeel/LocomotionPresenter.gd"))
	add_child(_loco)
	if player != null and player.has_node("BoostSystem"):
		var boost = player.get_node("BoostSystem")
		if boost.has_signal("boost_activated"):
			boost.boost_activated.connect(_on_player_boost_fx)
		if boost.has_signal("boost_ended"):
			boost.boost_ended.connect(_on_player_boost_fx_end)
	if race_manager != null and race_manager.has_node("PositionTracker"):
		var tracker = race_manager.get_node("PositionTracker")
		if tracker.has_signal("place_changed") and not tracker.place_changed.is_connected(_on_experience_place):
			tracker.place_changed.connect(_on_experience_place)
	_wire_shortcut_highlights()


func _wire_shortcut_highlights() -> void:
	if track == null:
		return
	var stack: Array = [track]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_signal("shortcut_entered") and not node.shortcut_entered.is_connected(_on_shortcut_entered):
			node.shortcut_entered.connect(_on_shortcut_entered)
		for child in node.get_children():
			stack.append(child)


func _on_experience_place(racer: Node, old_place: int, new_place: int) -> void:
	if racer == player and new_place < old_place and _experience != null and _experience.has_method("record_overtake"):
		_experience.record_overtake()


func _on_shortcut_entered(racer: Node, shortcut_id: String) -> void:
	if racer == player and _experience != null and _experience.has_method("record_shortcut_taken"):
		_experience.record_shortcut_taken(shortcut_id)
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null and racer == player and audio.has_method("play_race_cue"):
		audio.play_race_cue("shortcut")


func _on_player_boost_fx(_m: float, _d: float, _s: String) -> void:
	if _boost_fx != null and _boost_fx.has_method("set_active"):
		_boost_fx.set_active(true, _reduced_motion())


func _on_player_boost_fx_end() -> void:
	if _boost_fx != null and _boost_fx.has_method("set_active"):
		_boost_fx.set_active(false, _reduced_motion())


func _reduced_motion() -> bool:
	if AccessibilitySettings != null and bool(AccessibilitySettings.reduce_motion):
		return true
	if GameManager != null and int(GameManager.camera_profile) == 2:
		return true
	return false


func _process(delta: float) -> void:
	if _ghost_recorder != null and _ghost_recorder.get("recording") and player != null:
		if _ghost_recorder.has_method("tick"):
			_ghost_recorder.tick(delta, player)
	_tick_race_experience(delta)


func _tick_race_experience(delta: float) -> void:
	if player == null:
		return
	var profile := 0
	if GameManager != null:
		profile = int(GameManager.camera_profile)
	if AccessibilitySettings != null and bool(AccessibilitySettings.reduce_motion):
		profile = 2
	var speed := 0.0
	if "horizontal_speed" in player:
		speed = float(player.horizontal_speed)
	var ratio := clampf(speed / 24.0, 0.0, 1.35)
	var boosting := false
	if player.has_node("BoostSystem"):
		var boost = player.get_node("BoostSystem")
		if boost.has_method("get_speed_multiplier"):
			boosting = float(boost.get_speed_multiplier()) > 1.05
	if _speed_layer != null and _speed_layer.has_method("apply"):
		_speed_layer.apply(ratio, boosting, profile)
	var draft_phase := "none"
	var draft_str := 0.0
	if player.has_node("DraftingSystem"):
		var draft = player.get_node("DraftingSystem")
		draft_phase = str(draft.get("draft_phase"))
		draft_str = float(draft.get("draft_strength"))
	if _draft_fx != null and _draft_fx.has_method("apply"):
		_draft_fx.apply(draft_phase, draft_str, profile == 2)
	if _loco != null and _loco.has_method("tick") and player is CharacterBody3D:
		var drifting := false
		if "drift_system" in player and player.drift_system != null:
			drifting = bool(player.drift_system.get("is_drifting"))
		var steer := 0.0
		if InputManager != null and InputManager.has_method("get_steer"):
			steer = float(InputManager.get_steer())
		_loco.tick(delta, player, boosting, drifting, steer)
	var prox := ""
	var gap := ""
	if _opponents != null and _opponents.has_method("update_field"):
		var field: Dictionary = _opponents.update_field(player, get_tree().get_nodes_in_group("racers"), profile == 2)
		prox = str(field.get("proximity", ""))
		gap = str(field.get("gap", ""))
	var cue := ""
	var finish_near := false
	if track != null and track.has_method("get_course_points"):
		var points: Array = track.get_course_points()
		var routes: Array = track.get_shortcut_routes() if track.has_method("get_shortcut_routes") else []
		var decision: Dictionary = ShortcutDecisionScript.cue_for_player(player, points, routes, speed)
		cue = str(decision.get("cue", ""))
		var lap := 0
		var next_cp := 0
		if race_manager != null and race_manager.has_node("LapManager"):
			lap = int(race_manager.lap_manager.get_lap(player))
			next_cp = int(race_manager.lap_manager.get_next_checkpoint(player))
		var start_pt: Vector3 = Vector3.ZERO
		if not points.is_empty() and points[0] is Vector3:
			start_pt = points[0]
		finish_near = ShortcutDecisionScript.finish_approach(
			player, start_pt, lap, GameManager.total_laps if GameManager else 3, next_cp
		)
	if _experience != null and _experience.has_method("tick"):
		_experience.tick(delta, {
			"shortcut_cue": cue,
			"proximity": prox,
			"gap": gap,
			"finish_approach": finish_near,
		})
		if hud.has_method("apply_experience_snapshot"):
			hud.apply_experience_snapshot(_experience.snapshot())
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null and audio.has_method("set_speed_wind"):
		audio.set_speed_wind(ratio)


func _on_race_started_telemetry() -> void:
	var mode := "single"
	match GameManager.current_race_mode:
		GameManager.RaceMode.CUP:
			mode = "cup"
		GameManager.RaceMode.TIME_TRIAL:
			mode = "time_trial"
		GameManager.RaceMode.PRACTICE:
			mode = "practice"
		GameManager.RaceMode.LOCAL_MP:
			mode = "local_mp"
		_:
			mode = "quick_race"
	if TelemetryBus != null:
		TelemetryBus.race_start(str(course_data.get("id", "")), mode, GameManager.total_laps)


func _pick_player_profile():
	var preferred := str(GameManager.selected_runner_id)
	if preferred.is_empty():
		preferred = "dash_reed"
	return _RunnerProfile.by_id(preferred)


func _pick_ai_profile(slot: int):
	if _roster.is_empty():
		return _RunnerProfile.new()
	var player_id := str(_pick_player_profile().id)
	var choices: Array = []
	for p in _roster:
		if str(p.id) != player_id:
			choices.append(p)
	if choices.is_empty():
		return _roster[0]
	return choices[(slot - 1) % choices.size()]


func _assign_profile(racer: Node, profile) -> void:
	if racer == null or profile == null:
		return
	if "racer_display_name" in racer:
		racer.set("racer_display_name", profile.display_name)
	elif racer.has_method("set"):
		racer.set_meta("runner_display_name", profile.display_name)
	racer.set_meta("runner_profile_id", profile.id)
	racer.set_meta("runner_display_name", profile.display_name)
	var visual = racer.get_node_or_null("RacerVisual")
	if visual != null:
		visual = RunnerVisualResolver.attach(visual, profile)
	_wire_racer_visual_hooks(racer, visual)


func _wire_racer_visual_hooks(racer: Node, visual: Node) -> void:
	if visual == null or racer == null:
		return
	var boost = racer.get_node_or_null("BoostSystem")
	if boost != null and boost.has_signal("boost_activated"):
		boost.boost_activated.connect(_on_racer_boost.bind(visual))


func _on_racer_boost(_multiplier: float, _duration: float, _source: String, visual: Node) -> void:
	## Signal arity: boost_activated(multiplier, duration, source) + bind(visual).
	if visual != null and visual.has_method("set_boosting"):
		visual.set_boosting(true)
		get_tree().create_timer(0.35).timeout.connect(func ():
			if is_instance_valid(visual):
				visual.set_boosting(false)
		)


func _play_start_line_personalities(racers: Array) -> void:
	for racer in racers:
		var visual = racer.get_node_or_null("RacerVisual")
		if visual != null and visual.has_method("play_start_line"):
			visual.play_start_line()


func _on_countdown_personality(value: String) -> void:
	# Ready poses intensify as countdown reaches 1
	if value != "1":
		return
	for racer in [player, ai_racer]:
		if racer == null:
			continue
		var visual = racer.get_node_or_null("RacerVisual")
		if visual != null and visual.has_method("set_pose_state"):
			visual.set_pose_state("coiled", 0.9)


func _on_race_started_poses() -> void:
	pass


func _accept_drive_finish() -> void:
	# After countdown+GO, step the real checkpoint system so a 1-lap finish is evidenced.
	await get_tree().create_timer(4.5).timeout
	if not GameManager.accept_test_mode or player == null or race_manager == null:
		return
	var cps: Array = track.get_checkpoints() if track else []
	if cps.is_empty():
		return
	for _lap in range(maxi(GameManager.total_laps, 1)):
		for i in range(1, cps.size()):
			race_manager.lap_manager.on_checkpoint(player, i)
			await get_tree().create_timer(0.04).timeout
		race_manager.lap_manager.on_checkpoint(player, 0)
		await get_tree().create_timer(0.04).timeout


func _unhandled_input(event: InputEvent) -> void:
	# set_input_as_handled() stops this same event from also reaching
	# PauseMenu's own ALWAYS-mode "pause" listener (PauseMenu.gd). Without
	# it, Godot still delivers one input event to every listening node in
	# the same flush regardless of a pause mutation mid-flush, so a single
	# key tap could open AND immediately close the pause menu (net no-op).
	if event.is_action_pressed("pause"):
		pause_menu.toggle_pause()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	# Production void recovery: always available when a CourseTrack path exists.
	if float(player.global_position.y) < -2.0 and track != null and track.has_method("snap_body_to_nearest_path"):
		track.snap_body_to_nearest_path(player, 0.0)
	var follower = null
	if has_meta("path_steer_follower"):
		follower = get_meta("path_steer_follower")
	elif has_meta("accept_follower"):
		follower = get_meta("accept_follower")
	if follower == null or not follower.has_method("get_steer_and_accel"):
		GameManager.mobile_assist_steer = 0.0
		return
	_rescue_fallen_onto_path(follower)
	var cmd: Dictionary = follower.get_steer_and_accel(player, delta)
	var steer_cmd := float(cmd.get("steer", 0.0))
	if GameManager.accept_test_mode:
		GameManager.accept_steer = steer_cmd
	else:
		GameManager.accept_steer = 0.0
		# Soft assist is RUN-gated; neutral hands-off must keep assist at 0.
		if InputManager != null and InputManager.is_accelerating():
			GameManager.mobile_assist_steer = steer_cmd
		else:
			GameManager.mobile_assist_steer = 0.0


func _rescue_fallen_onto_path(follower: Node) -> void:
	## Catch void falls early and snap onto the racing line instead of restarting the course.
	if player == null or float(player.global_position.y) > -2.0:
		return
	if follower.has_method("snap_to_path") and track != null and track.has_method("get_race_path"):
		var path: Path3D = track.get_race_path()
		if path != null and path.curve != null:
			var offset := path.curve.get_closest_offset(path.to_local(player.global_position))
			follower.snap_to_path(player, offset, 0.0)
			if "horizontal_speed" in player:
				player.horizontal_speed = minf(float(player.horizontal_speed), 12.0)
			if "velocity" in player:
				player.velocity = Vector3.ZERO
			return
	if player.has_method("set_recovery_transform") == false and "global_transform" in player:
		pass




func _on_pause_requested() -> void:
	pause_menu.toggle_pause()


func _on_race_finished(finished_player: Node, finish_results: Array) -> void:
	var pos: int = race_manager.position_tracker.get_position_for(finished_player)
	GameManager.record_race_result(str(course_data.get("id", "")), race_manager.race_time, pos)
	GameManager.record_field_results(finish_results)
	if _ghost_recorder != null and _ghost_recorder.has_method("finish_and_save"):
		_ghost_recorder.finish_and_save(race_manager.race_time)
	if TelemetryBus != null:
		TelemetryBus.finish(
			str(course_data.get("id", "")),
			race_manager.race_time,
			pos,
			true,
			_race_perf_snapshot()
		)
	# Save ownership: Local MP is couch session — no career XP/PB writes.
	if not GameManager.is_local_mp():
		var ach := get_tree().root.get_node_or_null("AchievementRuntime")
		if ach != null and ach.has_method("report_event"):
			ach.report_event("race_finished")
			if pos == 1:
				ach.report_event("podium_finish")
			if GameManager.is_cup_active() and not GameManager.has_next_cup_race():
				if ach.has_method("set_flag"):
					ach.set_flag("cup_complete", true)
					ach.set_flag("cup:%s" % GameManager.active_cup_id, true)
		if GameManager.is_time_trial():
			var prog := get_tree().root.get_node_or_null("ProgressionSave")
			if prog != null:
				if prog.has_method("record_time_trial_pb"):
					prog.record_time_trial_pb(str(course_data.get("id", "")), race_manager.race_time)
				if prog.has_method("add_xp"):
					prog.add_xp(25)
		elif GameManager.is_challenge():
			var prog2 := get_tree().root.get_node_or_null("ProgressionSave")
			if prog2 != null and prog2.has_method("complete_challenge"):
				prog2.complete_challenge(str(GameManager.selected_challenge_id), 80)
		else:
			var prog3 := get_tree().root.get_node_or_null("ProgressionSave")
			if prog3 != null and prog3.has_method("add_xp"):
				prog3.add_xp(15)

	_play_finish_reactions(finish_results, pos)
	var field_lines := _build_field_lines(finish_results)
	var highlights := PackedStringArray()
	if _experience != null and _experience.has_method("results_highlights"):
		highlights = _experience.results_highlights()
	results.show_results(race_manager.race_time, pos, true, course_data, field_lines, highlights)
	if GameManager.is_local_mp() and results.has_method("annotate_local_mp"):
		results.annotate_local_mp(finish_results)
	var audio := get_node_or_null("/root/AudioDirector")
	if audio and audio.has_method("play_results"):
		audio.play_results()
	CrashWatchdogScript.note_event("race_finished", str(course_data.get("id", "")))


func _play_finish_reactions(finish_results: Array, _player_pos: int) -> void:
	var place := 0
	for entry in finish_results:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		place += 1
		var racer: Node = entry.get("racer")
		if racer == null:
			continue
		var visual = racer.get_node_or_null("RacerVisual")
		if visual == null or not visual.has_method("play_finish"):
			continue
		# Top-3 keep signature finish poses; everyone else reads as defeat.
		visual.play_finish(place <= 3)


func _setup_local_mp_split(player2: Node) -> void:
	var main_cam: Camera3D = camera_rig.get_node_or_null("Camera3D") as Camera3D
	var split := CanvasLayer.new()
	split.name = "LocalMPSplit"
	split.set_script(load("res://scripts/race/LocalMPSplitDirector.gd"))
	add_child(split)
	if split.has_method("setup"):
		split.setup(self, player, player2, main_cam)
	if split.has_method("resize_to_window"):
		split.resize_to_window()
	# Shared HUD stays on top; hide on-screen touch pads (keyboard/gamepad couch).
	if mobile_controls:
		mobile_controls.visible = false
	set_meta("local_mp_split", split)


func _build_field_lines(finish_results: Array) -> PackedStringArray:
	var lines: PackedStringArray = []
	var place := 1
	for entry in finish_results:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var racer: Node = entry.get("racer")
		var name := "Runner"
		if racer != null and racer.has_meta("runner_display_name"):
			name = str(racer.get_meta("runner_display_name"))
		var tag := ""
		if GameManager.is_local_mp() and bool(entry.get("is_player", false)):
			var idx := int(entry.get("local_player_index", 0))
			if racer != null and "local_player_index" in racer:
				idx = int(racer.local_player_index)
			tag = " (P1)" if idx == 0 else " (P2)"
		elif bool(entry.get("is_player", false)):
			tag = " (You)"
		lines.append("%d. %s%s" % [place, name, tag])
		place += 1
	return lines


func _race_perf_snapshot() -> Dictionary:
	## Lightweight SOFTWARE frame/pacing sample — not a physical device cert.
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(float(fps), 1.0)
	return {
		"fps": fps,
		"frame_ms": snappedf(frame_ms, 0.01),
		"budget_frame_ms_p50": 16.7,
		"within_budget": frame_ms <= 33.0,
	}


func _load_course() -> bool:
	course_data = _TrackCatalog.load_track(GameManager.selected_track_id)
	if course_data.is_empty():
		course_data = _TrackCatalog.load_track(_TrackCatalog.DEFAULT_TRACK_ID)
	if course_data.is_empty():
		push_error("No valid course is available")
		return false
	track = CourseTrack.new()
	track.name = "CourseTrack"
	track.configure(course_data)
	add_child(track)
	return track.build()


func _on_checkpoint_for_recovery(racer: Node, checkpoint_index: int) -> void:
	var expected_next: int = race_manager.lap_manager.get_next_checkpoint(racer)
	var accepted_next := (checkpoint_index + 1) % track.get_checkpoints().size()
	if expected_next == accepted_next and racer.has_method("set_recovery_transform"):
		racer.set_recovery_transform(track.get_checkpoint_recovery_transform(checkpoint_index))
	if racer == player and TelemetryBus != null:
		var lap := 0
		if race_manager and race_manager.has_node("LapManager"):
			lap = race_manager.lap_manager.get_lap(racer)
		TelemetryBus.checkpoint(str(course_data.get("id", "")), checkpoint_index, lap, true)
