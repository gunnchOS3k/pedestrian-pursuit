extends CanvasLayer

## Results screen shown after race finish.

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var time_label: Label = $Panel/Margin/VBox/TimeLabel
@onready var position_label: Label = $Panel/Margin/VBox/PositionLabel
@onready var course_label: Label = $Panel/Margin/VBox/CourseLabel
@onready var podium_label: Label = $Panel/Margin/VBox/PodiumLabel
@onready var cup_summary_label: Label = $Panel/Margin/VBox/CupSummaryLabel
@onready var menu_button: Button = $Panel/Margin/VBox/MenuButton
@onready var retry_button: Button = $Panel/Margin/VBox/RetryButton


func _ready() -> void:
	panel.visible = false
	menu_button.pressed.connect(_on_menu)
	retry_button.pressed.connect(_on_retry)


func show_results(
	time: float,
	position: int,
	finished: bool,
	course_data: Dictionary = {},
	field_lines: PackedStringArray = PackedStringArray()
) -> void:
	panel.visible = true
	_ensure_results_art()
	title_label.text = "Race Complete!" if finished else "Race Over"
	if position == 1 and finished:
		title_label.text = "Podium Finish!"
	if GameManager.is_local_mp():
		title_label.text = "Local MP Results"
	time_label.text = "Time: %02d:%05.2f" % [int(time) / 60, fmod(time, 60.0)]
	position_label.text = "Position: %d" % position
	course_label.text = str(course_data.get("display_name", "Unknown Course"))
	GameManager.last_race_time = time
	GameManager.last_race_position = position
	GameManager.last_race_finished = finished
	podium_label.text = _build_podium_text(field_lines)
	podium_label.visible = not podium_label.text.is_empty()
	var field_block := "\n".join(field_lines) if not field_lines.is_empty() else ""
	if GameManager.is_cup_active():
		var total_time := GameManager.get_cup_total_time()
		var standings := "\n".join(GameManager.get_cup_standings_lines())
		cup_summary_label.text = (
			"%s  •  %d points  •  %02d:%05.2f total\n%s\n%s"
			% [
				GameManager.get_cup_round_label(),
				GameManager.get_cup_total_points(),
				int(total_time) / 60,
				fmod(total_time, 60.0),
				field_block,
				standings if not standings.is_empty() else "Standings pending",
			]
		)
		if GameManager.has_next_cup_race():
			retry_button.text = "Next Course"
		else:
			title_label.text = "Cup Complete!"
			retry_button.text = "Race Cup Again"
			GameManager.save_cup_progress()
	elif GameManager.is_local_mp():
		cup_summary_label.text = (
			"Couch session — career XP not written.\nField:\n%s" % field_block
			if not field_block.is_empty()
			else "Couch session — career XP not written."
		)
		retry_button.text = "Rematch"
	else:
		cup_summary_label.text = (
			("Field:\n%s\n\nSingle-course race" % field_block)
			if not field_block.is_empty()
			else "Single-course race"
		)
		retry_button.text = "Race Again"


func annotate_local_mp(finish_results: Array) -> void:
	## Ensure P1/P2 tags survive even if field_lines were built early.
	if not GameManager.is_local_mp():
		return
	var tagged := PackedStringArray()
	var place := 1
	for entry in finish_results:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var racer: Node = entry.get("racer")
		var name := "Runner"
		if racer != null and racer.has_meta("runner_display_name"):
			name = str(racer.get_meta("runner_display_name"))
		var tag := ""
		if bool(entry.get("is_player", false)):
			var idx := int(entry.get("local_player_index", 0))
			if racer != null and "local_player_index" in racer:
				idx = int(racer.local_player_index)
			tag = " (P1)" if idx == 0 else " (P2)"
		tagged.append("%d. %s%s" % [place, name, tag])
		place += 1
	podium_label.text = _build_podium_text(tagged)
	podium_label.visible = not podium_label.text.is_empty()
	cup_summary_label.text = "Couch session — career XP not written.\nField:\n%s" % "\n".join(tagged)


func _build_podium_text(field_lines: PackedStringArray) -> String:
	if field_lines.is_empty():
		return ""
	var medals := ["🥇", "🥈", "🥉"]
	var slots: PackedStringArray = []
	for i in mini(3, field_lines.size()):
		var name := str(field_lines[i])
		# Strip leading "1. " style place numbers for a cleaner podium row.
		var clean := name
		var dot := name.find(". ")
		if dot >= 0 and dot < 3:
			clean = name.substr(dot + 2)
		slots.append("%s %s" % [medals[i], clean])
	return "Podium\n" + "\n".join(slots)


func hide_results() -> void:
	panel.visible = false


func _ensure_results_art() -> void:
	if get_node_or_null("ResultsArt") != null:
		return
	var tex := LaunchArtCatalog.ui_texture("results_panel")
	if tex == null:
		return
	var art := TextureRect.new()
	art.name = "ResultsArt"
	art.texture = tex
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.modulate = Color(1, 1, 1, 0.45)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	move_child(art, 0)


func _on_menu() -> void:
	GameManager.clear_cup()
	var tree := get_tree()
	if tree != null and tree.paused:
		tree.paused = false
	SceneLoader.go_to_main_menu()


func _on_retry() -> void:
	var tree := get_tree()
	if tree != null and tree.paused:
		tree.paused = false
	hide_results()
	if GameManager.is_cup_active():
		if GameManager.has_next_cup_race():
			GameManager.advance_cup()
			SceneLoader.restart_race("cup_next")
		else:
			GameManager.restart_cup()
			SceneLoader.restart_race("cup_restart")
	else:
		SceneLoader.restart_race("rematch")
