# ProGuard / R8 rules for uniro1

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Deferred Components / Play Core
-dontwarn com.google.android.play.core.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# App's own package: MainActivity MethodChannel handlers, home-screen
# widget providers and TimeChangeReceiver (all referenced from the
# manifest or via channels; keeps release minification from stripping them).
-keep class dev.sudoguy.uniro.** { *; }

# flutter_local_notifications README (v18 "Release build configuration"):
# GSON rules from the plugin's example proguard-rules.pro. The plugin
# uses GSON for scheduled-notification persistence; without these,
# release builds can silently drop rescheduled notifications.
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Java 8 desugaring
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-dontwarn java.time.**
