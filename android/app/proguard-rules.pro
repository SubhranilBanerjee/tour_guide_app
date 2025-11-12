# --- General Flutter & Android Keep Rules ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# --- Razorpay SDK Keep Rules ---
-keep class com.razorpay.** { *; }
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers
-dontwarn com.razorpay.**

# --- Suppress Warnings ---
-dontwarn javax.annotation.**
-dontwarn org.jetbrains.annotations.**
-ignorewarnings
