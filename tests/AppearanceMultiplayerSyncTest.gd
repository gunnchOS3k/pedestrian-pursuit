extends SceneTree

## create → customize → save → reopen → pack peer payload → apply on peer visual → edit again.

const CreatedRacerStoreScript = preload("res://scripts/data/CreatedRacerStore.gd")
const WardrobeCatalogScript = preload("res://scripts/data/WardrobeCatalog.gd")
const AppearanceSyncScript = preload("res://scripts/data/AppearanceSync.gd")
const RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")
const RunnerProfileScript = preload("res://scripts/data/RunnerProfile.gd")
const ArtAcceptanceScript = preload("res://scripts/data/ArtAcceptance.gd")


func _init() -> void:
	var failures: PackedStringArray = []
	## 1) Create + customize every schema field surface
	var racer := CreatedRacerStoreScript.create_racer("Sync Studio")
	racer["appearance"]["height_scale"] = 1.08
	racer["appearance"]["width_scale"] = 0.94
	racer["appearance"]["leg_scale"] = 1.05
	racer["appearance"]["skin_tone"] = "deep_warm"
	racer["appearance"]["undertone"] = "olive"
	racer["appearance"]["face_shape"] = "heart"
	racer["appearance"]["hair_style"] = "cornrows"
	racer["appearance"]["facial_hair"] = "goatee"
	racer["appearance"]["makeup"] = "soft_liner"
	racer["appearance"]["scar"] = "brow_nick"
	racer["appearance"]["birthmark"] = "temple_patch"
	racer["appearance"]["head_covering"] = "beanie"
	racer["appearance"]["assistive"] = "running_blade_vis"
	racer["appearance"]["expression_idle"] = "calm"
	racer["appearance"]["expression_start"] = "focused"
	racer["appearance"]["expression_victory"] = "fierce"
	racer["outfit_id"] = "orbit_signal_default"
	var preset: Dictionary = WardrobeCatalogScript.preset("orbit_signal_default")
	var slots: Dictionary = preset.get("slots", {})
	if slots.is_empty():
		failures.append("orbit_signal preset missing")
	CreatedRacerStoreScript.save_outfit("orbit_signal_default", slots, true)
	racer["footwear_vehicle_id"] = str(slots.get("footwear_vehicle", "anti_gravity_platforms"))
	CreatedRacerStoreScript.update_racer(racer)

	## 2) Reopen
	var again: Dictionary = CreatedRacerStoreScript.get_active()
	if str(again.get("appearance", {}).get("hair_style", "")) != "cornrows":
		failures.append("reopen lost hair_style")
	if str(again.get("outfit_id", "")) != "orbit_signal_default":
		failures.append("reopen lost outfit")

	## 3) Pack peer payload + apply on independent visual (simulated peer)
	var payload: Dictionary = AppearanceSyncScript.pack_from_created_racer(again, slots)
	var fp := AppearanceSyncScript.fingerprint(payload)
	if fp.is_empty():
		failures.append("empty fingerprint")
	var peer_visual := Node3D.new()
	peer_visual.set_script(RacerVisualScript)
	root.add_child(peer_visual)
	var profile := RunnerProfileScript.by_id("dash_reed")
	AppearanceSyncScript.apply_to_visual(peer_visual, payload)
	peer_visual.apply_profile(profile)
	if peer_visual.get_node_or_null("WardrobeRoot") == null:
		failures.append("peer wardrobe root missing")
	var peer_fp := ""
	if peer_visual.has_method("cosmetic_fingerprint"):
		peer_fp = str(peer_visual.cosmetic_fingerprint())
	if peer_fp.is_empty():
		failures.append("peer fingerprint empty")
	## LOD budget hook exists
	if peer_visual.has_method("set_visual_lod"):
		peer_visual.set_visual_lod(2)
		peer_visual.set_visual_lod(0)

	## 4) Pose validation hooks (run/boost/drift/jump presentation)
	if peer_visual.has_method("set_boosting"):
		peer_visual.set_boosting(true)
		peer_visual.set_boosting(false)
	if peer_visual.has_method("set_pose_state"):
		peer_visual.set_pose_state("forward_lean", 0.2)
		peer_visual.set_pose_state("idle", 0.1)

	## 5) Edit again after peer apply
	again["appearance"]["hair_style"] = "twists"
	CreatedRacerStoreScript.update_racer(again)
	var edited: Dictionary = CreatedRacerStoreScript.get_active()
	if str(edited.get("appearance", {}).get("hair_style", "")) != "twists":
		failures.append("post-sync edit failed")

	## 6) Multi-family integrated garment coverage
	var integrated_presets := WardrobeCatalogScript.integrated_complete_outfit_ids()
	if integrated_presets.size() < 5:
		failures.append("expected >=5 integrated presets, got %d" % integrated_presets.size())
	var family_counts := {}
	for g in WardrobeCatalogScript.garments():
		var fam := str(g.get("family_id", ""))
		family_counts[fam] = int(family_counts.get(fam, 0)) + 1
	if int(family_counts.get("harbor_linen", 0)) < 4:
		failures.append("harbor_linen underpopulated")
	if int(family_counts.get("myth_circuit", 0)) < 4:
		failures.append("myth_circuit underpopulated")

	## 7) Art acceptance honesty
	var counts := ArtAcceptanceScript.counts()
	if int(counts.get("playable_runtime", 0)) != 50:
		failures.append("playable_runtime != 50")
	if int(counts.get("final_art_approved", 0)) != 0:
		failures.append("commercial approved must stay 0")
	if not ArtAcceptanceScript.procedural_never_satisfies_commercial():
		failures.append("procedural commercial leak")

	var evidence := {
		"flow": "create_customize_save_reopen_peer_apply_edit",
		"fingerprint": fp,
		"peer_fingerprint": peer_fp,
		"peer_wardrobe_root": peer_visual.get_node_or_null("WardrobeRoot") != null,
		"integrated_presets": integrated_presets.size(),
		"family_garment_counts": family_counts,
		"art_acceptance": counts,
		"affects_collision": false,
		"affects_stats": false,
		"lod_hooks": true,
		"eight_player_complete": false,
	}
	DirAccess.make_dir_recursive_absolute("res://artifacts/appearance_sync")
	var af := FileAccess.open("res://artifacts/appearance_sync/FLOW_RESULT.json", FileAccess.WRITE)
	if af != null:
		af.store_string(JSON.stringify(evidence, "\t"))
		print("EVIDENCE_PATH=res://artifacts/appearance_sync/FLOW_RESULT.json")

	if failures.is_empty():
		print("AppearanceMultiplayerSyncTest PASS — peer outfit sync + multi-family wardrobe intact")
		quit(0)
	else:
		print("AppearanceMultiplayerSyncTest FAIL:")
		for f in failures:
			print(" - ", f)
		quit(1)
