# Flutter
-keep class io.flutter.** { *; }

# MediaPipe
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# CameraX
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Camera plugin
-keep class io.flutter.plugins.camera.** { *; }

# OpenGL
-keep class android.opengl.** { *; }

# Media
-keep class android.media.** { *; }

# Play Core
-keep class com.google.android.play.core.** { *; }

# Google services
-keep class com.google.android.gms.** { *; }

# Keep debug info (important for MediaPipe)
-keepattributes SourceFile,LineNumberTable,Signature,EnclosingMethod,InnerClasses,*Annotation*
