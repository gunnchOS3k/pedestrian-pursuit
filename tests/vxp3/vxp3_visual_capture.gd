extends SceneTree

## VXP-3 visual capture harness.
## Prefer a real display. Headless may yield CAPTURE_FAILED — label honestly.
## Usage:
##   GODOT_BIN=... $GODOT_BIN --path . -s res://tests/vxp3/vxp3_visual_capture.gd
## Optional user args: --vxp3-capture-phase=before|after --vxp3-capture-w=1280 --vxp3-capture-h=720

const PHASES := ["after"]
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2400, 1080), ## Pixel-class landscape digital proxy
]

var _phase := "after"
var _results: Array = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var s := str(arg)
		if s.begins_with("--vxp3-capture-phase="):
			_phase = s.get_slice("=", 1)
	call_deferred("_run")


func _log(msg: String) -> void:
	print("[vxp3_capture] %s" % msg)


func _shot(name: String) -> Dictionary:
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var size := root.get_viewport().get_visible_rect().size
	var meta := {
		"id": name,
		"phase": _phase,
		"timestamp": Time.get_datetime_string_from_system(true),
		"resolution": "%dx%d" % [int(size.x), int(size.y)],
		"platform": OS.get_name(),
		"engine": Engine.get_version_info().get("string", "godot"),
		"evidence_class": "REAL_RUNTIME_CAPTURE",
		"pixel_physical": false,
	}
	if img == null:
		meta["status"] = "CAPTURE_FAILED"
		meta["evidence_class"] = "ABSENT"
		_log("FAIL %s null image" % name)
		return meta
	var out_dir := "user://vxp3_capture/%s" % _phase
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path := "%s/%s.png" % [out_dir, name]
	var err := img.save_png(path)
	meta["status"] = "CAPTURED" if err == OK else "SAVE_FAILED"
	meta["path"] = ProjectSettings.globalize_path(path)
	_log("%s %s" % [meta["status"], meta.get("path", "")])
	return meta


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _run() -> void:
	_log("start phase=%s" % _phase)
	DisplayServer.window_set_size(RESOLUTIONS[0])
	await _wait(0.8)
	_results.append(await _shot("01_main_menu"))
	## Best-effort additional frames at alternate sizes (same scene).
	for i in range(1, RESOLUTIONS.size()):
		DisplayServer.window_set_size(RESOLUTIONS[i])
		await _wait(0.35)
		_results.append(await _shot("01_main_menu_%dx%d" % [RESOLUTIONS[i].x, RESOLUTIONS[i].y]))
	var manifest := {
		"schema": "vxp3.visual_capture_run/v1",
		"game": "pedestrian-pursuit",
		"lane": "VXP-3",
		"phase": _phase,
		"VXP3_PIXEL_PHYSICAL_CAPTURE_PASS": false,
		"shots": _results,
	}
	var mf_path := "user://vxp3_capture/%s/CAPTURE_RUN.json" % _phase
	var mf := FileAccess.open(mf_path, FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify(manifest, "\t"))
	_log("done shots=%d" % _results.size())
	quit()
