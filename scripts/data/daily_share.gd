extends RefCounted
class_name DailyShare

const URL := "https://macarronesc.github.io/invade.io/play/?utm_source=share&utm_medium=daily"
const APP_URL := "https://macarronesc.github.io/invade.io/play/?utm_source=app&utm_medium=settings"

## Tarjeta de texto para pegar en un chat (emojis: se verán en cualquier aplicación)
static func text(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	var date := Time.get_date_string_from_unix_time(int(result["day"]) * 86400)
	var stars := clampi(int(result["stars"]), 1, 3)
	return "invade.io · %s · %s · v%d\n%s · %ds · ×%.1f\n%s\n🎯 %s\n%s" % [
		LocaleStrings.text("daily_share"), date,
		int(result.get("balance_version", DailyRewards.BALANCE_VERSION)),
		"⭐".repeat(stars) + "☆".repeat(3 - stars),
		ceili(float(result["time"])), float(result.get("speed", 1.0)),
		LocaleStrings.text("daily_normalized"),
		LocaleStrings.text("share_invite"), URL]
