# Reglas R8 de compatibilidad para la build de Play; la plantilla Godot 4.7.2 no las incluye.

# Play debe poder reconocer la llamada de GodotApp incluso después de R8.
-keep class androidx.activity.EdgeToEdge { public static void enable(...); }
-keepnames class androidx.activity.ComponentActivity
-keepnames class androidx.activity.SystemBarStyle

# Godot 4.7.2 busca estos tipos y métodos por nombre desde platform/android/*.cpp.
-keepnames class org.godotengine.godot.Godot
-keep class org.godotengine.godot.GodotIO { public <methods>; }
-keep class org.godotengine.godot.utils.GodotNetUtils { public <methods>; }
-keep class org.godotengine.godot.io.file.FileAccessHandler { public <methods>; }
-keep class org.godotengine.godot.io.directory.DirectoryAccessHandler { public <methods>; }
-keep class org.godotengine.godot.Dictionary { *; }
-keep class org.godotengine.godot.nativeapi.GodotNativeBridge { *; }
-keep class org.godotengine.godot.variant.Callable { *; }
-keep class org.godotengine.godot.tts.GodotTTS { *; }
-keep interface org.godotengine.godot.GodotRenderView { *; }
-keepclassmembers class * implements org.godotengine.godot.GodotRenderView {
    void configurePointerIcon(int,java.lang.String,float,float);
    void setPointerIcon(int);
    boolean canCapturePointer();
    void requestPointerCapture();
    void releasePointerCapture();
}
-keep class org.godotengine.godot.plugin.AndroidRuntimePlugin {
    static java.lang.Object createProxyFromGodotCallable(java.lang.String,org.godotengine.godot.variant.Callable);
    static java.lang.Object createProxyFromGodotObjectID(long,java.lang.String[]);
}

# Godot carga el plugin Android de Sentry desde el manifiesto y refleja sus métodos.
-keep class * extends org.godotengine.godot.plugin.GodotPlugin {
    public <init>(org.godotengine.godot.Godot);
}
-keep @interface org.godotengine.godot.plugin.UsedByGodot
-keepattributes LineNumberTable
-keepclassmembers class * {
    @org.godotengine.godot.plugin.UsedByGodot *;
}
