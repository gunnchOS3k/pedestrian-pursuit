extends RefCounted
class_name CourseSelectPreviewV4

const IDENTITY := preload("res://scripts/gamefeel/CourseIdentityCatalog.gd")


static func card_text(track_id: String) -> String:
	if IDENTITY.has_method("preview_copy"):
		return IDENTITY.preview_copy(track_id)
	return str(track_id)


static func card_lines(track_id: String) -> PackedStringArray:
	var text := card_text(track_id)
	return PackedStringArray(text.split("\n"))
