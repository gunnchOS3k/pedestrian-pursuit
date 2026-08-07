extends Node

## G2-C6 device-role runtime. Loads SOFTWARE profiles for the four first-party
## device roles and applies input/HUD/map/GPS defaults. GPS is always simulated
## or none — never live device location.

signal role_changed(role_id: String)

const PROFILE_PATH := "res://device_ux/profiles/device_roles.json"
const SETTINGS_PATH := "user://device_role.cfg"

const ROLE_IDS: PackedStringArray = [
	"student_14_5",
	"handheld_hybrid",
	"ds_xl_coder",
	"edge_io_rings",
]

var _catalog: Dictionary = {}
var active_role_id: String = "student_14_5"
var active_profile: Dictionary = {}
var active_map_profile: Dictionary = {}


func _ready() -> void:
	_ensure_catalog()
	var saved := _load_saved_role()
	if saved.is_empty():
		saved = str(_catalog.get("default_role", "student_14_5"))
	set_role(saved, false)


func _ensure_catalog() -> void:
	if _catalog.is_empty() or not _catalog.has("roles"):
		_catalog = _load_catalog()


func get_role_ids() -> PackedStringArray:
	_ensure_catalog()
	return ROLE_IDS


func get_role_display_name(role_id: String) -> String:
	var roles: Dictionary = _catalog.get("roles", {})
	var role: Dictionary = roles.get(role_id, {})
	return str(role.get("display_name", role_id))


func get_input_default() -> String:
	return str(active_profile.get("input_default", "keyboard"))


func get_hud_layout() -> String:
	return str(active_profile.get("hud_layout", "landscape_classroom"))


func get_map_profile_id() -> String:
	return str(active_profile.get("map_profile", "sim_campus"))


func get_gps_mode() -> String:
	return str(active_profile.get("gps_mode", "SIMULATED"))


func get_input_hints() -> String:
	return str(active_profile.get("input_hints", ""))


func wants_touch_controls() -> bool:
	if bool(active_profile.get("show_touch_controls", false)):
		return true
	return get_input_default() == "touch"


func wants_debug_overlay() -> bool:
	return bool(active_profile.get("debug_overlay_default", false))


func get_ui_scale() -> float:
	return float(active_profile.get("ui_scale", 1.0))


func get_auto_accelerate_default() -> bool:
	return bool(active_profile.get("auto_accelerate_default", false))


func is_gps_simulated() -> bool:
	var mode := get_gps_mode().to_upper()
	return mode == "SIMULATED"


func uses_live_gps() -> bool:
	## PHYSICAL_EXECUTION_FREEZE: live GPS is never enabled in software runtime.
	return false


func set_role(role_id: String, persist: bool = true) -> bool:
	_ensure_catalog()
	var roles: Dictionary = _catalog.get("roles", {})
	if not roles.has(role_id):
		push_warning("Unknown device role '%s'" % role_id)
		return false
	active_role_id = role_id
	active_profile = (roles[role_id] as Dictionary).duplicate(true)
	var maps: Dictionary = _catalog.get("map_profiles", {})
	var map_id := get_map_profile_id()
	active_map_profile = (maps.get(map_id, {}) as Dictionary).duplicate(true)
	_apply_to_game_systems()
	if persist:
		_save_role(role_id)
	role_changed.emit(role_id)
	return true


func apply_to_race_scene(race_scene: Node) -> void:
	if race_scene == null:
		return
	race_scene.set_meta("device_role_id", active_role_id)
	race_scene.set_meta("map_profile_id", get_map_profile_id())
	race_scene.set_meta("gps_mode", get_gps_mode())
	race_scene.set_meta("hud_layout", get_hud_layout())
	var mobile = race_scene.get_node_or_null("MobileControls")
	if mobile != null and mobile.has_method("configure_for_device_role"):
		mobile.configure_for_device_role(active_profile)
	var hud = race_scene.get_node_or_null("RaceHUD")
	if hud != null and hud.has_method("apply_device_role"):
		hud.apply_device_role(active_profile, active_map_profile)
	var debug = race_scene.get_node_or_null("DebugOverlay")
	if debug != null:
		debug.visible = wants_debug_overlay()


func _apply_to_game_systems() -> void:
	var gm := _game_manager()
	if gm == null:
		return
	# Device role seeds defaults; AccessibilitySettings may override after load.
	if not gm.has_meta("accessibility_auto_accel_override"):
		gm.auto_accelerate = get_auto_accelerate_default()
	var inputs := _input_manager()
	if inputs != null and inputs.has_method("apply_device_role"):
		inputs.apply_device_role(active_profile)


func _game_manager() -> Node:
	return _root_node("GameManager")


func _input_manager() -> Node:
	return _root_node("InputManager")


func _root_node(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(node_name)


func _load_catalog() -> Dictionary:
	if not FileAccess.file_exists(PROFILE_PATH):
		push_error("Device role catalog missing: %s" % PROFILE_PATH)
		return _fallback_catalog()
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return _fallback_catalog()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Device role catalog is not a JSON object")
		return _fallback_catalog()
	return parsed


func _fallback_catalog() -> Dictionary:
	return {
		"default_role": "student_14_5",
		"roles": {
			"student_14_5": {
				"display_name": "Student 14.5",
				"input_default": "keyboard",
				"show_touch_controls": false,
				"hud_layout": "landscape_classroom",
				"map_profile": "sim_campus",
				"gps_mode": "SIMULATED",
				"input_hints": "Keyboard defaults",
				"auto_accelerate_default": false,
				"debug_overlay_default": false,
				"ui_scale": 1.0,
			}
		},
		"map_profiles": {
			"sim_campus": {"label": "Simulated Campus", "gps": "SIMULATED"},
		},
	}


func _save_role(role_id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("device", "role_id", role_id)
	cfg.save(SETTINGS_PATH)


func _load_saved_role() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	return str(cfg.get_value("device", "role_id", ""))
