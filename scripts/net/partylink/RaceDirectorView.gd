extends RefCounted
class_name RaceDirectorView

## Large-display Race Director for 2–8 racers (lead pack / battles / finish).

var mode: String = "lead_pack"
var standings: Array = []
var gaps: Array = []
var lap: int = 1
var final_lap: bool = false
var overhead_insert: bool = true


func update_from_racers(racers: Array, total_laps: int = 3) -> void:
	var ordered: Array = racers.duplicate()
	ordered.sort_custom(func(a, b):
		var la := int(a.get("lap", 1))
		var lb := int(b.get("lap", 1))
		if la != lb:
			return la > lb
		return float(a.get("progress", 0.0)) > float(b.get("progress", 0.0))
	)
	standings.clear()
	gaps.clear()
	for i in range(mini(ordered.size(), 8)):
		var r: Dictionary = ordered[i]
		standings.append({
			"place": i + 1,
			"seat": r.get("seat", i),
			"name": r.get("name", "Racer"),
			"lap": r.get("lap", 1),
			"progress": r.get("progress", 0.0),
		})
	for i in range(1, standings.size()):
		gaps.append(maxf(0.0, float(standings[i - 1].get("progress", 0.0)) - float(standings[i].get("progress", 0.0))))
	if ordered.is_empty():
		return
	lap = 1
	for r in ordered:
		lap = maxi(lap, int(r.get("lap", 1)))
	final_lap = lap >= total_laps
	var lead: Dictionary = ordered[0]
	var pack := 0
	for r in ordered:
		if absf(float(r.get("progress", 0.0)) - float(lead.get("progress", 0.0))) < 0.08:
			pack += 1
	if final_lap and float(lead.get("progress", 0.0)) > 0.9:
		mode = "finish_line"
	elif pack >= 2:
		mode = "close_battle"
	else:
		mode = "lead_pack"


func hud_slots_ok(player_count: int) -> bool:
	return standings.size() == player_count and player_count >= 2 and player_count <= 8
