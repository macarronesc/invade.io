@tool
extends EditorPlugin
## Registers the `Aptabase` autoload singleton when the plugin is enabled.

const AUTOLOAD_NAME := "Aptabase"
const AUTOLOAD_PATH := "res://addons/aptabase/aptabase.gd"


func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
