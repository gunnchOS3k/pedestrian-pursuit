extends SceneTree
const _PackageLifecycle = preload("res://scripts/rc/PackageLifecycle.gd")
const _CrashWatchdog = preload("res://scripts/rc/CrashWatchdog.gd")
const _InputProfileCatalog = preload("res://scripts/rc/InputProfileCatalog.gd")
const _LaunchArtCatalog = preload("res://scripts/ui/LaunchArtCatalog.gd")

## Digital RC product-state smoke — art/audio/packaging/input/crash.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_test_art(failures)
	_test_audio(failures)
	_test_packaging(failures)
	_test_input_profiles(failures)
	_test_crash(failures)

	if failures.is_empty():
		print("DigitalRcProductStateTest PASS")
		print("PEDESTRIAN_DIGITAL_RC_READY")
		print("PEDESTRIAN_PHYSICAL_PERFORMANCE_PENDING")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_art(failures: PackedStringArray) -> void:
	if not FileAccess.file_exists("res://data/art/LAUNCH_ART_INVENTORY.json"):
		failures.append("LAUNCH_ART_INVENTORY missing")
		return
	var f := FileAccess.open("res://data/art/LAUNCH_ART_INVENTORY.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("status", "")) != "LAUNCH_PROCEDURAL_FINAL":
		failures.append("launch art status")
	for rid in ["dash_reed", "nova_quill", "kai_volt"]:
		if _LaunchArtCatalog.racer_icon(rid) == null and not FileAccess.file_exists("res://assets/art/racers/%s.png" % rid):
			failures.append("racer art %s" % rid)
	for tid in ["verdant_cascade_circuit", "mirage_mesa"]:
		if not FileAccess.file_exists("res://assets/art/tracks/%s.png" % tid):
			failures.append("track art %s" % tid)
	if not FileAccess.file_exists("res://gate1/evidence/visual_qa/racers_contact_sheet.png"):
		failures.append("racer contact sheet")
	if not FileAccess.file_exists("res://data/art/provenance.json"):
		failures.append("provenance")


func _test_audio(failures: PackedStringArray) -> void:
	if not FileAccess.file_exists("res://assets/audio/music/menu_theme.wav"):
		failures.append("menu theme")
	if not FileAccess.file_exists("res://assets/audio/sfx/item_turbo_toes.wav"):
		failures.append("item sfx")
	if not FileAccess.file_exists("res://assets/audio/ui/confirm.wav"):
		failures.append("ui sfx")
	var audio := root.get_node_or_null("AudioDirector")
	if audio == null:
		# Autoload may not exist in SceneTree script context; load manually.
		audio = preload("res://scripts/audio/AudioDirector.gd").new()
		audio.name = "AudioDirector"
		root.add_child(audio)
	if audio == null or not audio.has_method("describe"):
		failures.append("AudioDirector")


func _test_packaging(failures: PackedStringArray) -> void:
	_PackageLifecycle.record_clean_install()
	var mig: Dictionary = _PackageLifecycle.migrate_or_update()
	if not bool(mig.get("offline_ok", false)):
		failures.append("package offline")
	var desc: Dictionary = _PackageLifecycle.describe()
	if int(desc.get("content_version", 0)) < 3:
		failures.append("package content version")


func _test_input_profiles(failures: PackedStringArray) -> void:
	var ids := _InputProfileCatalog.all_ids()
	if ids.size() < 4:
		failures.append("input profile count")
	for pid in ids:
		if _InputProfileCatalog.load_profile(str(pid)).is_empty():
			failures.append("input profile %s" % pid)


func _test_crash(failures: PackedStringArray) -> void:
	_CrashWatchdog.note_event("digital_rc_smoke", "ok")
	var last: Dictionary = _CrashWatchdog.last_event()
	if str(last.get("kind", "")) != "digital_rc_smoke":
		failures.append("crash watchdog")
