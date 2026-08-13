extends Node

## Software dock / multi-display hooks for device roles that already define
## dual_screen_debug (DS-XL Coder). Does not invent HDMI mirroring hardware.

signal dock_state_changed(docked: bool, screen_count: int)

const SETTINGS_PATH := "user://dock_display.cfg"

var is_docked: bool = false
var screen_count: int = 1
var external_display_available: bool = false
var preferred_layout: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh()


func refresh() -> void:
	screen_count = maxi(DisplayServer.get_screen_count(), 1)
	external_display_available = screen_count > 1
	var window_mode := DisplayServer.window_get_mode()
	var fullscreenish := window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN \
		or window_mode == DisplayServer.WINDOW_MODE_MAXIMIZED
	# Docked heuristic for hybrid/classroom devices: multi-screen OR large maximized window.
	var size := DisplayServer.screen_get_size()
	var large_landscape := size.x >= 1400 and size.x > size.y
	var was := is_docked
	is_docked = external_display_available or (fullscreenish and large_landscape)
	preferred_layout = "dual_screen_debug" if is_docked else "handheld"
	if was != is_docked:
		dock_state_changed.emit(is_docked, screen_count)
	_persist()


func apply_to_device_role(profile: Dictionary) -> Dictionary:
	## Returns a shallow-augmented profile with dock-aware HUD layout hints.
	refresh()
	var out := profile.duplicate(true)
	var base_layout := str(out.get("hud_layout", ""))
	if base_layout == "dual_screen_debug":
		out["dock_display_hook"] = true
		out["docked"] = is_docked
		out["screen_count"] = screen_count
		if is_docked:
			out["hud_layout"] = "dual_screen_debug"
			out["debug_overlay_default"] = true
		else:
			# Undocked DS-XL still keeps coder HUD but marks undocked.
			out["hud_layout"] = "dual_screen_debug"
			out["docked"] = false
	elif base_layout == "handheld" and is_docked:
		# Handheld hybrid docked to classroom display → landscape classroom HUD.
		out["hud_layout"] = "landscape_classroom"
		out["show_touch_controls"] = false
		out["dock_display_hook"] = true
		out["docked"] = true
		out["screen_count"] = screen_count
	else:
		out["dock_display_hook"] = external_display_available
		out["docked"] = is_docked
		out["screen_count"] = screen_count
	return out


func status_dict() -> Dictionary:
	return {
		"docked": is_docked,
		"screen_count": screen_count,
		"external_display_available": external_display_available,
		"preferred_layout": preferred_layout,
		"display_server": DisplayServer.get_name(),
	}


func _persist() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("dock", "last_docked", is_docked)
	cfg.set_value("dock", "last_screen_count", screen_count)
	cfg.save(SETTINGS_PATH)
