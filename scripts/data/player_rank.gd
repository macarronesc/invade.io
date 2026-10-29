extends RefCounted
class_name PlayerRank

## Rango del jugador: sube con la XP de batallas y misiones. No da ventajas en combate;
## algunos rangos regalan estética (ver CosmeticsDatabase, campo "rank").

const TITLE_COUNT := 10

static func level(xp: int) -> int:
	return 1 + floori(sqrt(maxi(0, xp) / 100.0))

## XP con la que empieza un nivel
static func level_start(p_level: int) -> int:
	return 100 * (p_level - 1) * (p_level - 1)

## Nombre del rango; pasado el último, "Mariscal 2", "Mariscal 3"...
static func title(p_level: int) -> String:
	var count := TITLE_COUNT
	var i := clampi(p_level - 1, 0, count - 1)
	var name := LocaleStrings.text("rank_%d" % (i + 1))
	var extra := p_level - count
	return name if extra <= 0 else "%s %d" % [name, extra + 1]

## Fracción del nivel actual ya recorrida con `xp` (0..1)
static func progress(xp: int) -> float:
	var l := level(xp)
	return float(xp - level_start(l)) / float(level_start(l + 1) - level_start(l))
