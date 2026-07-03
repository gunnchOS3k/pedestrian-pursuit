extends SpringArm3D

## Third-person follow camera with optional shake.

@export var follow_smoothing: float = 8.0
@export var look_ahead: float = 2.0
@export var shake_decay: float = 6.0

var _target: Node3D
var _shake_strength: float = 0.0
var _base_position: Vector3


func _ready() -> void:
	spring_length = 8.0
	_base_position = position


func set_target(target: Node3D) -> void:
	_target = target


func add_shake(strength: float) -> void:
	if GameManager.camera_shake_enabled:
		_shake_strength = maxf(_shake_strength, strength)


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	global_position = global_position.lerp(_target.global_position, follow_smoothing * delta)
	look_at(_target.global_position + _target.global_transform.basis.z * -look_ahead, Vector3.UP)
	if _shake_strength > 0.0:
		position = _base_position + Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		) * _shake_strength * 0.15
		_shake_strength = maxf(0.0, _shake_strength - shake_decay * delta)
	else:
		position = position.lerp(_base_position, 10.0 * delta)
