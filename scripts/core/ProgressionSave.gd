extends Node

## Career progression + unlock surfacing (digital Beta).

const SAVE_PATH := "user://pp_progression.cfg"
const SAVE_VERSION := 3

var xp: int = 0
var level: int = 1
var unlocked: Dictionary = {}
var challenge_progress: Dictionary = {}
var trophies: PackedStringArray = PackedStringArray()
var time_trial_pbs: Dictionary = {}
var tutorial_completed: bool = false
var first_run_complete: bool = false
var unlocked_vehicles: Dictionary = {} ## genuine player vehicle unlocks (separate from registry playable)


func _ready() -> void:
	load_or_migrate()


func load_or_migrate() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		# Migrate legacy cup-only save presence into progression shell.
		_seed_defaults()
		_migrate_legacy_cup_flag()
		save()
		return
	var version := int(cfg.get_value("meta", "save_version", 1))
	xp = int(cfg.get_value("career", "xp", 0))
	level = int(cfg.get_value("career", "level", 1))
	unlocked = cfg.get_value("career", "unlocked", {})
	challenge_progress = cfg.get_value("career", "challenges", {})
	trophies = PackedStringArray(cfg.get_value("career", "trophies", []))
	time_trial_pbs = cfg.get_value("career", "tt_pbs", {})
	tutorial_completed = bool(cfg.get_value("career", "tutorial_completed", false))
	first_run_complete = bool(cfg.get_value("career", "first_run_complete", false))
	unlocked_vehicles = cfg.get_value("career", "unlocked_vehicles", {})
	if version < SAVE_VERSION:
		_migrate_from(version)
		save()


func _seed_defaults() -> void:
	unlocked = {
		"shoe:starter_soles": true,
		"runner:dash_reed": true,
		"mode:quick_race": true,
		"mode:cup": true,
		"mode:time_trial": true,
		"mode:tutorial": true,
		"unlock_mode:starter": true,
	}
	unlocked_vehicles = {}
	xp = 0
	level = 1


func _migrate_legacy_cup_flag() -> void:
	var cup := ConfigFile.new()
	if cup.load("user://cup_progress.cfg") == OK:
		first_run_complete = true
		unlocked["mode:cup"] = true


func _migrate_from(version: int) -> void:
	if version < 2:
		unlocked["mode:challenges"] = true
		unlocked["mode:progression"] = true
		unlocked["mode:local_mp"] = true
		unlocked["mode:ghost"] = true
	if version < 3:
		## Separate developer/test unlock-all from genuine player progression.
		## Do NOT auto-grant all 50 vehicles — starters remain freely available via unlock.mode.
		unlocked["unlock_mode:starter"] = true
		if typeof(unlocked_vehicles) != TYPE_DICTIONARY:
			unlocked_vehicles = {}


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", SAVE_VERSION)
	cfg.set_value("meta", "saved_at", Time.get_datetime_string_from_system())
	cfg.set_value("career", "xp", xp)
	cfg.set_value("career", "level", level)
	cfg.set_value("career", "unlocked", unlocked)
	cfg.set_value("career", "challenges", challenge_progress)
	cfg.set_value("career", "trophies", Array(trophies))
	cfg.set_value("career", "tt_pbs", time_trial_pbs)
	cfg.set_value("career", "tutorial_completed", tutorial_completed)
	cfg.set_value("career", "first_run_complete", first_run_complete)
	cfg.set_value("career", "unlocked_vehicles", unlocked_vehicles)
	cfg.save(SAVE_PATH)


func is_unlocked(key: String) -> bool:
	return bool(unlocked.get(key, false))


func unlock(key: String) -> void:
	unlocked[key] = true
	save()


func unlock_vehicle(vehicle_id: String) -> void:
	unlocked_vehicles[vehicle_id] = true
	unlocked["vehicle:%s" % vehicle_id] = true
	save()


func is_vehicle_unlocked(vehicle_id: String) -> bool:
	if bool(unlocked_vehicles.get(vehicle_id, false)):
		return true
	if bool(unlocked.get("vehicle:%s" % vehicle_id, false)):
		return true
	## Mode-wide unlocks (cup/challenge/achievement/crossover career flags).
	var VehicleCatalogScript = load("res://scripts/data/VehicleCatalog.gd")
	var entry: Dictionary = VehicleCatalogScript.by_id(vehicle_id)
	var mode := "starter"
	var unlock_data: Variant = entry.get("unlock", {})
	if typeof(unlock_data) == TYPE_DICTIONARY:
		mode = str(unlock_data.get("mode", "starter"))
	if mode == "starter":
		return true
	return bool(unlocked.get("unlock_mode:%s" % mode, false))


func add_xp(amount: int) -> void:
	xp += maxi(amount, 0)
	while xp >= level * 100:
		xp -= level * 100
		level += 1
	save()


func record_time_trial_pb(track_id: String, time_sec: float) -> bool:
	var prev := float(time_trial_pbs.get(track_id, 0.0))
	if prev <= 0.0 or time_sec < prev:
		time_trial_pbs[track_id] = time_sec
		save()
		_ach_event("time_trial_pb")
		return true
	return false


func complete_challenge(challenge_id: String, reward_xp: int = 50) -> void:
	challenge_progress[challenge_id] = {
		"completed": true,
		"at": Time.get_datetime_string_from_system(),
	}
	add_xp(reward_xp)
	unlock("challenge:%s" % challenge_id)
	_ach_set_flag("challenge:%s" % challenge_id, true)
	_ach_event("challenge_complete")


func mark_tutorial_done() -> void:
	tutorial_completed = true
	first_run_complete = true
	unlock("mode:challenges")
	add_xp(40)
	save()
	_ach_set_flag("tutorial_completed", true)


func summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Level %d  •  %d XP to next" % [level, maxi(level * 100 - xp, 0)])
	lines.append("Unlocks: %d" % unlocked.size())
	lines.append("Challenges cleared: %d" % challenge_progress.size())
	lines.append("TT personal bests: %d" % time_trial_pbs.size())
	var ach := _achievements()
	if ach != null and ach.has_method("completion_percent"):
		lines.append("Achievements: %.0f%%  (%d/%d)" % [
			float(ach.completion_percent()),
			int(ach.unlocked_count()),
			int(ach.catalog_count()),
		])
	return lines


func _achievements() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("AchievementRuntime")


func _ach_event(event_id: String, amount: int = 1) -> void:
	var ach := _achievements()
	if ach != null and ach.has_method("report_event"):
		ach.report_event(event_id, amount)


func _ach_set_flag(flag: String, value: bool = true) -> void:
	var ach := _achievements()
	if ach != null and ach.has_method("set_flag"):
		ach.set_flag(flag, value)
