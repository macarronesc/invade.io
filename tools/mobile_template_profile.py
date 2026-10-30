"""Conservative Compatibility-only engine profile; used only by opt-in CI candidates."""
optimize = "size"
lto = "thin"
debug_symbols = False
disable_3d = True
disable_physics_2d = True
disable_navigation_2d = True
vulkan = False
metal = False
opengl3 = True
# Keep SVG, advanced text, GUI dialogs, TLS, threading and GDExtensions: the game uses them.
