extends Node

## Baked at export time. Review builds must never ship UNKNOWN.

const PATH := "res://data/build_identity.json"
const UNKNOWN := "UNKNOWN"

var return_to_guest_review: bool = false
var _data: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	_data = {
		"repo": "gunnchOS3k/pedestrian-pursuit",
		"git_sha": UNKNOWN,
		"git_sha_short": UNKNOWN,
		"ref": UNKNOWN,
		"version_name": UNKNOWN,
		"version_code": 0,
		"build_timestamp": UNKNOWN,
		"build_flavor": "unexported",
		"package_id": "com.gunnchos.pedestrianpursuit",
		"watermark": "PP UNKNOWN",
	}
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in parsed.keys():
			_data[key] = parsed[key]


func data() -> Dictionary:
	return _data.duplicate()


func git_sha() -> String:
	return str(_data.get("git_sha", UNKNOWN))


func git_sha_short() -> String:
	return str(_data.get("git_sha_short", UNKNOWN))


func build_flavor() -> String:
	return str(_data.get("build_flavor", "unexported"))


func watermark_text() -> String:
	return str(_data.get("watermark", "PP %s" % git_sha_short()))


func is_review_flavor() -> bool:
	return build_flavor().to_lower().find("review") >= 0


func review_sha_known() -> bool:
	if not is_review_flavor():
		return true
	return git_sha() != UNKNOWN and not git_sha().is_empty()


func display_lines() -> PackedStringArray:
	return PackedStringArray([
		"repo: %s" % _data.get("repo", UNKNOWN),
		"short git SHA: %s" % git_sha_short(),
		"full git SHA: %s" % git_sha(),
		"branch/ref: %s" % _data.get("ref", UNKNOWN),
		"versionName: %s" % _data.get("version_name", UNKNOWN),
		"versionCode: %s" % _data.get("version_code", 0),
		"build timestamp: %s" % _data.get("build_timestamp", UNKNOWN),
		"build flavor: %s" % build_flavor(),
		"package ID: %s" % _data.get("package_id", UNKNOWN),
	])
