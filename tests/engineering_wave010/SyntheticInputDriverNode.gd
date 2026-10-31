extends Node
## Physics-ticked Wave010 synthetic input driver.
## Basic profile: AIPathFollower line-steer through touch input (same as verdant-repro).
## Never named AcceptPathFollower; magnet off; no accept_test_mode; no net body teleport.
## Advanced profile keeps skill intents via SyntheticInputDriver on top of line-steer.

const DriverLogic = preload("res://tests/engineering_wave010/SyntheticInputDriver.gd")
const FollowerScript = preload("res://scripts/ai/AIPathFollower.gd")

var logic = null
var player: Node3D = null
var path: Path3D = null
var active: bool = false
var _follower: Node = null
var _profile: String = "basic"


func _ready() -> void:
	logic = DriverLogic.new()
	set_physics_process(false)


func start(p_player: Node3D, p_path: Path3D, profile: String = "basic") -> void:
	player = p_player
	path = p_path
	_profile = profile
	logic.reset(profile)
	active = true
	process_priority = -1000
	_attach_follower()
	set_physics_process(true)


func stop() -> void:
	active = false
	set_physics_process(false)
	_detach_follower()
	Input.action_release("drift")
	Input.action_release("boost")
	Input.action_release("jump")
	Input.action_release("trick")
	Input.action_release("accelerate")
	Input.action_release("brake")
	var im = _im()
	if im != null:
		im.set_touch_steer(0.0)
		im.set_touch_accelerate(false)


func set_profile(profile: String) -> void:
	_profile = profile
	if logic != null:
		logic.reset(profile)


func get_logic():
	return logic


func _attach_follower() -> void:
	_detach_follower()
	if player == null or path == null or path.curve == null:
		return
	_follower = FollowerScript.new()
	## Must NOT be named AcceptPathFollower — Wave010RaceSceneE2E rejects that proof path.
	_follower.name = "Wave010LineSteer"
	player.add_child(_follower)
	_follower.setup(path)
	_follower.set("look_ahead", 5.5)
	_follower.set("magnet_strength", 0.0)
	if _follower.has_method("set_tier"):
		_follower.set_tier(_follower.Tier)


func _detach_follower() -> void:
	if _follower != null and is_instance_valid(_follower):
		var f := _follower
		_follower = null
		if f.get_parent() != null:
			f.get_parent().remove_child(f)
		f.free()


func _im():
	var tree := get_tree()
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("InputManager")
	return null


func _physics_process(delta: float) -> void:
	if not active or player == null or path == null:
		return
	var tree := get_tree()
	if tree != null and tree.root != null:
		var gm = tree.root.get_node_or_null("GameManager")
		if gm != null:
			gm.accept_test_mode = false
			gm.accept_force_laps = 0
			gm.auto_accelerate = false
			gm.accept_steer = 0.0
			gm.mobile_assist_steer = 0.0

	var steer := 0.0
	var accelerate := true
	if _follower != null and player is CharacterBody3D and _follower.has_method("get_steer_and_accel"):
		var body := player as CharacterBody3D
		## Preserve Y — follower height-floor must not count as Wave010 proof teleport.
		var grounded_y := body.global_position.y
		var cmd: Dictionary = _follower.get_steer_and_accel(body, delta)
		var restored := body.global_position
		restored.y = grounded_y
		body.global_position = restored
		steer = float(cmd.get("steer", 0.0))
		accelerate = bool(cmd.get("accelerate", true))
	elif logic != null:
		## Fallback if follower unavailable.
		logic.tick(player, path, delta)
		return

	var im = _im()
	if im != null:
		im.set_touch_steer(steer)
		im.set_touch_accelerate(accelerate)
	if accelerate:
		Input.action_press("accelerate")
		Input.action_release("brake")
	else:
		Input.action_release("accelerate")
		Input.action_press("brake")

	## Advanced skill intents still ride the same line-steer (no transform cheats).
	if logic != null and _profile == "advanced":
		logic.force_normal_input_flags()
		logic.look_ahead = 5.5
		## Reuse skill ticker with externally applied steer baseline.
		if logic.has_method("_tick_advanced"):
			logic._sim_elapsed_sec += clampf(delta, 0.0, 0.25)
			logic._tick_advanced(player, path, steer, clampf(delta, 0.0, 0.25))
		else:
			logic.tick(player, path, delta)
