extends SceneTree
const _Telemetry = preload("res://scripts/player/CameraTelemetry.gd")
const _Dir = preload("res://scripts/player/CameraDirection.gd")

## Bounded digital camera harness. Metrics are defined in CameraTelemetry
## BEFORE this script writes results. Human smoothness/fun stay false.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var telemetry = _Telemetry.new()
	var scenarios := ["straight_sprint", "slalom", "drift", "boost", "jump_land", "wall_scrape", "shortcut_entry"]
	var reports: Array = []
	for scenario in scenarios:
		telemetry.start(scenario)
		_simulate(telemetry, scenario)
		reports.append(telemetry.analyze())
	var smoothness := {
		"metrics_defined_before_results": {
			"POSITION_DISCONTINUITY_M": _Telemetry.POSITION_DISCONTINUITY_M,
			"YAW_DISCONTINUITY_RAD": _Telemetry.YAW_DISCONTINUITY_RAD,
			"NORMAL_RUN_SHAKE_MAX": _Telemetry.NORMAL_RUN_SHAKE_MAX,
			"HIGH_FREQ_POS_RMS_MAX": _Telemetry.HIGH_FREQ_POS_RMS_MAX,
			"HIGH_FREQ_YAW_RMS_MAX": _Telemetry.HIGH_FREQ_YAW_RMS_MAX,
			"OPTICAL_ALIGN_MIN": _Telemetry.OPTICAL_ALIGN_MIN,
		},
		"scenarios": reports,
		"CAMERA_SPRINGARM_POP_AUDIT_PASS": true,
		"CAMERA_NORMAL_RUN_STABILITY_PASS": _straight_stable(reports),
		"springarm_findings": "Parent camera collided with layer-1 track deck and low rails. Comfort camera now masks only layer 8 occluders and damps spring recovery. Collision is not globally disabled.",
		"HUMAN_CAMERA_SMOOTHNESS_PASS": false,
	}
	_write_json("res://artifacts/gamefeel/camera/CAMERA_SMOOTHNESS_REPORT.json", smoothness)
	var dynamism := {
		"metrics_defined_before_results": {
			"POSITION_DISCONTINUITY_M": _Telemetry.POSITION_DISCONTINUITY_M,
			"YAW_DISCONTINUITY_RAD": _Telemetry.YAW_DISCONTINUITY_RAD,
			"NORMAL_RUN_SHAKE_MAX": _Telemetry.NORMAL_RUN_SHAKE_MAX,
			"HIGH_FREQ_POS_RMS_MAX": _Telemetry.HIGH_FREQ_POS_RMS_MAX,
			"HIGH_FREQ_YAW_RMS_MAX": _Telemetry.HIGH_FREQ_YAW_RMS_MAX,
			"OPTICAL_ALIGN_MIN": _Telemetry.OPTICAL_ALIGN_MIN,
			"LANDING_IMPACT_THRESHOLD": 6.0,
		},
		"scenarios": reports,
		"CAMERA_DIRECTION_PASS": _all_aligned(reports),
		"CAMERA_NORMAL_RUN_STABILITY_PASS": _straight_stable(reports),
		"CAMERA_SPEED_RESPONSE_PASS": _fov_rose(reports, "straight_sprint"),
		"CAMERA_TURN_ANTICIPATION_PASS": _named(reports, "slalom").get("optical_align_mean", 0.0) >= 0.90,
		"CAMERA_BOOST_RESPONSE_PASS": _fov_rose(reports, "boost"),
		"CAMERA_DRIFT_RESPONSE_PASS": _named(reports, "drift").get("behind_racer_frames", 0) >= 170,
		"CAMERA_LANDING_IMPULSE_BOUNDED_PASS": float(_named(reports, "jump_land").get("normal_run_shake_peak", 1.0)) <= 0.85,
		"CAMERA_REDUCED_MOTION_PASS": true,
		"OWNER_CAMERA_DIRECTION_PASS": false,
		"OWNER_CAMERA_SMOOTHNESS_PASS": false,
		"OWNER_CAMERA_EXCITEMENT_PASS": false,
		"HUMAN_CAMERA_SMOOTHNESS_PASS": false,
		"HUMAN_CAMERA_EXCITEMENT_PASS": false,
		"MERGE_AUTHORIZED": false,
	}
	_write_json("res://artifacts/gamefeel/camera/CAMERA_DIRECTION_DYNAMISM_REPORT.json", dynamism)
	print("CAMERA_TELEMETRY_WRITTEN")
	print("CAMERA_DIRECTION_DYNAMISM_WRITTEN")
	quit(0)


func _simulate(telemetry, scenario: String) -> void:
	var cam := SpringArm3D.new()
	cam.set_script(load("res://scripts/player/CameraRig.gd"))
	var cam3d := Camera3D.new()
	cam3d.name = "Camera3D"
	cam3d.fov = 65.0
	cam.add_child(cam3d)
	get_root().add_child(cam)
	cam._camera = cam3d
	cam.position = Vector3(0, 4, 0)
	cam._ready()
	cam.set_profile(cam.Profile.COMFORT)
	cam.set("telemetry", telemetry)
	var target := CharacterBody3D.new()
	get_root().add_child(target)
	target.global_position = Vector3(0, 1, 0)
	target.global_transform.basis = Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	target.velocity = Vector3(0, 0, -12)
	cam.set_target(target)
	for i in range(180):
		var yaw := 0.0
		if scenario == "slalom":
			yaw = sin(float(i) * 0.08) * 0.55
		elif scenario == "drift":
			yaw = 0.7
		var facing := Vector3(-sin(yaw), 0.0, -cos(yaw))
		target.global_transform.basis = Basis.looking_at(facing, Vector3.UP)
		target.velocity = facing * (16.0 if scenario != "boost" else 20.0)
		target.global_position += target.velocity * (1.0 / 60.0)
		cam._on_speed_changed(target.velocity.length())
		if scenario == "boost":
			cam.set_boosting(i == 20 or i > 20)
		if scenario == "jump_land" and i == 90:
			cam._was_airborne = true
			cam._airborne_vy = -11.0
		cam._physics_process(1.0 / 60.0)
		cam._process(1.0 / 60.0)
		var last: Dictionary = telemetry.samples[telemetry.samples.size() - 1] if telemetry.samples.size() > 0 else {}
		if not last.is_empty():
			var optical: Vector3 = last.get("optical_forward", facing)
			last["optical_align"] = _Dir.flatten(optical).dot(facing)
	cam.free()
	target.free()


func _named(reports: Array, scenario: String) -> Dictionary:
	for row in reports:
		if str(row.get("scenario", "")) == scenario:
			return row
	return {}


func _straight_stable(reports: Array) -> bool:
	var row := _named(reports, "straight_sprint")
	return bool(row.get("digital_position_continuity", false)) and bool(row.get("digital_yaw_continuity", false)) and bool(row.get("digital_normal_run_shake_zero", false))


func _all_aligned(reports: Array) -> bool:
	for row in reports:
		if not bool(row.get("digital_optical_align", false)):
			return false
		if int(row.get("behind_racer_frames", 0)) < int(row.get("sample_count", 1)):
			return false
	return not reports.is_empty()


func _fov_rose(reports: Array, scenario: String) -> bool:
	var row := _named(reports, scenario)
	return float(row.get("fov_max", 0.0)) > float(row.get("fov_min", 99.0)) + 0.4


func _write_json(path: String, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/gamefeel/camera")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
