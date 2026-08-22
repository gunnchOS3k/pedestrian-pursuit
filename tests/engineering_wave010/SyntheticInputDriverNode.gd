extends Node
## Physics-ticked Wave010 synthetic input driver (child of SceneTree root during E2E).
## Computes steer from CourseTrack path; applies InputManager/Input only.
## Never mutates player transform/velocity/checkpoints/laps.

const DriverLogic = preload("res://tests/engineering_wave010/SyntheticInputDriver.gd")

var logic = null
var player: Node3D = null
var path: Path3D = null
var active: bool = false


func _ready() -> void:
	logic = DriverLogic.new()
	set_physics_process(false)


func start(p_player: Node3D, p_path: Path3D, profile: String = "basic") -> void:
	player = p_player
	path = p_path
	logic.reset(profile)
	active = true
	# Run before PlayerController so action_press is visible to just_pressed / pressed queries.
	process_priority = -1000
	set_physics_process(true)


func stop() -> void:
	active = false
	set_physics_process(false)
	# Do not reset driver state here — callers snapshot production signals after stop.
	Input.action_release("drift")
	Input.action_release("boost")
	Input.action_release("jump")
	Input.action_release("trick")
	Input.action_release("accelerate")
	Input.action_release("brake")
	var im = null
	var tree := get_tree()
	if tree != null and tree.root != null:
		im = tree.root.get_node_or_null("InputManager")
	if im != null:
		im.set_touch_steer(0.0)
		im.set_touch_accelerate(false)


func set_profile(profile: String) -> void:
	if logic != null:
		logic.reset(profile)


func get_logic():
	return logic


func _physics_process(delta: float) -> void:
	if not active or logic == null or player == null or path == null:
		return
	# Pass physics delta so skill timing is simulation-seconds (time-scale invariant).
	logic.tick(player, path, delta)
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var gm = tree.root.get_node_or_null("GameManager")
	if gm != null:
		gm.accept_test_mode = false
		gm.accept_force_laps = 0
		gm.auto_accelerate = false
		gm.accept_steer = 0.0
		gm.mobile_assist_steer = 0.0
