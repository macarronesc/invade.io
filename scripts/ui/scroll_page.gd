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
	margin.resized.connect(UIThemeHelper.cap_page_width.bind(margin))
	add_child(margin)
	EventBus.coins_updated.connect(rebuild.unbind(1))
	rebuild()

func rebuild() -> void:
	var scroll := scroll_vertical
	var buttons := content.find_children("*", "BaseButton", true, false).filter(func(button): return not button.disabled)
	var viewport := get_viewport()
	var focus_index := buttons.find(viewport.gui_get_focus_owner()) if viewport else -1
	UIThemeHelper.clear(content)
	_build()
	UIThemeHelper.pass_scroll_events(content)
	set_deferred("scroll_vertical", scroll)
	if focus_index >= 0:
		call_deferred("_restore_focus", focus_index)

func _restore_focus(index: int) -> void:
	var buttons := content.find_children("*", "BaseButton", true, false).filter(func(button): return not button.disabled)
	if not buttons.is_empty():
		(buttons[mini(index, buttons.size() - 1)] as Control).grab_focus()

func _build() -> void:
	pass
