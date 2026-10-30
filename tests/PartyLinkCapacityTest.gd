extends SceneTree

## PartyLink capacity 2–8: allocated seats vs connected humans vs CPU fill.
## Bots never count as humans. BeatLink sibling stays 2. Physical 8p / Metal false.

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

	## Allocated capacity map: never invents connected humans.
	for seats in range(2, 9):
		var seat_map: Dictionary = OnlineArchitectureScript.partylink_seat_map(seats)
		if int(seat_map.get("allocated_human_seats", 0)) != seats:
			failures.append("seat_map allocated %d != %d" % [int(seat_map.get("allocated_human_seats", 0)), seats])
		if int(seat_map.get("connected_humans", -1)) != 0:
			failures.append("capacity map must not invent connected humans")
		if int(seat_map.get("cpu_seats", -1)) != 8 - seats:
			failures.append("seat_map cpu_seats wrong for %d allocated" % seats)
		var claimed_humans := 0
		var allocated_flags := 0
		for entry in seat_map.get("seats", []):
			if typeof(entry) != TYPE_DICTIONARY:
				failures.append("bad seat entry")
				continue
			if bool(entry.get("counts_as_human_participant", false)):
				claimed_humans += 1
			if bool(entry.get("allocated_human_capacity", false)):
				allocated_flags += 1
		if claimed_humans != 0:
			failures.append("capacity map must not count allocated seats as connected humans")
		if allocated_flags != seats:
			failures.append("allocated_human_capacity flags %d != %d" % [allocated_flags, seats])

	## Runtime roster: connected ≤ allocated; CPU fills the rest; bots ≠ humans.
	for allocated in range(2, 9):
		for connected in range(0, allocated + 1):
			var roster: Dictionary = OnlineArchitectureScript.partylink_runtime_roster(allocated, connected)
			if int(roster.get("allocated_human_seats", -1)) != allocated:
				failures.append("roster allocated mismatch")
			if int(roster.get("connected_humans", -1)) != connected:
				failures.append("roster connected mismatch a=%d c=%d" % [allocated, connected])
			if int(roster.get("cpu_seats", -1)) != 8 - connected:
				failures.append("roster cpu_seats wrong a=%d c=%d" % [allocated, connected])
			if bool(roster.get("physical_eight_human_party", true)):
				failures.append("roster must keep physical_eight_human_party false")
			if bool(roster.get("COURSE_ACCEPTED", true)):
				failures.append("roster COURSE_ACCEPTED must stay false")
			var humans := 0
			var cpus := 0
			for entry in roster.get("seats", []):
				if bool(entry.get("counts_as_human_participant", false)):
					humans += 1
					if str(entry.get("owner", "")) != "human":
						failures.append("human participant owner mismatch")
					if str(entry.get("control", "")) != "human_input":
						failures.append("human control mismatch")
				else:
					cpus += 1
					if str(entry.get("owner", "")) != "cpu":
						failures.append("non-human seat must be cpu")
			if humans != connected:
				failures.append("counted humans %d != connected %d" % [humans, connected])
			if cpus != 8 - connected:
				failures.append("counted cpus wrong")

	## Clamp honesty: out-of-range requests still stay 2–8 allocated; connected clamps.
	if int(OnlineArchitectureScript.partylink_seat_map(1).get("allocated_human_seats", 0)) != 2:
		failures.append("under-min seats must clamp to 2")
	if int(OnlineArchitectureScript.partylink_seat_map(99).get("allocated_human_seats", 0)) != 8:
		failures.append("over-max seats must clamp to 8")
	if int(OnlineArchitectureScript.partylink_runtime_roster(8, 99).get("connected_humans", -1)) != 8:
		failures.append("connected must clamp to allocated max")
	if int(OnlineArchitectureScript.partylink_runtime_roster(4, 8).get("connected_humans", -1)) != 4:
		failures.append("connected must not exceed allocated")

	var gm = preload("res://scripts/core/GameManager.gd").new()
	root.add_child(gm)
	## Allocated 8, connected 1 local — honest single-device PartyLink field.
	gm.start_party_link("lantern_corridor", 8, 1)
	if not gm.is_party_link():
		failures.append("start_party_link did not activate")
	if int(gm.party_link_human_seats) != 8:
		failures.append("party_link_human_seats not 8")
	if int(gm.party_link_connected_humans) != 1:
		failures.append("party_link_connected_humans must stay 1 (do not invent humans)")
	if int(gm.ai_field_size) != 7:
		failures.append("party_link field should be player + 7 AI = 8")
	if not gm.has_meta("party_link_seat_map"):
		failures.append("missing party_link_seat_map meta")
	if not gm.has_meta("party_link_runtime_roster"):
		failures.append("missing party_link_runtime_roster meta")
	else:
		var live: Dictionary = gm.get_meta("party_link_runtime_roster")
		if int(live.get("connected_humans", -1)) != 1:
			failures.append("runtime roster connected_humans != 1")
		if int(live.get("cpu_seats", -1)) != 7:
			failures.append("runtime roster cpu_seats != 7")

	## BeatLink-sibling dual connected (2h+6cpu) — still bots≠humans, not physical 8p.
	gm.start_party_link("lantern_corridor", 8, 2)
	if int(gm.party_link_connected_humans) != 2:
		failures.append("dual connected_humans must be 2")
	if int(gm.ai_field_size) != 6:
		failures.append("dual field should be player + local P2 + 6 AI = 8")
	if int(gm.get_meta("party_link_local_extra_humans")) != 1:
		failures.append("party_link_local_extra_humans must be 1 for connected=2")
	var dual: Dictionary = gm.get_meta("party_link_runtime_roster")
	if int(dual.get("connected_humans", -1)) != 2:
		failures.append("dual roster connected_humans != 2")
	if int(dual.get("cpu_seats", -1)) != 6:
		failures.append("dual roster cpu_seats != 6")
	## Cap: connected beyond BeatLink sibling still clamps seats; never invent 8 humans here.
	gm.start_party_link("lantern_corridor", 8, 8)
	if int(gm.party_link_connected_humans) != 8:
		failures.append("roster may record connected=8 when requested")
	if int(gm.get_meta("party_link_local_extra_humans")) != 1:
		failures.append("local extra humans must stay BeatLink-sibling capped at 1")
	if int(gm.ai_field_size) != 6:
		failures.append("local field wiring stays sibling-2 even if allocated/connected ask for 8")

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
			"PartyLinkCapacityTest PASS — allocated 2..8 · connected honest · field 8 · BeatLink sibling 2 · bots≠humans · physical 8p false"
		)
		quit(0)
		return
	print("PartyLinkCapacityTest FAIL:")
	for f in failures:
		print(" - ", f)
	quit(1)
