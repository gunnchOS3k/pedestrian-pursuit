extends Node3D
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _RunnerProfile = preload("res://scripts/data/RunnerProfile.gd")

## Wires together track, racers, race manager, HUD, and results.
## Assigns named character-life profiles so every racer reads as a person.

const AI_SCENE := preload("res://scenes/ai/AIRacer.tscn")

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
	if not _load_course():
		SceneLoader.go_to_main_menu()
		return
	_roster = _RunnerProfile.load_roster()
	race_manager.add_to_group("race_manager")
	camera_rig.set_target(player)
	var checkpoints: Array = track.get_checkpoints()
	var start_xf: Transform3D = track.get_start_transform()
	player.global_transform = start_xf
	player.setup_for_race(start_xf)

	var racers: Array = [player]
	var ai_offsets := [
		Vector3(2.5, 0, 3.0),
		Vector3(-2.5, 0, 4.5),
		Vector3(1.5, 0, 6.0),
	]
	_assign_profile(player, _pick_player_profile())
	_assigned_profiles = [_pick_player_profile()]
	for i in 3:
		var ai: Node = ai_racer if i == 0 else AI_SCENE.instantiate()
		var profile = _pick_ai_profile(i + 1)
		_assign_profile(ai, profile)
		_assigned_profiles.append(profile)
		if i > 0:
			add_child(ai)
		var offset: Vector3 = ai_offsets[i]
		var ai_start := start_xf.translated_local(offset)
		ai.global_transform = ai_start
		ai.setup_for_race(ai_start)
		if ai.has_method("setup_ai_path"):
			ai.setup_ai_path(track.get_race_path(), -4.0 - float(i), 2.5 + float(i) * 0.4)
		racers.append(ai)

	GameManager.total_laps = int(course_data.get("lap_count", 3))
	if GameManager.accept_force_laps > 0:
		GameManager.total_laps = GameManager.accept_force_laps
	# Acceptance: AI-style path steering for the human racer (1-lap finishes without fake results).
	if GameManager.accept_test_mode and player and track and track.has_method("get_race_path"):
		GameManager.auto_accelerate = true
		var path: Path3D = track.get_race_path()
		var follower_script = load("res://scripts/ai/AIPathFollower.gd")
		if path != null and follower_script != null:
			var follower: Node = player.get_node_or_null("AcceptPathFollower")
			if follower == null:
				follower = follower_script.new()
				follower.name = "AcceptPathFollower"
				player.add_child(follower)
			follower.setup(path)
			follower.snap_to_path(player, -2.0, 0.0)
			set_meta("accept_follower", follower)
	race_manager.setup_race(racers, player, checkpoints, GameManager.total_laps)
	for checkpoint in checkpoints:
		checkpoint.racer_passed.connect(_on_checkpoint_for_recovery)
	hud.setup(player, race_manager, course_data)
	debug_overlay.setup(player)
	results.hide_results()
	race_manager.countdown_tick.connect(_on_countdown_personality)
	race_manager.race_started.connect(_on_race_started_poses)
	race_manager.race_finished.connect(_on_race_finished)
	if mobile_controls.has_signal("pause_requested"):
		mobile_controls.connect("pause_requested", _on_pause_requested)
	_play_start_line_personalities(racers)
	# Pixel safety: never start a cup with the SceneTree left paused.
	if get_tree().paused:
		get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false
	race_manager.begin_countdown()
	if GameManager.accept_test_mode:
		call_deferred("_accept_drive_finish")


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
	if visual != null and visual.has_method("apply_profile"):
		visual.apply_profile(profile)
	_wire_racer_visual_hooks(racer, visual)


func _wire_racer_visual_hooks(racer: Node, visual: Node) -> void:
	if visual == null or racer == null:
		return
	var boost = racer.get_node_or_null("BoostSystem")
	if boost != null and boost.has_signal("boost_activated"):
		boost.boost_activated.connect(_on_racer_boost.bind(visual))


func _on_racer_boost(_multiplier: float, _duration: float, visual: Node) -> void:
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
	if event.is_action_pressed("pause"):
		pause_menu.toggle_pause()


func _physics_process(delta: float) -> void:
	if not GameManager.accept_test_mode or player == null:
		return
	if not has_meta("accept_follower"):
		return
	var follower = get_meta("accept_follower")
	if follower == null or not follower.has_method("get_steer_and_accel"):
		return
	var cmd: Dictionary = follower.get_steer_and_accel(player, delta)
	GameManager.accept_steer = float(cmd.get("steer", 0.0))


func _on_pause_requested() -> void:
	pause_menu.toggle_pause()


func _on_race_finished(finished_player: Node, finish_results: Array) -> void:
	var pos: int = race_manager.position_tracker.get_position_for(finished_player)
	GameManager.record_race_result(str(course_data.get("id", "")), race_manager.race_time, pos)
	GameManager.record_field_results(finish_results)
	_play_finish_reactions(finish_results, pos)
	var field_lines := _build_field_lines(finish_results)
	results.show_results(race_manager.race_time, pos, true, course_data, field_lines)


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
		var tag := " (You)" if bool(entry.get("is_player", false)) else ""
		lines.append("%d. %s%s" % [place, name, tag])
		place += 1
	return lines


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
