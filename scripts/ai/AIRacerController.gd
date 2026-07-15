extends PlayerController

## AI-controlled racer using path following.

var _ai_steer: float = 0.0
var _ai_accel: bool = true
var _ai_drift: bool = false

@onready var path_follower: Node = $AIPathFollower


func _ready() -> void:
	super._ready()
	is_player = false


func setup_ai_path(path: Path3D, start_offset: float, lane_offset: float = 0.0) -> void:
	path_follower.setup(path)
	path_follower.snap_to_path(self, start_offset, lane_offset)


func _get_steer() -> float:
	return _ai_steer


func _get_accelerate_input() -> bool:
	return _ai_accel


func _get_drift_input() -> bool:
	return _ai_drift


func _compute_target_speed() -> float:
	return super._compute_target_speed() * path_follower.speed_multiplier


func _physics_process(delta: float) -> void:
	var cmd: Dictionary = path_follower.get_steer_and_accel(self, delta)
	_ai_steer = cmd.steer
	_ai_accel = cmd.accelerate
	_ai_drift = cmd.drift
	super._physics_process(delta)
