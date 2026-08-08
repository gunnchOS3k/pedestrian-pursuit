extends RefCounted
class_name CrashWatchdog

## Digital crash / soft-fault handling — writes recovery breadcrumbs under user://.


const CRASH_LOG := "user://pp_crash_recovery.cfg"
const MAX_ENTRIES := 12


static func note_event(kind: String, detail: String = "") -> void:
	var cfg := ConfigFile.new()
	cfg.load(CRASH_LOG)
	var entries: Array = cfg.get_value("recovery", "events", [])
	entries.append(
		{
			"at": Time.get_datetime_string_from_system(),
			"kind": kind,
			"detail": detail,
			"track": str(GameManager.selected_track_id) if GameManager else "",
			"mode": str(GameManager.mode_label()) if GameManager and GameManager.has_method("mode_label") else "",
		}
	)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	cfg.set_value("recovery", "events", entries)
	cfg.set_value("recovery", "last_kind", kind)
	cfg.save(CRASH_LOG)


static func last_event() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(CRASH_LOG) != OK:
		return {}
	var entries: Array = cfg.get_value("recovery", "events", [])
	if entries.is_empty():
		return {}
	var last = entries[entries.size() - 1]
	return last if typeof(last) == TYPE_DICTIONARY else {}


static func describe() -> Dictionary:
	return {
		"schema": "pp_crash_watchdog/v1",
		"path": CRASH_LOG,
		"last": last_event(),
	}
