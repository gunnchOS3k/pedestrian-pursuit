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
	var allowed := GameManager.camera_shake_enabled
	var a11y := _accessibility()
	if a11y != null and a11y.has_method("camera_shake_allowed"):
		allowed = a11y.camera_shake_allowed()
	if allowed:
		_shake_strength = maxf(_shake_strength, strength)


func _accessibility() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("AccessibilitySettings")


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
