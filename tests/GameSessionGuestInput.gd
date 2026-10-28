extends SceneTree

## Guest process. It computes Player2 input from the host snapshot and the
## shared racing line. It does not run the course AI as the guest.

const COURSE_ID := "verdant_cascade_circuit"
const WAIT_MSEC := 210000
## Match the STANDARD headless line-steer look-ahead used by the host follower.
const LOOK_AHEAD_M := 8.0
const STEER_GAIN := 2.8
## Physics tick used to advance path progress (same as AIPathFollower).
const PHYSICS_DT := 1.0 / 60.0

var _progress_m: float = 0.0
var _path_length_m: float = 1.0
var _cum: PackedFloat32Array = PackedFloat32Array()
var _seeded := false


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
	_write_guest_appearance(dir)
	_write_json(dir.path_join("sync/guest_ready.json"), {
		"source": "guest-process",
		"pid": OS.get_process_id(),
	})
	var points: Array = []
	var frames := 0
	var host_fp_seen := ""
	var deadline := Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		if points.is_empty():
			var path_file := _read_json(dir.path_join("sync/path.json"))
			var loaded: Array = path_file.get("points", [])
			if loaded.size() > 2:
				points = loaded
				_build_cum(points)
		var snap := _read_json(dir.path_join("sync/snapshot.json"))
		if host_fp_seen.is_empty():
			host_fp_seen = str(snap.get("hostAppearanceFingerprint", ""))
		var position: Array = snap.get("guestPosition", [])
		if position.size() == 3 and not points.is_empty():
			var world := Vector3(float(position[0]), float(position[1]), float(position[2]))
			var forward := Vector3.FORWARD
			var forward_raw: Array = snap.get("guestForward", [])
			if forward_raw.size() == 3:
				forward = Vector3(float(forward_raw[0]), float(forward_raw[1]), float(forward_raw[2]))
			var speed := float(snap.get("guestSpeed", 0.0))
			var cmd := _steer_cmd(points, world, forward, speed)
			_write_json(dir.path_join("sync/guest_input.json"), {
				"source": "guest-process",
				"pid": OS.get_process_id(),
				"seq": frames + 1,
				"steer": float(cmd.get("steer", 0.0)),
				"accelerate": bool(cmd.get("accelerate", true)),
				"lookX": float(cmd.get("lookX", world.x)),
				"lookZ": float(cmd.get("lookZ", world.z)),
				"progressM": _progress_m,
				"lateralM": float(cmd.get("lateralM", 0.0)),
			})
			frames += 1
			if bool(snap.get("finished", false)) or int(snap.get("raceState", -1)) >= 3:
				break
		await physics_frame
	_report(dir, frames, false, host_fp_seen)
	print("GAME_SESSION_ROLE=guest")
	print("GAME_SESSION_COURSE=%s" % COURSE_ID)
	print("GAME_SESSION_GUEST_INPUT_FRAMES=%d" % frames)
	print("HOST_SECRET_IN_GUEST_STATE=false")
	print("GAME_SESSION_COURSE_AI_IS_GUEST=false")
	if not host_fp_seen.is_empty():
		print("PEER_SEES_HOST_APPEARANCE=true")
		print("HOST_APPEARANCE_FINGERPRINT=%s" % host_fp_seen)
	quit(0 if frames > 30 else 1)


func _write_guest_appearance(dir: String) -> void:
	## Guest cosmetic identity for host to apply on Player2Racer.
	const AppearanceSyncScript = preload("res://scripts/data/AppearanceSync.gd")
	const CreatedRacerStoreScript = preload("res://scripts/data/CreatedRacerStore.gd")
	const WardrobeCatalogScript = preload("res://scripts/data/WardrobeCatalog.gd")
	var racer: Dictionary = CreatedRacerStoreScript.create_racer("Guest Studio Racer")
	racer["appearance"]["skin_tone"] = "deep_cool"
	racer["appearance"]["hair_style"] = "box_braids"
	racer["appearance"]["assistive"] = "forearm_sleeve_vis"
	racer["outfit_id"] = "neon_trackside_default"
	var preset: Dictionary = WardrobeCatalogScript.preset("neon_trackside_default")
	var slots: Dictionary = preset.get("slots", {})
	CreatedRacerStoreScript.save_outfit("neon_trackside_default", slots, true)
	racer["footwear_vehicle_id"] = str(slots.get("footwear_vehicle", "quillspike_launchers"))
	CreatedRacerStoreScript.update_racer(racer)
	var payload: Dictionary = AppearanceSyncScript.pack_from_created_racer(racer, slots)
	AppearanceSyncScript.write_payload(dir.path_join("sync/guest_appearance.json"), payload)
	_write_json(dir.path_join("sync/guest_appearance_fingerprint.json"), {
		"fingerprint": AppearanceSyncScript.fingerprint(payload),
		"source": "guest-process",
	})


