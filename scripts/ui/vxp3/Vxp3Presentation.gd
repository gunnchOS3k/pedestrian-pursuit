extends RefCounted
class_name Vxp3Presentation

## Applies VXP-3 player presentation to live UI without changing gameplay contracts.

const BRAND := preload("res://scripts/ui/vxp3/Vxp3Brand.gd")


static func recomposite_main_menu(menu: Control) -> void:
	if menu == null:
		return
	BRAND.apply_surface_chrome(menu, {"title_size": BRAND.TYPE_DISPLAY})
	_ensure_hero(menu)
	var vbox := menu.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return
	var title := vbox.get_node_or_null("Title") as Label
	if title:
		title.text = "Pedestrian Pursuit"
		title.visible = true
		var df := BRAND.display_font_bold()
		if df:
			title.add_theme_font_override("font", df)
	var subtitle := vbox.get_node_or_null("Subtitle") as Label
	if subtitle:
		subtitle.text = BRAND.player_subtitle()
		subtitle.add_theme_color_override("font_color", BRAND.COLOR_MUTED)
	var cup := vbox.get_node_or_null("CupLabel") as Label
	if cup:
		cup.text = "Sole Surge Cup  ·  Championship courses"
		cup.add_theme_color_override("font_color", BRAND.COLOR_BOOST_CYAN)
	## Primary CTAs
	var race := vbox.get_node_or_null("SingleRaceButton") as Button
	if race:
		race.text = "RACE"
		BRAND.style_primary_cta(race)
	var start_cup := vbox.get_node_or_null("StartCupButton") as Button
	if start_cup:
		start_cup.text = "Championship"
		## Explicitly clear any prior primary CTA chrome so RACE stays sole hero action.
		start_cup.remove_theme_stylebox_override("normal")
		start_cup.remove_theme_stylebox_override("hover")
		start_cup.remove_theme_stylebox_override("pressed")
		start_cup.remove_theme_color_override("font_color")
		BRAND.style_secondary_control(start_cup)
		start_cup.custom_minimum_size.y = maxf(start_cup.custom_minimum_size.y, 48.0)
		start_cup.add_theme_color_override("font_color", BRAND.COLOR_INK)
	## Mode strip labels
	_relabel_button(vbox, "TimeTrialButton", "Time Trial")
	_relabel_button(vbox, "LocalMPButton", "Local 2P")
	_relabel_button(vbox, "TutorialButton", "Learn the Track")
	_relabel_button(vbox, "ChallengesButton", "Challenges")
	## Demote meta surfaces
	_relabel_button(vbox, "ProgressionButton", "Progression")
	_relabel_button(vbox, "AchievementsButton", "Achievements")
	_relabel_button(vbox, "HowToPlayButton", "How to Play")
	_relabel_button(vbox, "QuitButton", "Exit")
	for name in ["ProgressionButton", "AchievementsButton", "HowToPlayButton", "QuitButton"]:
		var b := vbox.get_node_or_null(name) as Button
		if b:
			BRAND.style_secondary_control(b)
			b.add_theme_color_override("font_color", BRAND.COLOR_MUTED)
	## Device role → Advanced / Device Lab
	var device_label := vbox.get_node_or_null("DeviceLabel") as Label
	if device_label:
		device_label.text = "Advanced · Device Lab"
		device_label.add_theme_color_override("font_color", BRAND.COLOR_MUTED)
		device_label.add_theme_font_size_override("font_size", BRAND.TYPE_METADATA)
	var device_hint := vbox.get_node_or_null("DeviceHint") as Label
	if device_hint:
		device_hint.add_theme_color_override("font_color", BRAND.COLOR_MUTED)
	_reorder_primary(vbox)
	_refresh_shoe_copy(menu)
	_style_pickers(vbox)


