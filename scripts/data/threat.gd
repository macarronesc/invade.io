extends RefCounted
class_name Threat

## Open-ended difficulty. Threat 0..1 is the original campaign curve and is handled by
## LevelDatabase.get_balance; everything above 1 grows here, softly capped so it never
## becomes unreadable. Each helper takes the raw threat and is neutral at or below 1.

static func over(threat: float) -> float:
	return maxf(0.0, threat - 1.0)

## Multiplier on enemy starting garrisons
static func troops(threat: float) -> float:
	return minf(1.0 + 0.12 * over(threat), 2.0)

## Multiplier on the three-star time: stronger armies reward faster wins
static func target_scale(threat: float) -> float:
	return maxf(1.0 - 0.08 * over(threat), 0.6)

## Applies the above-1 growth on top of a balance computed from the clamped threat
static func apply(balance: Dictionary, threat: float) -> void:
	var extra := over(threat)
	if extra <= 0.0:
		return
	balance["cadence"] = maxf(balance["cadence"] - 0.25 * extra, 1.5)
	balance["grace"] = maxf(balance["grace"] - 2.0 * extra, 4.0)
	balance["production"] = minf(balance["production"] + 0.15 * extra, 2.0)
	balance["actions"] = 3 if extra >= 1.0 else maxi(balance["actions"], 2)
	balance["joint_sources"] = 3
	balance["boss_interval"] = maxf(balance["boss_interval"] - 2.0 * extra, 14.0)
	balance["boss_reinforcement"] = mini(balance["boss_reinforcement"] + roundi(2.0 * extra), 20)
