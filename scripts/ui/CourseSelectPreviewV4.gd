extends RefCounted
class_name CourseSelectPreviewV4

## Static preview copy helper — call CourseIdentityCatalog statics directly (Godot 4.3).

const IDENTITY := preload("res://scripts/gamefeel/CourseIdentityCatalog.gd")


static func card_text(track_id: String) -> String:
	return IDENTITY.preview_copy(track_id)


static func card_lines(track_id: String) -> PackedStringArray:
	var text := card_text(track_id)
	return PackedStringArray(text.split("\n"))
