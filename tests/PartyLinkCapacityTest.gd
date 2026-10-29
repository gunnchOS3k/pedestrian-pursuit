extends SceneTree

## PartyLink capacity 2–8: seat ownership + field fill. Bots never count as humans.
## Preserves BeatLink sibling 2-human contract; does not claim physical 8p or Mac MoltenVK.

const OnlineArchitectureScript = preload("res://scripts/net/OnlineArchitecture.gd")
const TrackCatalogScript = preload("res://scripts/data/TrackCatalog.gd")
const CourseTrackScript = preload("res://scripts/tracks/CourseTrack.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	var desc: Dictionary = OnlineArchitectureScript.describe()
	var pl: Dictionary = desc.get("partylink", {})
	if int(pl.get("min_human_seats", 0)) != 2:
		failures.append("partylink min_human_seats != 2")
	if int(pl.get("max_human_seats", 0)) != 8:
		failures.append("partylink max_human_seats != 8")
	if int(pl.get("field_size", 0)) != 8:
		failures.append("partylink field_size != 8")
	if int(pl.get("beatlink_sibling_contract_humans", 0)) != 2:
		failures.append("BeatLink sibling contract humans must stay 2")
	if bool(pl.get("physical_eight_human_party", true)):
		failures.append("physical_eight_human_party must stay false")
	if not bool(pl.get("bots_never_count_as_humans", false)):
		failures.append("bots_never_count_as_humans required")

	for seats in range(2, 9):
		var seat_map: Dictionary = OnlineArchitectureScript.partylink_seat_map(seats)
		if int(seat_map.get("human_seats", 0)) != seats:
			failures.append("seat_map human_seats %d != %d" % [int(seat_map.get("human_seats", 0)), seats])
		if int(seat_map.get("cpu_seats", -1)) != 8 - seats:
			failures.append("seat_map cpu_seats wrong for %d humans" % seats)
		var humans := 0
		for entry in seat_map.get("seats", []):
			if typeof(entry) != TYPE_DICTIONARY:
				failures.append("bad seat entry")
				continue
			if bool(entry.get("counts_as_human_participant", false)):
				humans += 1
				if str(entry.get("owner", "")) != "human":
					failures.append("human participant owner mismatch")
			elif str(entry.get("owner", "")) != "cpu":
				failures.append("non-human seat must be cpu")
		if humans != seats:
			failures.append("counted humans %d != requested %d" % [humans, seats])

	## Clamp honesty: out-of-range requests still stay 2–8.
	if int(OnlineArchitectureScript.partylink_seat_map(1).get("human_seats", 0)) != 2:
		failures.append("under-min seats must clamp to 2")
	if int(OnlineArchitectureScript.partylink_seat_map(99).get("human_seats", 0)) != 8:
		failures.append("over-max seats must clamp to 8")

	var gm = preload("res://scripts/core/GameManager.gd").new()
	root.add_child(gm)
	gm.start_party_link("lantern_corridor", 8)
	if not gm.is_party_link():
		failures.append("start_party_link did not activate")
	if int(gm.party_link_human_seats) != 8:
		failures.append("party_link_human_seats not 8")
	if int(gm.ai_field_size) != 7:
		failures.append("party_link field should be player + 7 AI = 8")
	if not gm.has_meta("party_link_seat_map"):
		failures.append("missing party_link_seat_map meta")

	## Course still builds under PartyLink track pick (Neon Night candidate).
	var data := TrackCatalogScript.load_track("lantern_corridor")
	var course: Node = CourseTrackScript.new()
	root.add_child(course)
	course.configure(data)
	if not course.build():
		failures.append("lantern_corridor failed to build under PartyLink probe")
	elif course.get_node_or_null("NeonFill") == null:
		failures.append("PartyLink probe missing NeonFill")
	course.queue_free()

	if failures.is_empty():
		print(
			"PartyLinkCapacityTest PASS — seats 2..8 · field 8 · BeatLink sibling humans 2 · bots not humans · physical 8p false"
		)
		quit(0)
		return
	print("PartyLinkCapacityTest FAIL:")
	for f in failures:
		print(" - ", f)
	quit(1)
