extends RefCounted
class_name DailyRewards

## DailyRewards: reglas de la recompensa diaria con racha y del desafío diario.
## Funciones puras sobre "días" (número de día local desde 1970), fáciles de probar sin reloj.

## Oro por día de racha (el 7º día es el premio gordo y la racha vuelve a empezar el ciclo)
const STREAK_REWARDS = [50, 75, 100, 125, 150, 200, 300]
const DAILY_CHALLENGE_GOLD := 150
const DAILY_CHALLENGE_PREFIX := "daily_"
## Dificultad fija del desafío (mitad de la campaña: IA media y algunos neutrales extra)
const CHALLENGE_DIFFICULTY := 0.5

## Día local actual (cambia a medianoche en la zona horaria del dispositivo)
static func today() -> int:
	var d := Time.get_datetime_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day}) / 86400)

## Estado de la recompensa: {"can_claim", "streak" (tras reclamar hoy), "reward"}
static func evaluate(last_claim_day: int, streak: int, day: int) -> Dictionary:
	# day < last_claim_day: reloj atrasado; no se paga hasta volver al día del último cobro
	if day <= last_claim_day:
		return {"can_claim": false, "streak": streak, "reward": 0}
	var new_streak := streak + 1 if last_claim_day == day - 1 else 1
	return {"can_claim": true, "streak": new_streak, "reward": reward_for_streak(new_streak)}

static func reward_for_streak(streak: int) -> int:
	return STREAK_REWARDS[(maxi(streak, 1) - 1) % STREAK_REWARDS.size()]

static func challenge_id(day: int) -> String:
	return "%s%d" % [DAILY_CHALLENGE_PREFIX, day]

static func is_challenge(level_id: String) -> bool:
	return level_id.begins_with(DAILY_CHALLENGE_PREFIX)

static func challenge_day(level_id: String) -> int:
	return int(level_id.substr(DAILY_CHALLENGE_PREFIX.length()))
