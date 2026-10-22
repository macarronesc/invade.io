extends RefCounted
class_name LocaleStrings

## Acceso único a los textos traducidos. Las cadenas viven en locale/strings.csv,
## importado por Godot como recursos Translation; aquí sólo se resuelve la clave.
## Los nombres de ciudades viven en geo.json y los datos de juego usan claves
## estables (achievement_*, cosmetic_*, level_*...), nunca texto en español.

## Código canónico activo. Lo fija GameManager.set_language / _apply_save.
static var lang := LanguageCatalog.DEFAULT

static func set_locale(code: String) -> void:
	if not LanguageCatalog.is_supported(code):
		return
	lang = code
	TranslationServer.set_locale(code)

static func text(key: String) -> String:
	var translated := TranslationServer.translate(key)
	return translated if translated != "" else key

## Igual que text(), pero devuelve un texto de respaldo si la clave no existe.
## Útil para contenido opcional cuyo original no queremos mostrar como clave.
static func text_or(key: String, fallback: String) -> String:
	var translated := TranslationServer.translate(key)
	return translated if translated != key else fallback
