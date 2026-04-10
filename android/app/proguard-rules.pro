# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Isar
-keep class dev.isar.** { *; }

# Google Sign-In + Drive APIs
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.** { *; }
-keep class com.google.api.client.** { *; }

# flutter_local_notifications (uses Gson reflection)
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# mobile_scanner / MLKit
-keep class com.google.mlkit.** { *; }

# Suppress warnings
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