static func _ensure_hero(menu: Control) -> void:
	if menu.get_node_or_null("Vxp3Hero") != null:
		return
	var hero := HBoxContainer.new()
	hero.name = "Vxp3Hero"
	hero.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hero.offset_left = 32
	hero.offset_right = -32
	hero.offset_top = 24
	hero.offset_bottom = 120
	hero.add_theme_constant_override("separation", 16)
	menu.add_child(hero)
	menu.move_child(hero, 1)
	var mark := TextureRect.new()
	mark.custom_minimum_size = Vector2(88, 88)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.texture = BRAND.mark_texture(BRAND.high_contrast_active())
	hero.add_child(mark)
	var word := TextureRect.new()
	word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word.custom_minimum_size = Vector2(320, 72)
	word.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	word.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	word.texture = BRAND.wordmark_texture()
	hero.add_child(word)


static func _relabel_button(vbox: VBoxContainer, node_name: String, text: String) -> void:
	var b := vbox.get_node_or_null(node_name) as Button
	if b:
		b.text = text
		BRAND.style_secondary_control(b)


static func _reorder_primary(vbox: VBoxContainer) -> void:
	## Keep routes; prefer Race / Championship near top after pickers.
	var race := vbox.get_node_or_null("SingleRaceButton")
	var cup := vbox.get_node_or_null("StartCupButton")
	var course := vbox.get_node_or_null("CoursePicker")
	if race and cup and course:
		var base := course.get_index() + 1
		vbox.move_child(race, base)
		vbox.move_child(cup, base + 1)
	var resume := vbox.get_node_or_null("ResumeCupButton") as Button
	if resume and cup:
		resume.visible = resume.visible  # truth already gated by save
		vbox.move_child(resume, cup.get_index() + 1)


static func _refresh_shoe_copy(menu: Control) -> void:
	var info := menu.get_node_or_null("VBox/ShoeInfo") as Label
	if info == null:
		var shoe_picker := menu.get_node_or_null("VBox/ShoePicker")
		if shoe_picker == null:
			return
		info = Label.new()
		info.name = "ShoeInfo"
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", BRAND.TYPE_METADATA)
		info.add_theme_color_override("font_color", BRAND.COLOR_MUTED)
		var vbox: VBoxContainer = menu.get_node("VBox")
		vbox.add_child(info)
		vbox.move_child(info, shoe_picker.get_index() + 1)


static func first_run_copy() -> Dictionary:
	return {
		"title": "Learn the Track",
		"body": "A short course run teaches sprint, drift sparks, Perfect Step, jumps, items, and footwear surfaces — then you’re free to race.",
		"start": "Start Tutorial",
		"race_now": "Race Now",
	}


static func apply_pause_chrome(pause: CanvasLayer) -> void:
	var panel := pause.get_node_or_null("Panel") as PanelContainer
	if panel and BRAND.theme():
		panel.theme = BRAND.theme()
	var resume := pause.get_node_or_null("Panel/Margin/VBox/ResumeButton") as Button
	if resume:
		resume.text = "Resume"
		BRAND.style_primary_cta(resume)
	var title := pause.get_node_or_null("Panel/Margin/VBox/Title") as Label
	if title:
		title.add_theme_color_override("font_color", BRAND.COLOR_MIDSOLE_YELLOW)
	_ensure_tutorial_guide(pause)


static func _ensure_tutorial_guide(pause: CanvasLayer) -> void:
	var vbox := pause.get_node_or_null("Panel/Margin/VBox") as VBoxContainer
	if vbox == null or vbox.get_node_or_null("TutorialGuideButton") != null:
		return
	var btn := Button.new()
	btn.name = "TutorialGuideButton"
	btn.text = "Tutorial Guide"
	btn.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(btn)
	var menu_btn := vbox.get_node_or_null("MenuButton")
	if menu_btn:
		vbox.move_child(btn, menu_btn.get_index())
	btn.pressed.connect(func ():
		var director := pause.get_tree().root.find_child("TutorialDirector", true, false)
		if director and director.has_method("begin"):
			director.begin(false)
			return
		var coach := pause.get_tree().root.find_child("TutorialCoach", true, false)
		if coach and coach.has_method("show_tip"):
			coach.show_tip(
				"pause_guide",
				"Tutorial Guide",
				"Sprint W · Steer A/D · Drift Shift · Jump Space · Boost Q · Item E · Pause Esc. Footwear materials change surface feel.",
				false
			)
	)


