extends SceneTree

## Guest process. It computes Player2 input from the host snapshot and the
## shared racing line. It does not run the course AI as the guest.

const COURSE_ID := "verdant_cascade_circuit"
const WAIT_MSEC := 210000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dir := OS.get_environment("GAME_SESSION_DIR").strip_edges()
	var view_path := dir.path_join("guest_view.json")
	var view_text := FileAccess.get_file_as_string(view_path) if FileAccess.file_exists(view_path) else ""
	if view_text.contains("hostSession") or view_text.contains("hostToken"):
		_report(dir, 0, true)
		print("HOST_SECRET_IN_GUEST_STATE=true")
		quit(1)
		return
	var session: Variant = JSON.parse_string(view_text)
	if typeof(session) != TYPE_DICTIONARY or str((session as Dictionary).get("role", "")) != "guest":
		_report(dir, 0, false)
		print("GAME_SESSION_ROLE=guest")
		print("GAME_SESSION_RACE_FAIL guest view is missing")
		quit(1)
		return
	_write_json(dir.path_join("sync/guest_ready.json"), {
		"source": "guest-process",
		"pid": OS.get_process_id(),
	})
	var points: Array = []
	var frames := 0
	var deadline := Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		if points.is_empty():
			var path_file := _read_json(dir.path_join("sync/path.json"))
			var loaded: Array = path_file.get("points", [])
			if loaded.size() > 2:
				points = loaded
		var snap := _read_json(dir.path_join("sync/snapshot.json"))
		var position: Array = snap.get("guestPosition", [])
		if position.size() == 3 and not points.is_empty():
			var world := Vector3(float(position[0]), float(position[1]), float(position[2]))
			var forward := Vector3.FORWARD
			var forward_raw: Array = snap.get("guestForward", [])
			if forward_raw.size() == 3:
				forward = Vector3(float(forward_raw[0]), float(forward_raw[1]), float(forward_raw[2]))
			_write_json(dir.path_join("sync/guest_input.json"), {
				"source": "guest-process",
				"pid": OS.get_process_id(),
				"seq": frames + 1,
				"steer": _steer_along(points, world, forward),
				"accelerate": true,
			})
			frames += 1
			if bool(snap.get("finished", false)) or int(snap.get("raceState", -1)) >= 3:
				break
		await physics_frame
	_report(dir, frames, false)
	print("GAME_SESSION_ROLE=guest")
	print("GAME_SESSION_COURSE=%s" % COURSE_ID)
	print("GAME_SESSION_GUEST_INPUT_FRAMES=%d" % frames)
	print("HOST_SECRET_IN_GUEST_STATE=false")
	print("GAME_SESSION_COURSE_AI_IS_GUEST=false")
	quit(0 if frames > 30 else 1)


func _steer_along(points: Array, pos: Vector3, forward: Vector3) -> float:
	var closest := 0
	var best := 1.0e12
	for i in points.size():
		var raw: Array = points[i]
		var point := Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
		var distance := pos.distance_squared_to(point)
		if distance < best:
			best = distance
			closest = i
	var traveled := 0.0
	var index := closest
	var previous: Array = points[index]
	var previous_point := Vector3(float(previous[0]), float(previous[1]), float(previous[2]))
	while traveled < 5.5:
		var next_index := (index + 1) % points.size()
		var raw_next: Array = points[next_index]
		var next_point := Vector3(float(raw_next[0]), float(raw_next[1]), float(raw_next[2]))
		traveled += previous_point.distance_to(next_point)
		previous_point = next_point
		index = next_index
		if index == closest:
			break
	var to_target := previous_point - pos
	to_target.y = 0.0
	forward.y = 0.0
	if to_target.length_squared() < 0.0001 or forward.length_squared() < 0.0001:
		return 0.0
	return clampf(forward.normalized().cross(to_target.normalized()).y * 2.8, -1.0, 1.0)


func _report(dir: String, frames: int, secret_seen: bool) -> void:
	if dir.is_empty():
		return
	_write_json(dir.path_join("guest_report.json"), {
		"source": "guest-process",
		"pid": OS.get_process_id(),
		"inputFrames": frames,
		"containsHostSession": secret_seen,
		"courseAiIsGuest": false,
	})


func _read_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.contains("hostSession") or text.contains("hostToken"):
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


func _write_json(path: String, value: Dictionary) -> void:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(value))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)
