extends RefCounted
class_name CameraTelemetry

## Development-only camera smoothness sampler.
## Thresholds are defined here BEFORE any report is written.

const POSITION_DISCONTINUITY_M := 0.35
const YAW_DISCONTINUITY_RAD := 0.12
const NORMAL_RUN_SHAKE_MAX := 0.0
const HIGH_FREQ_POS_RMS_MAX := 0.08
const HIGH_FREQ_YAW_RMS_MAX := 0.04
const OPTICAL_ALIGN_MIN := 0.95
const MAX_SAMPLES := 2400

var samples: Array = []
var scenario: String = ""


func start(next_scenario: String) -> void:
	scenario = next_scenario
	samples.clear()


func sample(row: Dictionary) -> void:
	if samples.size() >= MAX_SAMPLES:
		return
	samples.append(row)


func analyze() -> Dictionary:
	var pos_deltas: Array = []
	var yaw_deltas: Array = []
	var shake_peak := 0.0
	var discontinuities := 0
	var yaw_breaks := 0
	var retracted_frames := 0
	var align_sum := 0.0
	var align_n := 0
	var behind_ok := 0
	var fov_min := 999.0
	var fov_max := 0.0
	for row in samples:
		var pd := float(row.get("pos_delta", 0.0))
		var yd := float(row.get("yaw_delta", 0.0))
		pos_deltas.append(pd)
		yaw_deltas.append(yd)
		shake_peak = maxf(shake_peak, float(row.get("shake_amplitude", 0.0)))
		if pd > POSITION_DISCONTINUITY_M:
			discontinuities += 1
		if yd > YAW_DISCONTINUITY_RAD:
			yaw_breaks += 1
		if bool(row.get("spring_retracted", false)):
			retracted_frames += 1
		if row.has("optical_align"):
			align_sum += float(row.get("optical_align", 0.0))
			align_n += 1
		if bool(row.get("behind_racer", true)):
			behind_ok += 1
		fov_min = minf(fov_min, float(row.get("fov", 65.0)))
		fov_max = maxf(fov_max, float(row.get("fov", 65.0)))
	var rms := _rms(pos_deltas)
	var yaw_rms := _rms(yaw_deltas)
	var align_mean := align_sum / float(maxi(align_n, 1))
	return {
		"scenario": scenario,
		"sample_count": samples.size(),
		"metrics_defined_before_results": {
			"POSITION_DISCONTINUITY_M": POSITION_DISCONTINUITY_M,
			"YAW_DISCONTINUITY_RAD": YAW_DISCONTINUITY_RAD,
			"NORMAL_RUN_SHAKE_MAX": NORMAL_RUN_SHAKE_MAX,
			"HIGH_FREQ_POS_RMS_MAX": HIGH_FREQ_POS_RMS_MAX,
			"HIGH_FREQ_YAW_RMS_MAX": HIGH_FREQ_YAW_RMS_MAX,
			"OPTICAL_ALIGN_MIN": OPTICAL_ALIGN_MIN,
		},
		"max_positional_delta_m": _max(pos_deltas),
		"high_freq_position_rms": rms,
		"high_freq_yaw_rms": yaw_rms,
		"max_yaw_delta_rad": _max(yaw_deltas),
		"position_discontinuity_count": discontinuities,
		"yaw_discontinuity_count": yaw_breaks,
		"normal_run_shake_peak": shake_peak,
		"springarm_retracted_frames": retracted_frames,
		"optical_align_mean": align_mean,
		"behind_racer_frames": behind_ok,
		"fov_min": 0.0 if fov_min > 900.0 else fov_min,
		"fov_max": fov_max,
		"digital_position_continuity": discontinuities == 0 and rms <= HIGH_FREQ_POS_RMS_MAX,
		"digital_yaw_continuity": yaw_breaks == 0 and yaw_rms <= HIGH_FREQ_YAW_RMS_MAX,
		"digital_normal_run_shake_zero": shake_peak <= NORMAL_RUN_SHAKE_MAX,
		"digital_optical_align": align_n == 0 or align_mean >= OPTICAL_ALIGN_MIN,
		"HUMAN_CAMERA_SMOOTHNESS_PASS": false,
		"HUMAN_CAMERA_EXCITEMENT_PASS": false,
	}


func write_report(path: String, extra: Dictionary = {}) -> void:
	var report := analyze()
	for key in extra.keys():
		report[key] = extra[key]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(report, "  "))


func _rms(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var acc := 0.0
	for v in values:
		acc += float(v) * float(v)
	return sqrt(acc / float(values.size()))


func _max(values: Array) -> float:
	var best := 0.0
	for v in values:
		best = maxf(best, float(v))
	return best