func _build_cum(points: Array) -> void:
	_cum = PackedFloat32Array()
	_cum.resize(points.size())
	_cum[0] = 0.0
	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		var pa := Vector3(float(a[0]), float(a[1]), float(a[2]))
		var pb := Vector3(float(b[0]), float(b[1]), float(b[2]))
		_cum[i] = _cum[i - 1] + pa.distance_to(pb)
	_path_length_m = maxf(_cum[_cum.size() - 1], 1.0)
	_progress_m = 0.0
	_seeded = false


func _sample_at(points: Array, distance_m: float) -> Vector3:
	var target := fposmod(distance_m, _path_length_m)
	var i := 0
	while i + 1 < _cum.size() and _cum[i + 1] < target:
		i += 1
	if i + 1 >= points.size():
		var raw_end: Array = points[points.size() - 1]
		return Vector3(float(raw_end[0]), float(raw_end[1]), float(raw_end[2]))
	var span := _cum[i + 1] - _cum[i]
	var t := 0.0 if span <= 0.0001 else clampf((target - _cum[i]) / span, 0.0, 1.0)
	var a: Array = points[i]
	var b: Array = points[i + 1]
	var pa := Vector3(float(a[0]), float(a[1]), float(a[2]))
	var pb := Vector3(float(b[0]), float(b[1]), float(b[2]))
	return pa.lerp(pb, t)


func _closest_offset_forward(points: Array, pos: Vector3) -> float:
	## Prefer samples near the current progress. A closed loop puts the finish
	## samples next to the start line; a global nearest jumps the cursor there.
	var best_dist := 1.0e12
	var best_offset := _progress_m
	var window_back := 8.0
	var window_ahead := 40.0
	var start_m := _progress_m - window_back
	var end_m := _progress_m + window_ahead
	if not _seeded:
		start_m = 0.0
		end_m = minf(48.0, _path_length_m * 0.25)
	var step := 2.0
	var cursor := start_m
	while cursor <= end_m:
		var sample := _sample_at(points, cursor)
		var flat := sample
		flat.y = pos.y
		var d := pos.distance_squared_to(flat)
		if d < best_dist:
			best_dist = d
			best_offset = fposmod(cursor, _path_length_m)
		cursor += step
	return best_offset


func _steer_cmd(points: Array, pos: Vector3, forward: Vector3, speed: float) -> Dictionary:
	var closest := _closest_offset_forward(points, pos)
	var on_path := _sample_at(points, closest)
	var lateral_vec := pos - on_path
	lateral_vec.y = 0.0
	var lateral := lateral_vec.length()
	if not _seeded:
		_progress_m = closest
		_seeded = true
	else:
		# Integrate forward like AIPathFollower. Reacquire only when the body is
		# slow and far from the estimate, or still on-line with a large gap.
		var gap := closest - _progress_m
		if gap > _path_length_m * 0.5:
			gap -= _path_length_m
		elif gap < -_path_length_m * 0.5:
			gap += _path_length_m
		var crawling := speed <= 4.0 and absf(gap) > 12.0
		var on_line := lateral <= 1.5 and absf(gap) > 20.0
		if crawling or on_line:
			_progress_m = closest
		else:
			_progress_m = fposmod(_progress_m + maxf(speed, 0.0) * PHYSICS_DT, _path_length_m)

	var target := _sample_at(points, _progress_m + LOOK_AHEAD_M)
	var mid := _sample_at(points, _progress_m + LOOK_AHEAD_M * 0.45)
	var planned := mid.lerp(target, 0.5)
	var to_target := planned - pos
	to_target.y = 0.0
	forward.y = 0.0
	if to_target.length_squared() < 0.0001:
		return {
			"steer": 0.0,
			"accelerate": true,
			"lookX": planned.x,
			"lookZ": planned.z,
			"lateralM": lateral,
		}
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var dir := to_target.normalized()
	# If the guest faces the wrong way, pure cross-product steer collapses to
	# ~0 and they keep accelerating off the course. Force a turn onto the line.
	var heading := forward.dot(dir)
	var steer := clampf(forward.cross(dir).y * STEER_GAIN, -1.0, 1.0)
	if heading < 0.0:
		var side := forward.cross(dir).y
		if absf(side) < 0.05:
			side = 1.0
		steer = 1.0 if side >= 0.0 else -1.0
	var accelerate := true
	if absf(steer) > 0.78 and speed > 14.5:
		accelerate = false
	return {
		"steer": steer,
		"accelerate": accelerate,
		"lookX": planned.x,
		"lookZ": planned.z,
		"lateralM": lateral,
	}


func _report(dir: String, frames: int, secret_seen: bool, host_fp: String = "") -> void:
	if dir.is_empty():
		return
	_write_json(dir.path_join("guest_report.json"), {
		"source": "guest-process",
		"pid": OS.get_process_id(),
		"inputFrames": frames,
		"containsHostSession": secret_seen,
		"courseAiIsGuest": false,
		"progressM": _progress_m,
		"pathLengthM": _path_length_m,
		"hostAppearanceFingerprint": host_fp,
		"peerSeesHostAppearance": not host_fp.is_empty(),
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
