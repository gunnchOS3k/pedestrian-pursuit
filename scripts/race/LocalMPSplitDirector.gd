extends CanvasLayer

## Vertical split-screen for Local MP: shared World3D, dual follow cameras, pane labels.

const _CameraRigScript = preload("res://scripts/player/CameraRig.gd")

var _p1: Node3D
var _p2: Node3D
var _rigs: Array = []
var _viewports: Array = []


func setup(world_root: Node3D, player1: Node3D, player2: Node3D, main_camera: Camera3D = null) -> void:
	layer = 0
	_p1 = player1
	_p2 = player2
	if main_camera != null:
		main_camera.current = false

	var root := Control.new()
	root.name = "SplitRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var hbox := HBoxContainer.new()
	hbox.name = "SplitRow"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 2)
	root.add_child(hbox)

	var world_3d: World3D = world_root.get_world_3d()
	_add_pane(hbox, world_3d, player1, "P1", Color(0.35, 0.75, 1.0))
	_add_pane(hbox, world_3d, player2, "P2", Color(1.0, 0.7, 0.3))


func _add_pane(parent: Control, world_3d: World3D, target: Node3D, label_text: String, accent: Color) -> void:
	var host := SubViewportContainer.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.stretch = true
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(host)

	var vp := SubViewport.new()
	vp.name = "Viewport%s" % label_text
	vp.world_3d = world_3d
	vp.handle_input_locally = false
	vp.audio_listener_enable_3d = label_text == "P1"
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(640, 720)
	host.add_child(vp)
	_viewports.append(vp)

	var rig := SpringArm3D.new()
	rig.name = "CameraRig%s" % label_text
	rig.set_script(_CameraRigScript)
	rig.spring_length = 10.0
	rig.position = Vector3(0, 4, 0)
	rig.rotation_degrees = Vector3(-30, 0, 0)
	vp.add_child(rig)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	rig.add_child(cam)
	if rig.has_method("set_target"):
		rig.set_target(target)
	_rigs.append(rig)

	var badge := Label.new()
	badge.name = "PaneLabel"
	badge.text = label_text
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", accent)
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = 12
	badge.offset_top = 10
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(badge)


func resize_to_window() -> void:
	var win := get_viewport().get_visible_rect().size
	var half_w := maxi(int(win.x * 0.5) - 1, 160)
	var h := maxi(int(win.y), 160)
	for vp in _viewports:
		if is_instance_valid(vp):
			vp.size = Vector2i(half_w, h)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		resize_to_window()
