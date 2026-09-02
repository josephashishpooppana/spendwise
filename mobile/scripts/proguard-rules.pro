# Keep Google Play Services / Sign-In classes in release builds (R8 minification).
-keep class io.flutter.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class androidx.** { *; }