static func apply_results_chrome(results: CanvasLayer) -> void:
	var panel := results.get_node_or_null("Panel") as PanelContainer
	if panel and BRAND.theme():
		panel.theme = BRAND.theme()
	var title := results.get_node_or_null("Panel/Margin/VBox/TitleLabel") as Label
	if title:
		title.add_theme_color_override("font_color", BRAND.COLOR_MIDSOLE_YELLOW)
		title.add_theme_font_size_override("font_size", BRAND.TYPE_RACE_TITLE)


static func podium_glyph_prefix(place: int) -> String:
	## Accessible text fallback paired with TextureRect glyphs in ResultsScreen.
	match place:
		1:
			return "1st"
		2:
			return "2nd"
		3:
			return "3rd"
		_:
			return "%d." % place


static func ensure_podium_glyphs(results: CanvasLayer, field_lines: PackedStringArray) -> void:
	## Replace placeholder [1]/[2]/[3] text rows with glyph + accessible text.
	if results == null:
		return
	var vbox := results.get_node_or_null("Panel/Margin/VBox") as VBoxContainer
	if vbox == null:
		return
	var row := vbox.get_node_or_null("PodiumRow") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "PodiumRow"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		vbox.add_child(row)
		var podium_label := vbox.get_node_or_null("PodiumLabel")
		if podium_label:
			vbox.move_child(row, podium_label.get_index())
	for c in row.get_children():
		c.queue_free()
	for i in mini(3, field_lines.size()):
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(48, 48)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture = BRAND.glyph_texture("podium_%d" % (i + 1))
		tex.tooltip_text = podium_glyph_prefix(i + 1)
		slot.add_child(tex)
		var lab := Label.new()
		var name := str(field_lines[i])
		var dot := name.find(". ")
		if dot >= 0 and dot < 3:
			name = name.substr(dot + 2)
		lab.text = "%s · %s" % [podium_glyph_prefix(i + 1), name]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", BRAND.TYPE_METADATA)
		lab.add_theme_color_override("font_color", BRAND.COLOR_INK)
		slot.add_child(lab)
		row.add_child(slot)
	var legacy := vbox.get_node_or_null("PodiumLabel") as Label
	if legacy:
		## Keep accessible summary; hide raw placeholder look.
		legacy.visible = false


static func apply_hud_chrome(hud: CanvasLayer) -> void:
	if hud == null:
		return
	var t := BRAND.theme()
	var margin := hud.get_node_or_null("Margin") as Control
	if margin and t:
		margin.theme = t
	_recluster_hud(hud)
	for path in ["Margin/VBox/LapLabel", "Margin/VBox/PositionLabel", "Margin/VBox/TimerLabel"]:
		var lab := hud.get_node_or_null(path) as Label
		if lab:
			lab.add_theme_font_size_override("font_size", BRAND.TYPE_HUD_PRIMARY)
			lab.add_theme_color_override("font_color", BRAND.COLOR_INK)
	var pos := hud.get_node_or_null("Margin/VBox/PositionLabel") as Label
	if pos:
		pos.add_theme_font_size_override("font_size", BRAND.TYPE_POSITION_NUMBER)
		pos.add_theme_color_override("font_color", BRAND.COLOR_KINETIC_ORANGE)
		## Strip redundant "Position:" engineer stacking if present.
		var tpos := pos.text
		if tpos.begins_with("Position:"):
			pos.text = tpos.replace("Position:", "P").strip_edges()
	var lap := hud.get_node_or_null("Margin/VBox/LapLabel") as Label
	if lap and lap.text.begins_with("Lap:"):
		lap.text = lap.text.replace("Lap:", "L").strip_edges()
	var timer := hud.get_node_or_null("Margin/VBox/TimerLabel") as Label
	if timer:
		timer.add_theme_font_size_override("font_size", BRAND.TYPE_TIMING_NUMBER)
		timer.add_theme_color_override("font_color", BRAND.COLOR_BOOST_CYAN)
	var boost := hud.get_node_or_null("Margin/VBox/BoostBar") as ProgressBar
	if boost:
		boost.modulate = BRAND.COLOR_BOOST_CYAN
	var course := hud.get_node_or_null("CourseLabel") as Label
	if course:
		course.add_theme_color_override("font_color", BRAND.COLOR_INK)
		course.add_theme_font_size_override("font_size", BRAND.TYPE_COURSE_NAME - 2)
		course.modulate = Color(1, 1, 1, 0.92)
	## Demote device-lab map noise unless Advanced role needs it
	var map_lab := hud.get_node_or_null("MapProfileLabel") as Label
	if map_lab:
		map_lab.add_theme_color_override("font_color", BRAND.COLOR_MUTED)
		map_lab.add_theme_font_size_override("font_size", BRAND.TYPE_METADATA)
		map_lab.modulate.a = 0.55


