extends RefCounted
class_name LanguageCatalog

## Idiomas soportados por la interfaz. La fuente única es assets/data/languages.json
## (también la leen las herramientas de tools/): `native` se muestra siempre en su
## propia escritura, `script` elige la fuente y `dir` ajusta iconos direccionales.
## El orden es el del selector de Ajustes.

const DEFAULT := "en"
const DATA_PATH := "res://assets/data/languages.json"
const FONT_DIR := "res://assets/fonts/locale/"

static var _languages: Dictionary = {}
static var _scripts: Dictionary = {}
static var _codes: Array[String] = []
static var _aliases: Dictionary = {}
static var _name_fonts: Array[String] = []
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var res = load(DATA_PATH)
	if not res is JSON or not res.data is Dictionary:
		push_error("Language manifest missing or invalid: " + DATA_PATH)
		_languages[DEFAULT] = {"native": "English", "script": "latin", "dir": "ltr"}
		_codes.append(DEFAULT)
		return
	_scripts = res.data.get("scripts", {})
	for entry in res.data.get("languages", []):
		var code := str(entry["code"])
		_languages[code] = entry
		_codes.append(code)
		for alias in entry.get("aliases", []):
			_aliases[str(alias)] = code
	for script in _scripts.values():
		var file := str(script["names"])
		if not _name_fonts.has(file):
			_name_fonts.append(file)

static func codes() -> Array[String]:
	_ensure_loaded()
	return _codes.duplicate()

static func is_supported(code: String) -> bool:
	_ensure_loaded()
	return _languages.has(code)

## Normaliza "es_MX", "pt-PT", "in_ID" o "zh_Hans_CN" al código soportado más cercano.
static func normalize(raw: String) -> String:
	_ensure_loaded()
	# standardize_locale also maps the legacy codes Android reports ("in" -> "id", "iw" -> "he").
	var code := TranslationServer.standardize_locale(raw.replace("-", "_"))
	var parts := code.split("_")
	for i in range(parts.size(), 0, -1):
		var candidate := "_".join(parts.slice(0, i))
		if _languages.has(candidate):
			return candidate
		if _aliases.has(candidate):
			return _aliases[candidate]
	return ""

## Idioma del sistema si está soportado; si no, inglés.
static func preferred_from_system() -> String:
	var match := normalize(OS.get_locale())
	return match if match != "" else DEFAULT

static func native_name(code: String) -> String:
	return str(_entry(code)["native"])

static func is_rtl(code: String) -> bool:
	return str(_entry(code)["dir"]) == "rtl"

static func script_of(code: String) -> String:
	return str(_entry(code)["script"])

## Fuente de subconjunto del idioma ("" si el manifiesto no la define).
static func font_file(code: String) -> String:
	_ensure_loaded()
	return str(_scripts.get(script_of(code), {}).get("font", ""))

## True si la fuente del idioma debe ir antes que la base (cubre letras que Fredoka no tiene).
static func uses_primary_font(code: String) -> bool:
	_ensure_loaded()
	return bool(_scripts.get(script_of(code), {}).get("primary", false))

## Fuentes con los nombres nativos de todos los idiomas, siempre disponibles como respaldo
## para que el selector de idioma se vea completo en cualquier idioma activo.
static func name_fonts() -> Array[String]:
	_ensure_loaded()
	return _name_fonts

static func _entry(code: String) -> Dictionary:
	_ensure_loaded()
	if _languages.has(code):
		return _languages[code]
	return _languages[DEFAULT]
