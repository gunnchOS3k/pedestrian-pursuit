extends SceneTree

## Digitally executable full-product depth checks for Pedestrian Pursuit.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_test_special_abilities(failures)
	_test_sense_of_speed(failures)
	_test_dock_hook(failures)
	_test_input_special(failures)
	_test_telemetry_special(failures)
	_test_tutorial_save_flag(failures)
	_self_challenge_identical_specials(failures)

	if failures.is_empty():
		print("FullProductDepthTest PASS")
		print("PEDESTRIAN_FULL_PRODUCT_DEPTH_DIGITAL")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		print("FullProductDepthTest FAIL count=%d" % failures.size())
		quit(1)


func _test_special_abilities(failures: PackedStringArray) -> void:
	if not FileAccess.file_exists("res://data/mechanics/special_abilities.json"):
		failures.append("missing special_abilities.json")
		return
	var catalog := _load_json("res://data/mechanics/special_abilities.json")
	var abilities: Dictionary = catalog.get("abilities", {})
	if abilities.size() < 8:
		failures.append("special ability catalog < 8")
	var host := Node.new()
	host.name = "HostRacer"
	root.add_child(host)
	var boost := Node.new()
	boost.name = "BoostSystem"
	boost.set_script(load("res://scripts/player/BoostSystem.gd"))
	host.add_child(boost)
	var stats := Node.new()
	stats.name = "MovementStats"
	stats.set_script(load("res://scripts/player/MovementStats.gd"))
	host.add_child(stats)
	var sys := Node.new()
	sys.set_script(load("res://scripts/player/SpecialAbilitySystem.gd"))
	root.add_child(sys)
	var seen_effects := {}
	for aid in abilities.keys():
		sys.setup(host, str(aid))
		if not sys.try_activate():
			failures.append("special '%s' failed to activate" % aid)
			continue
		var effect := str((abilities[aid] as Dictionary).get("effect", ""))
		seen_effects[effect] = true
		sys._cooldown_left = 0.0
		sys._clear_active()
	if seen_effects.size() < 4:
		failures.append("special ability effect diversity too low")
	sys.free()
	host.free()


func _test_sense_of_speed(failures: PackedStringArray) -> void:
	var cam := SpringArm3D.new()
	cam.set_script(load("res://scripts/player/CameraRig.gd"))
	var cam3d := Camera3D.new()
	cam3d.name = "Camera3D"
	cam3d.fov = 65.0
	cam.add_child(cam3d)
	root.add_child(cam)
	# Manually wire camera so we do not depend on _ready timing under --script.
	cam._camera = cam3d
	cam.base_fov = 65.0
	cam.max_fov = 82.0
	cam.base_look_ahead = 2.0
	cam.max_look_ahead = 5.5
	cam.base_spring_length = 8.0
	cam.max_spring_length = 11.5
	cam._on_speed_changed(24.0)
	cam.set_boosting(true)
	cam._physics_process(0.16)
	if float(cam.look_ahead) <= float(cam.base_look_ahead) + 0.01:
		failures.append("sense-of-speed look_ahead did not respond to speed")
	if float(cam3d.fov) <= float(cam.base_fov) + 0.05:
		failures.append("sense-of-speed FOV did not respond to speed")
	cam.free()


func _test_dock_hook(failures: PackedStringArray) -> void:
	var dock := Node.new()
	dock.set_script(load("res://scripts/core/DockDisplayHook.gd"))
	root.add_child(dock)
	dock.refresh()
	var st: Dictionary = dock.status_dict()
	if not st.has("docked") or not st.has("screen_count"):
		failures.append("dock status incomplete")
	var profile := {
		"hud_layout": "dual_screen_debug",
		"debug_overlay_default": true,
		"input_hints": "coder",
	}
	var out: Dictionary = dock.apply_to_device_role(profile)
	if not bool(out.get("dock_display_hook", false)):
		failures.append("dual_screen role missing dock_display_hook")
	dock.free()


func _test_input_special(failures: PackedStringArray) -> void:
	var im := root.get_node_or_null("InputManager")
	if im == null:
		im = Node.new()
		im.name = "InputManager"
		im.set_script(load("res://scripts/core/InputManager.gd"))
		root.add_child(im)
	if not im.has_method("is_special"):
		failures.append("InputManager.is_special missing")


func _test_telemetry_special(failures: PackedStringArray) -> void:
	var bus := root.get_node_or_null("TelemetryBus")
	if bus == null:
		bus = Node.new()
		bus.name = "TelemetryBus"
		bus.set_script(load("res://scripts/core/TelemetryBus.gd"))
		root.add_child(bus)
	if not bus.has_method("special_ability"):
		failures.append("TelemetryBus.special_ability missing")
		return
	var before := int(bus.get_event_count())
	bus.special_ability("clean_lines", "dash_reed")
	if int(bus.get_event_count()) < before + 1:
		failures.append("special_ability telemetry not recorded")


func _test_tutorial_save_flag(failures: PackedStringArray) -> void:
	var prog := root.get_node_or_null("ProgressionSave")
	if prog == null:
		prog = Node.new()
		prog.name = "ProgressionSave"
		prog.set_script(load("res://scripts/core/ProgressionSave.gd"))
		root.add_child(prog)
	if not ("tutorial_completed" in prog):
		failures.append("ProgressionSave.tutorial_completed missing")
	if not prog.has_method("mark_tutorial_done"):
		failures.append("ProgressionSave.mark_tutorial_done missing")


func _self_challenge_identical_specials(failures: PackedStringArray) -> void:
	var ids := RacerData.all_launch_ids()
	var specials := {}
	var fingerprints := {}
	for rid in ids:
		var data := RacerData.load_by_id(rid)
		var sid := str(data.get("special_ability_id", ""))
		if sid.is_empty():
			failures.append("racer '%s' missing special_ability_id" % rid)
			continue
		if specials.has(sid):
			failures.append("duplicate special_ability_id '%s' on %s and %s" % [sid, specials[sid], rid])
		specials[sid] = rid
		var fp := "%s|%.1f|%.1f|%.1f|%s" % [
			sid,
			float(data.get("top_speed", 0.0)),
			float(data.get("acceleration", 0.0)),
			float(data.get("handling", 0.0)),
			str(data.get("ai_line_bias", "")),
		]
		fingerprints[fp] = rid
	if fingerprints.size() < ids.size():
		failures.append("runner fingerprints collided — identical logic risk")
	var catalog := _load_json("res://data/mechanics/special_abilities.json")
	var abilities: Dictionary = catalog.get("abilities", {})
	var effect_fps := {}
	for sid in specials.keys():
		if not abilities.has(sid):
			failures.append("catalog missing ability '%s'" % sid)
			continue
		var def: Dictionary = abilities[sid]
		var efp := "%s|%s|%.2f|%.2f|%.3f" % [
			str(def.get("effect", "")),
			str(def.get("kind", "")),
			float(def.get("cooldown_sec", 0.0)),
			float(def.get("duration_sec", 0.0)),
			float(def.get("boost_mult", def.get("handling_mult", def.get("drift_charge_mult", 0.0)))),
		]
		if effect_fps.has(efp):
			failures.append("identical special effect fingerprint for %s and %s" % [effect_fps[efp], sid])
		effect_fps[efp] = sid


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
