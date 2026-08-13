extends Node

## Offline achievement runtime. Unlocks only via catalog conditions
## (flags / events / stats). There is no cheat or test-only unlock API.

signal unlocked(achievement_id: String, entry: Dictionary)
signal progress_changed(achievement_id: String, current: float, target: float)

const CATALOG_PATH := "res://release/ACHIEVEMENTS.json"
const SAVE_PATH := "user://achievements_v1.json"
const SAVE_VERSION := 1

var catalog_version: int = 1
var game_id: String = ""
var _defs: Array = []
var _by_id: Dictionary = {}
var _save_path: String = SAVE_PATH
var _catalog_path: String = CATALOG_PATH
var _loaded: bool = false
var _state: Dictionary = _empty_state()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_catalog()
	load_save()
	evaluate_all()


func configure_isolated(save_path: String, catalog_path: String = CATALOG_PATH) -> void:
	## Redirect persist/catalog paths. Does not unlock anything.
	_save_path = save_path
	_catalog_path = catalog_path
	_loaded = false
	_state = _empty_state()
	_defs.clear()
	_by_id.clear()
	load_catalog()
	load_save()


func _empty_state() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"catalog_version": 1,
		"unlocked": {},
		"progress": {},
		"flags": {},
		"stats": {},
		"events": {},
		"notifications": [],
	}


