# =============================================================================
# ProGuard / R8 rules for kitchy_app
# =============================================================================
# Applied when minifyEnabled = true in the release build type.
# Even with minifyEnabled = false (current default), having this file ready
# prevents future breakage if shrinking is enabled.
# =============================================================================

# ---------------------------------------------------------------------------
# Flutter engine
# ---------------------------------------------------------------------------
-keep class io.flutter.app.**        { *; }
-keep class io.flutter.plugin.**     { *; }
-keep class io.flutter.util.**       { *; }
-keep class io.flutter.view.**       { *; }
-keep class io.flutter.**            { *; }
-keep class io.flutter.plugins.**    { *; }
-keep class io.flutter.embedding.**  { *; }

# ---------------------------------------------------------------------------
# flutter_secure_storage
# Without this rule, R8 strips the plugin registration class and causes:
# MissingPluginException(No implementation found for method read on channel
#   plugins.it_nomads.com/flutter_secure_storage)
# ---------------------------------------------------------------------------
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ---------------------------------------------------------------------------
# in_app_purchase / Google Play Billing Library
# ---------------------------------------------------------------------------
-keep class com.android.billingclient.**                      { *; }
-keep class com.google.android.gms.internal.play_billing.**   { *; }

# ---------------------------------------------------------------------------
# google_mobile_ads
# ---------------------------------------------------------------------------
-keep class com.google.android.gms.ads.**  { *; }
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.android.gms.common.annotation.KeepName *;
}

# ---------------------------------------------------------------------------
# image_picker
# ---------------------------------------------------------------------------
-keep class io.flutter.plugins.imagepicker.** { *; }

# ---------------------------------------------------------------------------
# share_plus
# ---------------------------------------------------------------------------
-keep class dev.fluttercommunity.plus.share.** { *; }

# ---------------------------------------------------------------------------
# General Android / Kotlin / Reflection
# ---------------------------------------------------------------------------
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable

# Kotlin coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
