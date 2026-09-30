extends RefCounted
class_name Icons

## Iconos SVG de trazo simple (rejilla de 24 px). Se dibujan en blanco y se tiñen con
## `modulate` o con los colores de icono del tema; los de COLORED traen su propio color.

const COLORED := ["coin", "star"]

const SVG := {
	"play": '<path d="M8 5v14l11-7z" fill="#fff" stroke="none"/>',
	"map": '<path d="M3 6.5l6-2.5 6 2.5 6-2.5v13.5l-6 2.5-6-2.5-6 2.5z"/><path d="M9 4v13.5M15 6.5V20"/>',
	"target": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.6" fill="#fff" stroke="none"/>',
	"shield": '<path d="M12 2.8l7.5 2.8v5.9c0 4.6-3.2 8.2-7.5 9.9-4.3-1.7-7.5-5.3-7.5-9.9V5.6z"/>',
	"trophy": '<path d="M7 3.5h10v5.5a5 5 0 0 1-10 0z"/><path d="M7 5.5H4v1.5a3 3 0 0 0 3 3M17 5.5h3v1.5a3 3 0 0 1-3 3M12 14v4.5M8 20.5h8"/>',
	"gear": '<circle cx="12" cy="12" r="7.6" stroke-width="3.6" stroke-dasharray="3 2.97" stroke-linecap="butt"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2.2"/>',
	"coin": '<circle cx="12" cy="12" r="10" fill="#FFC83D" stroke="#8A5C00" stroke-width="1.6"/><circle cx="12" cy="12" r="6" stroke="#8A5C00" stroke-width="1.8"/>',
	"star": '<path d="M12 2.6l2.9 6 6.5.9-4.7 4.6 1.1 6.5L12 17.5l-5.8 3.1 1.1-6.5-4.7-4.6 6.5-.9z" fill="#FFC83D" stroke="none"/>',
	"pause": '<rect x="6.5" y="5" width="3.6" height="14" rx="1.4" fill="#fff" stroke="none"/><rect x="13.9" y="5" width="3.6" height="14" rx="1.4" fill="#fff" stroke="none"/>',
	"back": '<path d="M15 5l-7 7 7 7" stroke-width="2.8"/>',
	"next": '<path d="M9 5l7 7-7 7" stroke-width="2.8"/>',
	"lock": '<rect x="5" y="10.5" width="14" height="10" rx="2.5" fill="#fff" stroke="none"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
	"check": '<path d="M5 12.5l4.5 4.5L19 7.5" stroke-width="3"/>',
	"retry": '<path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3"/><path d="M19.5 4.5v4.5H15"/>',
	"gift": '<rect x="3.5" y="8.5" width="17" height="4" rx="1"/><path d="M5.5 12.5v8h13v-8M12 8.5v12M12 8.5c-1.5-3.5-5.5-4-5.5-1.5 0 1.5 3 1.5 5.5 1.5zM12 8.5c1.5-3.5 5.5-4 5.5-1.5 0 1.5-3 1.5-5.5 1.5z"/>',
	"clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>',
	"globe": '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/>',
	"help": '<circle cx="12" cy="12" r="9"/><path d="M9.6 9.4a2.5 2.5 0 1 1 3.4 2.4c-.7.3-1 .8-1 1.6v.4"/><circle cx="12" cy="17" r="1.2" fill="#fff" stroke="none"/>',
	"sound": '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z" fill="#fff" stroke="none"/><path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11"/>',
	"music": '<path d="M9 18V6.5l10-2.5v11.5"/><circle cx="6.8" cy="18" r="2.4" fill="#fff" stroke="none"/><circle cx="16.8" cy="15.5" r="2.4" fill="#fff" stroke="none"/>',
	"bolt": '<path d="M13.5 2.5L5 13.5h6.5l-1 8 8.5-11h-6.5z" fill="#fff" stroke="none"/>',
	"speed": '<path d="M5 6l6 6-6 6M12.5 6l6 6-6 6" stroke-width="2.6"/>',
	"share": '<path d="M12 15V4M8 7.5l4-4 4 4M5 12v7.5h14V12"/>',
	"flag": '<path d="M5.5 21V4M5.5 4.5h12l-2.5 4 2.5 4h-12"/>',
	"close": '<path d="M6 6l12 12M18 6L6 18" stroke-width="2.6"/>',
	"toggle_on": '<rect x="1" y="5" width="22" height="14" rx="7" fill="#2F9BFF" stroke="none"/><circle cx="16" cy="12" r="5" fill="#fff" stroke="none"/>',
	"toggle_off": '<rect x="1" y="5" width="22" height="14" rx="7" fill="#2A3A54" stroke="none"/><circle cx="8" cy="12" r="5" fill="#8FA3BD" stroke="none"/>',
	"knob": '<circle cx="12" cy="12" r="10" fill="#fff" stroke="none"/>',
	"chevron_down": '<path d="M6 9l6 6 6-6" stroke-width="2.6"/>',
}

static var _cache: Dictionary = {}

## Textura del icono a `size` píxeles de alto (cacheada)
static func texture(name: String, size: int = 48) -> Texture2D:
	var key := "%s@%d" % [name, size]
	if not _cache.has(key):
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % SVG[name]
		var image := Image.new()
		image.load_svg_from_string(svg, size / 24.0)
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]

## Icono listo para colocar en un contenedor
static func rect(name: String, size: int = 48, color: Color = Color.WHITE) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture(name, size)
	icon.modulate = Color.WHITE if name in COLORED else color
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
