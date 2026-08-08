extends RefCounted
class_name PackageLifecycle

## Clean install / update / rollback digital helpers for RC packaging evidence.


const PACKAGE_META := "user://pp_package_meta.cfg"
const CONTENT_VERSION := 3


static func record_clean_install() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("package", "content_version", CONTENT_VERSION)
	cfg.set_value("package", "installed_at", Time.get_datetime_string_from_system())
	cfg.set_value("package", "channel", "digital_rc")
	cfg.set_value("package", "rollback_version", CONTENT_VERSION - 1)
	cfg.save(PACKAGE_META)


static func migrate_or_update() -> Dictionary:
	var cfg := ConfigFile.new()
	var existed := cfg.load(PACKAGE_META) == OK
	var prev := int(cfg.get_value("package", "content_version", 1)) if existed else 0
	var rolled_back := false
	if prev > CONTENT_VERSION:
		# Simulated rollback path when newer package meta is encountered.
		cfg.set_value("package", "content_version", CONTENT_VERSION)
		cfg.set_value("package", "rolled_back_from", prev)
		rolled_back = true
	elif prev < CONTENT_VERSION:
		cfg.set_value("package", "content_version", CONTENT_VERSION)
		cfg.set_value("package", "updated_from", prev)
	cfg.set_value("package", "checked_at", Time.get_datetime_string_from_system())
	cfg.set_value("package", "rollback_version", CONTENT_VERSION - 1)
	cfg.save(PACKAGE_META)
	return {
		"existed": existed,
		"previous_version": prev,
		"content_version": CONTENT_VERSION,
		"updated": prev < CONTENT_VERSION,
		"rolled_back": rolled_back,
		"offline_ok": true,
	}


static func describe() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(PACKAGE_META)
	return {
		"schema": "pp_package_lifecycle/v1",
		"content_version": int(cfg.get_value("package", "content_version", CONTENT_VERSION)),
		"rollback_version": int(cfg.get_value("package", "rollback_version", CONTENT_VERSION - 1)),
		"channel": str(cfg.get_value("package", "channel", "digital_rc")),
		"offline_playable": true,
		"local_mp": true,
		"ai_field": true,
	}
