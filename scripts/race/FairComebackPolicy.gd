class_name FairComebackPolicy
extends RefCounted

## Fair, bounded comeback tools — NEVER rubber-band speed or forced finish order.
## Position-weighted item odds favor recovery/defense for trailers without
## guaranteeing race-deciding offense. Competitive mode forbids hidden assists.

const COMPETITIVE_MAX_OFFENSE_WEIGHT := 1.15
const CASUAL_MAX_OFFENSE_WEIGHT := 1.35

## Item roles for fair weighting.
const ROLE_MOBILITY := "mobility"
const ROLE_DEFENSE := "defense"
const ROLE_DISRUPTION := "disruption"
const ROLE_HAZARD := "hazard"
const ROLE_RECOVERY := "recovery"

const ITEM_ROLES := {
	"turbo_toes": ROLE_MOBILITY,
	"sole_shield": ROLE_DEFENSE,
	"bounce_bubble": ROLE_RECOVERY,
	"lace_trap": ROLE_HAZARD,
	"pulse_horn": ROLE_DISRUPTION,
	"magnet_lace": ROLE_DISRUPTION,
}


static func is_competitive(game_manager: Object) -> bool:
	if game_manager == null:
		return false
	if bool(game_manager.get("competitive_mode")):
		return true
	var mode := str(game_manager.get("race_mode"))
	return mode in ["time_trial", "competitive", "ghost"]


static func hidden_rubber_banding_enabled(_game_manager: Object) -> bool:
	## Always false — explicit doctrine.
	return false


static func forced_finish_order_enabled(_game_manager: Object) -> bool:
	return false


static func competitive_speed_assist(_place: int, _field_size: int) -> float:
	## Forbidden: always 1.0 (no place-based speed).
	return 1.0


static func weighted_item_id(place: int, field_size: int, rng: RandomNumberGenerator, competitive: bool) -> String:
	var ids: Array = ItemData.all_alpha_ids()
	var weights: Array[float] = []
	var total := 0.0
	var place_ratio := 0.0
	if field_size > 1:
		place_ratio = float(place - 1) / float(field_size - 1)
	place_ratio = clampf(place_ratio, 0.0, 1.0)
	var max_off := COMPETITIVE_MAX_OFFENSE_WEIGHT if competitive else CASUAL_MAX_OFFENSE_WEIGHT
	for id in ids:
		var role := str(ITEM_ROLES.get(id, ROLE_MOBILITY))
		var w := 1.0
		match role:
			ROLE_DEFENSE, ROLE_RECOVERY:
				# Trailers get more recovery/defense opportunity.
				w = lerpf(0.85, 1.55, place_ratio)
			ROLE_MOBILITY:
				w = lerpf(1.05, 1.25, place_ratio)
			ROLE_DISRUPTION, ROLE_HAZARD:
				# Leaders get slightly more disruption; trailers still get some — never extreme.
				w = lerpf(max_off, 0.75, place_ratio)
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	var acc := 0.0
	for i in ids.size():
		acc += weights[i]
		if roll <= acc:
			return str(ids[i])
	return str(ids[ids.size() - 1])


static func evaluate_distribution(seed: int, races: int = 200, field_size: int = 4) -> Dictionary:
	## Seeded fairness eval — digital only, not human fairness claim.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var by_place: Dictionary = {}
	for place in range(1, field_size + 1):
		by_place[place] = {"defense_recovery": 0, "disruption": 0, "total": 0}
	for _r in races:
		for place in range(1, field_size + 1):
			var id := weighted_item_id(place, field_size, rng, true)
			var role := str(ITEM_ROLES.get(id, ROLE_MOBILITY))
			by_place[place]["total"] += 1
			if role in [ROLE_DEFENSE, ROLE_RECOVERY]:
				by_place[place]["defense_recovery"] += 1
			elif role in [ROLE_DISRUPTION, ROLE_HAZARD]:
				by_place[place]["disruption"] += 1
	var leader_disrupt_rate := float(by_place[1]["disruption"]) / maxf(1.0, float(by_place[1]["total"]))
	var trailer_recovery_rate := float(by_place[field_size]["defense_recovery"]) / maxf(1.0, float(by_place[field_size]["total"]))
	# Fair bounds: trailers get more recovery/defense than leaders; leaders not extreme disruption.
	var trailer_better_recovery := trailer_recovery_rate >= float(by_place[1]["defense_recovery"]) / maxf(1.0, float(by_place[1]["total"]))
	return {
		"seed": seed,
		"races": races,
		"field_size": field_size,
		"by_place": by_place,
		"leader_disruption_rate": snappedf(leader_disrupt_rate, 0.001),
		"trailer_recovery_rate": snappedf(trailer_recovery_rate, 0.001),
		"hidden_rubber_banding": false,
		"forced_finish_order": false,
		"fair_bounds_ok": trailer_better_recovery and leader_disrupt_rate < 0.65 and trailer_recovery_rate > 0.18,
	}
