# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# JNI-based plugins (package:jni — path_provider_android, and
# shared_preferences_android >= 2.5.0) look these Kotlin classes up by name
# from Dart; renamed by R8 they fail at runtime with NoSuchMethodError
# (flutter/flutter#194649, dart-lang/native#3732).
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }

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