static func _recluster_hud(hud: CanvasLayer) -> void:
	## Collapse stacked Map/Lap/Position/Time/Speed/Item into primary + secondary clusters.
	var vbox := hud.get_node_or_null("Margin/VBox") as VBoxContainer
	if vbox == null or vbox.get_node_or_null("HudCluster") != null:
		return
	var cluster := VBoxContainer.new()
	cluster.name = "HudCluster"
	cluster.add_theme_constant_override("separation", 6)
	vbox.add_child(cluster)
	vbox.move_child(cluster, 0)
	var primary := HBoxContainer.new()
	primary.name = "PrimaryRaceReadouts"
	primary.add_theme_constant_override("separation", 16)
	cluster.add_child(primary)
	for n in ["PositionLabel", "LapLabel", "TimerLabel"]:
		var node := vbox.get_node_or_null(n)
		if node:
			vbox.remove_child(node)
			primary.add_child(node)
	var secondary := HBoxContainer.new()
	secondary.name = "SecondaryMeters"
	secondary.add_theme_constant_override("separation", 12)
	cluster.add_child(secondary)
	for n in ["SpeedLabel", "ItemLabel", "BoostBar", "DriftMeter", "DriftSparkIcon", "FootwearLabel"]:
		var node2 := vbox.get_node_or_null(n)
		if node2:
			vbox.remove_child(node2)
			secondary.add_child(node2)


static func apply_toast_chrome(toast: CanvasLayer) -> void:
	var panel := toast.get_node_or_null("PanelContainer") as PanelContainer
	if panel == null:
		## AchievementToast builds panel unnamed as first child
		for c in toast.get_children():
			if c is PanelContainer:
				panel = c
				break
	if panel and BRAND.theme():
		panel.theme = BRAND.theme()
	if panel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(BRAND.COLOR_PANEL.r, BRAND.COLOR_PANEL.g, BRAND.COLOR_PANEL.b, 0.96)
		sb.border_color = BRAND.COLOR_MIDSOLE_YELLOW
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", sb)


static func _style_pickers(vbox: VBoxContainer) -> void:
	## Soften raw OptionButton form-lab look without removing selection contracts.
	for name in ["RunnerPicker", "CoursePicker", "ShoePicker", "CupPicker", "DevicePicker"]:
		var ob := vbox.get_node_or_null(name) as OptionButton
		if ob == null:
			continue
		ob.custom_minimum_size.y = maxf(ob.custom_minimum_size.y, BRAND.TOUCH_MIN)
		ob.add_theme_font_size_override("font_size", BRAND.TYPE_CONTROL)
		ob.add_theme_color_override("font_color", BRAND.COLOR_INK)
		var sb := StyleBoxFlat.new()
		sb.bg_color = BRAND.COLOR_PANEL
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		ob.add_theme_stylebox_override("normal", sb)
