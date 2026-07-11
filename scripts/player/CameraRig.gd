extends SpringArm3D

## Third-person follow camera with optional shake.

@export var follow_smoothing: float = 8.0
@export var look_ahead: float = 2.0
@export var shake_decay: float = 6.0

var _target: Node3D
var _shake_strength: float = 0.0
var _follow_offset: Vector3


func _ready() -> void:
	spring_length = 8.0
	_follow_offset = position


func set_target(target: Node3D) -> void:
	_target = target
	global_position = _target.global_position + _follow_offset


func add_shake(strength: float) -> void:
	if GameManager.camera_shake_enabled:
		_shake_strength = maxf(_shake_strength, strength)


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var desired_position := _target.global_position + _follow_offset
	global_position = global_position.lerp(
		desired_position, clampf(follow_smoothing * delta, 0.0, 1.0)
	)
	if _shake_strength > 0.0:
		global_position += (
			Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
			* _shake_strength
			* 0.15
		)
		_shake_strength = maxf(0.0, _shake_strength - shake_decay * delta)
	look_at(_target.global_position + _target.global_transform.basis.z * -look_ahead, Vector3.UP)
