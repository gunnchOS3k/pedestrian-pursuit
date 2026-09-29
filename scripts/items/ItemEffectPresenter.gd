extends Node
class_name ItemEffectPresenter

## Ensures each of the six launch items has a visible world consequence.

const ITEM_FX := {
	"turbo_toes": {"label": "TURBO", "color": Color(1.0, 0.55, 0.1), "kind": "stride_streak"},
	"lace_trap": {"label": "TRAP", "color": Color(0.85, 0.2, 0.35), "kind": "lace_hazard"},
	"sole_shield": {"label": "SHIELD", "color": Color(0.35, 0.75, 1.0), "kind": "sole_shield"},
	"pulse_horn": {"label": "HORN", "color": Color(1.0, 0.85, 0.2), "kind": "cone_wave"},
	"magnet_lace": {"label": "MAGNET", "color": Color(0.7, 0.35, 1.0), "kind": "tether"},
	"bounce_bubble": {"label": "BUBBLE", "color": Color(0.45, 0.95, 0.75), "kind": "bubble"},
}


static func spawn_world_effect(parent: Node3D, item_id: String, origin: Vector3, facing: Vector3 = Vector3.FORWARD) -> Node3D:
	var spec: Dictionary = ITEM_FX.get(item_id, {})
	if spec.is_empty():
		return null
	var root := Node3D.new()
	root.name = "ItemFX_%s" % item_id
	root.position = origin
	parent.add_child(root)
	match str(spec.get("kind", "")):
		"stride_streak":
			_streak(root, spec["color"])
		"lace_hazard":
			_laces(root, spec["color"])
		"sole_shield":
			_shield(root, spec["color"])
		"cone_wave":
			_cone(root, spec["color"], facing)
		"tether":
			_tether(root, spec["color"], facing)
		"bubble":
			_bubble(root, spec["color"])
	var label := Label3D.new()
	label.text = str(spec.get("label", item_id))
	label.font_size = 48
	label.position = Vector3(0, 2.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = spec["color"]
	root.add_child(label)
	return root


static func _mat(c: Color, e: float = 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if c.a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	return m


static func _streak(root: Node3D, c: Color) -> void:
	for i in range(3):
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.2, 0.15, 1.6 + i * 0.4)
		m.mesh = b
		m.position = Vector3(0, 0.4 + i * 0.15, -0.8 - i * 0.3)
		m.material_override = _mat(c)
		root.add_child(m)


static func _laces(root: Node3D, c: Color) -> void:
	var warn := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.4
	cyl.bottom_radius = 1.4
	cyl.height = 0.15
	warn.mesh = cyl
	warn.material_override = _mat(Color(c.r, c.g, c.b, 0.7), 3.5)
	root.add_child(warn)
	for i in range(4):
		var lace := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.12, 0.08, 2.2)
		lace.mesh = b
		lace.rotation.y = float(i) * PI / 4.0
		lace.position.y = 0.2
		lace.material_override = _mat(c, 2.0)
		root.add_child(lace)


static func _shield(root: Node3D, c: Color) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.3
	s.height = 1.1
	m.mesh = s
	m.scale = Vector3(1.1, 0.55, 1.1)
	m.position.y = 0.9
	var col := c
	col.a = 0.45
	m.material_override = _mat(col, 2.0)
	root.add_child(m)


static func _cone(root: Node3D, c: Color, facing: Vector3) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 1.8
	cyl.height = 3.2
	m.mesh = cyl
	m.rotation_degrees = Vector3(90, 0, 0)
	m.position = facing.normalized() * 1.6 + Vector3(0, 0.8, 0)
	var col := c
	col.a = 0.5
	m.material_override = _mat(col, 3.0)
	root.add_child(m)


static func _tether(root: Node3D, c: Color, facing: Vector3) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.12, 0.12, 4.0)
	m.mesh = b
	m.position = facing.normalized() * 2.0 + Vector3(0, 1.0, 0)
	m.look_at(m.position + facing, Vector3.UP)
	m.material_override = _mat(c, 3.5)
	root.add_child(m)


static func _bubble(root: Node3D, c: Color) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.5
	s.height = 3.0
	m.mesh = s
	m.position.y = 1.1
	var col := c
	col.a = 0.35
	m.material_override = _mat(col, 2.2)
	root.add_child(m)
