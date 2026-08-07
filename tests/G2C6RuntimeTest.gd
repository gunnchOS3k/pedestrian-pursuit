extends SceneTree

## Headless G2-C6 smoke: device roles, accessibility markers, telemetry events.
## Instantiates runtimes directly so --script mode does not depend on autoload globals.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var roles = preload("res://scripts/core/DeviceRoleRuntime.gd").new()
	var a11y = preload("res://scripts/core/AccessibilitySettings.gd").new()
	var telemetry = preload("res://scripts/core/TelemetryBus.gd").new()
	var gm = preload("res://scripts/core/GameManager.gd").new()
	get_root().add_child(gm)
	get_root().add_child(roles)
	get_root().add_child(a11y)
	get_root().add_child(telemetry)
	# Ensure catalog load + defaults even if _ready order differs.
	if roles.has_method("set_role"):
		roles.set_role("student_14_5", false)
	_test_device_roles(roles, failures)
	_test_accessibility(a11y, failures)
	_test_telemetry(telemetry, failures)
	_test_restart_helper(gm, failures)
	if failures.is_empty():
		print("G2-C6 product-depth Godot smoke passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_device_roles(roles: Node, failures: PackedStringArray) -> void:
	var ids: PackedStringArray = roles.get_role_ids()
	if ids.size() != 4:
		failures.append("expected 4 device roles, got %d" % ids.size())
	for role_id in ["student_14_5", "handheld_hybrid", "ds_xl_coder", "edge_io_rings"]:
		if not roles.set_role(role_id, false):
			failures.append("failed to set role %s" % role_id)
			continue
		var gps := str(roles.get_gps_mode()).to_upper()
		if gps != "SIMULATED" and gps != "NONE":
			failures.append("role %s has non-simulated gps %s" % [role_id, gps])
		if roles.uses_live_gps():
			failures.append("role %s enabled live GPS" % role_id)
	roles.set_role("handheld_hybrid", false)
	if roles.get_input_default() != "touch":
		failures.append("handheld_hybrid should default to touch")
	if not roles.wants_touch_controls():
		failures.append("handheld_hybrid should want touch controls")
	if not roles.wants_soft_path_assist():
		failures.append("handheld_hybrid should enable soft path assist")
	roles.set_role("student_14_5", false)
	if roles.wants_soft_path_assist():
		failures.append("student_14_5 should not force soft path assist")


func _test_accessibility(a11y: Node, failures: PackedStringArray) -> void:
	a11y.set_colorblind_safe_hud(false)
	var def_player: Color = a11y.get_marker_color("player")
	a11y.set_colorblind_safe_hud(true)
	var cb_player: Color = a11y.get_marker_color("player")
	if def_player.is_equal_approx(cb_player):
		failures.append("colorblind markers should differ from default")
	a11y.set_larger_ui(true)
	if a11y.get_ui_scale_multiplier() < 1.2:
		failures.append("larger UI should increase scale")
	a11y.set_reduce_motion(true)
	if a11y.camera_shake_allowed():
		failures.append("reduce motion should disable camera shake")
	a11y.set_reduce_motion(false)
	if not a11y.camera_shake_allowed():
		failures.append("clearing reduce motion should restore camera shake")
	a11y.set_larger_ui(false)
	a11y.set_colorblind_safe_hud(false)


func _test_telemetry(telemetry: Node, failures: PackedStringArray) -> void:
	var before: int = telemetry.get_event_count()
	telemetry.race_start("verdant_cascade_circuit", "single", 3)
	telemetry.checkpoint("verdant_cascade_circuit", 1, 0, true)
	telemetry.item_use("turbo_toes", "verdant_cascade_circuit")
	telemetry.finish("verdant_cascade_circuit", 42.5, 2, true)
	telemetry.restart("verdant_cascade_circuit", "rematch")
	if telemetry.get_event_count() < before + 5:
		failures.append("telemetry did not record expected events")


func _test_restart_helper(gm: Node, failures: PackedStringArray) -> void:
	gm.start_single_race("verdant_cascade_circuit")
	gm.last_race_finished = true
	gm.last_race_time = 99.0
	gm.prepare_race_restart("unit_test")
	if gm.last_race_finished or gm.last_race_time != 0.0:
		failures.append("prepare_race_restart did not clear race stats")
