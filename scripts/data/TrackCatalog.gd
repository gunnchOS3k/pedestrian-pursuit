class_name TrackCatalog
extends RefCounted

## Loads and validates cup/course content before it reaches the race scene.

const DEFAULT_CUP_ID := "sole_surge_cup"
const DEFAULT_TRACK_ID := "verdant_cascade_circuit"
const CUP_ROOT := "res://data/cups/"
const TRACK_ROOT := "res://data/tracks/"

const REQUIRED_TRACK_FIELDS := [
	"schema_version",
	"id",
	"display_name",
	"lap_count",
	"difficulty",
	"theme",
	"description",
	"lane_width",
	"track_color",
	"accent_color",
	"sky_color",
	"backdrop_color",
	"path_points",
	"checkpoint_points"
]


static func load_cup(cup_id: String = DEFAULT_CUP_ID) -> Dictionary:
	if not _is_safe_identifier(cup_id):
		push_error("Rejected unsafe cup id: %s" % cup_id)
		return {}
	var cup := _load_json(CUP_ROOT + cup_id + ".json")
	var errors := validate_cup(cup)
	if not cup.is_empty() and str(cup.get("id", "")) != cup_id:
		errors.append("file id does not match requested cup id")
	if not errors.is_empty():
		push_error("Invalid cup '%s': %s" % [cup_id, "; ".join(errors)])
		return {}
	return cup


static func load_track(track_id: String) -> Dictionary:
	if not _is_safe_identifier(track_id):
		push_error("Rejected unsafe track id: %s" % track_id)
		return {}
	var track := _load_json(TRACK_ROOT + track_id + ".json")
	var errors := validate_track(track)
	if not track.is_empty() and str(track.get("id", "")) != track_id:
		errors.append("file id does not match requested track id")
	if not errors.is_empty():
		push_error("Invalid track '%s': %s" % [track_id, "; ".join(errors)])
		return {}
	return track


static func load_tracks_for_cup(cup_id: String = DEFAULT_CUP_ID) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cup := load_cup(cup_id)
	for track_id in cup.get("track_ids", []):
		var track := load_track(str(track_id))
		if not track.is_empty():
			result.append(track)
	return result


static func validate_cup(cup: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for field in [
		"schema_version", "id", "display_name", "description", "track_ids", "points_by_position"
	]:
		if not cup.has(field):
			errors.append("missing field '%s'" % field)
	if not errors.is_empty():
		return errors
	if int(cup.get("schema_version", 0)) != 1:
		errors.append("unsupported schema_version")
	if not _is_safe_identifier(str(cup.get("id", ""))):
		errors.append("id must use lowercase letters, numbers, and underscores")
	var track_ids: Array = cup.get("track_ids", [])
	if track_ids.size() != 4:
		errors.append("a championship cup must contain exactly four tracks")
	var unique_ids := {}
	for track_id in track_ids:
		var normalized_id := str(track_id)
		if not _is_safe_identifier(normalized_id):
			errors.append("invalid track id '%s'" % normalized_id)
		if unique_ids.has(normalized_id):
			errors.append("duplicate track id '%s'" % normalized_id)
		unique_ids[normalized_id] = true
	var points: Array = cup.get("points_by_position", [])
	if points.is_empty():
		errors.append("points_by_position cannot be empty")
	for i in range(1, points.size()):
		if int(points[i]) > int(points[i - 1]):
			errors.append("points_by_position must be descending")
			break
	for point_value in points:
		if not (point_value is int or point_value is float) or int(point_value) < 0:
			errors.append("points_by_position values must be non-negative numbers")
			break
	return errors


static func validate_track(track: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for field in REQUIRED_TRACK_FIELDS:
		if not track.has(field):
			errors.append("missing field '%s'" % field)
	if not errors.is_empty():
		return errors
	if int(track.get("schema_version", 0)) != 1:
		errors.append("unsupported schema_version")
	if not _is_safe_identifier(str(track.get("id", ""))):
		errors.append("id must use lowercase letters, numbers, and underscores")
	if str(track.get("display_name", "")).strip_edges().is_empty():
		errors.append("display_name cannot be empty")
	if int(track.get("lap_count", 0)) < 1 or int(track.get("lap_count", 0)) > 9:
		errors.append("lap_count must be between 1 and 9")
	var lane_width := float(track.get("lane_width", 0.0))
	if lane_width < 8.0 or lane_width > 24.0:
		errors.append("lane_width must be between 8 and 24")
	for color_field in ["track_color", "accent_color", "sky_color", "backdrop_color"]:
		if not _is_hex_color(str(track.get(color_field, ""))):
			errors.append("%s must be a #RRGGBB color" % color_field)
	var points: Array = track.get("path_points", [])
	if points.size() < 6:
		errors.append("path_points must contain at least six points")
	for index in range(points.size()):
		var point = points[index]
		if not (point is Array) or point.size() != 3:
			errors.append("path point %d must contain three numbers" % index)
			continue
		for coordinate in point:
			if not (coordinate is int or coordinate is float):
				errors.append("path point %d contains a non-numeric coordinate" % index)
				break
	var checkpoints: Array = track.get("checkpoint_points", [])
	if checkpoints.size() < 4:
		errors.append("checkpoint_points must contain at least four entries")
	if not checkpoints.is_empty() and int(checkpoints[0]) != 0:
		errors.append("the first checkpoint must be path point 0")
	var previous := -1
	for checkpoint in checkpoints:
		var point_index := int(checkpoint)
		if point_index <= previous:
			errors.append("checkpoint_points must be strictly increasing")
		if point_index < 0 or point_index >= points.size():
			errors.append("checkpoint point %d is out of range" % point_index)
		previous = point_index
	for collection_name in ["speed_lanes", "terrain_zones", "bounce_pads"]:
		for feature in track.get(collection_name, []):
			if not (feature is Dictionary):
				errors.append("%s entries must be objects" % collection_name)
				continue
			var feature_index := int(feature.get("point_index", -1))
			if feature_index < 0 or feature_index >= points.size():
				errors.append(
					"%s feature index %d is out of range" % [collection_name, feature_index]
				)
	for collection_name in ["item_boxes", "boost_pickups"]:
		for feature_index in track.get(collection_name, []):
			if int(feature_index) < 0 or int(feature_index) >= points.size():
				errors.append("%s index %d is out of range" % [collection_name, int(feature_index)])
	for segment_color in track.get("segment_colors", []):
		if not _is_hex_color(str(segment_color)):
			errors.append("segment_colors values must be #RRGGBB colors")
	return errors


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Content file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read content file: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Expected a JSON object in %s" % path)
		return {}
	return parsed as Dictionary


static func _is_safe_identifier(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		if not (character in "abcdefghijklmnopqrstuvwxyz0123456789_"):
			return false
	return true


static func _is_hex_color(value: String) -> bool:
	if value.length() != 7 or not value.begins_with("#"):
		return false
	for character in value.substr(1):
		if not (character.to_lower() in "0123456789abcdef"):
			return false
	return true
