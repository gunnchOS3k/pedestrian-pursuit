extends CanvasLayer

## Debug/review watermark only. Hidden in release UI.

func _ready() -> void:
	layer = 128
	if not OS.is_debug_build():
		return
	var identity := get_node_or_null("/root/BuildIdentity")
	var label := Label.new()
	label.name = "BuildWatermarkLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	if identity != null and identity.has_method("watermark_text"):
		label.text = str(identity.watermark_text())
	else:
		label.text = "PP UNKNOWN"
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.offset_left = -220
	label.offset_top = 8
	label.offset_right = -12
	label.offset_bottom = 32
	add_child(label)
