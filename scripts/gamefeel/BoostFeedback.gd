extends Node
class_name BoostFeedback

## Boost is an event. Presentation starts and stops with boost state. No hold-shake.
## V4: brief HUD acknowledgements for pickups and speed lanes.

signal presentation_started
signal presentation_stopped
signal pickup_acknowledged
signal speed_lane_acknowledged

var presenting: bool = false
var _trail: MeshInstance3D
var _host: Node3D
var _haptics: bool = true
var _boost_event_active: bool = false
var _hud_flash: Label


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


func is_boost_event_active() -> bool:
	return _boost_event_active


func acknowledge_pickup() -> void:
	pickup_acknowledged.emit()
	_flash_hud("BOOST +")
	set_active(true, false)
	var tree := get_tree()
	if tree:
		tree.create_timer(0.4).timeout.connect(func():
			if not _boost_event_active:
				set_active(false, false)
		)


func acknowledge_speed_lane() -> void:
	speed_lane_acknowledged.emit()
	_flash_hud("SPEED LANE")
	set_active(true, false)


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


func mark_boost_event(active: bool) -> void:
	_boost_event_active = active
	set_active(active, false)


func _flash_hud(text: String) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	if _hud_flash != null and is_instance_valid(_hud_flash):
		_hud_flash.queue_free()
	_hud_flash = Label.new()
	_hud_flash.name = "BoostHudAck"
	_hud_flash.text = text
	_hud_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_flash.add_theme_font_size_override("font_size", 28)
	_hud_flash.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_hud_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hud_flash.offset_top = 48
	_hud_flash.offset_bottom = 88
	_hud_flash.offset_left = -120
	_hud_flash.offset_right = 120
	tree.current_scene.add_child(_hud_flash)
	tree.create_timer(0.7).timeout.connect(func():
		if is_instance_valid(_hud_flash):
			_hud_flash.queue_free()
			_hud_flash = null
	)


func _paint(reduced_motion: bool) -> void:
	if _trail == null:
		return
	var mat := _trail.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color.a = 0.55 if presenting and not reduced_motion else (0.2 if presenting else 0.0)
	_trail.visible = presenting
