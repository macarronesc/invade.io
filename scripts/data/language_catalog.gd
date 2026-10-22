extends RefCounted
class_name LanguageCatalog

## Idiomas soportados por la interfaz. `native` se muestra siempre en su propia
## escritura; `script` elige la fuente de respaldo y `dir` permite ajustar iconos
## direccionales. El orden es el del selector de Ajustes.

const DEFAULT := "en"

const LANGUAGES := {
	"en": {"native": "English", "script": "latin", "dir": "ltr"},
	"es": {"native": "Español", "script": "latin", "dir": "ltr"},
	"pt_BR": {"native": "Português (Brasil)", "script": "latin", "dir": "ltr"},
	"fr": {"native": "Français", "script": "latin", "dir": "ltr"},
	"de": {"native": "Deutsch", "script": "latin", "dir": "ltr"},
	"it": {"native": "Italiano", "script": "latin", "dir": "ltr"},
	"ru": {"native": "Русский", "script": "cyrillic", "dir": "ltr"},
	"tr": {"native": "Türkçe", "script": "latin_ext", "dir": "ltr"},
	"ar": {"native": "العربية", "script": "arabic", "dir": "rtl"},
	"hi": {"native": "हिन्दी", "script": "devanagari", "dir": "ltr"},
	"id": {"native": "Bahasa Indonesia", "script": "latin", "dir": "ltr"},
	"vi": {"native": "Tiếng Việt", "script": "latin_ext", "dir": "ltr"},
	"zh_CN": {"native": "简体中文", "script": "cjk_sc", "dir": "ltr"},
	"ja": {"native": "日本語", "script": "cjk_jp", "dir": "ltr"},
	"ko": {"native": "한국어", "script": "cjk_kr", "dir": "ltr"},
}

## OS locales and old two-letter codes that map onto a supported UI locale.
const ALIASES := {
	"en": "en", "es": "es", "pt": "pt_BR", "pt_PT": "pt_BR",
	"fr": "fr", "de": "de", "it": "it", "ru": "ru", "tr": "tr",
	"ar": "ar", "hi": "hi", "id": "id", "vi": "vi",
	"zh": "zh_CN", "zh_Hans": "zh_CN", "zh_Hant": "zh_CN",
	"ja": "ja", "ko": "ko",
}

static func codes() -> Array[String]:
	var out: Array[String] = []
	for code in LANGUAGES:
		out.append(code)
	return out

static func is_supported(code: String) -> bool:
	return LANGUAGES.has(code)

## Normaliza "es_MX", "pt-PT" o "zh_Hans_CN" al código soportado más cercano.
static func normalize(raw: String) -> String:
	var code := raw.replace("-", "_")
	if LANGUAGES.has(code):
		return code
	var parts := code.split("_")
	for i in range(parts.size(), 0, -1):
		var candidate := "_".join(parts.slice(0, i))
		if LANGUAGES.has(candidate):
			return candidate
		if ALIASES.has(candidate):
			return ALIASES[candidate]
	return ""

## Idioma del sistema si está soportado; si no, inglés.
static func preferred_from_system() -> String:
	var match := normalize(OS.get_locale())
	return match if match != "" else DEFAULT

static func native_name(code: String) -> String:
	return str(LANGUAGES.get(code, LANGUAGES[DEFAULT])["native"])

static func is_rtl(code: String) -> bool:
	return str(LANGUAGES.get(code, LANGUAGES[DEFAULT])["dir"]) == "rtl"

static func script_of(code: String) -> String:
	return str(LANGUAGES.get(code, LANGUAGES[DEFAULT])["script"])
