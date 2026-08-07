extends Node

## Local race telemetry: signal bus + append-only JSONL under user://.
## Events: race_start, checkpoint, item_use, finish, restart.
## No PII — track ids, counts, and durations only.

signal event_recorded(event_name: String, payload: Dictionary)

const LOG_PATH := "user://telemetry/race_events.jsonl"
const ALLOWED_EVENTS := [
	"race_start",
	"checkpoint",
	"item_use",
	"finish",
	"restart",
]

var _session_id: String = ""
var _enabled: bool = true
var _event_count: int = 0


func _ready() -> void:
	_session_id = _make_session_id()
	_ensure_log_dir()


func is_enabled() -> bool:
	return _enabled


func set_enabled(value: bool) -> void:
	_enabled = value


func get_event_count() -> int:
	return _event_count


func get_session_id() -> String:
	return _session_id


func record(event_name: String, payload: Dictionary = {}) -> void:
	if not _enabled:
		return
	if event_name not in ALLOWED_EVENTS:
		push_warning("Telemetry ignored unknown event '%s'" % event_name)
		return
	var entry := {
		"event": event_name,
		"ts": Time.get_datetime_string_from_system(true),
		"unix_ms": Time.get_ticks_msec(),
		"session": _session_id,
		"device_role": _safe_role(),
		"payload": payload,
	}
	_append_jsonl(entry)
	_event_count += 1
	event_recorded.emit(event_name, entry)


func race_start(track_id: String, mode: String, laps: int) -> void:
	record("race_start", {
		"track_id": track_id,
		"mode": mode,
		"laps": laps,
		"map_profile": _safe_map_profile(),
		"gps_mode": _safe_gps_mode(),
	})


func checkpoint(track_id: String, checkpoint_index: int, lap: int, is_player: bool) -> void:
	record("checkpoint", {
		"track_id": track_id,
		"checkpoint_index": checkpoint_index,
		"lap": lap,
		"is_player": is_player,
	})


func item_use(item_id: String, track_id: String = "") -> void:
	record("item_use", {
		"item_id": item_id,
		"track_id": track_id,
	})


func finish(
	track_id: String,
	time_sec: float,
	position: int,
	finished: bool,
	perf: Dictionary = {}
) -> void:
	var payload := {
		"track_id": track_id,
		"time_sec": snappedf(time_sec, 0.01),
		"position": position,
		"finished": finished,
	}
	if not perf.is_empty():
		payload["perf"] = perf
	record("finish", payload)


func restart(track_id: String, reason: String = "rematch") -> void:
	record("restart", {
		"track_id": track_id,
		"reason": reason,
	})


func _safe_role() -> String:
	var roles := _device_roles()
	if roles != null:
		return str(roles.active_role_id)
	return "unknown"


func _safe_map_profile() -> String:
	var roles := _device_roles()
	if roles != null:
		return roles.get_map_profile_id()
	return "sim_campus"


func _safe_gps_mode() -> String:
	var roles := _device_roles()
	if roles != null:
		return roles.get_gps_mode()
	return "SIMULATED"


func _device_roles() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("DeviceRoleRuntime")


func _append_jsonl(entry: Dictionary) -> void:
	_ensure_log_dir()
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Telemetry could not open %s" % LOG_PATH)
		return
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.close()


func _ensure_log_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if not dir.dir_exists("telemetry"):
		dir.make_dir("telemetry")


func _make_session_id() -> String:
	return "pp_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
