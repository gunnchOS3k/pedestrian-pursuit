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
	var catalog = preload("res://scripts/data/TrackCatalog.gd")
	var course: Dictionary = catalog.load_track(COURSE_ID)
	var track_script = load("res://scripts/tracks/CourseTrack.gd")
	var track: Node = track_script.new()
	track.configure(course)
	get_root().add_child(track)
	if course.is_empty() or not track.build() or track.get_race_path() == null:
		_report(dir, 0, false)
		print("GAME_SESSION_ROLE=guest")
		print("GAME_SESSION_RACE_FAIL guest could not build the racing line")
		quit(1)
		return
	var follower_script = load("res://scripts/ai/AIPathFollower.gd")
	var follower: Node = follower_script.new()
	follower.name = "GuestLineSteer"
	track.add_child(follower)
	follower.setup(track.get_race_path())
	follower.set("look_ahead", 5.5)
	follower.set("magnet_strength", 0.0)
	var body := CharacterBody3D.new()
	body.name = "GuestInputBody"
	get_root().add_child(body)
	_write_json(dir.path_join("sync/guest_ready.json"), {
		"source": "guest-process",
		"pid": OS.get_process_id(),
	})
	var frames := 0
	var deadline := Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		var snap := _read_json(dir.path_join("sync/snapshot.json"))
		var position: Array = snap.get("guestPosition", [])
		if position.size() == 3 and follower.has_method("get_steer_and_accel"):
			body.global_position = Vector3(float(position[0]), float(position[1]), float(position[2]))
			var forward_raw: Array = snap.get("guestForward", [])
			if forward_raw.size() == 3:
				var forward := Vector3(float(forward_raw[0]), float(forward_raw[1]), float(forward_raw[2]))
				if forward.length_squared() > 0.001 and absf(forward.normalized().dot(Vector3.UP)) < 0.95:
					body.look_at(body.global_position + forward, Vector3.UP)
			body.velocity = -body.global_transform.basis.z * float(snap.get("guestSpeed", 0.0))
			var cmd: Dictionary = follower.get_steer_and_accel(body, 0.016)
			_write_json(dir.path_join("sync/guest_input.json"), {
				"source": "guest-process",
				"pid": OS.get_process_id(),
				"seq": frames + 1,
				"steer": float(cmd.get("steer", 0.0)),
				"accelerate": bool(cmd.get("accelerate", true)),
			})
			frames += 1
			if bool(snap.get("finished", false)) or int(snap.get("raceState", -1)) >= 3:
				break
		await physics_frame
	_report(dir, frames, false)
	print("GAME_SESSION_ROLE=guest")
	print("GAME_SESSION_GUEST_INPUT_FRAMES=%d" % frames)
	print("HOST_SECRET_IN_GUEST_STATE=false")
	print("GAME_SESSION_COURSE_AI_IS_GUEST=false")
	quit(0 if frames > 30 else 1)


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
