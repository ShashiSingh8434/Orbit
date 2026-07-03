# ============================================================
# Flutter Play Core / Deferred Components (optional dependency)
# Flutter embedding references these classes but they are only
# needed if you use dynamic delivery / deferred components.
# Since this app does not use them, suppress R8 missing-class errors.
# ============================================================
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ============================================================
# WorkManager / Room - Fix for release crash:
# "Failed to create an instance of androidx.work.impl.WorkDatabase"
# R8 strips Room's auto-generated migration classes by default.
# ============================================================
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class * extends androidx.room.migration.Migration { *; }
-dontwarn androidx.work.**

# Keep Room generated _Impl classes
-keep class **_Impl { *; }
-keep class **_Impl$* { *; }

# AndroidX Startup
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }

# Firebase Firestore
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions
