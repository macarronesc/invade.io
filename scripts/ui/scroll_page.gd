extends ScrollContainer
class_name ScrollPage

## Sección desplazable del menú. Se reconstruye entera cuando cambian sus datos (todo cobro o
## compra emite coins_updated) y conserva la posición del scroll.
## Cada sección sólo implementa `_build()` añadiendo nodos a `content`.

var content := UIThemeHelper.vbox()

func _ready() -> void:
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	scroll_deadzone = UIThemeHelper.TOUCH_SCROLL_DEADZONE
	var margin := UIThemeHelper.page_margin(content, 8, 48)
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(margin)
	EventBus.coins_updated.connect(rebuild.unbind(1))
	rebuild()

func rebuild() -> void:
	var scroll := scroll_vertical
	UIThemeHelper.clear(content)
	_build()
	UIThemeHelper.pass_scroll_events(content)
	set_deferred("scroll_vertical", scroll)

func _build() -> void:
	pass