func load_catalog() -> bool:
	if not FileAccess.file_exists(_catalog_path):
		push_warning("Achievement catalog missing: %s" % _catalog_path)
		return false
	var f := FileAccess.open(_catalog_path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Achievement catalog is not an object")
		return false
	game_id = str(parsed.get("game", ""))
	catalog_version = int(parsed.get("catalog_version", 1))
	_defs.clear()
	_by_id.clear()
	for item in parsed.get("achievements", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", ""))
		if id.is_empty():
			continue
		_defs.append(item)
		_by_id[id] = item
	return not _defs.is_empty()


func load_save() -> void:
	_loaded = true
	if not FileAccess.file_exists(_save_path):
		_state = _empty_state()
		_state["catalog_version"] = catalog_version
		return
	var f := FileAccess.open(_save_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_state = _empty_state()
		return
	_state = _empty_state()
	_state["save_version"] = int(parsed.get("save_version", SAVE_VERSION))
	_state["catalog_version"] = int(parsed.get("catalog_version", catalog_version))
	_state["unlocked"] = parsed.get("unlocked", {})
	_state["progress"] = parsed.get("progress", {})
	_state["flags"] = parsed.get("flags", {})
	_state["stats"] = parsed.get("stats", {})
	_state["events"] = parsed.get("events", {})
	_state["notifications"] = parsed.get("notifications", [])
	if int(_state.get("save_version", 1)) < SAVE_VERSION:
		_state["save_version"] = SAVE_VERSION
		_persist()


func _persist() -> void:
	_state["save_version"] = SAVE_VERSION
	_state["catalog_version"] = catalog_version
	_state["saved_at"] = Time.get_datetime_string_from_system(true)
	var f := FileAccess.open(_save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Achievement persist failed: %s" % _save_path)
		return
	f.store_string(JSON.stringify(_state, "  "))


func report_event(event_id: String, amount: int = 1, _payload: Dictionary = {}) -> void:
	if event_id.is_empty() or amount <= 0:
		return
	var prev := int(_state["events"].get(event_id, 0))
	_state["events"][event_id] = prev + amount
	evaluate_all()
	_persist()


func set_flag(flag: String, value: bool = true) -> void:
	if flag.is_empty():
		return
	_state["flags"][flag] = value
	evaluate_all()
	_persist()


func set_stat(stat: String, value: float) -> void:
	if stat.is_empty():
		return
	_state["stats"][stat] = value
	evaluate_all()
	_persist()


func is_unlocked(id: String) -> bool:
	var rec = _state["unlocked"].get(id, null)
	return typeof(rec) == TYPE_DICTIONARY and bool(rec.get("unlocked", false))


func unlocked_at(id: String) -> String:
	var rec = _state["unlocked"].get(id, {})
	if typeof(rec) != TYPE_DICTIONARY:
		return ""
	return str(rec.get("unlocked_at", ""))


func catalog_count() -> int:
	return _defs.size()


func unlocked_count() -> int:
	var n := 0
	for d in _defs:
		if is_unlocked(str(d.get("id", ""))):
			n += 1
	return n


func completion_percent() -> float:
	if _defs.is_empty():
		return 0.0
	return 100.0 * float(unlocked_count()) / float(_defs.size())


func progress_of(id: String) -> Dictionary:
	var def = _by_id.get(id, {})
	if typeof(def) != TYPE_DICTIONARY:
		return {"current": 0.0, "target": 1.0, "percent": 0.0}
	var pair := _condition_progress(def.get("unlock", {}))
	var current := float(pair[0])
	var target := maxf(float(pair[1]), 1.0)
	var pct := clampf(100.0 * current / target, 0.0, 100.0)
	if is_unlocked(id):
		pct = 100.0
		current = target
	return {"current": current, "target": target, "percent": pct}


func browser_entries() -> Array:
	var out: Array = []
	for d in _defs:
		var id := str(d.get("id", ""))
		var hidden := bool(d.get("hidden", false))
		var got := is_unlocked(id)
		var prog := progress_of(id)
		var title := str(d.get("title", id))
		var desc := str(d.get("description", ""))
		if hidden and not got:
			title = "???"
			desc = "Hidden achievement"
		out.append({
			"id": id,
			"title": title,
			"description": desc,
			"hidden": hidden,
			"unlocked": got,
			"unlocked_at": unlocked_at(id),
			"percent": float(prog.get("percent", 0.0)),
			"current": float(prog.get("current", 0.0)),
			"target": float(prog.get("target", 1.0)),
		})
	return out


func drain_notifications() -> Array:
	var pending: Array = _state["notifications"].duplicate(true)
	_state["notifications"] = []
	_persist()
	return pending


func pending_notification_count() -> int:
	return (_state["notifications"] as Array).size()


func evaluate_all() -> void:
	for d in _defs:
		var id := str(d.get("id", ""))
		if id.is_empty() or is_unlocked(id):
			continue
		if _condition_met(d.get("unlock", {})):
			_unlock(id, d)


func _unlock(id: String, def: Dictionary) -> void:
	# Duplicate prevention: never rewrite an existing unlock timestamp.
	if is_unlocked(id):
		return
	var stamp := Time.get_datetime_string_from_system(true)
	_state["unlocked"][id] = {
		"unlocked": true,
		"unlocked_at": stamp,
		"catalog_version": catalog_version,
	}
	var note := {
		"id": id,
		"title": str(def.get("title", id)),
		"description": str(def.get("description", "")),
		"hidden": bool(def.get("hidden", false)),
		"unlocked_at": stamp,
	}
	(_state["notifications"] as Array).append(note)
	unlocked.emit(id, note)


func _condition_met(cond) -> bool:
	if typeof(cond) != TYPE_DICTIONARY:
		return false
	var kind := str(cond.get("type", ""))
	match kind:
		"event_count":
			return int(_state["events"].get(str(cond.get("event", "")), 0)) >= int(cond.get("count", 1))
		"flag":
			return bool(_state["flags"].get(str(cond.get("flag", "")), false))
		"stat_at_least":
			return float(_state["stats"].get(str(cond.get("stat", "")), 0.0)) >= float(cond.get("threshold", 0.0))
		"all":
			for child in cond.get("conditions", []):
				if not _condition_met(child):
					return false
			return true
		"any":
			for child in cond.get("conditions", []):
				if _condition_met(child):
					return true
			return false
		_:
			return false


func _condition_progress(cond) -> Array:
	if typeof(cond) != TYPE_DICTIONARY:
		return [0.0, 1.0]
	var kind := str(cond.get("type", ""))
	match kind:
		"event_count":
			var target := float(cond.get("count", 1))
			var current := float(_state["events"].get(str(cond.get("event", "")), 0))
			return [minf(current, target), target]
		"flag":
			return [1.0 if bool(_state["flags"].get(str(cond.get("flag", "")), false)) else 0.0, 1.0]
		"stat_at_least":
			var thr := float(cond.get("threshold", 1.0))
			var val := float(_state["stats"].get(str(cond.get("stat", "")), 0.0))
			return [minf(val, thr), thr]
		"all":
			var kids: Array = cond.get("conditions", [])
			if kids.is_empty():
				return [0.0, 1.0]
			var met := 0
			for child in kids:
				if _condition_met(child):
					met += 1
			return [float(met), float(kids.size())]
		"any":
			return [1.0 if _condition_met(cond) else 0.0, 1.0]
		_:
			return [0.0, 1.0]
