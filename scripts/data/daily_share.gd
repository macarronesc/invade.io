extends RefCounted
class_name DailyShare

static func text(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	var date := Time.get_date_string_from_unix_time(int(result["day"]) * 86400)
	return "invade.io · %s · %s\n%s · %ds · ×%.1f\n🟦🟦🟦 %s" % [
		LocaleStrings.text("daily_share"), date,
		UIThemeHelper.star_rating(clampi(int(result["stars"]), 1, 3)),
		ceili(float(result["time"])), float(result.get("speed", 1.0)),
		LocaleStrings.text("share_invite")]
