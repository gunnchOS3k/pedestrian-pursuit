extends Node
class_name BoostFeedback

## Boost is an event. Presentation starts and stops with boost state. No hold-shake.

signal presentation_started
signal presentation_stopped

var presenting: bool = false
var _trail: MeshInstance3D
var _host: Node3D
var _haptics: bool = true


func setup(host: Node3D) -> void:
	_host = host
	if _trail == null and host != null:
		_trail = MeshInstance3D.new()
		_trail.name = "BoostTrail"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.28, 0.16, 3.2)
		_trail.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.75, 0.2, 0.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.15)
		_trail.material_override = mat
		_trail.position = Vector3(0.0, 0.85, 1.8)
		host.add_child(_trail)


func set_haptics_allowed(allowed: bool) -> void:
	_haptics = allowed


func set_active(active: bool, reduced_motion: bool = false) -> void:
	if active == presenting:
		_paint(reduced_motion)
		return
	presenting = active
	_paint(reduced_motion)
	if active:
		presentation_started.emit()
		if _haptics and not reduced_motion and OS.has_feature("mobile"):
			Input.vibrate_handheld(45)
	else:
		presentation_stopped.emit()


func _paint(reduced_motion: bool) -> void:
	if _trail == null:
		return
	var mat := _trail.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color.a = 0.55 if presenting and not reduced_motion else (0.2 if presenting else 0.0)
	_trail.visible = presenting
