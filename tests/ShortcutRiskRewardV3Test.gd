extends SceneTree
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _Geo = preload("res://scripts/tracks/ShortcutGeometry.gd")
const _Identity = preload("res://scripts/gamefeel/CourseIdentityCatalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var rows: Array = []
	var always_free := 0
	var always_worse := 0
	for track_id in _Identity.LAUNCH_TRACKS:
		var data := _TrackCatalog.load_track(track_id)
		if data.is_empty():
			failures.append("%s missing" % track_id)
			continue
		var routes: Array = data.get("shortcut_routes", [])
		if routes.is_empty():
			failures.append("%s no shortcut" % track_id)
			continue
		var route: Dictionary = routes[0]
		var row: Dictionary = _Geo.audit_row(track_id, data, route, float(data.get("lane_width", 14.0)))
		var risk := str(route.get("risk", ""))
		var save_s := float(row.get("estimated_time_saving_s", 0.0))
		var risk_penalty := 0.18 if not risk.is_empty() else 0.0
		var expected_with_risk := maxf(save_s - risk_penalty, 0.0)
		var difficulty := _difficulty(str(data.get("difficulty", "")), risk)
		var mistake := _mistake_cost(risk)
		row["expected_time_save_s"] = save_s
		row["expected_time_save_with_risk_s"] = expected_with_risk
		row["execution_difficulty"] = difficulty
		row["mistake_cost"] = mistake
		row["surface_turn_challenge"] = risk if not risk.is_empty() else "clean"
		row["ai_use"] = float(route.get("ai_preference", 0.35))
		row["rejoin_safety"] = "open_exit" if bool(row.get("mobile_reachability", false)) else "tight"
		row["mandatory_no_risk"] = risk.is_empty() and save_s > 1.5
		row["always_slower"] = save_s <= 0.0
		row["HUMAN_FUN_GATE"] = false
		if bool(row["mandatory_no_risk"]):
			always_free += 1
			failures.append("%s is always better with no risk" % track_id)
		if bool(row["always_slower"]):
			always_worse += 1
			failures.append("%s is always slower" % track_id)
		rows.append(row)
	var report := {
		"schema": "pp_shortcut_risk_reward/v3",
		"generated_at": Time.get_datetime_string_from_system(true, true),
		"note": "Digital geometry estimate only. Do not claim perfect balance from one simulated run.",
		"courses": rows,
		"count": rows.size(),
		"mandatory_no_risk_count": always_free,
		"always_slower_count": always_worse,
		"HUMAN_SHORTCUT_FUN_PASS": false,
		"OWNER_SHORTCUT_FUN_PASS": false,
	}
	DirAccess.make_dir_recursive_absolute("res://artifacts/gamefeel/shortcuts")
	var file := FileAccess.open("res://artifacts/gamefeel/shortcuts/SHORTCUT_RISK_REWARD_V3.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
	if failures.is_empty() and rows.size() == 8:
		print("SHORTCUT_RISK_REWARD_PASS=8/8")
		print("SHORTCUT_DECISION_FLOW_PASS=8/8")
		print("OWNER_SHORTCUT_FUN_PASS=false")
		print("ShortcutRiskRewardV3Test PASS")
		quit(0)
	else:
		for row in failures:
			push_error(row)
		print("ShortcutRiskRewardV3Test FAIL")
		quit(1)


func _difficulty(course_diff: String, risk: String) -> String:
	if risk in ["high", "narrow", "ash"]:
		return "hard"
	if course_diff in ["expert", "advanced"]:
		return "medium_plus"
	if risk.is_empty():
		return "medium"
	return "medium"


func _mistake_cost(risk: String) -> String:
	match risk:
		"high", "ash":
			return "high"
		"narrow", "wet_runoff", "mud":
			return "medium"
		_:
			return "low"
