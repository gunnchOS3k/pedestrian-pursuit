extends Node3D

## Visual-only ghost playback for Time Trial. Does not collide or affect physics.

var _samples: Array = []
var _elapsed: float = 0.0
var _playing: bool = false
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.2
	_mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.85, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	add_child(_mesh)
	visible = false


func start(samples: Array) -> void:
	_samples = samples.duplicate()
	_elapsed = 0.0
	_playing = not _samples.is_empty()
	visible = _playing
	if _playing:
		_apply_sample(0)


func stop() -> void:
	_playing = false
	visible = false


func _process(delta: float) -> void:
	if not _playing or _samples.is_empty():
		return
	_elapsed += delta
	var index := 0
	while index + 1 < _samples.size() and float(_samples[index + 1].get("t", 0.0)) <= _elapsed:
		index += 1
	_apply_sample(index)
	if index >= _samples.size() - 1:
		_playing = false


func _apply_sample(index: int) -> void:
	var sample: Dictionary = _samples[clampi(index, 0, _samples.size() - 1)]
	global_position = Vector3(
		float(sample.get("x", 0.0)),
		float(sample.get("y", 1.0)),
		float(sample.get("z", 0.0))
	)
	var forward := Vector3(
		float(sample.get("bx", 0.0)),
		float(sample.get("by", 0.0)),
		float(sample.get("bz", -1.0))
	)
	forward.y = 0.0
	if forward.length_squared() > 0.01:
		var look := global_position + forward.normalized() * 2.0
		look_at(look, Vector3.UP)
