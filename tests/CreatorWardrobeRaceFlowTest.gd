extends SceneTree

## Acceptance flow: create → wardrobe → save → apply visual → edit same character.
## Does not teleport / force checkpoints / raise 150s. Uses temporary user:// paths.

const CreatedRacerStoreScript = preload("res://scripts/data/CreatedRacerStore.gd")
const WardrobeCatalogScript = preload("res://scripts/data/WardrobeCatalog.gd")
const RunnerProfileScript = preload("res://scripts/data/RunnerProfile.gd")
const RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")
const GarageProgressionScript = preload("res://scripts/data/GarageProgression.gd")
const ArtAcceptanceScript = preload("res://scripts/data/ArtAcceptance.gd")


func _init() -> void:
	var failures: PackedStringArray = []
	GarageProgressionScript.set_test_unlock_all(true)

	## 1) Create / customize
	var racer := CreatedRacerStoreScript.create_racer("Flow Tester", "dash_reed")
	if racer.is_empty() or str(racer.get("id", "")).is_empty():
		failures.append("create_racer failed")
	racer["appearance"]["skin_tone"] = "rich_brown"
	racer["appearance"]["hair_style"] = "box_braids"
	racer["appearance"]["assistive"] = "leg_brace_vis"
	racer["appearance"]["affects_collision"] = false
	racer["appearance"]["affects_stats"] = false

	## 2) Choose clothing + footwear
	var preset := WardrobeCatalogScript.preset("metro_pulse_default")
	if preset.is_empty():
		failures.append("metro_pulse_default preset missing")
	var slots: Dictionary = preset.get("slots", {})
	if WardrobeCatalogScript.integrated_complete_outfit_ids().is_empty():
		failures.append("no integrated complete outfit")
	slots["footwear_vehicle"] = "reedline_circlers"
	CreatedRacerStoreScript.save_outfit("metro_pulse_default", slots, true)
	racer["outfit_id"] = "metro_pulse_default"
	racer["footwear_vehicle_id"] = "reedline_circlers"
	CreatedRacerStoreScript.update_racer(racer)

	## 3) Save outfit + reload same character
	var again := CreatedRacerStoreScript.get_active()
	if str(again.get("id", "")) != str(racer.get("id", "")):
		failures.append("active racer mismatch after save")
	if str(again.get("appearance", {}).get("hair_style", "")) != "box_braids":
		failures.append("appearance not persisted")
	var outfit := CreatedRacerStoreScript.get_outfit("metro_pulse_default")
	if outfit.is_empty():
		failures.append("saved outfit missing")

	## 4) Build visual like race entry (procedural fallback + wardrobe overlays)
	var root := Node3D.new()
	root.name = "FlowRoot"
	get_root().add_child(root)
	var visual := Node3D.new()
	visual.set_script(RacerVisualScript)
	root.add_child(visual)
	var profile := RunnerProfileScript.by_id("dash_reed")
	profile.display_name = str(again.get("display_name", "Flow Tester"))
	if visual.has_method("set_menu_preview"):
		visual.set_menu_preview(true)
	if visual.has_method("apply_avatar_appearance"):
		visual.apply_avatar_appearance(again.get("appearance", {}), false)
	if visual.has_method("apply_wardrobe_outfit"):
		visual.apply_wardrobe_outfit(slots, false)
	if visual.has_method("apply_profile"):
		visual.apply_profile(profile)
	if visual.get_child_count() < 3:
		failures.append("racer visual did not build modular figure")
	if visual.get_node_or_null("WardrobeRoot") == null:
		failures.append("wardrobe root missing after outfit apply")

	## 5) Edit same character again
	again["appearance"]["hair_style"] = "locs_shoulder"
	CreatedRacerStoreScript.update_racer(again)
	var edited := CreatedRacerStoreScript.get_active()
	if str(edited.get("appearance", {}).get("hair_style", "")) != "locs_shoulder":
		failures.append("edit same character failed")

	## Capture evidence screenshot via viewport when display present; always write JSON artifact.
	var evidence := {
		"flow": "create_customize_clothing_save_race_visual_edit",
		"racer_id": str(edited.get("id", "")),
		"outfit_id": "metro_pulse_default",
		"footwear_vehicle_id": str(edited.get("footwear_vehicle_id", "")),
		"wardrobe_root_present": visual.get_node_or_null("WardrobeRoot") != null,
		"art_acceptance": ArtAcceptanceScript.counts(),
		"human_commercial_art_gate": false,
		"affects_collision": false,
		"affects_stats": false,
	}
	DirAccess.make_dir_recursive_absolute("user://creator_wardrobe_evidence")
	var ef := FileAccess.open("user://creator_wardrobe_evidence/FLOW_RESULT.json", FileAccess.WRITE)
	if ef != null:
		ef.store_string(JSON.stringify(evidence, "\t"))
	## Also mirror under res artifacts when writable (CI checkout).
	DirAccess.make_dir_recursive_absolute("res://artifacts/creator_wardrobe")
	var af := FileAccess.open("res://artifacts/creator_wardrobe/FLOW_RESULT.json", FileAccess.WRITE)
	if af != null:
		af.store_string(JSON.stringify(evidence, "\t"))
		print("EVIDENCE_PATH=res://artifacts/creator_wardrobe/FLOW_RESULT.json")
	else:
		print("EVIDENCE_PATH=user://creator_wardrobe_evidence/FLOW_RESULT.json")

	## Screenshot attempt (xvfb in CI).
	if DisplayServer.get_name() != "headless":
		var img := get_root().get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("user://creator_wardrobe_evidence/preview.png")
			print("SCREENSHOT=user://creator_wardrobe_evidence/preview.png")

	if failures.is_empty():
		print("CreatorWardrobeRaceFlowTest PASS — create/wardrobe/save/visual/edit intact")
		quit(0)
	else:
		print("CreatorWardrobeRaceFlowTest FAIL:")
		for f in failures:
			print(" - ", f)
		quit(1)
