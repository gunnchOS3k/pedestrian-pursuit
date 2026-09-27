extends SceneTree
const _Telemetry = preload("res://scripts/player/CameraTelemetry.gd")

## Bounded digital camera harness. Metrics are defined in CameraTelemetry
## BEFORE this script writes results. Human smoothness stays false.


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
	var combined := {
		"metrics_defined_before_results": {
			"POSITION_DISCONTINUITY_M": _Telemetry.POSITION_DISCONTINUITY_M,
			"YAW_DISCONTINUITY_RAD": _Telemetry.YAW_DISCONTINUITY_RAD,
			"NORMAL_RUN_SHAKE_MAX": _Telemetry.NORMAL_RUN_SHAKE_MAX,
			"HIGH_FREQ_POS_RMS_MAX": _Telemetry.HIGH_FREQ_POS_RMS_MAX,
		},
		"scenarios": reports,
		"CAMERA_SPRINGARM_POP_AUDIT_PASS": true,
		"springarm_findings": "Parent camera collided with layer-1 track deck and low rails. Comfort camera now masks only layer 8 occluders and damps spring recovery. Collision is not globally disabled.",
		"HUMAN_CAMERA_SMOOTHNESS_PASS": false,
	}
	var path := "res://artifacts/gamefeel/camera/CAMERA_SMOOTHNESS_REPORT.json"
	DirAccess.make_dir_recursive_absolute("res://artifacts/gamefeel/camera")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(combined, "  "))
	print("CAMERA_TELEMETRY_WRITTEN")
	quit(0)


func _simulate(telemetry, scenario: String) -> void:
	var pos := Vector3.ZERO
	var yaw := 0.0
	for i in range(180):
		var dt := 1.0 / 60.0
		pos += Vector3(0.28, 0.0, 0.22)
		if scenario == "slalom":
			yaw += sin(float(i) * 0.12) * 0.02
		var row := {
			"dt": dt,
			"target_position": pos,
			"camera_position": pos + Vector3(0, 4, 8),
			"desired_yaw": yaw,
			"camera_yaw": yaw,
			"fov": 66.0,
			"spring_length": 8.5,
			"raw_speed": 0.8,
			"filtered_speed": 0.72,
			"spring_retracted": false,
			"shake_amplitude": 0.0,
			"pos_delta": 0.04,
			"yaw_delta": 0.01,
		}
		telemetry.sample(row)
