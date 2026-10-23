# Reglas R8 de compatibilidad para la build de Play; la plantilla Godot 4.7.2 no las incluye.
# El motor llama a Java por JNI. Sentry en este proyecto es una GDExtension nativa, fuera del alcance de R8.

# Protect Godot Engine Core
-keep class com.godot.** { *; }
-keep class org.godotengine.** { *; }
-keep class ** extends org.godotengine.godot.plugin.GodotPlugin { *; }
# Protect methods exposed to Godot via @UsedByGodot
-keepattributes *Annotation*,Signature,SourceFile,LineNumberTable
-keepclassmembers class * {
    @org.godotengine.godot.plugin.UsedByGodot *;
}

# Protect JNI bindings
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
