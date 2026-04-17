# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# MediaPipe (THE DEFINITIVE FIX)
# We must preserve ALL names and attributes for MediaPipe to work with JNI
-keep class com.google.mediapipe.** { *; }
-dontobfuscate class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Plugin Keep: The caller 'R1.l' suggests the plugin itself is being obfuscated.
# We must keep the plugin code that calls MediaPipe.
-keep class com.google.mediapipe.tasks.** { *; }
-keep class com.google.mediapipe.framework.** { *; }

# CRITICAL: MediaPipe native code performs stack trace analysis.
# We MUST keep these attributes for the entire app or at least the calling packages.
-keepattributes SourceFile,LineNumberTable,Signature,EnclosingMethod,InnerClasses,*Annotation*

# ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# OpenGL & Native
-keep class android.opengl.** { *; }
-keep class com.google.fpl.liquidfun.** { *; }
-keep class com.google.protobuf.** { *; }

# CameraX
-keep class androidx.camera.** { *; }
-keep enum androidx.camera.** { *; }
-keep interface androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Google Play Services & Play Core
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.**

# Video & Notifications
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
