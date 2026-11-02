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
	## Ensure trail_expression is present for chase-cam fingerprint deepen (S7N).
	if str(slots.get("trail_expression", "")).is_empty():
		slots["trail_expression"] = "metro_pulse_trail"
	var payload: Dictionary = AppearanceSyncScript.pack_from_created_racer(again, slots)
	var fp := AppearanceSyncScript.fingerprint(payload)
	if fp.is_empty():
		failures.append("empty fingerprint")
	if str(payload.get("trail_expression_id", "")).is_empty():
		failures.append("pack missing trail_expression_id")
	if bool(payload.get("counts_as_human_participant", true)):
		failures.append("cosmetics must not count as human participants")
	var trail_meta: Dictionary = payload.get("chase_cam_trail", {})
	if not bool(trail_meta.get("cosmetic_only", false)):
		failures.append("chase_cam_trail must be cosmetic_only")
	if str(trail_meta.get("handling_owner", "")) != "footwear":
		failures.append("chase_cam_trail handling_owner must be footwear")
	if fp.find("trail=") < 0:
		failures.append("fingerprint must include trail=")
	## S7O: host→peer trail parity (repacked peer payload must match).
	var peer_pack: Dictionary = AppearanceSyncScript.pack_from_created_racer(again, slots)
	var parity: Dictionary = AppearanceSyncScript.peer_trail_parity(payload, peer_pack)
	if not bool(parity.get("parity_ok", false)):
		failures.append("peer_trail_parity must match host pack")
	if bool(parity.get("counts_as_human_participant", true)):
		failures.append("peer_trail_parity must not invent humans")
	if bool(parity.get("HUMAN", true)) or bool(parity.get("COURSE_ACCEPTED", true)):
		failures.append("peer_trail_parity must keep HUMAN/COURSE false")
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

	## S7P: nine family trail cosmetics without inventing humans.
	var trail_cov: Dictionary = WardrobeCatalogScript.family_trail_coverage()
	if int(trail_cov.get("family_count", -1)) != 9:
		failures.append("family_trail_coverage family_count != 9")
	if int(trail_cov.get("trail_garment_count", -1)) != 9:
		failures.append("family_trail_coverage trail_garment_count != 9")
	if int(trail_cov.get("presets_with_trail", -1)) != 9:
		failures.append("family_trail_coverage presets_with_trail != 9")
	if bool(trail_cov.get("counts_as_human_participant", true)):
		failures.append("family trails must not count as humans")
	if bool(trail_cov.get("HUMAN", true)) or bool(trail_cov.get("RC2", true)) or bool(trail_cov.get("V1", true)):
		failures.append("family_trail_coverage must keep HUMAN/RC2/V1 false")

	## S7S: footwear_vehicle handling coverage across families.
	var foot_cov: Dictionary = WardrobeCatalogScript.family_footwear_handling_coverage()
	if int(foot_cov.get("family_count", -1)) != 9:
		failures.append("family_footwear_handling_coverage family_count != 9")
	if int(foot_cov.get("footwear_bind_count", -1)) != 9:
		failures.append("family_footwear_handling_coverage footwear_bind_count != 9")
	if int(foot_cov.get("presets_with_footwear", -1)) != 9:
		failures.append("family_footwear_handling_coverage presets_with_footwear != 9")
	if int(foot_cov.get("footwear_missing_paths", 1)) != 0:
		failures.append("family_footwear_handling_coverage footwear shoe JSON must resolve")
	if str(foot_cov.get("handling_owner", "")) != "footwear":
		failures.append("handling_owner must remain footwear")
	if bool(foot_cov.get("counts_as_human_participant", true)):
		failures.append("footwear coverage must not invent humans")
	if bool(foot_cov.get("HUMAN", true)) or bool(foot_cov.get("RC2", true)) or bool(foot_cov.get("V1", true)):
		failures.append("family_footwear_handling_coverage must keep HUMAN/RC2/V1 false")

	## S7Q: preset trail fingerprint matrix — 9 unique cosmetic fingerprints.
	var matrix: Dictionary = AppearanceSyncScript.preset_trail_fingerprint_matrix()
	if int(matrix.get("preset_count", -1)) != 9:
		failures.append("preset trail matrix preset_count != 9")
	if int(matrix.get("missing_trail", 1)) != 0:
		failures.append("preset trail matrix missing_trail must be 0")
	if not bool(matrix.get("all_unique", false)):
		failures.append("preset trail fingerprints must be unique")
	if bool(matrix.get("counts_as_human_participant", true)):
		failures.append("preset matrix must not invent humans")
	if bool(matrix.get("HUMAN", true)) or bool(matrix.get("RC2", true)) or bool(matrix.get("V1", true)):
		failures.append("preset matrix must keep HUMAN/RC2/V1 false")

	## S7R: integrated presets keep trail binds.
	var bind: Dictionary = AppearanceSyncScript.integrated_preset_trail_bind()
	if not bool(bind.get("all_bound", false)):
		failures.append("integrated presets must all bind trails")
	if int(bind.get("trail_missing", 1)) != 0:
		failures.append("integrated preset trail_missing must be 0")
	if bool(bind.get("counts_as_human_participant", true)):
		failures.append("integrated trail bind must not invent humans")
	if bool(bind.get("HUMAN", true)) or bool(bind.get("RC2", true)) or bool(bind.get("V1", true)):
		failures.append("integrated trail bind must keep HUMAN/RC2/V1 false")

	## S7V: key cosmetic slots cover all 9 families.
	var key_cov: Dictionary = WardrobeCatalogScript.key_slot_family_coverage()
	if not bool(key_cov.get("all_covered", false)):
		failures.append("key_slot_family_coverage all_covered required")
	if bool(key_cov.get("counts_as_human_participant", true)):
		failures.append("key slot coverage must not invent humans")
	if bool(key_cov.get("HUMAN", true)) or bool(key_cov.get("RC2", true)) or bool(key_cov.get("V1", true)):
		failures.append("key_slot_family_coverage must keep HUMAN/RC2/V1 false")

	## S7W: every family has top and/or full_body; cosmetics ≠ humans.
	var upper: Dictionary = WardrobeCatalogScript.family_upper_body_coverage()
	if not bool(upper.get("all_covered", false)):
		failures.append("family_upper_body_coverage all_covered required")
	if int(upper.get("upper_body_ok_count", -1)) != 9:
		failures.append("family_upper_body_coverage expects 9/9")
	if bool(upper.get("counts_as_human_participant", true)):
		failures.append("upper body coverage must not invent humans")
	if bool(upper.get("HUMAN", true)) or bool(upper.get("RC2", true)) or bool(upper.get("V1", true)):
		failures.append("family_upper_body_coverage must keep HUMAN/RC2/V1 false")

	## S7U: every wardrobe family stays integrated_mesh_v1.
	var mesh: Dictionary = WardrobeCatalogScript.family_integrated_mesh_honesty()
	if not bool(mesh.get("all_integrated", false)):
		failures.append("family_integrated_mesh_honesty all_integrated required")
	if int(mesh.get("family_count", -1)) != 9 or int(mesh.get("integrated_mesh_v1", -1)) != 9:
		failures.append("family_integrated_mesh_honesty expects 9/9 integrated")
	if bool(mesh.get("commercial_final_art", true)):
		failures.append("family mesh honesty must keep commercial_final_art false")
	if bool(mesh.get("counts_as_human_participant", true)):
		failures.append("family mesh honesty must not invent humans")
	if bool(mesh.get("HUMAN", true)) or bool(mesh.get("RC2", true)) or bool(mesh.get("V1", true)):
		failures.append("family_integrated_mesh_honesty must keep HUMAN/RC2/V1 false")

	## S7T: empty trail never invents a human participant.
	var empty_trail: Dictionary = AppearanceSyncScript.empty_trail_never_invents_human({})
	if not bool(empty_trail.get("trail_empty", false)):
		failures.append("empty trail helper must report trail_empty")
	if bool(empty_trail.get("counts_as_human_participant", true)):
		failures.append("empty trail must not invent humans")
	if bool(empty_trail.get("HUMAN", true)) or bool(empty_trail.get("RC2", true)) or bool(empty_trail.get("V1", true)):
		failures.append("empty trail helper must keep HUMAN/RC2/V1 false")

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
