extends RefCounted
class_name StartGrid8

## Explicit 8 start-grid slots for Party Race (no AI fillers required).

const MAX_SLOTS := 8


static func slots(player_count: int) -> Array:
	var n := clampi(player_count, 2, MAX_SLOTS)
	var out: Array = []
	for i in range(n):
		var lane := -3.5 + float(i) * 1.0
		var row := float(i % 2) * 1.5
		out.append({"x": lane, "z": row, "yaw": 0.0, "seat": i})
	return out
