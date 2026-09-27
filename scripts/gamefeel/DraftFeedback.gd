extends Node
class_name DraftFeedback

## Compact draft presentation. Does not change draft power.

var phase: String = "none"
var strength: float = 0.0
var presenting: bool = false
var _wake: MeshInstance3D
var _host: Node3D


func setup(host: Node3D) -> void:
	_host = host
	if _wake == null and host != null:
		_wake = MeshInstance3D.new()
		_wake.name = "DraftWake"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.35, 0.12, 2.4)
		_wake.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.9, 1.0, 0.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.8, 1.0)
		_wake.material_override = mat
		_wake.position = Vector3(0.0, 0.9, 1.6)
		host.add_child(_wake)


func apply(next_phase: String, next_strength: float, reduced_motion: bool) -> void:
	phase = next_phase
	strength = clampf(next_strength, 0.0, 1.0)
	presenting = phase in ["entering", "building", "active"]
	if _wake == null:
		return
	var alpha := 0.0
	if presenting and not reduced_motion:
		alpha = 0.15 + strength * 0.45
	elif presenting:
		alpha = 0.12
	var mat := _wake.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color.a = alpha
	_wake.visible = presenting


func hud_token() -> String:
	match phase:
		"entering":
			return "DRAFT ·"
		"building":
			return "DRAFT ··"
		"active":
			return "DRAFT"
		"leaving":
			return "DRAFT ▾"
		_:
			return ""
