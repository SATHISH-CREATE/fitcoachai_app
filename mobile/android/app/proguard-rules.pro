# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# MediaPipe (CRITICAL FIX FOR "NO CALLER FOUND")
# We MUST keep the names and the stack attributes for MediaPipe JNI
-keep class com.google.mediapipe.** { *; }
-keepnames class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keepattributes SourceFile,LineNumberTable,Signature,EnclosingMethod,InnerClasses,*Annotation*

# ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# OpenGL & Native (EXPLICIT KEEP FOR JNI)
-keep class android.opengl.** { *; }
-keep class com.google.fpl.liquidfun.** { *; }
-keep class com.google.protobuf.** { *; }

# CameraX / Camera Plugin
-keep class androidx.camera.** { *; }
-keep enum androidx.camera.** { *; }
-keep interface androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Google Play Services & Play Core
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.**

# Video & Plugins
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
