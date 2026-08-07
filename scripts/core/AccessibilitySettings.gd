extends Node

## Runtime accessibility settings (persisted). Seeds from device role defaults
## then lets the player override reduce-motion, larger UI, auto-accelerate,
## and colorblind-safe HUD markers.

signal settings_changed

const SETTINGS_PATH := "user://accessibility.cfg"

var reduce_motion: bool = false
var larger_ui: bool = false
var auto_accelerate: bool = false
var colorblind_safe_hud: bool = false

## Colorblind-safe marker palette (Okabe–Ito inspired).
const MARKER_PLAYER := Color(0.0, 0.45, 0.7) ## blue
const MARKER_CHECKPOINT := Color(0.9, 0.6, 0.0) ## orange
const MARKER_FINISH := Color(0.0, 0.62, 0.45) ## bluish green
const MARKER_HAZARD := Color(0.8, 0.4, 0.0) ## vermillion-ish
const MARKER_AI := Color(0.35, 0.7, 0.9) ## sky


func _ready() -> void:
	load_settings()
	_sync_game_manager()
	var roles := _device_roles()
	if roles != null and roles.has_signal("role_changed"):
		if not roles.role_changed.is_connected(_on_role_changed):
			roles.role_changed.connect(_on_role_changed)


func _on_role_changed(_role_id: String) -> void:
	# Fresh role only seeds auto-accelerate when the player has not overridden it.
	if not _has_saved_auto_accel():
		var roles := _device_roles()
		if roles != null:
			auto_accelerate = roles.get_auto_accelerate_default()
		_sync_game_manager()
		settings_changed.emit()


func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	_persist_and_notify()


func set_larger_ui(value: bool) -> void:
	larger_ui = value
	_persist_and_notify()


func set_auto_accelerate(value: bool) -> void:
	auto_accelerate = value
	var gm := _game_manager()
	if gm != null:
		gm.set_meta("accessibility_auto_accel_override", true)
	_sync_game_manager()
	_persist_and_notify()


func set_colorblind_safe_hud(value: bool) -> void:
	colorblind_safe_hud = value
	_persist_and_notify()


func get_ui_scale_multiplier() -> float:
	var role_scale := 1.0
	var roles := _device_roles()
	if roles != null:
		role_scale = roles.get_ui_scale()
	var a11y_scale := 1.25 if larger_ui else 1.0
	return role_scale * a11y_scale


func get_marker_color(kind: String) -> Color:
	if not colorblind_safe_hud:
		match kind:
			"player":
				return Color(0.2, 0.85, 1.0)
			"checkpoint":
				return Color(1.0, 0.85, 0.2)
			"finish":
				return Color(0.3, 1.0, 0.45)
			"hazard":
				return Color(1.0, 0.35, 0.25)
			"ai":
				return Color(1.0, 0.55, 0.35)
			_:
				return Color.WHITE
	match kind:
		"player":
			return MARKER_PLAYER
		"checkpoint":
			return MARKER_CHECKPOINT
		"finish":
			return MARKER_FINISH
		"hazard":
			return MARKER_HAZARD
		"ai":
			return MARKER_AI
		_:
			return Color.WHITE


func camera_shake_allowed() -> bool:
	if reduce_motion:
		return false
	var gm := _game_manager()
	if gm == null:
		return false
	return bool(gm.camera_shake_enabled)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		var roles := _device_roles()
		if roles != null:
			auto_accelerate = roles.get_auto_accelerate_default()
		return
	reduce_motion = bool(cfg.get_value("a11y", "reduce_motion", false))
	larger_ui = bool(cfg.get_value("a11y", "larger_ui", false))
	auto_accelerate = bool(cfg.get_value("a11y", "auto_accelerate", false))
	colorblind_safe_hud = bool(cfg.get_value("a11y", "colorblind_safe_hud", false))
	var gm := _game_manager()
	if gm != null and cfg.has_section_key("a11y", "auto_accelerate"):
		gm.set_meta("accessibility_auto_accel_override", true)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("a11y", "reduce_motion", reduce_motion)
	cfg.set_value("a11y", "larger_ui", larger_ui)
	cfg.set_value("a11y", "auto_accelerate", auto_accelerate)
	cfg.set_value("a11y", "colorblind_safe_hud", colorblind_safe_hud)
	cfg.save(SETTINGS_PATH)


func _has_saved_auto_accel() -> bool:
	var gm := _game_manager()
	return gm != null and gm.has_meta("accessibility_auto_accel_override")


func _sync_game_manager() -> void:
	var gm := _game_manager()
	if gm == null:
		return
	gm.auto_accelerate = auto_accelerate
	# Reduce-motion owns shake while enabled; restoring clears the freeze.
	gm.camera_shake_enabled = not reduce_motion


func _persist_and_notify() -> void:
	save_settings()
	_sync_game_manager()
	settings_changed.emit()


func _game_manager() -> Node:
	return _root_node("GameManager")


func _device_roles() -> Node:
	return _root_node("DeviceRoleRuntime")


func _root_node(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(node_name)